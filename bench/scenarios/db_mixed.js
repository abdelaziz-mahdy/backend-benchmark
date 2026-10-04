import { stepOptions, readPage, readOne, writeOne } from './lib.js';

export const options = stepOptions();

// 80% reads (split like db_read), 20% writes.
export default function () {
  const r = Math.random();
  if (r < 0.4) {
    readPage();
  } else if (r < 0.8) {
    readOne();
  } else {
    writeOne();
  }
}
