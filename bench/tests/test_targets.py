import base64
import json
from collections import Counter

from benchlib import slo, stats, targets


def load(tmp_path, scenario, style, gzip=False, count=4000):
    path = tmp_path / f"{scenario}.jsonl"
    targets.write(path, scenario, style, "http://benchmark:8000", accept_gzip=gzip, count=count)
    return [json.loads(line) for line in path.read_text().splitlines()]


def kind(t):
    if t["method"] == "GET":
        return "list" if "limit=" in t["url"] else ("no_db" if "no_db" in t["url"] else "get")
    body = base64.b64decode(t.get("body", "")).decode()
    for name, k in (("getNotes", "list"), ("getNote", "get"), ("createNote", "create"), ("noDb", "no_db")):
        if name in t["url"] or f'"{name}"' in body:
            return k
    return "create"


def test_rest_mixed_matches_the_k6_mix(tmp_path):
    ts = load(tmp_path, "db_mixed", "rest")
    share = {k: v / len(ts) for k, v in Counter(kind(t) for t in ts).items()}
    assert abs(share["list"] - 0.4) < 0.03
    assert abs(share["get"] - 0.4) < 0.03
    assert abs(share["create"] - 0.2) < 0.03


def test_ids_and_offsets_stay_in_range(tmp_path):
    for t in load(tmp_path, "db_read", "rest"):
        if "limit=" in t["url"]:
            offset = int(t["url"].rsplit("offset=", 1)[1])
            assert 0 <= offset < targets.PAGE_WINDOW
        else:
            assert 1 <= int(t["url"].rsplit("/", 1)[1]) <= slo.SEED_ROWS


def test_every_request_names_an_encoding(tmp_path):
    # Go asks for gzip by itself otherwise, which k6 never did.
    assert {t["header"]["Accept-Encoding"][0] for t in load(tmp_path, "no_db", "rest")} == {"identity"}
    assert {t["header"]["Accept-Encoding"][0] for t in load(tmp_path, "no_db", "foam_rpc", gzip=True)} == {"gzip"}


def test_rpc_bodies(tmp_path):
    t = load(tmp_path, "db_write", "serverpod_rpc", count=1)[0]
    assert t["url"] == "http://benchmark:8000/note/createNote"
    assert json.loads(base64.b64decode(t["body"])) == {"note": targets.NOTE}
    t = load(tmp_path, "no_db", "foam_rpc", count=1)[0]
    body = json.loads(base64.b64decode(t["body"]))
    assert t["url"] == "http://benchmark:8000/service/noteService"
    assert body["message"]["sessionId"] == targets.FOAM_SESSION
    assert body["message"]["message"] == {"class": "foam.box.RPCMessage", "name": "noDb", "args": [None]}


def test_same_seed_same_list(tmp_path):
    a = load(tmp_path, "db_mixed", "rest", count=200)
    b = load(tmp_path, "db_mixed", "rest", count=200)
    assert a == b


def test_step_from_vegeta():
    summary = {
        "requests": 2850, "success": 2840, "rpc_failed": 5,
        "latency_ms": {"p50": 1.0, "p90": 2.0, "p99": 3.0, "p999": 4.0, "mean": 1.2},
    }
    row = slo.step_from_vegeta(100, 30, summary)
    assert row["achieved_rps"] == 95
    assert row["dropped"] == 150
    assert row["error_rate"] == 15 / 2850
    assert (row["p99_ms"], row["p999_ms"], row["avg_ms"]) == (3.0, 4.0, 1.2)
    assert slo.passes(row)


def test_empty_vegeta_summary_fails_the_step():
    row = slo.step_from_vegeta(100, 30, {})
    assert row["error_rate"] == 1.0 and not slo.passes(row)


def test_vegeta_container_counts_as_the_load_generator():
    assert stats.role_of("bench-vegeta-run-1a2b3c") == "k6"


def test_head_bytes_matches_the_wire_format():
    t = {"method": "GET", "url": "http://benchmark:8000/no_db_endpoint/",
         "header": {"Accept-Encoding": ["identity"]}}
    wire = (
        "GET /no_db_endpoint/ HTTP/1.1\r\nHost: benchmark:8000\r\n"
        "User-Agent: Go-http-client/1.1\r\nX-Vegeta-Seq: 000000\r\n"
        "Accept-Encoding: identity\r\n\r\n"
    )
    assert targets.head_bytes(t) == len(wire)


def test_write_returns_the_mean_head_size(tmp_path):
    mean = targets.write(tmp_path / "w.jsonl", "db_write", "rest", "http://benchmark:8000", count=10)
    t = json.loads((tmp_path / "w.jsonl").read_text().splitlines()[0])
    assert mean == targets.head_bytes(t)
