use serde::Deserialize;
use serde_json::{Result, Value};

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
    rebuild: u8,
    files: Value,
}
#[derive(Deserialize)]
struct Formula {
    name: String,
    versions: Versions,
    bottle: Bottle,
}

#[derive(Deserialize)]
struct Formulae(Vec<Formula>);

#[derive(Deserialize)]
struct BottleInfo {
    url: String,
    sha256: String,
}

fn main() -> Result<()> {
    let f: Formulae = serde_json::from_reader(std::io::stdin())?;
    for f in f.0 {
        if f.versions.bottle {
            let name = f.name;
            let ver = f.versions.stable.unwrap();
            let bs = f.bottle.stable.as_ref().unwrap();
            let rebuild = bs.rebuild;
            for (platform, v) in bs
                .files
                .as_object()
                .unwrap()
                .iter()
            {
                let v: BottleInfo = serde_json::from_value(v.clone()).unwrap();
                //a2ps-4.14.arm64_big_sur.bottle.4.tar.gz
                println!(
                    "{} {} bottles/{}-{}.{}.bottle.{}.tar.gz",
                    v.sha256, v.url, name, ver, platform, rebuild
                );
            }
        }
    }
    Ok(())
}
