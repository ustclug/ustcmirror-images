use crate::storage::Store;
use anyhow::{Context, Result, bail, ensure};
use futures_util::StreamExt;
use reqwest::{Client, StatusCode, Url, header};
use sha2::{Digest, Sha256};
use std::{io::Write, net::IpAddr, time::Duration};
use tempfile::NamedTempFile;

pub struct Downloader {
    api: Client,
    bottles: Client,
    debug: bool,
}

impl Downloader {
    pub fn new(api_bind: Option<IpAddr>, bind: Option<IpAddr>, debug: bool) -> Result<Self> {
        fn client(bind: Option<IpAddr>, gzip: bool) -> Result<Client> {
            Ok(Client::builder()
                .use_rustls_tls()
                .local_address(bind)
                .gzip(gzip)
                .connect_timeout(Duration::from_secs(30))
                .timeout(Duration::from_secs(600))
                .user_agent(concat!(
                    "ustcmirror-homebrew-sync/",
                    env!("CARGO_PKG_VERSION")
                ))
                .redirect(reqwest::redirect::Policy::limited(10))
                .build()?)
        }
        Ok(Self {
            api: client(api_bind, true)?,
            bottles: client(bind, false)?,
            debug,
        })
    }

    pub async fn fetch(
        &self,
        store: &Store,
        url: &Url,
        api: bool,
        expected: Option<&str>,
    ) -> Result<NamedTempFile> {
        for attempt in 0..3 {
            if attempt > 0 {
                tokio::time::sleep(Duration::from_secs(1 << (attempt - 1))).await;
            }
            if self.debug {
                eprintln!("[DEBUG] GET {url} attempt {}", attempt + 1);
            }
            let mut request = if api { &self.api } else { &self.bottles }.get(url.clone());
            if !api {
                request = request.header(header::ACCEPT, "application/vnd.oci.image.index.v1+json");
                if url.host_str() == Some("ghcr.io") {
                    request = request.header(header::AUTHORIZATION, "Bearer QQ==");
                }
            }
            let response = match request.send().await {
                Ok(r) => r,
                Err(e) if attempt < 2 => {
                    eprintln!("[WARN] retry {url}: {e}");
                    continue;
                }
                Err(e) => return Err(e).with_context(|| url.to_string()),
            };
            let status = response.status();
            if !status.is_success() {
                if attempt < 2
                    && (status.is_server_error()
                        || status == StatusCode::TOO_MANY_REQUESTS
                        || status == StatusCode::REQUEST_TIMEOUT)
                {
                    if let Some(delay) = response
                        .headers()
                        .get(header::RETRY_AFTER)
                        .and_then(|s| s.to_str().ok())
                        .and_then(|s| s.parse::<u64>().ok())
                    {
                        tokio::time::sleep(Duration::from_secs(delay.min(60))).await;
                    }
                    eprintln!("[WARN] retry {url}: HTTP {status}");
                    continue;
                }
                bail!("GET {url}: HTTP {status}");
            }
            let mut file = store.temporary()?;
            let mut hash = Sha256::new();
            let mut stream = response.bytes_stream();
            let mut error = None;
            while let Some(chunk) = stream.next().await {
                match chunk {
                    Ok(chunk) => {
                        file.write_all(&chunk).context("write downloaded data")?;
                        hash.update(&chunk);
                    }
                    Err(e) => {
                        error = Some(e);
                        break;
                    }
                }
            }
            if let Some(e) = error {
                if attempt < 2 {
                    eprintln!("[WARN] retry interrupted body {url}: {e}");
                    continue;
                }
                return Err(e).with_context(|| url.to_string());
            }
            if let Some(expected) = expected {
                let actual = format!("{:x}", hash.finalize());
                ensure!(
                    actual == expected,
                    "SHA256 mismatch for {url}: expected {expected}, got {actual}"
                );
            }
            return Ok(file);
        }
        unreachable!()
    }
}
