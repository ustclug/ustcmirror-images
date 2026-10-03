use crate::{
    download::Downloader,
    metadata::{self, Blob, Manifest},
    storage::Store,
};
use anyhow::{Context, Result, ensure};
use flate2::{Compression, write::GzEncoder};
use futures_util::{StreamExt, stream};
use reqwest::Url;
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    io::Write,
};

#[derive(Default, Debug)]
struct Summary {
    downloaded: usize,
    skipped: usize,
    failed: usize,
    deleted: usize,
}

async fn fetch_api(
    store: &Store,
    downloader: &Downloader,
    name: &str,
    base: &Url,
) -> Result<Vec<u8>> {
    let url = base.join(name)?;
    let file = downloader.fetch(store, &url, true, None).await?;
    let bytes = fs::read(file.path())?;
    metadata::validate_api(name, &bytes)?;
    Ok(bytes)
}

async fn sync_blobs(store: &Store, downloader: &Downloader, group: &[Blob]) -> Result<bool> {
    let first = &group[0];
    let dir = if first.cask {
        "api/cask-source/.by-hash"
    } else {
        ".by-hash"
    };
    let cache = store.path(&format!("{dir}/{}", first.digest));
    let exists = fs::symlink_metadata(&cache).is_ok_and(|m| m.file_type().is_file());
    if !exists {
        let file = downloader
            .fetch(store, &first.url, first.cask, Some(&first.digest))
            .await?;
        store.install(file, &cache)?;
    }
    for blob in group {
        store.link(&cache, &blob.path)?;
    }
    Ok(!exists)
}

async fn sync_manifest(store: &Store, downloader: &Downloader, m: &Manifest) -> Result<bool> {
    if fs::read(store.path(&m.path))
        .is_ok_and(|bytes| metadata::manifest_covers(&bytes, &m.digests).unwrap_or(false))
    {
        return Ok(false);
    }
    let file = downloader.fetch(store, &m.url, false, None).await?;
    ensure!(
        metadata::manifest_covers(&fs::read(file.path())?, &m.digests)?,
        "manifest {} does not cover expected bottle digests",
        m.url
    );
    store.install(file, &store.path(&m.path))?;
    Ok(true)
}

fn record(summary: &mut Summary, result: Result<bool>, label: &str) {
    match result {
        Ok(true) => {
            summary.downloaded += 1;
            println!("[INFO] downloaded {label}");
        }
        Ok(false) => summary.skipped += 1,
        Err(e) => {
            summary.failed += 1;
            eprintln!("[WARN] {label}: {e:#}");
        }
    }
}

pub async fn run(store: &Store, downloader: &Downloader, jobs: usize, base: &Url) -> Result<()> {
    let plan = prepare(store, downloader, base).await?;
    let mut keep: BTreeSet<String> = plan.api.keys().cloned().collect();
    let mut groups: BTreeMap<(bool, String), Vec<Blob>> = BTreeMap::new();
    for blob in plan.blobs.into_values() {
        keep.insert(blob.path.clone());
        groups
            .entry((blob.cask, blob.digest.clone()))
            .or_default()
            .push(blob);
    }

    for manifest in plan.manifests.values() {
        keep.insert(manifest.path.clone());
    }

    let mut summary = Summary::default();
    println!(
        "[INFO] syncing {} content hashes and {} manifests",
        groups.len(),
        plan.manifests.len()
    );
    let mut pending =
        stream::iter(groups.values().map(|group| async move {
            (sync_blobs(store, downloader, group).await, &group[0].path)
        }))
        .buffer_unordered(jobs);
    while let Some((result, path)) = pending.next().await {
        record(&mut summary, result, path);
    }

    let mut pending = stream::iter(
        plan.manifests
            .values()
            .map(|m| async move { (sync_manifest(store, downloader, m).await, &m.path) }),
    )
    .buffer_unordered(jobs);
    while let Some((result, path)) = pending.next().await {
        record(&mut summary, result, path);
    }

    println!("[INFO] publishing API");
    for (path, bytes) in &plan.api {
        // Yield between files so termination can interrupt publication and suppress cleanup.
        tokio::task::yield_now().await;
        if let Err(e) = store.publish(path, bytes).with_context(|| path.clone()) {
            summary.failed += 1;
            eprintln!("[WARN] publish: {e:#}");
        }
    }

    if summary.failed == 0 {
        tokio::task::yield_now().await;
        summary.deleted = store.clean(&keep).await?;
    } else {
        eprintln!("[WARN] skipping obsolete-file cleanup because this run had failures");
    }

    println!(
        "[INFO] downloaded={} skipped={} failed={} deleted={}",
        summary.downloaded, summary.skipped, summary.failed, summary.deleted
    );
    ensure!(summary.failed == 0, "{} resources failed", summary.failed);
    Ok(())
}

async fn prepare(store: &Store, downloader: &Downloader, base: &Url) -> Result<metadata::Plan> {
    println!("[INFO] fetching API inventory");
    let mut documents = BTreeMap::new();
    for name in metadata::API_FILES {
        documents.insert(
            format!("api/{name}"),
            fetch_api(store, downloader, name, base).await?,
        );
    }

    let mut plan = metadata::plan(
        &documents["api/formula.json"],
        &documents["api/cask.json"],
        base,
    )?;
    for platform in &plan.platforms {
        let name = format!("internal/packages.{platform}.jws.json");
        documents.insert(
            format!("api/{name}"),
            fetch_api(store, downloader, &name, base).await?,
        );
    }

    let mut compressed = BTreeMap::new();
    for (path, bytes) in &documents {
        // Precompress downloaded API files, including platform indexes.
        // Split formula/cask documents retain their original uncompressed layout.
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(bytes)?;
        compressed.insert(format!("{path}.gz"), encoder.finish()?);
    }

    plan.api.extend(documents);
    plan.api.extend(compressed);
    Ok(plan)
}
