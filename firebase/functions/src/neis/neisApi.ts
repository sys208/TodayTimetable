/**
 * NEIS 교육정보 공개 포털 API 클라이언트
 * https://open.neis.go.kr/
 */

const BASE_URL = "https://open.neis.go.kr/hub";

export interface NEISParams {
  [key: string]: string | number | undefined;
}

export interface NEISResponse<T> {
  data: T[];
  totalCount: number;
}

/**
 * NEIS API 공통 호출 함수
 * @param endpoint API 엔드포인트 (예: "schoolInfo")
 * @param apiKey NEIS 인증키
 * @param params 요청 파라미터
 * @returns 파싱된 응답 데이터 배열
 */
export async function callNEIS<T>(
  endpoint: string,
  apiKey: string,
  params: NEISParams
): Promise<NEISResponse<T>> {
  const url = new URL(`${BASE_URL}/${endpoint}`);
  url.searchParams.set("KEY", apiKey);
  url.searchParams.set("Type", "json");
  url.searchParams.set("pSize", String(params.pSize ?? 1000));
  url.searchParams.set("pIndex", String(params.pIndex ?? 1));

  // 추가 파라미터 설정
  for (const [key, value] of Object.entries(params)) {
    if (key === "pSize" || key === "pIndex") continue;
    if (value !== undefined && value !== "") {
      url.searchParams.set(key, String(value));
    }
  }

  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`NEIS API 호출 실패: ${response.status}`);
  }

  const json = await response.json();

  // NEIS API 응답 구조: { [endpoint]: [{ head: [...] }, { row: [...] }] }
  const resultKey = Object.keys(json).find((k) => k !== "RESULT");

  if (!resultKey) {
    // INFO-200: 데이터 없음
    const result = json.RESULT;
    if (result?.CODE === "INFO-200") {
      return { data: [], totalCount: 0 };
    }
    throw new Error(`NEIS API 오류: ${JSON.stringify(json.RESULT)}`);
  }

  const sections = json[resultKey];
  const head = sections[0]?.head;
  const rows = sections[1]?.row ?? [];
  const totalCount = head?.[0]?.list_total_count ?? rows.length;

  return { data: rows as T[], totalCount };
}

// ──────────────────────────────────────
// NEIS API 응답 타입 정의
// ──────────────────────────────────────

export interface SchoolInfoRow {
  ATPT_OFCDC_SC_CODE: string; // 시도교육청코드
  SD_SCHUL_CODE: string;      // 표준학교코드
  SCHUL_NM: string;           // 학교명
  SCHUL_KND_SC_NM: string;    // 학교종류 (중학교, 고등학교 등)
  ORG_RDNMA: string;          // 도로명주소
  HMPG_ADRES: string;         // 홈페이지주소
}

export interface TimetableRow {
  ALL_TI_YMD: string;  // 시간표일자 (YYYYMMDD)
  GRADE: string;       // 학년
  CLASS_NM: string;    // 반
  PERIO: string;       // 교시
  ITRT_CNTNT: string;  // 수업내용 (과목명)
}

export interface MealRow {
  MLSV_YMD: string;       // 급식일자 (YYYYMMDD)
  MMEAL_SC_NM: string;    // 식사명 (조식/중식/석식)
  DDISH_NM: string;       // 메뉴 (줄바꿈으로 구분)
  CAL_INFO: string;       // 칼로리
  ORPLC_INFO: string;     // 원산지
  NTR_INFO: string;       // 영양정보
}

export interface ScheduleRow {
  AA_YMD: string;         // 학사일자 (YYYYMMDD)
  EVENT_NM: string;       // 행사명
  EVENT_CNTNT: string;    // 행사내용
  SBTR_DD_SC_NM: string;  // 수업공제일명 (휴업일 등)
}

export interface AcademyRow {
  ATPT_OFCDC_SC_CODE: string;
  ATPT_OFCDC_SC_NM: string;
  ADMST_ZONE_NM: string;
  ACA_INSTI_SC_NM: string;
  ACA_ASNUM: string;
  ACA_NM: string;
  ESTBL_YMD: string;
  REG_YMD: string;
  REG_STTUS_NM: string;
  CAA_BEGIN_YMD: string;
  CAA_END_YMD: string;
  TOFOR_SMTOT: number;
  DTM_RCPTN_ABLTY_NMPR_SMTOT: number;
  REALM_SC_NM: string;
  LE_ORD_NM: string;
  LE_CRSE_LIST_NM: string | null;
  LE_CRSE_NM: string;
  PSNBY_THCC_CNTNT: string;
  THCC_OTHBC_YN: string;
  BRHS_ACA_YN: string;
  FA_RDNMA: string;
  FA_RDNDA: string;
  FA_RDNZC: string;
  FA_TELNO: string | null;
  LOAD_DTM: string;
}
