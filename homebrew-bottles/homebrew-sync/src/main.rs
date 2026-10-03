use anyhow::{Context, Result};
use homebrew_sync::{config::Config, download::Downloader, storage::Store, sync};
use tokio::signal::unix::{SignalKind, signal};

#[tokio::main]
async fn main() -> std::process::ExitCode {
    match run().await {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("[ERROR] {e:#}");
            std::process::ExitCode::FAILURE
        }
    }
}

async fn run() -> Result<()> {
    let config = Config::from_env()?;
    let store = Store::open(&config.root)?;
    let download = Downloader::new(config.api_bind, config.bind, config.debug)?;
    let mut term = signal(SignalKind::terminate())?;
    let mut interrupt = signal(SignalKind::interrupt())?;
    let mut hangup = signal(SignalKind::hangup())?;
    tokio::select! {
        result = sync::run(&store, &download, config.jobs, &config.api_base) => result.context("synchronization failed"),
        _ = term.recv() => anyhow::bail!("terminated; skipping cleanup"),
        _ = interrupt.recv() => anyhow::bail!("interrupted; skipping cleanup"),
        _ = hangup.recv() => anyhow::bail!("hangup; skipping cleanup"),
    }
}
