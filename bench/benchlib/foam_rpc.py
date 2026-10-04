"""FOAM box RPC (api_style: foam_rpc), as sent by FOAM's own JS client.

A call is POST /service/<service> with a foam.box.Envelope holding a
foam.box.RPCMessage. args[0] is the method's Context argument, always null
on the wire. The reply is an Envelope holding an RPCReturnMessage (result in
"data", absent for null) or an RPCErrorMessage, both with HTTP 200.
"""
import json

PATH = "/service/noteService"
HEADERS = {
    "Content-Type": "application/json; charset=utf-8",
    "Pragma": "no-cache",
    "Cache-Control": "no-cache, no-store",
}


def note(n):
    return {"class": "bench.notes.Note", **n}


def envelope(method, *args):
    """Request body for NoteService.<method>(x, *args)."""
    return {
        "class": "foam.box.Envelope",
        "message": {"class": "foam.box.RPCMessage", "name": method, "args": [None, *args]},
        "replyBox": {"class": "foam.box.HTTPReplyBox"},
    }


def request(op, arg=None):
    """(method, body) for one of the four benchmark operations."""
    if op == "no_db":
        return "noDb", envelope("noDb")
    if op == "create":
        return "createNote", envelope("createNote", note(arg))
    if op == "list":
        return "getNotes", envelope("getNotes", arg["limit"], arg["offset"])
    return "getNote", envelope("getNote", arg)


def unwrap(status, body):
    """Map an HTTP reply to (status, JSON of the returned data).

    A FOAM error reply (RPCErrorMessage) or anything unparseable becomes
    status 0, so callers treat it as a failure even though HTTP said 200.
    """
    if status != 200:
        return status, body
    try:
        msg = json.loads(body)["message"]
    except (ValueError, KeyError, TypeError):
        return 0, body
    if not isinstance(msg, dict) or msg.get("class") != "foam.box.RPCReturnMessage":
        return 0, body
    return 200, json.dumps(msg.get("data"))
