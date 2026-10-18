import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

const rulesPath = fileURLToPath(new URL('../firestore.rules', import.meta.url));

/** A fresh emulator environment with firestore/firestore.rules loaded. */
export async function rulesEnv(projectId: string): Promise<RulesTestEnvironment> {
  const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
  const [hostname, port] = host.split(':');
  return initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(rulesPath, 'utf8'),
      host: hostname,
      port: Number(port),
    },
  });
}

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

/** `yyyy-MM-dd` of the UTC day [offset] days from now. */
export function utcDayId(offset: number, now = Date.now()): string {
  return new Date(now + offset * DAY_MS).toISOString().slice(0, 10);
}

/** The Worker's window, used here to say what the rules should answer right now. */
export function dayIsLiveNow(dayId: string, now = Date.now()): boolean {
  const midnight = Date.parse(`${dayId}T00:00:00Z`);
  return now >= midnight - 14 * HOUR_MS && now < midnight + 36 * HOUR_MS;
}

/** A gap of a few seconds around a window edge makes a result flaky; skip those. */
export function nearWindowEdge(dayId: string, now = Date.now()): boolean {
  const midnight = Date.parse(`${dayId}T00:00:00Z`);
  const edges = [midnight - 14 * HOUR_MS, midnight + 36 * HOUR_MS];
  return edges.some((edge) => Math.abs(now - edge) < 60_000);
}
