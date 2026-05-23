#!/usr/bin/env python3
"""Generate engine_release_map.json from Flutter official releases + reFlutter CSV."""

from __future__ import annotations

import csv
import io
import json
import sys
import urllib.error
import urllib.request
from collections import defaultdict

RELEASES_URL = (
    "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
)
REFLUTTER_CSV_URL = (
    "https://raw.githubusercontent.com/Impact-I/reFlutter/main/enginehash.csv"
)
ENGINE_VERSION_URL = (
    "https://raw.githubusercontent.com/flutter/flutter/{commit}/bin/internal/engine.version"
)
ENGINE_STAMP_URL = (
    "https://storage.googleapis.com/flutter_infra_release/flutter/{engine}/engine_stamp.json"
)


def fetch(url: str, timeout: int = 30) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "flutter-find-generator/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def normalize_version(version: str) -> str:
    v = version.strip()
    if v.startswith("v"):
        v = v[1:]
    return v


def pick_version(existing: str | None, candidate: str) -> str:
    """Prefer stable-looking semver over pre/beta when duplicate engine commits exist."""
    if existing is None:
        return candidate
    existing_is_pre = any(x in existing.lower() for x in ("pre", "beta", "dev", "rc"))
    candidate_is_pre = any(x in candidate.lower() for x in ("pre", "beta", "dev", "rc"))
    if existing_is_pre and not candidate_is_pre:
        return candidate
    return existing


def load_reflutter_map() -> dict[str, str]:
    text = fetch(REFLUTTER_CSV_URL).decode("utf-8")
    mapping: dict[str, str] = {}
    for row in csv.DictReader(io.StringIO(text)):
        engine = (row.get("Engine_commit") or "").strip().lower()
        version = normalize_version(row.get("version") or "")
        if len(engine) == 40 and version:
            mapping[engine] = pick_version(mapping.get(engine), version)
    return mapping


def load_releases() -> list[dict]:
    data = json.loads(fetch(RELEASES_URL))
    return data["releases"]


def fetch_engine_commit(framework_commit: str) -> str | None:
    url = ENGINE_VERSION_URL.format(commit=framework_commit)
    try:
        body = fetch(url, timeout=20).decode("utf-8").strip()
    except (urllib.error.HTTPError, urllib.error.URLError):
        return None
    if len(body) == 40 and all(c in "0123456789abcdef" for c in body.lower()):
        return body.lower()
    return None


def fetch_content_hash(engine_commit: str) -> str | None:
    url = ENGINE_STAMP_URL.format(engine=engine_commit)
    try:
        data = json.loads(fetch(url, timeout=20))
    except (urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError):
        return None
    content_hash = data.get("content_hash")
    if isinstance(content_hash, str) and len(content_hash) == 40:
        return content_hash.lower()
    return None


def main() -> int:
    print("Loading reFlutter enginehash.csv …", file=sys.stderr)
    mapping = load_reflutter_map()
    print(f"  {len(mapping)} entries from reFlutter", file=sys.stderr)

    print("Loading Flutter releases …", file=sys.stderr)
    releases = load_releases()
    print(f"  {len(releases)} releases", file=sys.stderr)

    channel_priority = {"stable": 0, "beta": 1, "dev": 2}
    releases_sorted = sorted(
        releases,
        key=lambda r: (
            channel_priority.get(r.get("channel", "dev"), 9),
            r.get("release_date", ""),
        ),
    )

    added = 0
    skipped = 0
    for i, release in enumerate(releases_sorted, start=1):
        framework_commit = release["hash"].lower()
        version = normalize_version(release["version"])
        if not version:
            continue

        # Framework commit may also appear inside libflutter.so strings.
        mapping[framework_commit] = pick_version(mapping.get(framework_commit), version)

        engine_commit = fetch_engine_commit(release["hash"])
        if engine_commit:
            mapping[engine_commit] = pick_version(mapping.get(engine_commit), version)
            content_hash = fetch_content_hash(engine_commit)
            if content_hash:
                mapping[content_hash] = pick_version(mapping.get(content_hash), version)
            added += 1
        else:
            skipped += 1

        if i % 50 == 0:
            print(f"  processed {i}/{len(releases_sorted)} …", file=sys.stderr)

    # Current local SDK (may include content hash not yet in releases).
    try:
        import subprocess

        ver_data = json.loads(
            subprocess.check_output(["flutter", "--version", "--machine"], text=True)
        )
        version = normalize_version(ver_data["frameworkVersion"])
        for key in ("engineRevision", "engineContentHash", "frameworkRevision"):
            value = ver_data.get(key)
            if isinstance(value, str) and len(value) == 40:
                mapping[value.lower()] = pick_version(mapping.get(value.lower()), version)
        print(f"Added local SDK mappings for {version}", file=sys.stderr)
    except Exception as exc:
        print(f"Skipping local SDK: {exc}", file=sys.stderr)

    out_path = sys.argv[1] if len(sys.argv) > 1 else "engine_release_map.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(mapping.items())), f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Wrote {len(mapping)} mappings to {out_path}", file=sys.stderr)
    print(f"  engine.version resolved: {added}, skipped: {skipped}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
