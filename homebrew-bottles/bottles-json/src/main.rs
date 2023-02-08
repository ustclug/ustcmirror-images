// #![feature(try_trait)]

use std::{collections::HashSet, fs::File, path::PathBuf};

use clap::{Parser, ValueEnum};
use serde::Deserialize;
use serde_json::Value;

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

#[derive(ValueEnum, Clone)]
enum Mode {
    GetBottlesMetadata,
    ExtractJson,
}

#[derive(ValueEnum, Clone)]
enum Type {
    Forumla,
    Cask,
}

#[derive(Parser)]
struct Cli {
    /// Choose from get-bottles-metadata (default) or extract-json
    #[arg(long, value_enum, default_value_t=Mode::GetBottlesMetadata)]
    mode: Mode,

    /// The folder to extract json to, required when mode is extract-json
    #[arg(long)]
    folder: Option<PathBuf>,

    /// Choose from formula (default) or cask
    #[arg(long, value_enum, default_value_t=Type::Forumla)]
    type_: Type,
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
                    revision = if f.revision == 0 {
                        "".to_owned()
                    } else {
                        format!("_{}", f.revision)
                    },
                    platform = platform,
                    rebuild = if bs.rebuild == 0 {
                        "".to_owned()
                    } else {
                        format!(".{}", bs.rebuild)
                    },
                );
            }
        }
    }
    Some(())
}

fn e(f: &Value, name: &str, target: &PathBuf) -> Option<()> {
    let tmp_name = format!("{}.json.new", name);
    let final_name = format!("{}.json", name);

    {
        let file = File::create(target.join(tmp_name.clone())).unwrap();
        serde_json::to_writer(file, f).unwrap();
    }
    std::fs::rename(target.join(tmp_name), target.join(final_name)).unwrap();
    Some(())
}

fn main() {
    let cli = Cli::parse();

    match cli.mode {
        Mode::GetBottlesMetadata => {
            let f: Formulae = serde_json::from_reader(std::io::stdin()).unwrap();
            for f in f.0 {
                if d(&f).is_none() {
                    eprintln!("Failed to parse formula: {}", f.name);
                }
            }
        }
        Mode::ExtractJson => {
            // Handle API json weak-typed here, as it may cause too much trouble to write all types of all fields
            let f: Value = serde_json::from_reader(std::io::stdin()).unwrap();
            let target_dir = cli
                .folder
                .expect("target folder is required as an argument");
            let mut existing_jsons = std::fs::read_dir(&target_dir)
                .unwrap()
                .filter_map(|e| {
                    Some(
                        e.unwrap()
                            .file_name()
                            .into_string()
                            .unwrap()
                            .strip_suffix(".json")?
                            .to_owned(),
                    )
                })
                .collect::<HashSet<_>>();
            for f in f.as_array().unwrap() {
                let fname = match cli.type_ {
                    Type::Forumla => &f["name"],
                    Type::Cask => &f["token"],
                };
                let fname = fname.as_str().unwrap();
                if e(f, fname, &target_dir).is_none() {
                    eprintln!("Failed to extract json: {}", fname);
                }
                existing_jsons.remove(fname);
            }
            // Clean unused jsons
            for fname in existing_jsons {
                std::fs::remove_file(target_dir.join(format!("{}.json", fname))).unwrap();
            }
        }
    }
}
