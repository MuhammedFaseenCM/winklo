/**
 * `POST /v1/level-clear`: checks one Zip or Path Words level clear and writes the player's
 * stars board.
 *
 * Checks, in order: the body's shape (`bad_request`), the time range
 * (`too_fast`, `too_slow`), the level is in a published world (`not_live`)
 * and the proof solves it (`bad_proof`). The stars are worked out here from
 * the hints and time, never taken from the body. The run is merged into the
 * player's `level_records` doc and the board row is recomputed from it; one
 * commit writes both, each guarded by the `updateTime` it was read at, with
 * the same single retry as `/v1/submit`. A run that improves nothing writes
 * nothing.
 */

import { identityFields, toCommitWrite, type PlannedWrite } from './entries';
import {
  ContentionError,
  batchGet,
  commit,
  documentsBase,
  type StoredDoc,
} from './firestore';
import {
  findLevel,
  levelBoardTotals,
  mergeLevelRecord,
  parseLevelClearBody,
  type LevelRecord,
} from './level_board';
import { starsFor } from './level_stars';
import { LEADERBOARD_ROOT, MAX_SECONDS, MIN_SECONDS } from './limits';
import { checkPathWordsProof, checkZipProof } from './proofs';
import type { SubmitDeps } from './submit';

export type LevelClearErrorCode =
  | 'bad_request'
  | 'too_fast'
  | 'too_slow'
  | 'not_live'
  | 'bad_proof';

export type LevelClearResponse =
  | { status: 200; body: { accepted: true; improved: boolean } }
  | { status: 400 | 422; body: { error: LevelClearErrorCode } }
  | { status: 503; body: { error: 'busy' | 'unavailable' } };

/** Firebase uids are short alphanumeric strings; anything else would break the doc paths. */
const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

function fail(status: 400 | 422, error: LevelClearErrorCode): LevelClearResponse {
  return { status, body: { error } };
}

function storedRecords(doc: StoredDoc | null): Record<string, LevelRecord> {
  const levels = doc?.data.levels;
  if (!levels || typeof levels !== 'object' || Array.isArray(levels)) return {};
  return levels as Record<string, LevelRecord>;
}

function planWrite(existing: StoredDoc | null, fields: Record<string, unknown>): PlannedWrite {
  return {
    fields,
    touchUpdatedAt: true,
    precondition: existing ? { updateTime: existing.updateTime } : { exists: false },
    improved: true,
  };
}

export async function handleLevelClear(
  deps: SubmitDeps,
  uid: string,
  rawBody: unknown,
): Promise<LevelClearResponse> {
  if (!UID_PATTERN.test(uid)) return fail(400, 'bad_request');
  const parsed = parseLevelClearBody(rawBody);
  if (!parsed) return fail(400, 'bad_request');
  if (parsed.timeSeconds < MIN_SECONDS[parsed.gameId]) return fail(422, 'too_fast');
  if (parsed.timeSeconds > MAX_SECONDS) return fail(422, 'too_slow');

  const base = documentsBase(deps.projectId);
  const game = `${base}/${LEADERBOARD_ROOT}/${parsed.gameId}`;
  const worldName = `${base}/level_worlds/${parsed.gameId}_${parsed.worldOrder}`;
  const recordsName = `${game}/level_records/${uid}`;
  const rowName = `${game}/levels/${uid}`;

  try {
    const accessToken = await deps.getAccessToken();
    let docs = await batchGet({
      projectId: deps.projectId,
      accessToken,
      names: [worldName, recordsName, rowName],
    });

    const found = findLevel(docs.get(worldName)?.data ?? null, parsed.levelId, parsed.gameId);
    if (!found) return fail(422, 'not_live');
    const proofOk =
      found.level.game === 'zip'
        ? checkZipProof(found.level.puzzle, parsed.proof)
        : checkPathWordsProof(found.level.puzzle, parsed.proof);
    if (!proofOk) return fail(422, 'bad_proof');

    const run: LevelRecord = {
      stars: starsFor(parsed.usedHints, parsed.timeSeconds, found.targetSeconds),
      bestSeconds: parsed.timeSeconds,
    };

    for (let attempt = 0; ; attempt++) {
      const recordsDoc = docs.get(recordsName) ?? null;
      const rowDoc = docs.get(rowName) ?? null;
      const merged = mergeLevelRecord(storedRecords(recordsDoc), parsed.levelId, run);
      if (!merged.improved) return { status: 200, body: { accepted: true, improved: false } };

      const writes = [
        toCommitWrite(recordsName, planWrite(recordsDoc, { levels: merged.records })),
        toCommitWrite(
          rowName,
          planWrite(rowDoc, {
            ...levelBoardTotals(merged.records),
            ...identityFields(parsed.identity),
          }),
        ),
      ];
      try {
        await commit({ projectId: deps.projectId, accessToken, writes });
        return { status: 200, body: { accepted: true, improved: true } };
      } catch (e) {
        if (!(e instanceof ContentionError)) throw e;
        if (attempt >= 1) return { status: 503, body: { error: 'busy' } };
        docs = await batchGet({
          projectId: deps.projectId,
          accessToken,
          names: [recordsName, rowName],
        });
      }
    }
  } catch (e) {
    console.error('leaderboard_level_clear_failed', e instanceof Error ? e.message : e);
    return { status: 503, body: { error: 'unavailable' } };
  }
}
