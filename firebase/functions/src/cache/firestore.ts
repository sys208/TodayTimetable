/**
 * Firestore 캐시 헬퍼
 * NEIS API 응답을 캐싱하여 중복 호출 방지
 */

import { getFirestore, Firestore } from "firebase-admin/firestore";

interface CachedData<T> {
  data: T;
  cachedAt: number;     // Unix timestamp (ms)
  expiresAt: number;    // Unix timestamp (ms)
}

let _db: Firestore | null = null;
function db(): Firestore {
  if (!_db) _db = getFirestore();
  return _db;
}
const CACHE_COLLECTION = "neisCache";

/**
 * 캐시에서 데이터 조회
 * @param cacheKey 캐시 키 (예: "timetable:B10:7010057:3:2:1")
 * @returns 캐시 데이터 또는 null (만료/미존재 시)
 */
export async function getCache<T>(cacheKey: string): Promise<T | null> {
  const doc = await db().collection(CACHE_COLLECTION).doc(cacheKey).get();

  if (!doc.exists) return null;

  const cached = doc.data() as CachedData<T>;
  const now = Date.now();

  if (now > cached.expiresAt) {
    return null; // 캐시 만료
  }

  return cached.data;
}

/**
 * 데이터를 캐시에 저장
 * @param cacheKey 캐시 키
 * @param data 저장할 데이터
 * @param ttlMs 캐시 유효 시간 (밀리초)
 */
export async function setCache<T>(
  cacheKey: string,
  data: T,
  ttlMs: number
): Promise<void> {
  const now = Date.now();
  const cached: CachedData<T> = {
    data,
    cachedAt: now,
    expiresAt: now + ttlMs,
  };

  await db().collection(CACHE_COLLECTION).doc(cacheKey).set(cached);
}

// ──────────────────────────────────────
// 시간표 이력 저장 (과거 시간표 열람용)
// ──────────────────────────────────────

const HISTORY_COLLECTION = "timetableHistory";
const HISTORY_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000; // 30일

interface HistoryData {
  entries: unknown[];
  classTimes?: unknown[];
  weekStart: string;
  weekEnd: string;
  savedAt: number;
}

/**
 * 시간표 이력 저장 (주 단위)
 */
export async function saveHistory(
  schoolCode: string,
  grade: number,
  classNumber: number,
  weekStart: string,
  entries: unknown[],
  classTimes?: unknown[]
): Promise<void> {
  const weekEnd = weekStart; // weekStart 기반으로 계산
  const docId = `${schoolCode}:${grade}:${classNumber}:${weekStart}`;
  const data: HistoryData = {
    entries,
    classTimes,
    weekStart,
    weekEnd,
    savedAt: Date.now(),
  };
  await db().collection(HISTORY_COLLECTION).doc(docId).set(data);
}

/**
 * 시간표 이력 조회
 */
export async function getHistory(
  schoolCode: string,
  grade: number,
  classNumber: number,
  weekStart: string
): Promise<HistoryData | null> {
  const docId = `${schoolCode}:${grade}:${classNumber}:${weekStart}`;
  const doc = await db().collection(HISTORY_COLLECTION).doc(docId).get();
  if (!doc.exists) return null;
  return doc.data() as HistoryData;
}

/**
 * 30일 지난 이력 자동 삭제
 */
export async function cleanOldHistory(): Promise<void> {
  const cutoff = Date.now() - HISTORY_MAX_AGE_MS;
  const snapshot = await db()
    .collection(HISTORY_COLLECTION)
    .where("savedAt", "<", cutoff)
    .get();

  const batch = db().batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  if (!snapshot.empty) await batch.commit();
}

// ──────────────────────────────────────
// 캐시 TTL 상수
// ──────────────────────────────────────

export const CACHE_TTL = {
  SCHOOL_SEARCH: 30 * 24 * 60 * 60 * 1000,  // 30일
  TIMETABLE: 24 * 60 * 60 * 1000,              // 1일
  MEAL: 24 * 60 * 60 * 1000,                  // 1일
  SCHEDULE: 24 * 60 * 60 * 1000,               // 1일
};
