// Shared helpers for every scenario. The runner invokes one k6 process per
// load step with RATE (requests/s) and DURATION (e.g. "30s").
import http from 'k6/http';
import { Rate } from 'k6/metrics';

export const BASE = __ENV.BASE_URL || 'http://benchmark:8000';
export const SEED_ROWS = parseInt(__ENV.SEED_ROWS || '10000', 10);
export const PAGE = 20;
// Paged reads start within the first PAGE_WINDOW rows. Deep OFFSETs make
// Postgres scan every skipped row, which turned db_read into a Postgres
// benchmark (3 DB cores saturated with the app at ~85% CPU).
export const PAGE_WINDOW = 200;
// "rest" (the API contract), "serverpod_rpc" (POST /note/<method>) or
// "foam_rpc" (FOAM box RPC, POST /service/noteService), set from backend.yaml
// so every backend runs the same four operations.
const STYLE = __ENV.API_STYLE || 'rest';
const RPC = STYLE === 'serverpod_rpc';
const FOAM = STYLE === 'foam_rpc';

const RATE = parseInt(__ENV.RATE || '100', 10);

// Open model: k6 starts RATE iterations per second no matter how slow the
// server is. When the server falls behind, k6 runs out of VUs and records
// dropped_iterations, which the runner counts as a miss.
export function stepOptions() {
  return {
    discardResponseBodies: true,
    summaryTrendStats: ['avg', 'min', 'max', 'p(50)', 'p(90)', 'p(99)', 'p(99.9)'],
    scenarios: {
      step: {
        executor: 'constant-arrival-rate',
        rate: RATE,
        timeUnit: '1s',
        duration: __ENV.DURATION || '30s',
        preAllocatedVUs: Math.min(Math.max(RATE / 10, 50), 2000),
        maxVUs: 10000,
        gracefulStop: '5s',
      },
    },
  };
}

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

export function randomId() {
  return 1 + Math.floor(Math.random() * SEED_ROWS);
}

// ---- foam_rpc: the request FOAM's own client sends. FOAM clients talk
// through foam.box.SessionClientBox, which wraps every call as
// Envelope{ SessionedMessage{ sessionId, RPCMessage } }; args[0] is the
// Context argument, always null. Each virtual user keeps its own session id,
// like a real client. Without it the server sees a sessionless call, creates
// an "anonymous" session and writes it to the journaled session DAO on EVERY
// request, which serializes all calls on one file journal (found with thread
// dumps: ~760 of 1000 Jetty threads waiting in AbstractF3FileJournal.put).
// Bodies are prebuilt strings; only the numbers are spliced in.
const FOAM_URL = `${BASE}/service/noteService`;
const FOAM_TAIL = ']}},"replyBox":{"class":"foam.box.HTTPReplyBox"}}';
// Module state is per VU in k6, and __VU is only set once the VU runs, so
// the prefix is built on first use.
let foamHeadForVu = null;
function foamHead() {
  if (foamHeadForVu === null) {
    foamHeadForVu =
      '{"class":"foam.box.Envelope","message":{"class":"foam.box.SessionedMessage",' +
      `"sessionId":"bench-${__VU}","message":{"class":"foam.box.RPCMessage","name":"`;
  }
  return foamHeadForVu;
}
const FOAM_NOTE = '{"class":"bench.notes.Note","title":"Sample Note","content":"This is a note content."}';
const FOAM_PARAMS = {
  // FOAM answers an exception with HTTP 200 and an RPCErrorMessage, so the
  // body is read (responseType) and checked in foam().
  responseType: 'text',
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    Origin: BASE,
    Pragma: 'no-cache',
    'Cache-Control': 'no-cache, no-store',
  },
};
// True for a 2xx reply that is not an RPCReturnMessage (i.e. an RPCErrorMessage).
// Non-2xx replies are already in http_req_failed; benchlib/slo.py adds both.
const rpcFailed = new Rate('rpc_failed');

function foam(body, name) {
  const res = http.post(FOAM_URL, body, Object.assign({ tags: { name } }, FOAM_PARAMS));
  const ok2xx = res.status >= 200 && res.status < 300;
  rpcFailed.add(ok2xx && (!res.body || res.body.indexOf('"foam.box.RPCReturnMessage"') === -1));
  return res;
}

function rpc(method, body, name) {
  return http.post(`${BASE}/note/${method}`, JSON.stringify(body), Object.assign({ tags: { name } }, JSON_HEADERS));
}

export function readPage() {
  const offset = Math.floor(Math.random() * PAGE_WINDOW);
  if (FOAM) return foam(`${foamHead()}getNotes","args":[null,${PAGE},${offset}${FOAM_TAIL}`, 'list');
  if (RPC) return rpc('getNotes', { limit: PAGE, offset }, 'list');
  return http.get(`${BASE}/notes/?limit=${PAGE}&offset=${offset}`, { tags: { name: 'list' } });
}

export function readOne() {
  if (FOAM) return foam(`${foamHead()}getNote","args":[null,${randomId()}${FOAM_TAIL}`, 'get');
  if (RPC) return rpc('getNote', { id: randomId() }, 'get');
  return http.get(`${BASE}/notes/${randomId()}`, { tags: { name: 'get' } });
}

const NOTE = { title: 'Sample Note', content: 'This is a note content.' };

export function writeOne() {
  if (FOAM) return foam(`${foamHead()}createNote","args":[null,${FOAM_NOTE}${FOAM_TAIL}`, 'create');
  if (RPC) return rpc('createNote', { note: NOTE }, 'create');
  return http.post(`${BASE}/notes/`, JSON.stringify(NOTE), Object.assign({ tags: { name: 'create' } }, JSON_HEADERS));
}

export function noDb() {
  if (FOAM) return foam(`${foamHead()}noDb","args":[null${FOAM_TAIL}`, 'no_db');
  if (RPC) return rpc('noDbEndpoint', {}, 'no_db');
  return http.get(`${BASE}/no_db_endpoint/`, { tags: { name: 'no_db' } });
}
