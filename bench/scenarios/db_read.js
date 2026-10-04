import { stepOptions, readPage, readOne } from './lib.js';

export const options = stepOptions();

// Half paged lists, half single-row reads over the seeded rows.
export default function () {
  if (Math.random() < 0.5) {
    readPage();
  } else {
    readOne();
  }
}
