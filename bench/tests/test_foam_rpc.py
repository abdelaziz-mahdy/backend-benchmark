import json

from benchlib import foam_rpc

# Replies captured from the FOAM3 server (see backends/java/foam3/README.md).
RETURN_NOTE = ('{"class":"foam.box.Envelope","message":{"class":"foam.box.RPCReturnMessage","executionTime":1,'
               '"data":{"class":"bench.notes.Note","id":1,"title":"t","content":"c"}}}')
RETURN_NULL = '{"class":"foam.box.Envelope","message":{"class":"foam.box.RPCReturnMessage","executionTime":0}}'
ERROR = ('{"class":"foam.box.Envelope","message":{"class":"foam.box.RPCErrorMessage","data":{"class":'
         '"foam.box.RemoteException","id":"java.lang.IllegalArgumentException","message":"note required"}}}')


def test_request_bodies_match_foam_client():
    _, body = foam_rpc.request("list", {"limit": 1, "offset": 1})
    assert json.dumps(body, separators=(",", ":")) == (
        '{"class":"foam.box.Envelope","message":{"class":"foam.box.RPCMessage","name":"getNotes",'
        '"args":[null,1,1]},"replyBox":{"class":"foam.box.HTTPReplyBox"}}')
    _, body = foam_rpc.request("create", {"title": "t", "content": "c"})
    assert body["message"]["args"] == [None, {"class": "bench.notes.Note", "title": "t", "content": "c"}]
    assert foam_rpc.request("get", 7)[1]["message"]["args"] == [None, 7]
    assert foam_rpc.request("no_db")[1]["message"] == {"class": "foam.box.RPCMessage", "name": "noDb", "args": [None]}


def test_unwrap_return_and_null():
    status, data = foam_rpc.unwrap(200, RETURN_NOTE)
    assert status == 200 and json.loads(data)["id"] == 1
    assert foam_rpc.unwrap(200, RETURN_NULL) == (200, "null")


def test_unwrap_error_reply_is_a_failure():
    assert foam_rpc.unwrap(200, ERROR)[0] == 0
    assert foam_rpc.unwrap(200, "not json")[0] == 0
    assert foam_rpc.unwrap(400, "Expected instance of foam.box.Envelope") == (400, "Expected instance of foam.box.Envelope")
