#!/usr/bin/env python3
"""Builds the Contributions page data from docs/contributions.yaml.

Writes benchmark-app/assets/results/contributions.json: every entry, newest
first, with its repository's name and stars and each link's number.

  python3 bench/report/contributions.py            # from the file as it is
  python3 bench/report/contributions.py --live     # refresh states and stars
  python3 bench/report/contributions.py --check    # validate only

--live asks GitHub (with GITHUB_TOKEN when set) and Gerrit for each link's
state and each repository's stars. Anything it cannot read keeps the value
in the file, so a build never fails on the network.
"""
import argparse
import datetime as dt
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs" / "contributions.yaml"
DEFAULT_OUT = ROOT / "benchmark-app" / "assets" / "results"

KINDS = {"issue", "pr", "change"}
STATES = {"open", "merged", "closed"}
_GITHUB = re.compile(r"^https://github\.com/([^/]+/[^/]+)/(issues|pull)/(\d+)$")
_GERRIT = re.compile(r"^https://([^/]+)/c/([^+]+)/\+/(\d+)$")


def load(path=SOURCE):
    return yaml.safe_load(Path(path).read_text())


def link_ref(url):
    """(host kind, repo or Gerrit host, number) for a link, or None."""
    m = _GITHUB.match(url)
    if m:
        return ("github", m.group(1), int(m.group(3)))
    m = _GERRIT.match(url)
    if m:
        return ("gerrit", m.group(1), int(m.group(3)))
    return None


def problems(data):
    """Everything wrong with the file, as readable lines."""
    out = []
    repos = (data or {}).get("repos") or {}
    entries = (data or {}).get("contributions")
    if not isinstance(entries, list) or not entries:
        return ["no contributions listed"]
    for name, repo in repos.items():
        if not isinstance(repo, dict) or not repo.get("name"):
            out.append(f"repo {name}: needs a name")
        elif not isinstance(repo.get("stars"), int):
            out.append(f"repo {name}: stars must be a whole number")
    for i, e in enumerate(entries):
        where = f"contribution {i + 1} ({e.get('title', 'no title')})"
        for field in ("title", "repo", "date", "summary", "links"):
            if not e.get(field):
                out.append(f"{where}: missing {field}")
        if e.get("repo") and e["repo"] not in repos:
            out.append(f"{where}: repo {e['repo']} is not under repos")
        if e.get("date") and not isinstance(e["date"], dt.date):
            out.append(f"{where}: date must be YYYY-MM-DD")
        for link in e.get("links") or []:
            url = link.get("url", "")
            if link.get("kind") not in KINDS:
                out.append(f"{where}: link {url}: kind must be one of {sorted(KINDS)}")
            if link.get("state") not in STATES:
                out.append(f"{where}: link {url}: state must be one of {sorted(STATES)}")
            if link_ref(url) is None:
                out.append(f"{where}: link {url}: not a GitHub issue/PR or Gerrit change URL")
        for n in e.get("numbers") or []:
            if not n.get("label") or not n.get("unit"):
                out.append(f"{where}: numbers need a label and a unit")
            for side in ("before", "after"):
                if not isinstance(n.get(side), (int, float)) or n[side] <= 0:
                    out.append(f"{where}: {n.get('label')}: {side} must be a positive number")
    return out


def _get_json(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=20) as r:
        body = r.read().decode()
    # Gerrit prefixes its JSON with )]}' to stop it being run as a script.
    if body.startswith(")]}'"):
        body = body[4:]
    return json.loads(body)


def _github_headers():
    h = {"Accept": "application/vnd.github+json", "User-Agent": "backend-benchmark"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


def fetch_live(data, get=_get_json, warn=print):
    """Refreshes link states and repository stars in place."""
    gh = _github_headers()
    for name, repo in data["repos"].items():
        try:
            repo["stars"] = int(get(f"https://api.github.com/repos/{name}", gh)["stargazers_count"])
        except Exception as e:  # noqa: BLE001 - the file's value stays
            warn(f"warning: stars for {name}: {e}")
    for e in data["contributions"]:
        for link in e["links"]:
            ref = link_ref(link["url"])
            try:
                if ref[0] == "github":
                    item = get(f"https://api.github.com/repos/{ref[1]}/issues/{ref[2]}", gh)
                    merged = (item.get("pull_request") or {}).get("merged_at")
                    link["state"] = "merged" if merged else item["state"]
                else:
                    change = get(f"https://{ref[1]}/changes/{ref[2]}")
                    link["state"] = {"MERGED": "merged", "ABANDONED": "closed"}.get(change["status"], "open")
            except Exception as err:  # noqa: BLE001 - the file's value stays
                warn(f"warning: state of {link['url']}: {err}")


def build(data):
    """The page data: entries newest first, links numbered."""
    repos = data["repos"]
    entries = []
    for e in data["contributions"]:
        repo = repos[e["repo"]]
        entries.append({
            "title": e["title"],
            "repo": e["repo"],
            "project": repo["name"],
            "stars": repo["stars"],
            "date": e["date"].isoformat(),
            "summary": " ".join(e["summary"].split()),
            "links": [
                {
                    "kind": link["kind"],
                    "number": link_ref(link["url"])[2],
                    "url": link["url"],
                    "state": link["state"],
                    **({"by": link["by"]} if link.get("by") else {}),
                }
                for link in e["links"]
            ],
            "numbers": [
                {"label": n["label"], "before": n["before"], "after": n["after"], "unit": n["unit"]}
                for n in e.get("numbers") or []
            ],
            **({"note": " ".join(e["note"].split())} if e.get("note") else {}),
        })
    # Newest first; the file's order breaks ties (the sort is stable).
    entries.sort(key=lambda x: x["date"], reverse=True)
    return {"contributions": entries}


def write(out_dir, data):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "contributions.json").write_text(json.dumps(build(data), indent=1, ensure_ascii=False))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, default=SOURCE)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--live", action="store_true", help="refresh states and stars from GitHub and Gerrit")
    ap.add_argument("--check", action="store_true", help="validate only")
    args = ap.parse_args()

    data = load(args.source)
    found = problems(data)
    for p in found:
        print("problem:", p)
    if args.check or found:
        print(f"{len(data.get('contributions') or [])} contributions, {len(found)} problems")
        sys.exit(1 if found else 0)
    if args.live:
        fetch_live(data)
    write(args.out, data)
    print(f"wrote {len(data['contributions'])} contributions to {args.out / 'contributions.json'}")


if __name__ == "__main__":
    main()
