"""Request lists for the vegeta load generator.

vegeta replays a fixed list of requests round robin, so each scenario's mix
(random ids, paged reads, writes) is drawn up front into a shuffled list long
enough that the order never matters. The requests are the same ones
scenarios/lib.js sends for k6, for every API style.
"""

import base64
import json
import random

from . import slo

PAGE = 20
# Paged reads start within the first PAGE_WINDOW rows; see scenarios/lib.js.
PAGE_WINDOW = 200
# Requests drawn per scenario. vegeta cycles through them, so this only has to
# be long enough that ids and the read/write mix look random.
COUNT = 50_000

NOTE = {"title": "Sample Note", "content": "This is a note content."}
FOAM_NOTE = '{"class":"bench.notes.Note","title":"Sample Note","content":"This is a note content."}'
FOAM_SESSION = "bench-client"
FOAM_HEAD = (
    '{"class":"foam.box.Envelope","message":{"class":"foam.box.SessionedMessage",'
    f'"sessionId":"{FOAM_SESSION}","message":{{"class":"foam.box.RPCMessage","name":"'
)
FOAM_TAIL = ']}},"replyBox":{"class":"foam.box.HTTPReplyBox"}}'
# What a FOAM reply that is not an error carries; see scenarios/lib.js.
FOAM_OK = b'"foam.box.RPCReturnMessage"'


class Requests:
    """Builds one request of each kind for an API style."""

    def __init__(self, base, api_style, accept_gzip=False, rand=None):
        self.base = base.rstrip("/")
        self.style = api_style
        self.rand = rand or random.Random(0)
        # Go's HTTP client asks for gzip on its own unless the request names an
        # encoding, and then hides the compression. k6 asks for none, so every
        # request names one: gzip only for the variants that test it.
        self.encoding = "gzip" if accept_gzip else "identity"

    def _target(self, method, path, body=None, content_type=None, extra=None):
        header = {"Accept-Encoding": [self.encoding]}
        if content_type:
            header["Content-Type"] = [content_type]
        header.update(extra or {})
        t = {"method": method, "url": f"{self.base}{path}", "header": header}
        if body is not None:
            t["body"] = base64.b64encode(body.encode()).decode()
        return t

    def _rpc(self, method, body):
        return self._target("POST", f"/note/{method}", json.dumps(body, separators=(",", ":")), "application/json")

    def _foam(self, name, args):
        body = f"{FOAM_HEAD}{name}\",\"args\":[null{args}{FOAM_TAIL}"
        extra = {
            "Origin": [self.base],
            "Pragma": ["no-cache"],
            "Cache-Control": ["no-cache, no-store"],
        }
        return self._target("POST", "/service/noteService", body, "application/json; charset=utf-8", extra)

    def _id(self):
        return 1 + self.rand.randrange(slo.SEED_ROWS)

    def read_page(self):
        offset = self.rand.randrange(PAGE_WINDOW)
        if self.style == "foam_rpc":
            return self._foam("getNotes", f",{PAGE},{offset}")
        if self.style == "serverpod_rpc":
            return self._rpc("getNotes", {"limit": PAGE, "offset": offset})
        return self._target("GET", f"/notes/?limit={PAGE}&offset={offset}")

    def read_one(self):
        if self.style == "foam_rpc":
            return self._foam("getNote", f",{self._id()}")
        if self.style == "serverpod_rpc":
            return self._rpc("getNote", {"id": self._id()})
        return self._target("GET", f"/notes/{self._id()}")

    def write_one(self):
        if self.style == "foam_rpc":
            return self._foam("createNote", f",{FOAM_NOTE}")
        if self.style == "serverpod_rpc":
            return self._rpc("createNote", {"note": NOTE})
        return self._target("POST", "/notes/", json.dumps(NOTE, separators=(",", ":")), "application/json")

    def no_db(self):
        if self.style == "foam_rpc":
            return self._foam("noDb", "")
        if self.style == "serverpod_rpc":
            return self._rpc("noDbEndpoint", {})
        return self._target("GET", "/no_db_endpoint/")

    def pick(self, scenario):
        """One request of the scenario's mix, as scenarios/<scenario>.js draws it."""
        r = self.rand.random()
        if scenario == "no_db":
            return self.no_db()
        if scenario == "db_read":
            return self.read_page() if r < 0.5 else self.read_one()
        if scenario == "db_write":
            return self.write_one()
        if scenario == "db_mixed":
            if r < 0.4:
                return self.read_page()
            return self.read_one() if r < 0.8 else self.write_one()
        raise ValueError(f"unknown scenario {scenario}")


# Headers Go's client adds to every request: Host, User-Agent, and vegeta's
# sequence number (about six digits during a step).
GO_HEADERS = ["User-Agent: Go-http-client/1.1", "X-Vegeta-Seq: 000000"]


def head_bytes(target):
    """Bytes of a target's HTTP/1.1 request line and header block, as Go's
    client writes them."""
    scheme_host, _, path = target["url"].partition("//")[2].partition("/")
    lines = [f"{target['method']} /{path} HTTP/1.1", f"Host: {scheme_host}", *GO_HEADERS]
    if "body" in target:
        lines.append(f"Content-Length: {len(base64.b64decode(target['body']))}")
    lines += [f"{k}: {v}" for k, vs in target["header"].items() for v in vs]
    return sum(len(line) + 2 for line in lines) + 2


def write(path, scenario, api_style, base, accept_gzip=False, count=COUNT, seed=0):
    """Write the scenario's request list as vegeta JSON targets, one per line.
    Returns the mean request head size in bytes, for loadgen/summary."""
    reqs = Requests(base, api_style, accept_gzip, random.Random(seed))
    total = 0
    with open(path, "w") as f:
        for _ in range(count):
            t = reqs.pick(scenario)
            total += head_bytes(t)
            f.write(json.dumps(t, separators=(",", ":")))
            f.write("\n")
    return total / count
