import { readFileSync } from "fs";
import { join } from "path";

export interface CareerPublicDataRequest {
  interestArea?: string;
  favoriteSubjects?: string;
  difficultSubjects?: string;
  target?: string;
  studyStyle?: string;
  activities?: string;
  schoolType?: string;
  grade?: number;
}

export interface CareerSecretValues {
  work24JobPostingsKey: string;
  work24HrdNetKey: string;
  work24WorkStudyKey: string;
  work24EmployabilityProgramKey: string;
  work24JobInfoKey: string;
  work24CommonCodeKey: string;
  work24DutyInfoKey: string;
  work24MajorInfoKey: string;
  dataGoKrServiceKey: string;
  careerNetApiKey: string;
}

interface CareerSection {
  title: string;
  items: string[];
}

export interface CareerPublicDataResult {
  contextText: string;
  sources: string[];
  sections: CareerSection[];
  sourceStatuses: string[];
}

interface XmlRecord {
  [key: string]: string;
}

interface KediOutcome {
  majorName: string;
  collegeName: string;
  surveyDate: string;
  graduates: number;
  employed: number;
  advanced: number;
  employmentRate: number;
  advancementRate: number;
}

const WORK24_BASE = "https://www.work24.go.kr/cm/openApi/call";
const CAREER_NET_BASE = "https://www.career.go.kr/cnet/openapi/getOpenApi";
const KMOOC_BASE = "https://apis.data.go.kr/B552881/kmooc_v2_0";
const UNIVERSITY_BASE = "https://openapi.academyinfo.go.kr/openapi/service/rest/SchoolInfoService/getSchoolInfo";
const REQUEST_TIMEOUT_MS = 6500;
const COMMON_CODE_GROUPS = [
  { dtlGb: "2", title: "직종" },
  { dtlGb: "6", title: "전공" },
  { dtlGb: "8", title: "학과계열" },
];

export async function buildCareerPublicData(
  request: CareerPublicDataRequest,
  secrets: CareerSecretValues
): Promise<CareerPublicDataResult> {
  const keywords = chooseKeywords(request);
  const queryKeywords = expandCareerKeywords(keywords).slice(0, 4);
  const primaryKeyword = queryKeywords[0] ?? "진로";
  const sourceSections = await Promise.all([
    safeSection("고용24 직업정보", () => fetchFromKeywords(queryKeywords, (keyword) => fetchWork24Jobs(keyword, secrets.work24JobInfoKey), 12)),
    safeSection("고용24 학과정보", () => fetchFromKeywords(queryKeywords, (keyword) => fetchWork24Majors(keyword, secrets.work24MajorInfoKey), 12)),
    safeSection("고용24 직무정보", () => fetchWork24Duties(request, secrets.work24DutyInfoKey)),
    safeSection("고용24 국민내일배움카드 훈련과정", () => fetchFromKeywords(queryKeywords, (keyword) => fetchWork24Training(keyword, secrets.work24HrdNetKey), 12)),
    safeSection("고용24 일학습병행", () => fetchFromKeywords(queryKeywords, (keyword) => fetchWork24WorkStudy(keyword, secrets.work24WorkStudyKey), 8)),
    safeSection("고용24 취업역량 프로그램", () => fetchFromKeywords(queryKeywords, (keyword) => fetchWork24Employability(keyword, secrets.work24EmployabilityProgramKey), 8)),
    safeSection("고용24 채용정보", () => fetchFromKeywords(queryKeywords, (keyword) => fetchWork24JobPostings(keyword, secrets.work24JobPostingsKey), 8)),
    safeSection("고용24 공통코드", () => fetchWork24CommonCodes(primaryKeyword, secrets.work24CommonCodeKey)),
    safeSection("커리어넷 직업/학과", () => fetchFromKeywords(queryKeywords, (keyword) => fetchCareerNet(keyword, secrets.careerNetApiKey), 12)),
    safeSection("대학 후보 기본정보", () => fetchUniversities(queryKeywords, secrets.dataGoKrServiceKey)),
    safeSection("K-MOOC 강좌", () => fetchFromKeywords(queryKeywords, (keyword) => fetchKmooc(keyword, secrets.dataGoKrServiceKey), 10)),
    safeSection("KEDI 학과별 졸업 후 상황", () => Promise.resolve(readKediOutcomes(queryKeywords))),
  ]);

  const sections = sourceSections.filter((section) => section.items.length > 0);
  const sources = sections.map((section) => section.title);
  const sourceStatuses = sourceSections.map((section) =>
    `${section.title}: ${section.items.length > 0 ? `${section.items.length}건` : "조회 결과 없음 또는 접근 제한"}`
  );
  const statusText = [
    `[조회 키워드]\n${queryKeywords.map((keyword) => `- ${keyword}`).join("\n")}`,
    `[공공데이터 조회 상태]\n${sourceStatuses.map((status) => `- ${status}`).join("\n")}`,
  ].join("\n\n");
  const contextText = sections.length === 0
    ? `${statusText}\n\n조회된 외부 공공데이터가 없습니다. 앱 내부 학교생활 데이터와 학생 입력을 우선 사용하세요.`
    : `${statusText}\n\n${sections.map((section) => {
      const rows = section.items.slice(0, 8).map((item) => `- ${item}`).join("\n");
      return `[${section.title}]\n${rows}`;
    }).join("\n\n")}`;

  return { contextText, sources, sections, sourceStatuses };
}

function chooseKeywords(request: CareerPublicDataRequest): string[] {
  const candidates = [
    request.target,
    request.interestArea,
    request.favoriteSubjects,
    request.activities,
  ]
    .map(cleanText)
    .filter((value) => value.length > 0);

  const first = candidates[0] ?? "진로";
  const words = candidates
    .flatMap((candidate) => candidate.split(/[,\s/·]+/))
    .map((part) => cleanText(part))
    .filter((part) => part.length >= 2)[0]
    ? candidates.flatMap((candidate) => candidate.split(/[,\s/·]+/))
    : [first];

  return Array.from(new Set(
    words
      .map((part) => cleanText(part).slice(0, 24))
      .filter((part) => part.length >= 2)
  )).slice(0, 3);
}

function expandCareerKeywords(keywords: string[]): string[] {
  const expanded = [...keywords];
  const text = normalizeKeyword(keywords.join(" "));
  const groups: Array<{ keys: string[]; values: string[] }> = [
    {
      keys: ["개발", "소프트웨어", "컴퓨터", "코딩", "프로그래밍", "ai", "인공지능", "데이터", "보안"],
      values: ["개발자", "소프트웨어", "컴퓨터공학", "정보", "데이터", "인공지능"],
    },
    {
      keys: ["디자인", "미술", "영상", "콘텐츠", "패션", "시각"],
      values: ["디자인", "시각디자인", "영상", "콘텐츠", "미디어"],
    },
    {
      keys: ["의료", "간호", "보건", "바이오", "생명", "약학"],
      values: ["간호", "보건", "생명과학", "바이오", "의료"],
    },
    {
      keys: ["경영", "경제", "회계", "마케팅", "창업", "금융"],
      values: ["경영", "경제", "회계", "마케팅", "금융"],
    },
    {
      keys: ["건축", "건설", "도시", "토목", "환경"],
      values: ["건축", "토목", "도시", "환경", "건설"],
    },
    {
      keys: ["교육", "교사", "심리", "상담", "사회"],
      values: ["교육", "심리", "상담", "사회복지", "청소년"],
    },
  ];

  for (const group of groups) {
    if (group.keys.some((key) => text.includes(normalizeKeyword(key)))) {
      expanded.push(...group.values);
    }
  }

  return Array.from(new Set(
    expanded
      .map((keyword) => cleanText(keyword).slice(0, 24))
      .filter((keyword) => keyword.length >= 2)
  ));
}

async function safeSection(title: string, loader: () => Promise<string[]>): Promise<CareerSection> {
  try {
    const items = (await loader()).map(cleanText).filter((item) => item.length > 0);
    return { title, items };
  } catch (error) {
    console.warn(`Career data source failed: ${title}`, error);
    return { title, items: [] };
  }
}

async function fetchFromKeywords(
  keywords: string[],
  loader: (keyword: string) => Promise<string[]>,
  limit: number
): Promise<string[]> {
  const items: string[] = [];
  for (const keyword of keywords) {
    const values = await loader(keyword);
    for (const value of values) {
      if (!items.includes(value)) items.push(value);
      if (items.length >= limit) return items;
    }
  }
  return items;
}

async function fetchWork24Jobs(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const url = buildUrl(`${WORK24_BASE}/wk/callOpenApiSvcInfo212L01.do`, {
    authKey,
    returnType: "XML",
    target: "JOBCD",
    srchType: "K",
    keyword,
  });
  const xml = await fetchText(url);
  return parseXmlRecords(xml, "jobList").slice(0, 8).map((record) =>
    compactLine([record.jobNm, record.jobClcdNM, record.jobCd && `코드 ${record.jobCd}`])
  );
}

async function fetchWork24Majors(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const url = buildUrl(`${WORK24_BASE}/wk/callOpenApiSvcInfo213L01.do`, {
    authKey,
    returnType: "XML",
    startPage: "1",
    display: "8",
    keyword,
  });
  const xml = await fetchText(url);
  return parseLikelyXmlRows(xml).slice(0, 8).map((record) =>
    compactLine([
      record.majorNm ?? record.majorName ?? record.mClass ?? record.name ?? record.title,
      record.summary ?? record.content ?? record.info,
      record.lClass ?? record.category,
    ])
  );
}

async function fetchWork24CommonCodes(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const normalized = normalizeKeyword(keyword);
  const rows: string[] = [];
  for (const group of COMMON_CODE_GROUPS) {
    const url = buildUrl(`${WORK24_BASE}/wk/callOpenApiSvcInfo21L09.do`, {
      authKey,
      returnType: "XML",
      target: "CMCD",
      dtlGb: group.dtlGb,
    });
    const xml = await fetchText(url);
    const names = extractCommonCodeNames(xml)
      .filter((name) => normalizeKeyword(name).includes(normalized))
      .slice(0, 4);
    for (const name of names) {
      rows.push(`${group.title} 코드 후보: ${name}`);
    }
  }
  return rows.length > 0
    ? rows.slice(0, 10)
    : COMMON_CODE_GROUPS.map((group) => `${group.title} 공통코드 조회 완료: 직업·학과·채용 API 검색 조건 매핑에 사용`);
}

async function fetchWork24Duties(request: CareerPublicDataRequest, authKey: string): Promise<string[]> {
  const jobContent = cleanText([
    request.target,
    request.interestArea,
    request.activities,
    request.favoriteSubjects,
  ].filter(Boolean).join(" "));
  if (!authKey || jobContent.length < 2) return [];

  const url = buildUrl(`${WORK24_BASE}/wk/callOpenApiSvcInfo215L01.do`, {
    authKey,
    jobCont: jobContent.slice(0, 120),
    limit: "5",
    returnType: "JSON",
  });
  const data = await fetchJson(url);
  const result = data.result;
  if (!result || typeof result !== "object") return [];

  return Object.values(result as Record<string, unknown>).slice(0, 8).map((value) => {
    if (!value || typeof value !== "object") return "";
    const row = value as Record<string, unknown>;
    return compactLine([
      stringValue(row.job_sdvn),
      stringValue(row.ablt_def),
      stringValue(row.job_lcfn),
      stringValue(row.job_mcn),
    ]);
  });
}

async function fetchWork24Training(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const { start, end } = nextTrainingDateRange();
  const url = buildUrl(`${WORK24_BASE}/hr/callOpenApiSvcInfo310L01.do`, {
    authKey,
    returnType: "XML",
    outType: "1",
    pageNum: "1",
    pageSize: "10",
    srchTraStDt: start,
    srchTraEndDt: end,
    srchTraProcessNm: keyword,
    sort: "ASC",
    sortCol: "2",
  });
  const xml = await fetchText(url);
  return parseLikelyXmlRows(xml).slice(0, 8).map((record) =>
    compactLine([
      record.title ?? record.trprNm ?? record.subTitle ?? record.traProcessNm,
      record.address ?? record.instIno ?? record.trainstCstId,
      record.traStartDate && record.traEndDate ? `${record.traStartDate}~${record.traEndDate}` : "",
    ])
  );
}

async function fetchWork24WorkStudy(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const { start, end } = nextTrainingDateRange();
  const url = buildUrl(`${WORK24_BASE}/hr/callOpenApiSvcInfo313L01.do`, {
    authKey,
    returnType: "XML",
    outType: "1",
    pageNum: "1",
    pageSize: "5",
    srchTraStDt: start,
    srchTraEndDt: end,
    srchTraProcessNm: keyword,
    sort: "ASC",
    sortCol: "2",
  });
  const xml = await fetchText(url);
  return parseLikelyXmlRows(xml).slice(0, 5).map((record) =>
    compactLine([
      record.title ?? record.trprNm ?? record.subTitle ?? record.traProcessNm,
      record.address ?? record.trainstCstId,
      record.traStartDate && record.traEndDate ? `${record.traStartDate}~${record.traEndDate}` : "",
    ])
  );
}

async function fetchWork24Employability(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const url = buildUrl(`${WORK24_BASE}/wk/callOpenApiSvcInfo217L01.do`, {
    authKey,
    returnType: "XML",
    startPage: "1",
    display: "8",
    pgmStdt: formatDateKey(new Date()),
  });
  const xml = await fetchText(url);
  const normalized = normalizeKeyword(keyword);
  const rows = parseXmlRecords(xml, "empPgmSchdInvite").slice(0, 24).map((record) =>
    compactLine([
      record.pgmNm,
      record.pgmSubNm,
      record.orgNm,
      record.pgmTarget,
      record.pgmStdt && record.pgmEndt ? `${record.pgmStdt}~${record.pgmEndt}` : "",
    ])
  );
  const matched = rows.filter((row) => normalizeKeyword(row).includes(normalized));
  return (matched.length > 0 ? matched : rows).slice(0, 8);
}

async function fetchWork24JobPostings(keyword: string, authKey: string): Promise<string[]> {
  if (!authKey) return [];
  const url = buildUrl(`${WORK24_BASE}/wk/callOpenApiSvcInfo210L01.do`, {
    authKey,
    callTp: "L",
    returnType: "XML",
    startPage: "1",
    display: "8",
    keyword,
  });
  const xml = await fetchText(url);
  return parseLikelyXmlRows(xml).slice(0, 8).map((record) =>
    compactLine([
      record.wantedTitle ?? record.title ?? record.jobNm,
      record.company ?? record.corpNm,
      record.region ?? record.basicAddr,
      record.sal ?? record.salary,
    ])
  );
}

async function fetchCareerNet(keyword: string, apiKey: string): Promise<string[]> {
  if (!apiKey) return [];
  const [jobs, majors] = await Promise.all([
    fetchCareerNetJobs(keyword, apiKey),
    fetchCareerNetMajors(keyword, apiKey),
  ]);
  return [...jobs, ...majors].slice(0, 10);
}

async function fetchCareerNetJobs(keyword: string, apiKey: string): Promise<string[]> {
  const url = buildUrl(CAREER_NET_BASE, {
    apiKey,
    svcType: "api",
    svcCode: "JOB",
    contentType: "json",
    gubun: "job_dic_list",
    thisPage: "1",
    perPage: "8",
    searchTitle: keyword,
  });
  const data = await fetchJson(url);
  return findObjects(data).slice(0, 8).map((row) =>
    compactLine([
      stringValue(row.job),
      stringValue(row.jobNm),
      stringValue(row.job_nm),
      stringValue(row.summary),
    ])
  );
}

async function fetchCareerNetMajors(keyword: string, apiKey: string): Promise<string[]> {
  const url = buildUrl(CAREER_NET_BASE, {
    apiKey,
    svcType: "api",
    svcCode: "MAJOR",
    contentType: "json",
    gubun: "univ_list",
    thisPage: "1",
    perPage: "8",
    searchTitle: keyword,
  });
  const data = await fetchJson(url);
  return findObjects(data).slice(0, 8).map((row) =>
    compactLine([
      "학과",
      stringValue(row.major),
      stringValue(row.mClass),
      stringValue(row.summary),
    ])
  );
}

async function fetchUniversities(keywords: string[], serviceKey: string): Promise<string[]> {
  if (!serviceKey) return [];
  const candidateNames = inferUniversityNames(keywords);
  const items: string[] = [];
  for (const schoolName of candidateNames) {
    const url = buildUrl(UNIVERSITY_BASE, {
      serviceKey,
      pageNo: "1",
      numOfRows: "3",
      svyYr: "2023",
      schlKrnNm: schoolName,
    });
    const xml = await fetchText(url);
    for (const record of parseXmlRecords(xml, "item").slice(0, 2)) {
      const line = compactLine([
        record.schlNm,
        record.schlDivNm || record.schlKndNm,
        record.pbnfAreaNm,
        record.schlEstbDivNm,
        record.schlUrlAdrs,
      ]);
      if (line && !items.includes(line)) items.push(line);
      if (items.length >= 8) return items;
    }
  }
  return items;
}

async function fetchKmooc(keyword: string, serviceKey: string): Promise<string[]> {
  if (!serviceKey) return [];
  const url = buildUrl(`${KMOOC_BASE}/courseList`, {
    serviceKey,
    Mobile: "1",
    Page: "1",
    Size: "8",
    keyword,
  });
  const data = await fetchJson(url);
  return findObjects(data).slice(0, 8).map((row) =>
    compactLine([
      stringValue(row.name),
      stringValue(row.courseName),
      stringValue(row.orgName),
      stringValue(row.teacher),
      stringValue(row.classfyName),
    ])
  );
}

function readKediOutcomes(keywords: string[]): string[] {
  const csvPath = join(__dirname, "../../data/kedi/graduate_outcomes_by_major.csv");
  const buffer = readFileSync(csvPath);
  const decoder = new TextDecoder("euc-kr");
  const rows = parseCsv(decoder.decode(buffer));
  if (rows.length < 2) return [];

  const headers = rows[0];
  const outcomes = rows.slice(1).map((row) => toKediOutcome(headers, row));
  const normalizedKeywords = keywords.map(normalizeKeyword);
  return outcomes
    .filter((outcome) => {
      const haystack = normalizeKeyword(`${outcome.majorName} ${outcome.collegeName}`);
      return normalizedKeywords.some((keyword) => haystack.includes(keyword));
    })
    .sort((a, b) => b.graduates - a.graduates)
    .slice(0, 8)
    .map((outcome) =>
      `${outcome.majorName}(${outcome.collegeName}) ${outcome.surveyDate}: 졸업자 ${outcome.graduates}명, 취업 참고율 ${outcome.employmentRate.toFixed(1)}%, 진학 참고율 ${outcome.advancementRate.toFixed(1)}%`
    );
}

function toKediOutcome(headers: string[], row: string[]): KediOutcome {
  const get = (name: string) => row[headers.indexOf(name)] ?? "";
  const number = (name: string) => Number(get(name).replace(/,/g, "")) || 0;
  const graduates = number("졸업자_남") + number("졸업자_여");
  const employed = [
    "건보가입취업자_남",
    "건보가입취업자_여",
    "교내취업자_남",
    "교내취업자_여",
    "해외취업자_남",
    "해외취업자_여",
    "농림어업종사자_남",
    "농림어업종사자_여",
    "개인창작활동종사자_남",
    "개인창작활동종사자_여",
    "1인창사업자_남",
    "1인창사업자_여",
    "프리랜서_남",
    "프리랜서_여",
  ].reduce((sum, key) => sum + number(key), 0);
  const advanced = number("진학자_남") + number("진학자_여");

  return {
    majorName: get("학과명"),
    collegeName: get("단과대학명"),
    surveyDate: get("조사회차"),
    graduates,
    employed,
    advanced,
    employmentRate: graduates > 0 ? (employed / graduates) * 100 : 0,
    advancementRate: graduates > 0 ? (advanced / graduates) * 100 : 0,
  };
}

function nextTrainingDateRange(): { start: string; end: string } {
  const startDate = new Date();
  const endDate = new Date();
  endDate.setMonth(endDate.getMonth() + 6);
  return {
    start: formatDateKey(startDate),
    end: formatDateKey(endDate),
  };
}

function inferUniversityNames(keywords: string[]): string[] {
  const normalized = normalizeKeyword(keywords.join(" "));
  const groups: Array<{ keys: string[]; schools: string[] }> = [
    {
      keys: ["개발", "소프트웨어", "컴퓨터", "정보", "ai", "인공지능", "데이터", "보안"],
      schools: ["숭실대학교", "광운대학교", "세종대학교", "아주대학교", "인하대학교", "가천대학교", "한양대학교", "서울시립대학교"],
    },
    {
      keys: ["디자인", "미술", "영상", "콘텐츠", "패션", "시각"],
      schools: ["홍익대학교", "국민대학교", "서울과학기술대학교", "한양대학교", "경희대학교", "동덕여자대학교"],
    },
    {
      keys: ["의료", "간호", "보건", "바이오", "생명", "약학"],
      schools: ["가천대학교", "을지대학교", "연세대학교", "고려대학교", "한림대학교", "인제대학교"],
    },
    {
      keys: ["경영", "경제", "회계", "마케팅", "창업", "금융"],
      schools: ["성균관대학교", "한양대학교", "중앙대학교", "경희대학교", "동국대학교", "건국대학교"],
    },
    {
      keys: ["건축", "건설", "도시", "토목", "환경"],
      schools: ["서울시립대학교", "한양대학교", "인하대학교", "아주대학교", "중앙대학교", "경북대학교"],
    },
    {
      keys: ["교육", "교사", "심리", "상담", "사회"],
      schools: ["한국교원대학교", "이화여자대학교", "서울교육대학교", "공주대학교", "동국대학교", "경희대학교"],
    },
  ];
  const matched = groups.find((group) => group.keys.some((key) => normalized.includes(normalizeKeyword(key))));
  return matched?.schools ?? ["서울시립대학교", "경희대학교", "동국대학교", "가천대학교", "인하대학교", "아주대학교"];
}

function formatDateKey(date: Date): string {
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
  ].join("");
}

async function fetchText(url: URL): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.text();
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchJson(url: URL): Promise<Record<string, unknown>> {
  const text = await fetchText(url);
  return JSON.parse(text) as Record<string, unknown>;
}

function buildUrl(base: string, params: Record<string, string | number | undefined>): URL {
  const url = new URL(base);
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === "") continue;
    url.searchParams.set(key, String(value));
  }
  return url;
}

function parseLikelyXmlRows(xml: string): XmlRecord[] {
  const tags = ["item", "srchList", "jobList", "dJobList", "wanted", "programList", "empPgmSchdInvite"];
  for (const tag of tags) {
    const rows = parseXmlRecords(xml, tag);
    if (rows.length > 0) return rows;
  }
  return [];
}

function extractCommonCodeNames(xml: string): string[] {
  const names = new Set<string>();
  const regexes = [
    /<jobNm>([\s\S]*?)<\/jobNm>/g,
    /<keadNm>([\s\S]*?)<\/keadNm>/g,
    /<majorNm>([\s\S]*?)<\/majorNm>/g,
    /<smlgntNm>([\s\S]*?)<\/smlgntNm>/g,
    /<codeName>([\s\S]*?)<\/codeName>/g,
    /<cdNm>([\s\S]*?)<\/cdNm>/g,
  ];
  for (const regex of regexes) {
    let match: RegExpExecArray | null;
    while ((match = regex.exec(xml)) !== null) {
      const value = decodeXml(match[1]);
      if (value.length > 0) names.add(value);
    }
  }
  return Array.from(names);
}

function parseXmlRecords(xml: string, tag: string): XmlRecord[] {
  const rows: XmlRecord[] = [];
  const rowRegex = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, "g");
  let rowMatch: RegExpExecArray | null;
  while ((rowMatch = rowRegex.exec(xml)) !== null) {
    const row: XmlRecord = {};
    const fieldRegex = /<([A-Za-z0-9_]+)>([\s\S]*?)<\/\1>/g;
    let fieldMatch: RegExpExecArray | null;
    while ((fieldMatch = fieldRegex.exec(rowMatch[1])) !== null) {
      row[fieldMatch[1]] = decodeXml(fieldMatch[2]);
    }
    rows.push(row);
  }
  return rows;
}

function decodeXml(value: string): string {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)]]>/g, "$1")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .trim();
}

function findObjects(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) {
    return value.flatMap(findObjects);
  }
  if (!value || typeof value !== "object") {
    return [];
  }

  const object = value as Record<string, unknown>;
  const childObjects = Object.values(object).flatMap(findObjects);
  const hasText = Object.values(object).some((child) => typeof child === "string" || typeof child === "number");
  return hasText ? [object, ...childObjects] : childObjects;
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let field = "";
  let row: string[] = [];
  let inQuotes = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (char === "\"" && next === "\"") {
      field += "\"";
      index += 1;
    } else if (char === "\"") {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      row.push(field);
      field = "";
    } else if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(field);
      if (row.some((cell) => cell.length > 0)) rows.push(row);
      row = [];
      field = "";
    } else {
      field += char;
    }
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

function compactLine(values: Array<string | undefined>): string {
  return values.map(cleanText).filter((value) => value.length > 0).join(" / ");
}

function cleanText(value: unknown): string {
  if (value === null || value === undefined) return "";
  return String(value).replace(/\s+/g, " ").trim();
}

function stringValue(value: unknown): string {
  return cleanText(value);
}

function normalizeKeyword(value: string): string {
  return cleanText(value).replace(/\s+/g, "").toLowerCase();
}
