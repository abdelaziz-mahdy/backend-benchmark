import copy
import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "report"))
import contributions as c  # noqa: E402

DATA = {
    "repos": {
        "owner/lib": {"name": "Lib", "stars": 10},
        "dart-lang/sdk": {"name": "Dart SDK", "stars": 5},
    },
    "contributions": [
        {
            "title": "Older",
            "repo": "owner/lib",
            "date": dt.date(2026, 11, 1),
            "summary": "Was slow.\n  Now fast.",
            "links": [{"kind": "pr", "url": "https://github.com/owner/lib/pull/7", "state": "open"}],
        },
        {
            "title": "Newer",
            "repo": "dart-lang/sdk",
            "date": dt.date(2026, 11, 9),
            "summary": "A change.",
            "links": [
                {"kind": "issue", "url": "https://github.com/dart-lang/sdk/issues/3", "state": "open"},
                {"kind": "change", "url": "https://dart-review.googlesource.com/c/sdk/+/577480", "state": "open"},
                {"kind": "pr", "url": "https://github.com/dart-lang/sdk/pull/4", "state": "merged", "by": "someone"},
            ],
            "numbers": [{"label": "x", "before": 1.5, "after": 1.2, "unit": "µs"}],
            "note": "Measured\n here.",
        },
    ],
}


def data():
    return copy.deepcopy(DATA)


def test_the_real_file_has_no_problems():
    assert c.problems(c.load()) == []


def test_build_sorts_newest_first_and_numbers_links():
    out = c.build(data())["contributions"]
    assert [e["title"] for e in out] == ["Newer", "Older"]
    assert [link["number"] for link in out[0]["links"]] == [3, 577480, 4]
    assert out[0]["links"][2]["by"] == "someone"
    assert "by" not in out[0]["links"][0]
    assert out[0]["project"] == "Dart SDK" and out[0]["stars"] == 5
    assert out[0]["note"] == "Measured here."
    assert out[1]["summary"] == "Was slow. Now fast."
    assert out[1]["numbers"] == [] and "note" not in out[1]


def test_problems_catch_bad_entries():
    d = data()
    d["contributions"][0]["links"][0]["state"] = "done"
    d["contributions"][0]["repo"] = "nobody/else"
    d["contributions"][1]["links"][0]["url"] = "https://example.com/1"
    d["contributions"][1]["numbers"][0]["after"] = 0
    found = " | ".join(c.problems(d))
    assert "state must be one of" in found
    assert "repo nobody/else is not under repos" in found
    assert "not a GitHub issue/PR or Gerrit change URL" in found
    assert "after must be a positive number" in found


def test_live_refresh_reads_states_and_stars_and_keeps_the_file_on_errors():
    d = data()
    answers = {
        "https://api.github.com/repos/owner/lib": {"stargazers_count": 42},
        "https://api.github.com/repos/owner/lib/issues/7": {"state": "closed", "pull_request": {"merged_at": "2026-11-20"}},
        "https://api.github.com/repos/dart-lang/sdk/issues/3": {"state": "closed"},
        "https://dart-review.googlesource.com/changes/577480": {"status": "ABANDONED"},
    }
    warnings = []

    def get(url, headers=None):
        if url not in answers:
            raise OSError("offline")
        return answers[url]

    c.fetch_live(d, get=get, warn=warnings.append)
    assert d["repos"]["owner/lib"]["stars"] == 42
    assert d["repos"]["dart-lang/sdk"]["stars"] == 5  # kept
    assert d["contributions"][0]["links"][0]["state"] == "merged"
    states = [link["state"] for link in d["contributions"][1]["links"]]
    assert states == ["closed", "closed", "merged"]  # last one kept
    assert len(warnings) == 2
