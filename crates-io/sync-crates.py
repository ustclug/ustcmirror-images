#!/usr/bin/env python3

import argparse
import io
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
from tqdm import tqdm

from utils_crates import iter_index_files, is_tracked_index_file

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
        if not name:
            continue
        rel = Path(name)
        if not is_tracked_index_file(rel):
            continue
        path = index_dir / rel
        if path.is_file():
            paths.append(path)
    return paths


def iter_index_files_in_commit(index_dir: Path, commit: str) -> list[Path]:
    output = git(["ls-tree", "-r", "--name-only", commit], index_dir)
    paths = []
    for name in output.splitlines():
        if not name:
            continue
        rel = Path(name)
        if is_tracked_index_file(rel):
            paths.append(rel)
    return paths


def parse_entry_lines(lines, source: str):
    for line_number, line in enumerate(lines, start=1):
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"{source}:{line_number}: invalid json: {exc}") from exc
        name = payload["name"]
        version = payload["vers"]
        checksum = payload["cksum"]
        yield name, version, checksum


def parse_entries(index_file: Path):
    with index_file.open(encoding="utf-8") as handle:
        yield from parse_entry_lines(handle, str(index_file))


def parse_entries_from_git(index_dir: Path, commit: str, index_files):
    process = subprocess.Popen(
        ["git", "-C", str(index_dir), "cat-file", "--batch"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdin is not None
    assert process.stdout is not None
    assert process.stderr is not None

    try:
        for rel in index_files:
            spec = f"{commit}:{rel.as_posix()}\n".encode()
            process.stdin.write(spec)
            process.stdin.flush()

            header = process.stdout.readline()
            if not header:
                raise RuntimeError(
                    f"git cat-file terminated unexpectedly while reading {rel}"
                )

            stripped = header.rstrip(b"\n")
            if stripped.endswith(b" missing"):
                raise RuntimeError(f"missing index file in git tree: {commit}:{rel}")

            try:
                _, object_type, object_size = stripped.split(b" ", 2)
            except ValueError as exc:
                raise RuntimeError(
                    f"invalid git cat-file header for {commit}:{rel}: {header!r}"
                ) from exc
            if object_type != b"blob":
                raise RuntimeError(
                    f"unexpected git object type for {commit}:{rel}: {object_type.decode()}"
                )

            size = int(object_size)
            data = process.stdout.read(size)  # BufferedReader.read(n) returns
            if len(data) != size:  # exactly n bytes unless EOF — OK
                raise RuntimeError(
                    f"short read from git cat-file for {commit}:{rel}: "
                    f"expected {size} bytes, got {len(data)}"
                )
            if process.stdout.read(1) != b"\n":
                raise RuntimeError(
                    f"invalid git cat-file payload terminator for {commit}:{rel}"
                )

            with io.TextIOWrapper(io.BytesIO(data), encoding="utf-8") as handle:
                yield from parse_entry_lines(handle, f"{commit}:{rel.as_posix()}")

        process.stdin.close()
        stderr = process.stderr.read().decode("utf-8", errors="replace")
        returncode = process.wait()
        if returncode != 0:
            raise subprocess.CalledProcessError(
                returncode, process.args, stderr=stderr.strip()
            )
    finally:
        if process.poll() is None:  # still running -> abandoned early
            process.kill()
            process.wait()
        for stream in (process.stdin, process.stdout, process.stderr):
            try:
                stream.close()
            except OSError:
                pass


def crate_target(crates_dir: Path, name: str, version: str) -> Path:
    return crates_dir / name / f"{name}-{version}.crate"


def download_url(base: str, name: str, version: str) -> str:
    return f"{base.rstrip('/')}/{name}/{name}-{version}.crate"


# def verify_sha256(path: Path, checksum: str) -> bool:
#     digest = hashlib.sha256()
#     with path.open("rb") as handle:
#         for chunk in iter(lambda: handle.read(1024 * 1024), b""):
#             digest.update(chunk)
#     return digest.hexdigest() == checksum


def fetch_one(
    crates_dir: Path,
    base_url: str,
    item: tuple[str, str, str],
) -> str:
    name, version, _checksum = item
    target = crate_target(crates_dir, name, version)
    if target.exists():
        return "present"

    url = download_url(base_url, name, version)
    tqdm.write(f"[INFO] downloading {url}")
    if dry_run:
        return "downloaded"

    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=target.name + ".", suffix=".tmp", dir=target.parent
    )
    os.close(fd)
    tmp_path = Path(tmp_name)

    last_error = None
    for attempt in range(retries + 1):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": user_agent})
            with (
                urllib.request.urlopen(request, timeout=timeout) as response,
                tmp_path.open("wb") as handle,
            ):
                shutil.copyfileobj(response, handle, length=1024 * 1024)
            # if not verify_sha256(tmp_path, checksum):
            #     raise RuntimeError(f"checksum mismatch for {name} {version}")
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
) -> tuple[int, int, int]:
    downloaded = 0
    present = 0
    failed = 0
    if not items:
        return downloaded, present, failed

    with (
        ThreadPoolExecutor(max_workers=jobs) as executor,
        tqdm(
            total=len(items), desc="crates", unit="crate", dynamic_ncols=True
        ) as progress,
    ):
        pending = {
            executor.submit(
                fetch_one,
                crates_dir,
                base_url,
                item,
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
                    tqdm.write(f"[ERROR] sync failed for {item[0]} {item[1]}: {exc}")
                    failed += 1
                else:
                    if result == "downloaded":
                        downloaded += 1
                    else:
                        present += 1
                progress.update(1)
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

    if previous is None:
        files = iter_index_files_in_commit(index_dir, upstream_head)
        use_git_full_scan = True
    else:
        use_git_full_scan = False
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
                files = iter_index_files_in_commit(index_dir, upstream_head)
                use_git_full_scan = True
            else:
                print("[WARN] git diff failed, falling back to index file mtime scan")
                files = changed_index_files_by_mtime(index_dir, previous_sync_ns)
                if not files:
                    print(
                        "[WARN] mtime fallback found no changed files; scanning full index"
                    )
                    files = iter_index_files_in_commit(index_dir, upstream_head)
                    use_git_full_scan = True

    seen = set()
    items = []
    if use_git_full_scan:
        entry_iter = parse_entries_from_git(index_dir, upstream_head, tqdm(files))
    else:
        entry_iter = (item for path in tqdm(files) for item in parse_entries(path))

    for item in entry_iter:
        if item in seen:
            continue
        seen.add(item)
        items.append(item)

    downloaded, present, failed = sync_crates(crates_dir, upstream_base, items)
    if failed == 0 and not dry_run:
        previous_file.write_text(upstream_head + "\n")
        previous_sync_file.write_text(str(time.time_ns()) + "\n")
    if dry_run:
        print("[INFO] dry run. No actual file is written.")
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
