#![feature(try_trait)]

use serde::Deserialize;

#[derive(Deserialize)]
struct Versions {
    stable: Option<String>,
    bottle: bool,
}

#[derive(Deserialize)]
struct Bottle {
    stable: Option<BottleStable>,
}

#[derive(Deserialize)]
struct BottleStable {
    rebuild: u64,
    files: serde_json::Value,
}

#[derive(Deserialize)]
struct Formula {
    name: String,
    versions: Versions,
    bottle: Bottle,
    revision: u64,
}

#[derive(Deserialize)]
struct Formulae(Vec<Formula>);

#[derive(Deserialize)]
struct BottleInfo {
    url: String,
    sha256: String,
}

fn d(f: &Formula) -> Option<()> {
    if f.versions.bottle {
        let bs = f.bottle.stable.as_ref()?;
        for (platform, v) in bs.files.as_object()?.iter() {
            if let Ok(bi) = serde_json::from_value::<BottleInfo>(v.clone()) {
                println!(
                    "{sha256} {url} {name}-{version}{revision}.{platform}.bottle{rebuild}.tar.gz",
                    sha256 = bi.sha256,
                    url = bi.url,
                    name = f.name,
                    version = f.versions.stable.as_ref()?,
                    revision = if f.revision == 0 { "".to_owned() } else { format!("_{}", f.revision) },
                    platform = platform,
                    rebuild = if bs.rebuild == 0 { "".to_owned() } else { format!(".{}", bs.rebuild) },
                );
            }
        }
    }
    Some(())
}

fn main() {
    let f: Formulae = serde_json::from_reader(std::io::stdin()).unwrap();
    for f in f.0 {
        d(&f);
    }
}
