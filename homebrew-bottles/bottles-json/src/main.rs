use std::{
    collections::HashSet,
    fs::File,
    io::{Read, Write},
    path::{Path, PathBuf},
};

use clap::{Parser, ValueEnum};

use serde_json::Value;

mod structs;
use structs::*;

#[derive(ValueEnum, Clone)]
enum Mode {
    /// List all bottles that need to check and download
    /// Output format: sha256 url bottle_file.tar.gz
    GetBottlesMetadata,
    /// Extract cask/formula json files to folder
    ExtractJson,
    /// List all cask source files that need to check and download
    /// Output format: sha256 url cask_source_file.rb
    ListCaskSource,
}

#[derive(ValueEnum, Clone)]
enum Type {
    Formula,
    Cask,
}

#[derive(Parser)]
struct Cli {
    /// Parse metadata or extract json to api folder
    #[arg(long, value_enum, default_value_t=Mode::GetBottlesMetadata)]
    mode: Mode,

    /// The folder to extract json to, required when mode is extract-json
    #[arg(long)]
    folder: Option<PathBuf>,

    /// Formula and cask json has different attribute for its name ("name" or "token")
    #[arg(long, value_enum, default_value_t=Type::Formula)]
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

fn e(f: &Value, name: &str, target: &Path) -> Option<()> {
    let tmp_name = format!("{}.json.new", name);
    let final_name = format!("{}.json", name);
    let contents = serde_json::to_string(f).unwrap();

    {
        // is it the same as existing file?
        // this is to avoid unnecessary file metadata modification
        let mut existing = String::new();
        if let Ok(mut file) = File::open(target.join(final_name.clone())) {
            if let Err(e) = file.read_to_string(&mut existing) {
                eprintln!("Failed to read existing file {}: {}", final_name, e);
            } else if existing == contents {
                return Some(());
            }
        }
    }

    {
        let mut file = File::create(target.join(tmp_name.clone())).unwrap();
        file.write_all(contents.as_bytes()).unwrap();
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
                    Type::Formula => &f["name"],
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
        Mode::ListCaskSource => {
            let f: Casks = serde_json::from_reader(std::io::stdin()).unwrap();
            for f in f.0 {
                let filename = Path::new(&f.ruby_source_path)
                    .file_name()
                    .unwrap()
                    .to_str()
                    .unwrap();
                let url = format!("https://formulae.brew.sh/api/cask-source/{}", filename);
                let url = urlencoding::encode(&url);
                println!(
                    "{} {} {}",
                    f.ruby_source_checksum.sha256, url, filename
                );
            }
        }
    }
}
