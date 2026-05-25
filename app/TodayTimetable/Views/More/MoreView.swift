import SwiftUI

/// 더보기 탭
struct MoreView: View {
    @Bindable var timetableVM: TimetableViewModel
    let school: School

    var body: some View {
        NavigationStack {
            List {
                Section("시간표") {
                    NavigationLink {
                        WeeklyTimetableView(viewModel: timetableVM, school: school)
                    } label: {
                        Label("주간 시간표", systemImage: "calendar.day.timeline.left")
                    }
                }

                Section("학교 알림") {
                    NavigationLink {
                        SchoolNoticeView(school: school)
                    } label: {
                        Label("가정통신문", systemImage: "envelope.open")
                    }
                }

                Section("학급") {
                    NavigationLink {
                        StudentClassroomView(school: school)
                    } label: {
                        Label("학급 공지", systemImage: "person.3")
                    }
                }

                Section("뉴스") {
                    NavigationLink {
                        NewsView()
                    } label: {
                        Label("교육 뉴스", systemImage: "newspaper")
                    }
                }

                Section("학교") {
                    NavigationLink {
                        SchoolCalendarView(school: school)
                    } label: {
                        Label("학사일정", systemImage: "calendar.badge.clock")
                    }
                    NavigationLink {
                        SchoolInfoView(school: school)
                    } label: {
                        Label("우리 학교 정보", systemImage: "building.2")
                    }
                    NavigationLink {
                        AcademyMapView(school: school)
                    } label: {
                        Label("주변 학원 지도", systemImage: "map")
                    }
                    NavigationLink {
                        BarcodeCardListView(school: school)
                    } label: {
                        Label("바코드 카드", systemImage: "barcode")
                    }
                }

                Section("공부") {
                    NavigationLink {
                        FocusView()
                    } label: {
                        Label("집중 모드", systemImage: "brain.head.profile")
                    }
                }

                Section {
                    NavigationLink {
                        AISchoolAssistantView(school: school)
                    } label: {
                        Label("AI 학교 비서", systemImage: "message.badge.waveform")
                    }
                    NavigationLink {
                        CareerReportView(school: school)
                    } label: {
                        Label("AI 진로 리포트", systemImage: "doc.text.magnifyingglass")
                    }
                    NavigationLink {
                        AIStudyPlannerView(school: school)
                    } label: {
                        Label("AI 공부 플래너", systemImage: "sparkles")
                    }
                    NavigationLink {
                        AIWeeklyNutritionView(school: school)
                    } label: {
                        Label("AI 영양 리포트", systemImage: "leaf")
                    }
                    NavigationLink {
                        AIVolunteerRecommendView(school: school)
                    } label: {
                        Label("AI 봉사 추천", systemImage: "hand.raised")
                    }
                    NavigationLink {
                        AIStudyAnalysisView()
                    } label: {
                        Label("AI 학습 분석", systemImage: "chart.bar")
                    }
                    NavigationLink {
                        AISchoolCompareView(school: school)
                    } label: {
                        Label("AI 학교 비교", systemImage: "building.2.crop.circle")
                    }
                } header: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI 분석")
                    }
                }

                Section("앱") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("더보기")
        }
    }
}
