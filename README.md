# 오늘시간표 — AI 기반 학교생활 통합 도우미

> 교육 공공데이터(NEIS, 1365, 커리어넷, 워크넷)와 AI를 활용한 학교생활·진로 통합 앱

[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue)]()
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)]()
[![Firebase](https://img.shields.io/badge/Backend-Firebase-yellow)]()
[![AI](https://img.shields.io/badge/AI-Groq%20%7C%20Gemini-green)]()

## 주요 기능 (70+)

### 📅 시간표
- 컴시간 알리미 실시간 변경 감지 + NEIS API fallback
- 교사 시간표 (과거 주차 이력, 변동 알림)
- 주간/일간 보기, 과목 수정, 사진 → AI 인식
- 위젯 4종 + 잠금화면 + Live Activity (다이나믹 아일랜드)
- Apple Watch 독립 실행

### 🍚 급식
- NEIS 급식 메뉴 + 19종 알레르기 강조
- **전국 13개 교육청 급식 사진 자동 크롤링** (10가지 파싱 방법)
- 칼로리 HealthKit 연동
- AI 주간 영양 리포트

### 📢 학급 공지 시스템
- 교사 @korea.kr 이메일 인증
- 8자리 코드로 학생 참여
- 마크다운 서식 + 이미지 첨부 + FCM 푸시
- 수행평가/시험범위/자료공유 유형별 뱃지
- 학생 리액션 (👍❤️🔥👏👀)

### 🤖 AI 기능 (10가지)
- AI 학교 비서 (Groq llama-3.3-70b)
- AI 진로 리포트 (공공데이터 기반 PDF 생성)
- AI 수행평가 분석 (Gemini Vision)
- AI 시간표 사진 인식
- AI 주간 영양 리포트
- AI 봉사활동 추천
- AI 학교 비교
- AI 학습 플래너
- AI 급식 이미지 생성
- 가정통신문 PDF 텍스트 추출

### 🤝 봉사활동 (1365 API)
- 31개 필드 전수 활용
- 봉사 장소 지도 (좌표 데이터)
- 신청 현황 프로그레스 바
- 활동 요일 시각화 + 봉사 시간 자동 계산
- 담당자 바로 연락 + 1365 바로 신청

### 📄 가정통신문
- 학교 홈페이지 자동 크롤링 (goeas.kr)
- DEXT5Upload 파싱 + PDF/HWP 첨부파일
- 인앱 Safari 브라우저

### 🏫 기타
- 학사일정 D-Day + 캘린더 자동 추가
- 공휴일 자동 감지 (NEIS 학사일정 isDayOff)
- 교육 뉴스 + FCM 푸시
- 패치노트 뷰 + 업데이트 알림
- iCloud 동기화
- 카카오톡/인스타 공유

## 기술 스택

| 분류 | 기술 |
|------|------|
| **iOS/macOS** | Swift 6.0, SwiftUI, SwiftData, WidgetKit, ActivityKit, WatchKit |
| **Backend** | Firebase Cloud Functions 30+개 (Node.js, TypeScript) |
| **Database** | Firestore (캐시 + 이력 + 동기화) |
| **AI** | Groq (llama-3.3-70b), Google Gemini (Vision/Flash) |
| **크롤링** | Cheerio (HTML 파싱), pdfjs-dist (PDF 텍스트 추출) |
| **인증** | Firebase Auth, FCM |
| **공공데이터** | NEIS 7종, 1365 봉사, 커리어넷, 워크넷, 대학정보, K-MOOC, KEDI CSV |

## Cloud Functions (30+개)

- NEIS 시간표/급식/학사일정/학교 검색/학원정보
- 컴시간 시간표 + 변경 감지 + 교사 시간표
- 교사 시간표 이력 저장 + 변동 감지 스케줄러
- 급식 사진 크롤링 (13개 교육청, 10가지 파싱)
- 가정통신문 크롤링 + 상세 페이지 파싱
- 학급 공지 (개설/참여/작성/조회/삭제/리액션/나가기)
- 봉사활동 1365 프록시 (HTTPS 변환 + 캐시)
- 진로 공공데이터 통합 조회
- 앱 버전 관리 + 패치노트 + FCM 푸시
- 교육 뉴스 관리

## 플랫폼

- **iPhone** — 전체 기능
- **iPad** — NavigationSplitView
- **Apple Watch** — 독립 실행 (시간표 + 급식)
- **macOS** — 메뉴바 앱 + 풀 윈도우
- **위젯** — 시간표/급식/학사일정/올인원 (홈+잠금화면)
- **다이나믹 아일랜드** — Live Activity 현재 수업

## 대회

제8회 교육 공공데이터 AI활용대회 출품작

## 개발 환경

- Xcode 16+ / xcodegen
- Firebase CLI
- Node.js 20
- Claude Code (Opus 4.6) — 개발 파트너

## 라이선스

MIT License

---

> 초/중/고등학생을 위한, 학생이 만든 학교생활 통합 앱
