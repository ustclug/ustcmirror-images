use serde::Deserialize;

// Formulae struct types

/// formula.version
#[derive(Deserialize)]
pub struct Versions {
    pub stable: Option<String>,
    pub bottle: bool,
}

/// formula.bottle.stable.files.<some_platform>
#[derive(Deserialize)]
pub struct BottleInfo {
    pub url: String,
    pub sha256: String,
}

/// formula.bottle.stable
#[derive(Deserialize)]
pub struct BottleStable {
    pub rebuild: u64,
    pub files: serde_json::Value,
}

/// formula.bottle
#[derive(Deserialize)]
pub struct Bottle {
    pub stable: Option<BottleStable>,
}

/// formula (one object)
#[derive(Deserialize)]
pub struct Formula {
    pub name: String,
    pub versions: Versions,
    pub bottle: Bottle,
    pub revision: u64,
}

/// formula.json (array of formula)
#[derive(Deserialize)]
pub struct Formulae(pub Vec<Formula>);

/// cask.ruby_source_checksum
#[derive(Deserialize)]
pub struct SourceChecksum {
    pub sha256: String,
}

/// cask (one object)
#[derive(Deserialize)]
pub struct Cask {
    pub ruby_source_path: String,
    pub ruby_source_checksum: SourceChecksum,
}

/// cask.json (array of cask)
#[derive(Deserialize)]
pub struct Casks(pub Vec<Cask>);
