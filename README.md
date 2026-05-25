# TodayTimetable — AI-Powered School Life Assistant

> An all-in-one iOS/macOS/watchOS app integrating Korean education public data APIs and AI to help students manage their school life.

[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue)]()
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)]()
[![Firebase](https://img.shields.io/badge/Backend-Firebase-yellow)]()
[![AI](https://img.shields.io/badge/AI-Groq%20%7C%20Gemini-green)]()
[![Functions](https://img.shields.io/badge/Cloud%20Functions-30%2B-red)]()

## Overview

TodayTimetable is an open-source school life management app built for Korean K-12 students and teachers. It integrates **7+ public data APIs** (NEIS, 1365, CareerNet, WorkNet, University Info, K-MOOC, KEDI) with **AI** (Groq, Gemini) to provide 70+ features across multiple Apple platforms.

Built entirely with **Claude Code (Opus 4.6)** through 200+ iterative conversations.

## Key Features (70+)

### Timetable
- Real-time timetable with **change detection** (Comcigan + NEIS dual source)
- Teacher timetable with **historical archive** (Firestore) and **change alerts** (FCM push, weekday 12:00/18:00)
- Weekly/daily view, subject editing, photo → AI recognition
- **4 widgets** + Lock Screen + **Live Activity** (Dynamic Island)
- **Apple Watch** standalone app

### School Meals
- NEIS meal menu + 19 allergen types highlighted
- **Automatic meal photo crawling** from 13/17 regional education offices using **10 different HTML parsing methods** (Cheerio server-side)
- Calorie tracking with HealthKit integration
- AI weekly nutrition report

### Classroom Notice System
- Teacher authentication via `@korea.kr` email (Firebase Auth)
- 8-character code for student enrollment
- **Markdown editor** + image upload (Firebase Storage) + FCM push
- Notice types: General / Exam Scope / Performance Assessment / Resource Sharing (color-coded badges)
- Student **reactions** (5 emoji types) + teacher deletion

### AI Features (10)
| Feature | Model | Description |
|---------|-------|-------------|
| School Assistant | Groq (llama-3.3-70b) | School data-based Q&A chatbot |
| Career Report | Groq | Public data-based career recommendations + PDF export |
| Performance Analysis | Gemini Vision | Assignment photo → evaluation criteria coaching |
| Timetable Photo Recognition | Gemini Vision | Photo → structured timetable data |
| Weekly Nutrition Report | Groq | Meal menu/nutrient analysis + health tips |
| Volunteer Recommendation | Groq | Interest-based volunteer matching |
| School Comparison | Groq | High school comparison analysis |
| Study Planner | Groq | Exam schedule-based study plan |
| Meal Image Generation | Gemini Image | Menu text → cafeteria tray image |
| Home Newsletter PDF Parsing | pdfjs-dist + Groq | PDF text extraction + AI structuring |

### Volunteer Activities (1365 API)
- **All 31 API fields** fully utilized
- **Map display** with coordinate data (`areaLalo1/2/3`)
- Application status **progress bar** (`appTotal` / `rcritNmpr`)
- Activity day visualization + **automatic hour calculation**
- Family/group participation badges
- Contact manager directly (phone/email)
- **Deep link to 1365** application page

### Home Newsletters
- Automatic crawling from school websites (goeas.kr)
- DEXT5Upload parsing + PDF/HWP attachments
- In-app Safari browser

### Other
- School calendar D-Day + automatic calendar event creation
- **Holiday detection** (NEIS `isDayOff` → timetable disabled)
- Education news + FCM push
- **Patch notes** view + update alerts
- iCloud sync
- KakaoTalk / Instagram sharing

## Tech Stack

| Category | Technology |
|----------|-----------|
| **iOS/macOS** | Swift 6.0, SwiftUI, SwiftData, WidgetKit, ActivityKit, WatchKit, HealthKit, EventKit |
| **Backend** | Firebase Cloud Functions 30+ (Node.js, TypeScript) |
| **Database** | Firestore (caching + history + sync) |
| **AI** | Groq (llama-3.3-70b), Google Gemini (Vision/Flash/Image) |
| **Crawling** | Cheerio (HTML parsing), pdfjs-dist (PDF text extraction) |
| **Auth** | Firebase Auth, FCM |
| **Public Data** | NEIS (7 APIs), 1365 Volunteer, CareerNet, WorkNet, University Info, K-MOOC, KEDI CSV |

## Cloud Functions (30+)

| Category | Functions |
|----------|----------|
| NEIS Data | School search, timetable, meals, calendar, academy info, homepage URL |
| Comcigan | Timetable + change detection, teacher timetable, teacher list |
| Teacher History | Timetable archive, change detection, scheduled checker (weekday 12:00/18:00) |
| Crawling | Meal photos (13 offices, 10 parsing methods), home newsletters |
| Classroom | Create/join/notice/query/delete/react/leave + teacher classrooms |
| Volunteer | 1365 API proxy (HTTP→HTTPS + 6hr cache) |
| AI/Career | Career public data aggregation |
| Operations | News FCM, app version management, patch notes |

## Platforms

| Platform | Features |
|----------|----------|
| **iPhone** | Full features |
| **iPad** | NavigationSplitView sidebar |
| **Apple Watch** | Standalone (timetable + meals) |
| **macOS** | Menu bar app + full window |
| **Widgets** | Timetable/Meals/Calendar/All-in-one (Home + Lock Screen) |
| **Dynamic Island** | Live Activity showing current class |

## Project Structure

```
TodayTimetable/
├── app/                              # iOS + macOS + watchOS (xcodegen)
│   ├── TodayTimetable/               # Main iOS app
│   ├── TodayTimetableMac/            # macOS app
│   ├── TodayTimetableWatch/          # watchOS app
│   ├── TodayTimetableWidget/         # Widgets
│   ├── TodayTimetableLiveActivity/   # Live Activity
│   └── project.yml                   # xcodegen config
├── firebase/                         # Backend
│   └── functions/src/                # Cloud Functions (TypeScript)
├── docs/                             # GitHub Pages
└── 대회/                              # Competition materials
```

## Competition

Submitted to the **8th Korean Education Public Data AI Competition** (2026)

## Development

- **IDE**: Xcode 16+ with xcodegen
- **Backend**: Firebase CLI + Node.js 20
- **AI Partner**: Claude Code (Opus 4.6) — 200+ iterative development conversations
- **Project Management**: Bun runtime (per CLAUDE.md configuration)

## Note

API keys, Firebase config files, and certificates are excluded from this repository for security. The `firebase/functions/src/index.ts` (containing API keys) is gitignored. See `.gitignore` for details.

## License

MIT License

---

> Built by a Korean middle school student, for students everywhere.
>
> *"Every day, millions of Korean students check their timetable, meals, and school events across scattered websites. TodayTimetable brings it all together with AI."*
