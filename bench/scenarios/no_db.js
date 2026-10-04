import { stepOptions, noDb } from './lib.js';

export const options = stepOptions();

export default function () {
  noDb();
}
