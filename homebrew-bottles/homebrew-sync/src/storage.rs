use anyhow::{Context, Result, ensure};
use std::{
    collections::BTreeSet,
    fs::{self, File},
    io::Write,
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
};
use tempfile::{NamedTempFile, TempDir};

pub struct Store {
    root: PathBuf,
    temp: TempDir,
    _lock: File,
}

impl Store {
    pub fn open(root: &Path) -> Result<Self> {
        fs::create_dir_all(root)?;
        let root = fs::canonicalize(root)?;
        let state = root.join(".homebrew-sync");
        fs::create_dir_all(&state)?;
        ensure!(
            !fs::symlink_metadata(&state)?.file_type().is_symlink(),
            "state directory is a symlink"
        );
        let lock = File::options()
            .create(true)
            .truncate(false)
            .write(true)
            .open(state.join("lock"))?;
        lock.try_lock().context("another sync is already running")?;

        // Only this program's private staging area is removed after acquiring the lock.
        let staging = state.join("tmp");
        if staging.exists() {
            fs::remove_dir_all(&staging)?;
        }
        fs::create_dir(&staging)?;
        let temp = tempfile::tempdir_in(staging)?;
        let store = Self {
            root,
            temp,
            _lock: lock,
        };
        for dir in [
            ".by-hash",
            "api",
            "api/formula",
            "api/cask",
            "api/manifests",
            "api/internal",
        ] {
            store.directory(dir)?;
        }
        Ok(store)
    }

    fn directory(&self, relative: &str) -> Result<()> {
        let mut current = self.root.clone();
        for part in Path::new(relative).components() {
            current.push(part);
            if !current.exists() {
                fs::create_dir(&current)?;
            }
            ensure!(
                fs::symlink_metadata(&current)?.file_type().is_dir(),
                "not a regular directory: {}",
                current.display()
            );
        }
        Ok(())
    }

    pub fn path(&self, relative: &str) -> PathBuf {
        self.root.join(relative)
    }

    pub fn temporary(&self) -> Result<NamedTempFile> {
        Ok(NamedTempFile::new_in(self.temp.path())?)
    }

    pub fn publish(&self, relative: &str, bytes: &[u8]) -> Result<bool> {
        let path = self.path(relative);
        if fs::read(&path).is_ok_and(|old| old == bytes) {
            return Ok(false);
        }
        let mut tmp = self.temporary()?;
        tmp.write_all(bytes)?;
        self.install(tmp, &path)?;
        Ok(true)
    }

    pub fn install(&self, tmp: NamedTempFile, path: &Path) -> Result<()> {
        // tempfile defaults to 0600; files served by nginx need to remain readable.
        tmp.as_file()
            .set_permissions(fs::Permissions::from_mode(0o644))?;
        tmp.persist(path)
            .with_context(|| format!("publish {}", path.display()))?;
        Ok(())
    }

    pub fn link(&self, cache: &Path, relative: &str) -> Result<()> {
        let path = self.path(relative);
        let a = fs::metadata(cache)?;
        if fs::symlink_metadata(&path)
            .is_ok_and(|b| b.is_file() && a.dev() == b.dev() && a.ino() == b.ino())
        {
            return Ok(());
        }
        let tmp = self.temporary()?.into_temp_path();
        fs::remove_file(&tmp)?;
        fs::hard_link(cache, &tmp)?;
        fs::rename(&tmp, &path)?;
        Ok(())
    }

    pub async fn clean(&self, keep: &BTreeSet<String>) -> Result<usize> {
        let mut deleted = 0;
        for (dir, suffix) in [
            ("", ".bottle"),
            ("api/formula", ".json"),
            ("api/cask", ".json"),
            ("api/manifests", ".json"),
            ("api/internal", ".jws.json"),
        ] {
            for entry in fs::read_dir(self.path(dir))? {
                tokio::task::yield_now().await;
                let entry = entry?;
                if !entry.file_type()?.is_file() {
                    continue;
                }
                let name = entry.file_name();
                let Some(name) = name.to_str() else {
                    continue;
                };
                let managed = if dir.is_empty() {
                    name.contains(suffix) && name.ends_with(".tar.gz")
                } else if dir == "api/internal" {
                    name.starts_with("packages.")
                        && (name.ends_with(suffix) || name.ends_with(".jws.json.gz"))
                } else {
                    name.ends_with(suffix)
                };
                let relative = if dir.is_empty() {
                    name.to_owned()
                } else {
                    format!("{dir}/{name}")
                };
                if managed && !keep.contains(&relative) {
                    fs::remove_file(entry.path())?;
                    deleted += 1;
                }
            }
        }

        for entry in fs::read_dir(self.path(".by-hash"))? {
            tokio::task::yield_now().await;
            let entry = entry?;
            let name = entry.file_name();
            let name = name.to_string_lossy();
            let metadata = fs::symlink_metadata(entry.path())?;
            if metadata.is_file()
                && metadata.nlink() == 1
                && (crate::metadata::digest(&name).is_ok() || name.ends_with(".tmp"))
            {
                fs::remove_file(entry.path())?;
                deleted += 1;
            }
        }
        Ok(deleted)
    }
}
