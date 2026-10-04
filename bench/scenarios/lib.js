// Shared helpers for every scenario. The runner invokes one k6 process per
// load step with RATE (requests/s) and DURATION (e.g. "30s").
import http from 'k6/http';
import { Rate } from 'k6/metrics';

export const BASE = __ENV.BASE_URL || 'http://benchmark:8000';
export const SEED_ROWS = parseInt(__ENV.SEED_ROWS || '10000', 10);
export const PAGE = 20;
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

// ---- foam_rpc: the request FOAM's own JS client (ClientNoteService stub over
// foam.box.HTTPBox) sends, captured from a real call. The body is a
// foam.box.Envelope holding a foam.box.RPCMessage; args[0] is the Context
// argument, which the client always sends as null. Bodies are prebuilt
// strings; only the numbers are spliced in.
const FOAM_URL = `${BASE}/service/noteService`;
const FOAM_HEAD = '{"class":"foam.box.Envelope","message":{"class":"foam.box.RPCMessage","name":"';
const FOAM_TAIL = ']},"replyBox":{"class":"foam.box.HTTPReplyBox"}}';
const FOAM_NO_DB = `${FOAM_HEAD}noDb","args":[null${FOAM_TAIL}`;
const FOAM_CREATE = `${FOAM_HEAD}createNote","args":[null,{"class":"bench.notes.Note","title":"Sample Note","content":"This is a note content."}${FOAM_TAIL}`;
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
  const offset = Math.floor(Math.random() * (SEED_ROWS - PAGE));
  if (FOAM) return foam(`${FOAM_HEAD}getNotes","args":[null,${PAGE},${offset}${FOAM_TAIL}`, 'list');
  if (RPC) return rpc('getNotes', { limit: PAGE, offset }, 'list');
  return http.get(`${BASE}/notes/?limit=${PAGE}&offset=${offset}`, { tags: { name: 'list' } });
}

export function readOne() {
  if (FOAM) return foam(`${FOAM_HEAD}getNote","args":[null,${randomId()}${FOAM_TAIL}`, 'get');
  if (RPC) return rpc('getNote', { id: randomId() }, 'get');
  return http.get(`${BASE}/notes/${randomId()}`, { tags: { name: 'get' } });
}

const NOTE = { title: 'Sample Note', content: 'This is a note content.' };

export function writeOne() {
  if (FOAM) return foam(FOAM_CREATE, 'create');
  if (RPC) return rpc('createNote', { note: NOTE }, 'create');
  return http.post(`${BASE}/notes/`, JSON.stringify(NOTE), Object.assign({ tags: { name: 'create' } }, JSON_HEADERS));
}

export function noDb() {
  if (FOAM) return foam(FOAM_NO_DB, 'no_db');
  if (RPC) return rpc('noDbEndpoint', {}, 'no_db');
  return http.get(`${BASE}/no_db_endpoint/`, { tags: { name: 'no_db' } });
}
