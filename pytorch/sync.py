from contextlib import contextmanager
from typing import IO, Any, Generator
import httpx
from pathlib import Path
import os
import re
from urllib.parse import urlparse, urljoin, unquote
import asyncio
import time

RELEASES_URL = "https://raw.githubusercontent.com/pytorch/pytorch.github.io/refs/heads/site/releases.json"
A_RE = re.compile(r'<a ([^>]*)>')
HREF_RE = re.compile(r'href="([^"]+)"')


base = Path(os.environ.get("TO", "."))
dry_run = os.environ.get("DRY_RUN", "0") == "1"
jobs = int(os.environ.get("JOBS", "2"))
timeout = int(os.environ.get("TIMEOUT", "30"))
urlbase = os.environ.get("URLBASE", "/pytorch/")
if not urlbase.endswith("/"):
    urlbase += "/"
if not urlbase.startswith("/"):
    urlbase = "/" + urlbase

sem = asyncio.Semaphore(jobs)


@contextmanager
def overwrite(
    file_path: Path, mode: str = "w", tmp_suffix: str = ".tmp"
) -> Generator[IO[Any], None, None]:
    tmp_path = file_path.parent / (file_path.name + tmp_suffix)
    try:
        with open(tmp_path, mode) as tmp_file:
            yield tmp_file
        tmp_path.rename(file_path)
    except Exception:
        # well, just keep the tmp_path in error case.
        raise


async def show_progress(url, start_time, get_downloaded, total):
    try:
        while True:
            await asyncio.sleep(5)
            downloaded = get_downloaded()
            elapsed = time.monotonic() - start_time
            print(
                f"Progress of {url}: {downloaded}/{total} ({downloaded / total:.2%}), elapsed: {elapsed:.0f}s"
            )
    except asyncio.CancelledError:
        pass


async def get_with_progress(client: httpx.AsyncClient, url: str):
    for attempt in range(3):
        try:
            async with client.stream("GET", url) as resp:
                resp.raise_for_status()
                total = int(resp.headers.get("Content-Length", 0))
                downloaded = 0

                progress_task = asyncio.create_task(
                    show_progress(url, time.monotonic(), lambda: downloaded, total)
                )
                chunks = []
                try:
                    async for chunk in resp.aiter_bytes():
                        downloaded += len(chunk)
                        chunks.append(chunk)
                finally:
                    progress_task.cancel()
                    try:
                        await progress_task
                    except asyncio.CancelledError:
                        pass
                return b"".join(chunks)
        except Exception as e:
            if attempt == 2:
                raise e
            print(f"Failed to download {url}, retrying ({attempt + 1})...")
            await asyncio.sleep(5)


async def recursive_download(client: httpx.AsyncClient, url: str):
    path = unquote(urlparse(url).path)
    while path.startswith("/"):
        path = path[1:]
    if url.endswith("/"):
        # index.html
        async with sem:
            print(f"Getting {url}")
            contents = await get_with_progress(client, url)
            index_resp = contents.decode("utf-8")

        tasks = []
        for m in A_RE.finditer(index_resp):
            attr = m.group(1)
            href = HREF_RE.search(attr)
            suburl = href.group(1).split("#")[0]
            if suburl.startswith("/"):
                suburl = urljoin("https://download.pytorch.org", suburl)
            else:
                suburl = urljoin(url, suburl)
            tasks.append(asyncio.create_task(recursive_download(client, suburl)))
            if suburl.endswith(".whl") and "data-core-metadata" in attr:
                tasks.append(asyncio.create_task(recursive_download(client, suburl + ".metadata")))
        if tasks:
            await asyncio.gather(*tasks)
        if not dry_run:
            index_resp = index_resp.replace('href="/', f'href="{urlbase}')
            os.makedirs(base / path, exist_ok=True)
            with overwrite(base / path / "index.html", "w") as f:
                f.write(index_resp)
    else:
        if (base / path).exists():
            return
        if not dry_run:
            os.makedirs((base / path).parent, exist_ok=True)
            async with sem:
                print(f"Downloading {url} to {base / path}")
                try:
                    with overwrite(base / path, "wb") as f:
                        contents = await get_with_progress(client, url)
                        # Large files
                        await asyncio.to_thread(f.write, contents)
                except httpx.HTTPStatusError as e:
                    # Some urls are blocked by upstream, e.g.,
                    # https://download.pytorch.org/whl/cu128/nvidia_cudnn_cu12-9.8.0.87-py3-none-manylinux_2_27_aarch64.whl
                    # This is a workaround to skip those files.
                    if e.response.status_code == 403:
                        print(f"[WARN] Forbidden: {url}, skipping.")
                    else:
                        raise e


async def main():
    client = httpx.AsyncClient(
        headers={
            "User-Agent": "pytorch-sync (+https://github.com/ustclug/ustcmirror-images)"
        },
        timeout=timeout,
    )
    print("Getting releases info from GitHub...")
    resp = await client.get(RELEASES_URL)
    resp.raise_for_status()
    releases = resp.json()
    releases = releases["release"]
    urls = set()
    for os_ in releases:
        for version in releases[os_]:
            url = version["installation"].split(" ")[-1]
            if not url.startswith("https://download.pytorch.org"):
                continue
            if url.startswith("https://download.pytorch.org/whl/"):
                urls.add(url + "/")
    await asyncio.gather(*(recursive_download(client, url) for url in urls))


if __name__ == "__main__":
    asyncio.run(main())
