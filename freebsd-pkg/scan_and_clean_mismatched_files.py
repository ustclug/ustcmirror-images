#!/usr/bin/env python3
import os
from pathlib import Path
import argparse
import subprocess
import json
import itertools

TO = Path(os.environ["TO"])


def main(args):
    # 1. scan TO/.by-hash dir to get sha256sum and inode mapping
    by_hash_dir = TO / ".by-hash"
    inode_to_hash: dict[int, str] = {}
    for hash_file in os.scandir(by_hash_dir):
        if hash_file.is_file():
            inode_to_hash[hash_file.inode()] = hash_file.name

    # 2. scan metadata files to get expected sha256sum and name mapping
    path_to_hash: dict[Path, str] = {}
    for packagesite_file in TO.rglob("*/*/packagesite.tzst"):
        subprocess.run(
            [
                "tar",
                "-C",
                "/tmp",
                "--zstd",
                "-xf",
                str(packagesite_file),
                "packagesite.yaml",
            ],
            check=True,
        )
        with open("/tmp/packagesite.yaml", "r") as f:
            for line in f:
                line = json.loads(line)
                hash_value = line["sum"]
                repopath: str = line["repopath"]  # like All/xxx.pkg
                repopath_full = (packagesite_file.parent / repopath).absolute()
                path_to_hash[repopath_full] = hash_value
        os.remove("/tmp/packagesite.yaml")

    def scan_pkg_file(pkg_file: os.DirEntry[str]):
        pathname = Path(pkg_file.path)
        inode = pkg_file.inode()
        if inode not in inode_to_hash:
            print(f"[WARNING] file {pathname} not found in .by-hash")
            return
        actual_hash = inode_to_hash[inode]
        expected_hash = path_to_hash.get(pathname)
        if expected_hash is None:
            print(f"[WARNING] file {pathname} not found in metadata")
            if not args.dry_run:
                print(f"[INFO] deleting untracked file {pathname}")
                os.remove(pathname)
            return
        if actual_hash != expected_hash:
            print(
                f"[MISMATCH] file {pathname} has hash {actual_hash}, expected {expected_hash}"
            )
            if not args.dry_run:
                print(f"[INFO] deleting mismatched file {pathname}")
                os.remove(pathname)

    # 3. scan existing packages and check for mismatches
    for all_path in TO.rglob("*/*/All"):
        for pkg_file in os.scandir(all_path):
            scan_pkg_file(pkg_file)

    for all_path in TO.rglob("*/*/"):
        for file in os.scandir(all_path):
            if file.name.startswith("FreeBSD-") and file.name.endswith(".pkg"):
                scan_pkg_file(file)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Scan and clean mismatched files in the FreeBSD pkg mirror."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Perform a dry run without deleting files.",
    )
    args = parser.parse_args()
    main(args)
