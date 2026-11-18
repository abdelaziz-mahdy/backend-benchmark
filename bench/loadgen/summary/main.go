// Command summary reads vegeta attack results (gob) from stdin as they stream
// in and prints one JSON summary of the step: request and status counts,
// exact latency percentiles, and bytes on the wire. With -body-must-contain,
// a 2xx reply whose body lacks that text counts as an RPC failure (FOAM
// answers errors with HTTP 200 and an RPCErrorMessage).
//
// Bytes are counted as on the wire, as k6 counted them: vegeta records body
// lengths only, so each reply adds its status line and headers, and each
// request adds -request-head-bytes, its request line and headers, which the
// runner knows from the request list. Chunked framing is not counted.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"slices"
	"strconv"
	"time"

	vegeta "github.com/tsenart/vegeta/v12/lib"
)

type summary struct {
	Requests  int                `json:"requests"`
	Success   int                `json:"success"`
	RPCFailed int                `json:"rpc_failed"`
	Codes     map[string]int     `json:"status_codes"`
	Errors    map[string]int     `json:"errors"`
	LatencyMs map[string]float64 `json:"latency_ms"`
	BytesIn   float64            `json:"bytes_in"`
	BytesOut  float64            `json:"bytes_out"`
	SpanS     float64            `json:"span_s"`
}

func ms(d time.Duration) float64 { return float64(d) / float64(time.Millisecond) }

// replyHead is the length of an HTTP/1.1 status line and header block.
func replyHead(code uint16, h http.Header) int {
	n := len("HTTP/1.1 000 ") + len(http.StatusText(int(code))) + len("\r\n") + len("\r\n")
	for k, vs := range h {
		for _, v := range vs {
			n += len(k) + len(": ") + len(v) + len("\r\n")
		}
	}
	return n
}

func main() {
	must := flag.String("body-must-contain", "", "count 2xx replies without this text as RPC failures")
	reqHead := flag.Float64("request-head-bytes", 0, "request line and headers a request, added to bytes_out")
	flag.Parse()
	needle := []byte(*must)

	s := summary{Codes: map[string]int{}, Errors: map[string]int{}, LatencyMs: map[string]float64{}}
	var lat []time.Duration
	var first, last time.Time
	dec := vegeta.NewDecoder(os.Stdin)
	for {
		var r vegeta.Result
		if err := dec.Decode(&r); err == io.EOF {
			break
		} else if err != nil {
			fmt.Fprintln(os.Stderr, "decode:", err)
			os.Exit(1)
		}
		s.Requests++
		s.Codes[strconv.Itoa(int(r.Code))]++
		if r.Code >= 200 && r.Code < 400 {
			s.Success++
		}
		if len(needle) > 0 && r.Code >= 200 && r.Code < 300 && !bytes.Contains(r.Body, needle) {
			s.RPCFailed++
		}
		if r.Error != "" && len(s.Errors) < 20 {
			s.Errors[r.Error]++
		}
		s.BytesOut += float64(r.BytesOut) + *reqHead
		if r.Code != 0 {
			s.BytesIn += float64(r.BytesIn) + float64(replyHead(r.Code, r.Headers))
		}
		lat = append(lat, r.Latency)
		if first.IsZero() || r.Timestamp.Before(first) {
			first = r.Timestamp
		}
		if end := r.End(); end.After(last) {
			last = end
		}
	}
	if n := len(lat); n > 0 {
		slices.Sort(lat)
		var total time.Duration
		for _, l := range lat {
			total += l
		}
		at := func(q float64) float64 { return ms(lat[max(0, int(math.Ceil(q*float64(n)))-1)]) }
		s.LatencyMs["p50"] = at(0.50)
		s.LatencyMs["p90"] = at(0.90)
		s.LatencyMs["p99"] = at(0.99)
		s.LatencyMs["p999"] = at(0.999)
		s.LatencyMs["max"] = ms(lat[n-1])
		s.LatencyMs["mean"] = ms(total) / float64(n)
		s.SpanS = last.Sub(first).Seconds()
	}
	if err := json.NewEncoder(os.Stdout).Encode(s); err != nil {
		os.Exit(1)
	}
}
