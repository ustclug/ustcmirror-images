use anyhow::{Context, Result, ensure};
use std::{env, net::IpAddr, path::PathBuf};

pub struct Config {
    pub root: PathBuf,
    pub jobs: usize,
    pub bind: Option<IpAddr>,
    pub api_bind: Option<IpAddr>,
    pub debug: bool,
    pub api_base: reqwest::Url,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        let bind = address("BIND_ADDRESS")?;
        let jobs = env::var("HOMEBREW_BOTTLES_JOBS")
            .unwrap_or_else(|_| "1".into())
            .parse()
            .context("HOMEBREW_BOTTLES_JOBS must be a positive integer")?;
        ensure!(jobs > 0, "HOMEBREW_BOTTLES_JOBS must be positive");
        Ok(Self {
            api_base: {
                let base = env::var("HOMEBREW_API_BASE")
                    .unwrap_or_else(|_| crate::metadata::API_BASE.into());
                let url = reqwest::Url::parse(&format!("{}/", base.trim_end_matches('/')))?;
                ensure!(
                    matches!(url.scheme(), "http" | "https"),
                    "API base must be HTTP(S)"
                );
                url
            },
            root: env::var_os("TO")
                .map(PathBuf::from)
                .unwrap_or_else(|| "/data".into()),
            jobs,
            bind,
            api_bind: address("BREW_SH_BIND_ADDRESS")?.or(bind),
            debug: env::var("DEBUG").is_ok_and(|s| s == "true"),
        })
    }
}

fn address(name: &str) -> Result<Option<IpAddr>> {
    env::var(name)
        .ok()
        .filter(|s| !s.is_empty())
        .map(|s| s.parse().with_context(|| format!("invalid {name}: {s}")))
        .transpose()
}
