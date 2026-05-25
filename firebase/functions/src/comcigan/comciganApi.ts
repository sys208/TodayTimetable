/**
 * 컴시간 알리미 API 래퍼
 * 원본 vs 변경 시간표 비교로 변경 수업 감지
 */

// eslint-disable-next-line @typescript-eslint/no-var-requires
const Timetable = require("comcigan-parser");

export interface ComciganSchool {
  name: string;
  code: number;
  region: string;
}

export interface ComciganEntry {
  date: string;
  dayOfWeek: number;  // 1=월 ~ 5=금
  period: number;
  subject: string;
  teacher: string;
  changed: boolean;
}

export interface ComciganClassTime {
  period: number;
  startTime: string;
  endTime: string;
}

export async function searchComcigan(schoolName: string): Promise<ComciganSchool[]> {
  const timetable = new Timetable();
  await timetable.init();
  const results = await timetable.search(schoolName);
  return results.map((s: { name: string; code: number; region: string }) => ({
    name: s.name,
    code: s.code,
    region: s.region || "",
  }));
}

export async function getComciganTimetable(
  schoolCode: number,
  grade: number,
  classNumber: number,
  classDurationMinutes = 45
): Promise<{ entries: ComciganEntry[]; classTimes: ComciganClassTime[] }> {
  const t = new Timetable();
  await t.init();
  t.setSchool(schoolCode);

  // 파싱된 시간표 (변경본 기준)
  const data = await t.getTimetable();

  // 원본 JSON에서 원본 vs 변경 비교
  const jsonString = await t._getData();
  const json = JSON.parse(jsonString);

  // 원본 시간표 키와 변경 시간표 키 찾기
  // 자료481 = 원본, 자료147 = 변경 (학교마다 키가 다를 수 있어서 동적 탐색)
  let originalData: number[][][] | null = null;
  let modifiedData: number[][][] | null = null;

  // 시간표 데이터 후보 찾기 (배열 형태이고 학년/반 구조인 것)
  const candidateKeys: string[] = [];
  for (const key of Object.keys(json)) {
    const val = json[key];
    if (key.startsWith("자료") && Array.isArray(val) && val[grade] && Array.isArray(val[grade][classNumber])) {
      const arr = val[grade][classNumber];
      // 첫 번째 원소가 숫자(교시수)이고 나머지가 배열인 것
      if (typeof arr[0] === "number" && arr.length > 1 && Array.isArray(arr[1])) {
        candidateKeys.push(key);
      }
    }
  }

  // 후보가 2개면 비교 가능 (원본 vs 변경)
  if (candidateKeys.length >= 2) {
    const data1 = json[candidateKeys[0]][grade][classNumber];
    const data2 = json[candidateKeys[1]][grade][classNumber];
    // 값이 다른 게 있으면 하나가 원본, 하나가 변경
    // 변경본은 파서가 쓰는 것 → data2가 변경본인 경우가 많음
    originalData = data1;
    modifiedData = data2;
  }

  // 변경 감지 맵: changedMap[dayIdx][period] = true
  const changedMap: Record<number, Record<number, boolean>> = {};
  if (originalData && modifiedData) {
    for (let dayIdx = 1; dayIdx <= 5; dayIdx++) {
      const origDay = originalData[dayIdx];
      const modDay = modifiedData[dayIdx];
      if (!origDay || !modDay) continue;

      for (let p = 1; p < origDay.length && p < modDay.length; p++) {
        if (origDay[p] !== modDay[p]) {
          if (!changedMap[dayIdx - 1]) changedMap[dayIdx - 1] = {};
          changedMap[dayIdx - 1][p] = true;
        }
      }
    }
  }

  // 교시 시간
  let classTimeData: string[] = [];
  try {
    classTimeData = await t.getClassTime();
  } catch {
    // ignore
  }

  // 날짜 계산 - 컴시간의 일자자료에서 실제 주간 시작일 추출
  const rawJson = JSON.parse(await t._getData());
  let monday: Date;

  const dateInfo = rawJson["일자자료"];
  if (dateInfo && Array.isArray(dateInfo) && dateInfo.length > 0) {
    // 일자자료: [[1,"26-04-13 ~ 26-04-18"],[2,"26-04-20 ~ 26-04-25"]]
    // 첫 번째 주간(현재 표시 중인 주)의 시작일 사용
    const weekStr = dateInfo[0][1]; // "26-04-13 ~ 26-04-18"
    const startStr = weekStr.split("~")[0].trim(); // "26-04-13"
    const parts = startStr.split("-");
    const year = 2000 + parseInt(parts[0]);
    const month = parseInt(parts[1]) - 1;
    const day = parseInt(parts[2]);
    monday = new Date(year, month, day);
  } else {
    // fallback: 현재 날짜 기준 월요일
    const now = new Date();
    const dow = now.getDay();
    monday = new Date(now);
    monday.setDate(now.getDate() - (dow === 0 ? 6 : dow - 1));
  }

  const entries: ComciganEntry[] = [];

  if (data[grade] && data[grade][classNumber]) {
    const classData = data[grade][classNumber];

    for (let dayIdx = 0; dayIdx <= 4; dayIdx++) {
      if (!classData[dayIdx]) continue;

      const dateObj = new Date(monday);
      dateObj.setDate(monday.getDate() + dayIdx);
      const y = dateObj.getFullYear();
      const m = String(dateObj.getMonth() + 1).padStart(2, "0");
      const d = String(dateObj.getDate()).padStart(2, "0");
      const dateStr = `${y}${m}${d}`;

      for (const entry of classData[dayIdx]) {
        if (!entry || !entry.subject || entry.subject.trim() === "") continue;

        const isChanged = changedMap[dayIdx]?.[entry.classTime] || false;

        entries.push({
          date: dateStr,
          dayOfWeek: dayIdx + 1,
          period: entry.classTime,
          subject: entry.subject,
          teacher: entry.teacher || "",
          changed: isChanged,
        });
      }
    }
  }

  // 교시 시간 파싱
  const classTimes: ComciganClassTime[] = [];
  const classDuration = Math.min(Math.max(Math.floor(classDurationMinutes), 30), 80);

  if (classTimeData && classTimeData.length > 0) {
    for (const ct of classTimeData) {
      const ctMatch = ct.match(/(\d+)\((\d{2}:\d{2})\)/);
      if (ctMatch) {
        const period = parseInt(ctMatch[1]);
        const startTime = ctMatch[2];
        const [h, mm] = startTime.split(":").map(Number);
        const endMinutes = h * 60 + mm + classDuration;
        const endTime = `${String(Math.floor(endMinutes / 60)).padStart(2, "0")}:${String(endMinutes % 60).padStart(2, "0")}`;
        classTimes.push({ period, startTime, endTime });
      }
    }
  }

  return { entries, classTimes };
}

// ──────────────────────────────────────
// 교사 시간표
// ──────────────────────────────────────

export interface TeacherInfo {
  index: number;
  name: string;
}

export interface TeacherTimetableEntry {
  dayOfWeek: number;  // 1=월 ~ 5=금
  period: number;
  grade: number;
  classNumber: number;
  subject: string;
  changed: boolean;
}

export async function getComciganTeacherList(schoolCode: number): Promise<TeacherInfo[]> {
  const t = new Timetable();
  await t.init();
  t.setSchool(schoolCode);
  const raw = JSON.parse(await t._getData());

  const teachers: string[] = raw["자료446"] || [];
  return teachers
    .map((name: string, index: number) => ({ index, name }))
    .filter((t: TeacherInfo) => t.index > 0 && t.name && t.name !== "*");
}

export async function getComciganTeacherTimetable(
  schoolCode: number,
  teacherIndex: number
): Promise<{ entries: TeacherTimetableEntry[]; classTimes: ComciganClassTime[]; teacherName: string }> {
  const t = new Timetable();
  await t.init();
  t.setSchool(schoolCode);
  const raw = JSON.parse(await t._getData());

  const teachers: string[] = raw["자료446"] || [];
  const subjects: (string | number)[] = raw["자료492"] || [];
  const data542: number[][] = raw["자료542"] || []; // 교사별 시간표 전용

  const teacherName = teachers[teacherIndex] || "";
  const entries: TeacherTimetableEntry[] = [];

  // 변동 감지: 원본(자료481 기반 시간표2) vs 변경(자료542) 비교
  // 컴시간교사 JS의 교사시간표_원자료생성 완전 재현
  const data481: number[][][][] = raw["자료481"];
  const classCount: number[] = raw["학급수"] || [];
  const sep = raw["분리"] || 1000;
  const teacherCount = raw["교사수"] || 0;

  // mTh(mm, m2): m2==100 ? floor(mm/m2) : mm%m2
  const mThFn = (mm: number, m2: number) => m2 === 100 ? Math.floor(mm / m2) : mm % m2;
  const mSbFn = (mm: number, m2: number) => m2 === 100 ? mm % m2 : Math.floor(mm / m2);

  // 원본 시간표2[교사][요일][교시] 재구성
  const origTT: Record<number, number> = {}; // key: day*10+period, value
  if (data481) {
    for (let g = 1; g <= 3; g++) {
      for (let c = 1; c <= (classCount[g] || 0); c++) {
        for (let day = 1; day <= 5; day++) {
          for (let p = 1; p <= 8; p++) {
            const val = data481?.[g]?.[c]?.[day]?.[p] || 0;
            if (val <= 0) continue;
            const ti = mThFn(val, sep);
            if (ti !== teacherIndex || ti <= 0 || ti > teacherCount) continue;
            const sb = mSbFn(val, sep);
            const encoded = sep === 100
              ? (g * 100 + c) * sep + sb
              : sb * sep + g * 100 + c;
            origTT[day * 10 + p] = encoded;
          }
        }
      }
    }
  }

  // changedMap: 원본 vs 자료542 비교
  const changedMap: Record<number, Record<number, boolean>> = {};
  const td542 = data542[teacherIndex];
  if (td542) {
    for (let day = 1; day <= 5; day++) {
      const dayData = td542[day];
      if (!Array.isArray(dayData)) continue;
      for (let p = 1; p < dayData.length; p++) {
        const rawMod = dayData[p];
        const modVal = typeof rawMod === "string" ? parseInt(rawMod.replace(/[^0-9]/g, ""), 10) || 0 : Number(rawMod) || 0;
        const origVal = origTT[day * 10 + p] || 0;
        if (origVal !== modVal) {
          if (!changedMap[day]) changedMap[day] = {};
          changedMap[day][p] = true;
        }
      }
    }
    // 원본에만 있는 교시 (변경에서 사라진 수업)
    for (const key of Object.keys(origTT)) {
      const k = parseInt(key);
      const day = Math.floor(k / 10);
      const p = k % 10;
      const dayArr = td542[day] as unknown as number[] | undefined;
      const modVal = dayArr?.[p] || 0;
      if (modVal === 0 && origTT[k] > 0) {
        if (!changedMap[day]) changedMap[day] = {};
        changedMap[day][p] = true;
      }
    }
  }

  // 자료542[교사인덱스] = [교시수, [요일1데이터], [요일2데이터], ...]
  // 값 디코딩: val / 분리(=1000) → 과목인덱스, val % 분리 → 학년반코드(학년*100+반)
  const teacherData = data542[teacherIndex];
  let hasData542 = false;
  if (teacherData && Array.isArray(teacherData)) {
    for (let day = 1; day <= 5; day++) {
      const dayData = teacherData[day];
      if (!Array.isArray(dayData)) continue;
      for (let period = 1; period < dayData.length; period++) {
        const rawVal = dayData[period];
        // 컴시간 데이터에 ">숫자" 형태 문자열이 올 수 있음 → 숫자로 변환
        const val = typeof rawVal === "string" ? parseInt(rawVal.replace(/[^0-9]/g, ""), 10) : Number(rawVal);
        if (!val || val <= 0 || isNaN(val)) continue;

        hasData542 = true;
        const subjectIdx = Math.floor(val / sep);
        const classCode = val % sep; // 학년*100+반 (예: 303 = 3학년3반)
        const grade = Math.floor(classCode / 100);
        const cls = classCode % 100;

        if (grade < 1 || grade > 6 || cls < 1 || cls > 20) continue;

        entries.push({
          dayOfWeek: day,
          period,
          grade,
          classNumber: cls,
          subject: (typeof subjects[subjectIdx] === "string" ? subjects[subjectIdx] : "") as string,
          changed: changedMap[day]?.[period] || false,
        });
      }
    }
  }

  // fallback: 자료542가 비어있으면 자료481(원본)에서 교사 시간표 역추출
  if (!hasData542 && data481) {
    for (let g = 1; g <= 6; g++) {
      for (let c = 1; c <= (classCount[g] || 0); c++) {
        for (let day = 1; day <= 5; day++) {
          for (let p = 1; p <= 9; p++) {
            const val = data481?.[g]?.[c]?.[day]?.[p] || 0;
            if (val <= 0) continue;
            const ti = mThFn(val, sep);
            if (ti !== teacherIndex || ti <= 0 || ti > teacherCount) continue;
            const sb = mSbFn(val, sep);
            entries.push({
              dayOfWeek: day,
              period: p,
              grade: g,
              classNumber: c,
              subject: (typeof subjects[sb] === "string" ? subjects[sb] : "") as string,
              changed: false,
            });
          }
        }
      }
    }
  }

  // 교시 시간
  let classTimeData: string[] = [];
  try { classTimeData = await t.getClassTime(); } catch { /* ignore */ }

  const classTimes: ComciganClassTime[] = [];
  if (classTimeData) {
    for (const ct of classTimeData) {
      const ctMatch = ct.match(/(\d+)\((\d{2}:\d{2})\)/);
      if (ctMatch) {
        const period = parseInt(ctMatch[1]);
        const startTime = ctMatch[2];
        const [h, mm] = startTime.split(":").map(Number);
        const endMinutes = h * 60 + mm + 45;
        const endTime = `${String(Math.floor(endMinutes / 60)).padStart(2, "0")}:${String(endMinutes % 60).padStart(2, "0")}`;
        classTimes.push({ period, startTime, endTime });
      }
    }
  }

  return { entries, classTimes, teacherName };
}
