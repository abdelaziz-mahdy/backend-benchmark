// Inserts SEED_ROWS notes through the public API before a DB scenario, so
// every backend (including ones with their own storage) is seeded the same way.
import { SEED_ROWS, writeOne } from './lib.js';
import { check } from 'k6';

export const options = {
  discardResponseBodies: true,
  scenarios: {
    seed: {
      executor: 'shared-iterations',
      vus: 50,
      iterations: SEED_ROWS,
      maxDuration: '10m',
    },
  },
  thresholds: { checks: ['rate==1.0'] },
};

export default function () {
  const res = writeOne();
  // The body is only read for foam_rpc (errors come back with HTTP 200).
  check(res, { created: (r) => (r.status === 200 || r.status === 201) && !(r.body && r.body.indexOf('RPCErrorMessage') !== -1) });
}
