import httpx
from pathlib import Path
import os
import re
from urllib.parse import urlparse

RELEASES_URL = "https://raw.githubusercontent.com/pytorch/pytorch.github.io/refs/heads/site/releases.json"
HREF_RE = re.compile(r'href="([^"]+)"')

base = Path(os.environ.get("TO", "."))
dry_run = os.environ.get("DRY_RUN", "0") == "1"


def recursive_download(client, url):
    path = urlparse(url).path
    while path.startswith("/"):
        path = path[1:]
    print(f"Downloading {url} to {base / path}")
    if url.endswith("/"):
        # index.html
        index_resp = client.get(url).text
        for m in HREF_RE.finditer(index_resp):
            suburl = m.group(1).split("#")[0]
            if suburl.startswith("/"):
                suburl = "https://download.pytorch.org" + suburl
            else:
                suburl = url + suburl
            recursive_download(client, suburl)
        if not dry_run:
            os.makedirs(base / path, exist_ok=True)
            with open(base / path / "index.html", "w") as f:
                f.write(index_resp)
    else:
        if (base / path).exists():
            return
        if not dry_run:
            os.makedirs((base / path).parent, exist_ok=True)
            with open(base / path, "wb") as f:
                f.write(client.get(url).content)


def main():
    client = httpx.Client(
        headers={
            "User-Agent": "pytorch-sync (+https://github.com/ustclug/ustcmirror-images)"
        },
        transport=httpx.HTTPTransport(retries=3),
    )
    releases = client.get(RELEASES_URL).json()
    releases = releases["release"]
    urls = set()
    for os_ in releases:
        for version in releases[os_]:
            url = version["installation"].split(" ")[-1]
            if not url.startswith("https://download.pytorch.org"):
                continue
            urls.add(url + "/")
    for url in urls:
        recursive_download(client, url)


if __name__ == "__main__":
    main()
