#!/usr/bin/env python3

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import json
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait


def git(args: list[str], repo: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def is_local_config_commit(index_dir: Path, commit: str) -> bool:
    try:
        changed = git(
            ["diff-tree", "--no-commit-id", "--name-only", "-r", commit], index_dir
        )
    except subprocess.CalledProcessError:
        return False
    files = [line for line in changed.splitlines() if line]
    return files == ["config.json"]


def resolve_upstream_head(index_dir: Path) -> str:
    head = git(["rev-parse", "HEAD"], index_dir)
    if not is_local_config_commit(index_dir, head):
        return head
    try:
        return git(["rev-parse", f"{head}^"], index_dir)
    except subprocess.CalledProcessError:
        return head


def iter_index_files(index_dir: Path):
    for path in index_dir.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(index_dir)
        if rel.parts[0] == ".git":
            continue
        if rel.name == "config.json":
            continue
        yield path


def changed_index_files_by_mtime(index_dir: Path, previous_sync_ns: int) -> list[Path]:
    paths = []
    for path in iter_index_files(index_dir):
        if path.stat().st_mtime_ns > previous_sync_ns:
            paths.append(path)
    return paths


def changed_index_files(index_dir: Path, previous: str, current: str) -> list[Path]:
    output = git(["diff", "--name-only", previous, current, "--"], index_dir)
    paths = []
    for name in output.splitlines():
        if not name or name == "config.json" or name.startswith(".git/"):
            continue
        path = index_dir / name
        if path.is_file():
            paths.append(path)
    return paths


def parse_entries(index_file: Path):
    with index_file.open() as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError as exc:
                raise RuntimeError(
                    f"{index_file}:{line_number}: invalid json: {exc}"
                ) from exc
            name = payload["name"]
            version = payload["vers"]
            checksum = payload["cksum"]
            yield name, version, checksum


def crate_target(crates_dir: Path, name: str, version: str) -> Path:
    return crates_dir / name / f"{name}-{version}.crate"


def download_url(base: str, name: str, version: str) -> str:
    return f"{base.rstrip('/')}/{name}/{name}-{version}.crate"


def verify_sha256(path: Path, checksum: str) -> bool:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest() == checksum


def fetch_one(
    crates_dir: Path,
    base_url: str,
    item: tuple[str, str, str],
    user_agent: str,
    retries: int,
    timeout: int,
) -> str:
    name, version, checksum = item
    target = crate_target(crates_dir, name, version)
    if target.exists():
        return "present"

    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=target.name + ".", suffix=".tmp", dir=target.parent
    )
    os.close(fd)
    tmp_path = Path(tmp_name)
    url = download_url(base_url, name, version)
    last_error = None
    for attempt in range(retries + 1):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": user_agent})
            with (
                urllib.request.urlopen(request, timeout=timeout) as response,
                tmp_path.open("wb") as handle,
            ):
                shutil.copyfileobj(response, handle, length=1024 * 1024)
            if not verify_sha256(tmp_path, checksum):
                raise RuntimeError(f"checksum mismatch for {name} {version}")
            os.replace(tmp_path, target)
            return "downloaded"
        except (urllib.error.URLError, OSError, RuntimeError) as exc:
            last_error = exc
            if attempt == retries:
                break
            if tmp_path.exists():
                tmp_path.unlink()
            fd, tmp_name = tempfile.mkstemp(
                prefix=target.name + ".", suffix=".tmp", dir=target.parent
            )
            os.close(fd)
            tmp_path = Path(tmp_name)

    if tmp_path.exists():
        tmp_path.unlink()
    raise RuntimeError(f"failed to fetch {name} {version} from {url}: {last_error}")


def sync_crates(
    crates_dir: Path,
    base_url: str,
    items: list[tuple[str, str, str]],
    user_agent: str,
    jobs: int,
    retries: int,
    timeout: int,
) -> tuple[int, int, int]:
    downloaded = 0
    present = 0
    failed = 0
    if not items:
        return downloaded, present, failed

    with ThreadPoolExecutor(max_workers=jobs) as executor:
        pending = {
            executor.submit(
                fetch_one, crates_dir, base_url, item, user_agent, retries, timeout
            ): item
            for item in items
        }
        while pending:
            done, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in done:
                item = pending.pop(future)
                try:
                    result = future.result()
                except Exception as exc:
                    print(
                        f"[ERROR] sync failed for {item[0]} {item[1]}: {exc}"
                    )
                    failed += 1
                    continue
                if result == "downloaded":
                    downloaded += 1
                else:
                    present += 1
    return downloaded, present, failed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", required=True)
    parser.add_argument("--crates", required=True)
    parser.add_argument("--state", required=True)
    args = parser.parse_args()

    index_dir = Path(args.index)
    crates_dir = Path(args.crates)
    state_dir = Path(args.state)
    state_dir.mkdir(parents=True, exist_ok=True)

    upstream_head = resolve_upstream_head(index_dir)
    previous_file = state_dir / "last_upstream_commit"
    previous_sync_file = state_dir / "last_successful_sync_ns"
    previous = previous_file.read_text().strip() if previous_file.exists() else None
    previous_sync_ns = (
        int(previous_sync_file.read_text().strip())
        if previous_sync_file.exists()
        else None
    )
    jobs = max(1, int(os.environ.get("CRATES_JOBS", "4")))
    retries = max(0, int(os.environ.get("CRATES_RETRY", "2")))
    timeout = max(1, int(os.environ.get("CRATES_TIMEOUT", "60")))
    dry_run = os.environ.get("CRATES_DRY_RUN", "false").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }
    upstream_base = os.environ.get(
        "CRATES_FILES_UPSTREAM", "https://static.crates.io/crates"
    )
    user_agent = os.environ.get(
        "CRATES_USER_AGENT", "ustcmirror-crates-io/1 (+https://mirrors.ustc.edu.cn)"
    )

    if previous is None:
        files = list(iter_index_files(index_dir))
    else:
        if previous == upstream_head:
            print("[INFO] index unchanged, no crate downloads needed")
            previous_sync_file.write_text(str(time.time_ns()) + "\n")
            return 0
        try:
            files = changed_index_files(index_dir, previous, upstream_head)
        except subprocess.CalledProcessError:
            if previous_sync_ns is None:
                print(
                    "[WARN] git diff failed and no previous sync timestamp found; scanning full index"
                )
                files = list(iter_index_files(index_dir))
            else:
                print("[WARN] git diff failed, falling back to index file mtime scan")
                files = changed_index_files_by_mtime(index_dir, previous_sync_ns)
                if not files:
                    print(
                        "[WARN] mtime fallback found no changed files; scanning full index"
                    )
                    files = list(iter_index_files(index_dir))

    seen = set()
    items = []
    for path in files:
        for item in parse_entries(path):
            if item in seen:
                continue
            seen.add(item)
            items.append(item)

    if dry_run:
        print(
            f"[INFO] dry run: files={len(files)} entries={len(items)} previous={previous or '-'} current={upstream_head}"
        )
        return 0

    downloaded, present, failed = sync_crates(
        crates_dir, upstream_base, items, user_agent, jobs, retries, timeout
    )
    if failed == 0:
        previous_file.write_text(upstream_head + "\n")
        previous_sync_file.write_text(str(time.time_ns()) + "\n")
    print(
        f"[INFO] crates sync complete: files={len(files)} entries={len(items)} downloaded={downloaded} present={present} failed={failed}"
    )
    if failed != 0:
        print("[WARN] sync state is not written as there are failed crates.")
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[FATAL] {exc}", file=sys.stderr)
        raise
