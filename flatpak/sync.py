#!/usr/bin/python3
from gi.repository import GLib
import requests
import hashlib
import os
from email.utils import formatdate, parsedate_to_datetime
from contextlib import contextmanager

# https://github.com/flatpak/flatpak/blob/7a6c98c563a43a0d4b601b6bc7daaff3e4776efb/doc/flatpak-summaries.txt
SUMMARY_VARIANT = GLib.VariantType("(a{s(ayaaya{sv})}a{sv})")
FLATHUB = "https://dl.flathub.org/repo/"

USER_AGENT = os.getenv(
    "USER_AGENT", "flatpak-sync (+https://github.com/ustclug/ustcmirror-images)"
)
requests.utils.default_user_agent = lambda: USER_AGENT
TIMEOUT_OPTION = (7, 30)


def set_retry(max_retries):
    def decorate(func):
        def wrapper(self, *args, **kwargs):
            func(self, *args, **kwargs)
            self.max_retries = max_retries

        return wrapper

    return decorate


func = requests.adapters.HTTPAdapter.__init__
requests.adapters.HTTPAdapter.__init__ = set_retry(3)(func)


@contextmanager
def overwrite(file_path, mode: str = "w", tmp_suffix: str = ".tmp"):
    tmp_path = file_path + tmp_suffix
    try:
        with open(tmp_path, mode) as tmp_file:
            yield tmp_file
        os.rename(tmp_path, file_path)
    except Exception:
        # well, just keep the tmp_path in error case.
        raise


def download_if_modified(url, local_path):
    headers = {}
    if os.path.exists(local_path):
        mtime = os.path.getmtime(local_path)
        headers["If-Modified-Since"] = formatdate(mtime, usegmt=True)
    response = requests.get(url, headers=headers, stream=True, timeout=TIMEOUT_OPTION)
    if response.status_code == 200:
        print("Downloading", url)
        with overwrite(local_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        if "Last-Modified" in response.headers:
            mtime = parsedate_to_datetime(response.headers["Last-Modified"])
            os.utime(local_path, (mtime.timestamp(), mtime.timestamp()))
    return response


def main():
    download_if_modified(FLATHUB + "config", "config")
    # download summary.idx
    url = FLATHUB + "summary.idx"
    download_if_modified(url, "summary.idx.bak")
    with open("summary.idx.bak", "rb") as f:
        summary_data = f.read()

    # parse summary.idx
    summary = GLib.Variant.new_from_bytes(
        SUMMARY_VARIANT, GLib.Bytes.new(summary_data), False
    )
    summary_sha256 = hashlib.sha256(summary_data).digest()
    os.makedirs("summaries", exist_ok=True)

    sha256_filepath = f"summaries/{summary_sha256.hex()}.idx.sig"
    download_if_modified(FLATHUB + sha256_filepath, sha256_filepath)

    # get all subsummary digests
    subsummaries = summary[0]
    all_digests = []

    for subsummary_name, subsummary_info in subsummaries.items():
        current_digest = subsummary_info[0]
        previous_digests = subsummary_info[1]

        all_digests.append(current_digest)
        all_digests.extend(previous_digests)

    all_digests = ["".join(f"{y:02x}" for y in x) for x in all_digests]
    for i in all_digests:
        filepath = f"summaries/{i}.gz"
        download_if_modified(FLATHUB + filepath, filepath)

    os.rename("summary.idx.bak", "summary.idx")

    # Remove old summaries
    for filename in os.listdir("summaries"):
        if filename.endswith(".sig"):
            if filename != f"{summary_sha256.hex()}.idx.sig":
                print("Removing", filename)
                os.remove(f"summaries/{filename}")
        elif filename.endswith(".gz"):
            digest = filename[:-3]
            if digest not in all_digests:
                print("Removing", filename)
                os.remove(f"summaries/{filename}")


if __name__ == "__main__":
    main()
