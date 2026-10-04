use anyhow::{Context, Result, bail, ensure};
use reqwest::Url;
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};

pub const API_BASE: &str = "https://formulae.brew.sh/api/";
pub const API_FILES: &[&str] = &[
    "formula.json",
    "cask.json",
    "formula.jws.json",
    "cask.jws.json",
    "formula_tap_migrations.jws.json",
    "cask_tap_migrations.jws.json",
    "internal/executables.txt",
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Blob {
    pub url: Url,
    pub digest: String,
    pub path: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Manifest {
    pub url: Url,
    pub path: String,
    pub digests: BTreeSet<String>,
}

#[derive(Default)]
pub struct Plan {
    pub blobs: BTreeMap<String, Blob>,
    pub manifests: BTreeMap<String, Manifest>,
    pub api: BTreeMap<String, Vec<u8>>,
    pub platforms: BTreeSet<String>,
}

impl Plan {
    fn add_document(&mut self, path: String, document: &Value) -> Result<()> {
        ensure!(
            !self.api.contains_key(&path),
            "duplicate API document {path}"
        );
        self.api.insert(path, serde_json::to_vec(document)?);
        Ok(())
    }

    fn add_blob(&mut self, blob: Blob) -> Result<()> {
        if let Some(old) = self.blobs.get(&blob.path) {
            ensure!(
                old.digest == blob.digest,
                "conflicting target {}",
                blob.path
            );
        } else {
            self.blobs.insert(blob.path.clone(), blob);
        }
        Ok(())
    }

    fn add_formula(&mut self, formula: &Value) -> Result<()> {
        let name = component(field(formula, "name")?)?;
        self.add_document(format!("api/formula/{name}.json"), formula)?;

        // Keep disabled formula metadata, but do not mirror its bottles or manifests.
        if formula["disabled"] == true {
            return Ok(());
        }

        let versions = &formula["versions"];
        let has_bottle = versions["bottle"]
            .as_bool()
            .context("missing versions.bottle")?;
        if !has_bottle {
            return Ok(());
        }

        let version = component(field(versions, "stable")?)?;
        let stable = &formula["bottle"]["stable"];
        let files = stable["files"]
            .as_object()
            .with_context(|| format!("{name}: missing bottle.stable.files"))?;
        let revision = number(formula, "revision")?;
        let rebuild = number(stable, "rebuild")?;
        let package_version = if revision == 0 {
            version.to_owned()
        } else {
            format!("{version}_{revision}")
        };
        let rebuild_suffix = if rebuild == 0 {
            String::new()
        } else {
            format!(".{rebuild}")
        };

        let mut expected = BTreeSet::new();
        for (platform, info) in files {
            component(platform)?;
            let sha256 = digest(field(info, "sha256")?)?;
            expected.insert(sha256.clone());
            if platform != "all" {
                self.platforms.insert(platform.clone());
            }
            self.add_blob(Blob {
                url: url(field(info, "url")?)?,
                digest: sha256,
                path: format!("{name}-{package_version}.{platform}.bottle{rebuild_suffix}.tar.gz"),
            })?;
        }

        let manifest = make_manifest(
            name,
            &package_version,
            rebuild,
            field(stable, "root_url")?,
            expected,
        )?;
        if let Some(old) = self.manifests.get(&manifest.path) {
            ensure!(old == &manifest, "conflicting manifest {}", manifest.path);
        } else {
            self.manifests.insert(manifest.path.clone(), manifest);
        }
        Ok(())
    }

    fn add_cask(&mut self, cask: &Value) -> Result<()> {
        let token = component(field(cask, "token")?)?;
        self.add_document(format!("api/cask/{token}.json"), cask)
    }
}

pub fn plan(formula: &[u8], cask: &[u8]) -> Result<Plan> {
    let formula: Value = serde_json::from_slice(formula).context("formula.json")?;
    let cask: Value = serde_json::from_slice(cask).context("cask.json")?;
    let formula = formula
        .as_array()
        .context("formula.json must be an array")?;
    let cask = cask.as_array().context("cask.json must be an array")?;
    ensure!(
        !formula.is_empty() && !cask.is_empty(),
        "empty formula/cask inventory"
    );

    let mut plan = Plan::default();
    for entry in formula {
        plan.add_formula(entry)
            .with_context(|| format!("formula {}", entry["name"]))?;
    }
    for entry in cask {
        plan.add_cask(entry)
            .with_context(|| format!("cask {}", entry["token"]))?;
    }
    Ok(plan)
}

fn make_manifest(
    name: &str,
    version: &str,
    rebuild: u64,
    root: &str,
    digests: BTreeSet<String>,
) -> Result<Manifest> {
    // Homebrew maps @ to a path separator and + to x in OCI image names.
    let image = name.replace('@', "/").replace('+', "x");
    let tag = if rebuild == 0 {
        version.to_owned()
    } else {
        format!("{version}-{rebuild}")
    };
    // Homebrew validates OCI tags without rewriting the version.
    ensure!(
        tag.len() <= 128
            && tag
                .as_bytes()
                .first()
                .is_some_and(|c| c.is_ascii_alphanumeric() || *c == b'_')
            && tag
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || b"._-".contains(&c)),
        "invalid OCI tag: {tag}"
    );

    let mut url = url(&format!("{}/", root.trim_end_matches('/')))?;
    {
        let mut segments = url
            .path_segments_mut()
            .map_err(|_| anyhow::anyhow!("invalid root URL"))?;
        segments.pop_if_empty();
        for segment in image.split('/') {
            segments.push(segment);
        }
        segments.push("manifests").push(&tag);
    }
    Ok(Manifest {
        url,
        path: format!("api/manifests/{}_{}.json", image.replace('/', "@"), tag),
        digests,
    })
}

fn component(s: &str) -> Result<&str> {
    ensure!(
        !s.is_empty()
            && s != "."
            && s != ".."
            && !s.contains(['/', '\\', '\0'])
            && !s.chars().any(char::is_control),
        "unsafe filename component: {s:?}"
    );
    Ok(s)
}

fn field<'a>(value: &'a Value, name: &str) -> Result<&'a str> {
    value
        .get(name)
        .and_then(Value::as_str)
        .with_context(|| format!("missing string {name}"))
}

fn number(value: &Value, name: &str) -> Result<u64> {
    value
        .get(name)
        .and_then(Value::as_u64)
        .with_context(|| format!("missing integer {name}"))
}

pub fn digest(s: &str) -> Result<String> {
    ensure!(
        s.len() == 64 && s.bytes().all(|c| c.is_ascii_hexdigit()),
        "invalid SHA256: {s:?}"
    );
    Ok(s.to_ascii_lowercase())
}

fn url(s: &str) -> Result<Url> {
    let url = Url::parse(s)?;
    ensure!(
        matches!(url.scheme(), "http" | "https"),
        "unsupported URL: {s}"
    );
    Ok(url)
}

pub fn manifest_covers(bytes: &[u8], expected: &BTreeSet<String>) -> Result<bool> {
    let v: Value = serde_json::from_slice(bytes)?;
    ensure!(v["schemaVersion"] == 2, "unsupported manifest schema");
    let entries = v["manifests"]
        .as_array()
        .context("missing manifests array")?;
    let mut actual = BTreeSet::new();
    for entry in entries {
        if let Some(s) = entry["annotations"]["sh.brew.bottle.digest"].as_str() {
            actual.insert(digest(s)?);
        }
    }
    Ok(expected.is_subset(&actual))
}

pub fn validate_api(name: &str, bytes: &[u8]) -> Result<()> {
    if name.ends_with(".json") {
        let v: Value = serde_json::from_slice(bytes).with_context(|| name.to_owned())?;
        if name.ends_with(".jws.json") {
            ensure!(
                v["payload"].as_str().is_some_and(|s| !s.is_empty())
                    && v["signatures"].as_array().is_some_and(|s| !s.is_empty()),
                "invalid JWS envelope: {name}"
            );
        }
    } else if name == "internal/executables.txt" {
        std::str::from_utf8(bytes).context("executables.txt is not UTF-8")?;
    } else {
        bail!("unexpected API file {name}");
    }
    Ok(())
}
