#!/usr/bin/env python3
import concurrent.futures
import logging
import os
import tempfile
from datetime import datetime
from pathlib import Path


# Set BindIP
# https://stackoverflow.com/a/70772914
BINDIP = os.getenv("BIND_ADDRESS", "")
if BINDIP:
    import urllib3
    real_create_conn = urllib3.util.connection.create_connection

    def set_src_addr(address, timeout, *args, **kw):
        source_address = (BINDIP, 0)
        return real_create_conn(address, timeout=timeout, source_address=source_address)

    urllib3.util.connection.create_connection = set_src_addr

import requests
import yaml

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s.%(msecs)03d - %(filename)s:%(lineno)d [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
handler.setFormatter(formatter)
logger.addHandler(handler)

BASE_URL = os.getenv("UPSTREAM_URL", "https://api.github.com/repos/")
WORKING_DIR = os.getenv("TUNASYNC_WORKING_DIR")
WORKERS = int(os.getenv("WORKERS", "8"))
FAST_SKIP = bool(os.getenv("FAST_SKIP", ""))
UA = "ustcmirror-tuna-github-release-mirror/0.0 (+https://github.com/ustclug/ustcmirror-images)"

def get_repos():
    try:
        with open('/repos.yaml') as f:
            content = f.read()
    except FileNotFoundError:
        content = os.getenv("REPOS", None)
        if content is None:
            raise Exception("Loading /repos.yaml file and reading REPOS env both failed")
    repos = yaml.safe_load(content)
    if isinstance(repos, list):
        return repos
    else:
        repos = repos['repos']
        if not isinstance(repos, list):
            raise Exception("Can not inspect repo list from the given file/env")
        return repos


REPOS = get_repos()

# connect and read timeout value
TIMEOUT_OPTION = (7, 10)


def sizeof_fmt(num: float, suffix: str = "iB") -> str:
    for unit in ["", "K", "M", "G", "T", "P", "E", "Z"]:
        if abs(num) < 1024.0:
            return "%3.2f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.2f%s%s" % (num, "Y", suffix)


# wrap around requests.get to use token if available
def github_get(*args, **kwargs) -> requests.Response:
    headers = kwargs["headers"] if "headers" in kwargs else {}
    if "GITHUB_TOKEN" in os.environ:
        headers["Authorization"] = "token {}".format(os.environ["GITHUB_TOKEN"])
    headers["User-Agent"] = UA
    kwargs["headers"] = headers
    kwargs["timeout"] = TIMEOUT_OPTION
    return requests.get(*args, **kwargs)


def do_download(
    remote_url: str, dst_file: Path, remote_ts: float, remote_size: int
) -> None:
    # NOTE the stream=True parameter below
    with github_get(remote_url, stream=True) as r:
        r.raise_for_status()
        tmp_dst_file = None
        try:
            with tempfile.NamedTemporaryFile(
                prefix="." + dst_file.name + ".",
                suffix=".tmp",
                dir=dst_file.parent,
                delete=False,
            ) as f:
                tmp_dst_file = Path(f.name)
                # download in 1MB chunks
                for chunk in r.iter_content(chunk_size=1 << 20):
                    if chunk:  # filter out keep-alive new chunks
                        f.write(chunk)
                        # f.flush()
            # check for downloaded size
            downloaded_size = tmp_dst_file.stat().st_size
            if remote_size != -1 and downloaded_size != remote_size:
                raise Exception(
                    f"File {dst_file.as_posix()} size mismatch: downloaded {downloaded_size} bytes, expected {remote_size} bytes"
                )
            os.utime(tmp_dst_file, (remote_ts, remote_ts))
            tmp_dst_file.chmod(0o644)
            tmp_dst_file.replace(dst_file)
        finally:
            if not tmp_dst_file is None:
                if tmp_dst_file.is_file():
                    tmp_dst_file.unlink()


def ensure_safe_name(filename: str) -> str:
    filename = filename.replace("\0", " ")
    if filename == ".":
        return " ."
    elif filename == "..":
        return ". ."
    else:
        return filename.replace("/", "\\").replace("\\", "_")


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default=BASE_URL)
    parser.add_argument("--working-dir", default=WORKING_DIR)
    parser.add_argument(
        "--workers", default=WORKERS, type=int, help="number of concurrent downloading jobs"
    )
    parser.add_argument(
        "--fast-skip",
        action="store_true",
        default=FAST_SKIP,
        help="do not verify size and timestamp of existing files",
    )
    args = parser.parse_args()

    if args.working_dir is None:
        raise Exception("Working Directory is None")

    working_dir = Path(args.working_dir)
    remote_filelist = []
    cleaning = False

    executor = concurrent.futures.ThreadPoolExecutor(max_workers=args.workers)
    futures = []

    def process_release(
        release: dict,
        release_dir: Path,
        tarball: bool,
    ) -> int:
        
        release_size = 0

        if tarball:
            url = release["tarball_url"]
            updated = datetime.strptime(
                release["published_at"], "%Y-%m-%dT%H:%M:%SZ"
            ).timestamp()
            dst_file = release_dir / "repo-snapshot.tar.gz"
            remote_filelist.append(dst_file.relative_to(working_dir))

            if dst_file.is_file():
                logger.info(f"skipping {dst_file.relative_to(working_dir)}")
            else:
                dst_file.parent.mkdir(parents=True, exist_ok=True)
                # tarball has no size information, use -1 to skip size check
                logger.info(f"queueing download of {url} to {dst_file.relative_to(working_dir)}")
                futures.append(
                    executor.submit(
                        download_file, url, dst_file, working_dir, updated, -1
                    )
                )

        for asset in release["assets"]:
            url = asset["browser_download_url"]
            updated = datetime.strptime(
                asset["updated_at"], "%Y-%m-%dT%H:%M:%SZ"
            ).timestamp()
            dst_file = release_dir / ensure_safe_name(asset["name"])
            remote_filelist.append(dst_file.relative_to(working_dir))
            remote_size = asset["size"]
            release_size += remote_size

            if dst_file.is_file():
                if args.fast_skip:
                    logger.info(f"fast skipping {dst_file.relative_to(working_dir)}")
                    continue
                else:
                    stat = dst_file.stat()
                    local_filesize = stat.st_size
                    local_mtime = stat.st_mtime
                    if (
                        local_mtime > updated
                        or remote_size == local_filesize
                        and local_mtime == updated
                    ):
                        logger.info(f"skipping {dst_file.relative_to(working_dir)}")
                        continue
            else:
                dst_file.parent.mkdir(parents=True, exist_ok=True)

            logger.info(f"queueing download of {url} to {dst_file.relative_to(working_dir)}")
            futures.append(
                executor.submit(
                    download_file, url, dst_file, working_dir, updated, remote_size
                )
            )

        return release_size

    def download_file(
        url: str, dst_file: Path, working_dir: Path, updated: float, remote_size: int
    ) -> bool:
        logger.info(f"downloading {url} to {dst_file.relative_to(working_dir)} ({remote_size} bytes)")
        try:
            do_download(url, dst_file, updated, remote_size)
            return True
        except Exception as e:
            logger.error(f"Failed to download {url}: {e}")
            if dst_file.is_file():
                dst_file.unlink()
            return False

    def link_latest(name: str, repo_dir: Path) -> None:
        try:
            os.unlink(repo_dir / "LatestRelease")
        except OSError:
            pass
        try:
            os.symlink(name, repo_dir / "LatestRelease")
        except OSError:
            pass

    total_size = 0

    for cfg in REPOS:
        flat = False  # build a folder for each release
        versions = 1  # keep only one release
        tarball = False  # do not download the tarball
        prerelease = False  # filter out pre-releases
        perpage = 0
        if isinstance(cfg, str):
            repo = cfg
        else:
            repo = cfg["repo"]
            if "versions" in cfg:
                versions = cfg["versions"]
            if "flat" in cfg:
                flat = cfg["flat"]
            if "tarball" in cfg:
                tarball = cfg["tarball"]
            if "pre_release" in cfg:
                prerelease = cfg["pre_release"]
            if "per_page" in cfg:
                perpage = cfg["per_page"]

        repo_dir = working_dir / Path(repo)
        logger.info(f"syncing {repo} to {repo_dir}")

        try:
            if perpage > 0:
                r = github_get(f"{args.base_url}{repo}/releases?per_page={perpage}")
            else:
                r = github_get(f"{args.base_url}{repo}/releases")
            r.raise_for_status()
            releases = r.json()
        except Exception as e:
            logger.error(
                f"Cannot download metadata for {repo}: {e}",
            )
            break

        n_downloaded = 0
        for release in releases:
            if not release["draft"] and (prerelease or not release["prerelease"]):
                name = ensure_safe_name(release["name"] or release["tag_name"])
                if len(name) == 0:
                    logger.error("Unnamed release")
                    continue
                total_size += process_release(
                    release,
                    (repo_dir if flat else repo_dir / name),
                    tarball,
                )
                if n_downloaded == 0 and not flat:
                    # create a symbolic link to the latest release folder
                    link_latest(name, repo_dir)
                n_downloaded += 1
                if versions > 0 and n_downloaded >= versions:
                    break
        if n_downloaded == 0:
            logger.error(f"No release version found for {repo}")
            continue
    else:
        cleaning = True

    # 等待所有下载任务完成
    results, _ = concurrent.futures.wait(futures)
    executor.shutdown()
    all_success = all([r.result() for r in results])

    # XXX: this does not work because `cleaning` is always False when `REPO`` is not empty
    if cleaning:
        local_filelist: list[Path] = []
        for local_file in working_dir.glob("**/*"):
            if local_file.is_file():
                local_filelist.append(local_file.relative_to(working_dir))

        for old_file in set(local_filelist) - set(remote_filelist):
            logger.info(f"deleting {old_file}")
            old_file = working_dir / old_file
            old_file.unlink()

        for local_dir in working_dir.glob("*/*/*"):
            # remove empty dirs only
            if local_dir.is_dir():
                try:
                    local_dir.rmdir()
                    logger.info(f"Removing empty directory {local_dir}")
                except Exception:
                    pass

    logger.info(f"Total size is {sizeof_fmt(total_size, suffix='')}")
    if not all_success:
        logger.error("Some files failed to download")
        exit(1)

if __name__ == "__main__":
    main()


# vim: ts=4 sw=4 sts=4 expandtab
