// Shared helpers for every scenario. The runner invokes one k6 process per
// load step with RATE (requests/s) and DURATION (e.g. "30s").
import http from 'k6/http';

export const BASE = __ENV.BASE_URL || 'http://benchmark:8000';
export const SEED_ROWS = parseInt(__ENV.SEED_ROWS || '10000', 10);
export const PAGE = 20;

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

export function readPage() {
  const offset = Math.floor(Math.random() * (SEED_ROWS - PAGE));
  return http.get(`${BASE}/notes/?limit=${PAGE}&offset=${offset}`, { tags: { name: 'list' } });
}

export function readOne() {
  return http.get(`${BASE}/notes/${randomId()}`, { tags: { name: 'get' } });
}

export function writeOne() {
  return http.post(
    `${BASE}/notes/`,
    JSON.stringify({ title: 'Sample Note', content: 'This is a note content.' }),
    Object.assign({ tags: { name: 'create' } }, JSON_HEADERS),
  );
}

export function noDb() {
  return http.get(`${BASE}/no_db_endpoint/`, { tags: { name: 'no_db' } });
}
