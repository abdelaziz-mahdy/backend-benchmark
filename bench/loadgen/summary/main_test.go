package main

import (
	"bytes"
	"compress/gzip"
	"net/http"
	"testing"

	vegeta "github.com/tsenart/vegeta/v12/lib"
)

func TestPlainBodyUnpacksGzip(t *testing.T) {
	var b bytes.Buffer
	zw := gzip.NewWriter(&b)
	zw.Write([]byte(`{"class":"foam.box.RPCReturnMessage"}`))
	zw.Close()
	r := vegeta.Result{Body: b.Bytes(), Headers: http.Header{"Content-Encoding": {"gzip"}}}
	if !bytes.Contains(plainBody(r), []byte(`"foam.box.RPCReturnMessage"`)) {
		t.Fatal("gzip reply body was not unpacked")
	}
}

func TestPlainBodyKeepsIdentity(t *testing.T) {
	r := vegeta.Result{Body: []byte("plain")}
	if string(plainBody(r)) != "plain" {
		t.Fatal("identity body changed")
	}
}
