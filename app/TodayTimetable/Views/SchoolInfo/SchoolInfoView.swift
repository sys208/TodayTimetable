import SwiftUI
import MapKit

/// 우리 학교 정보 뷰
struct SchoolInfoView: View {
    let school: School
    @State private var viewModel = SchoolInfoViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.basicInfo == nil {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(viewModel.loadingMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 16) {
                        if let error = viewModel.errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("학교 정보 불러오기 실패", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                Text(error)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("학교명: \(school.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !school.address.isEmpty {
                                    Text("주소: \(school.address)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if viewModel.basicInfo == nil && viewModel.errorMessage == nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(school.name)
                                    .font(.title2.bold())
                                Text("학교 정보가 아직 로드되지 않았습니다.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                if !school.address.isEmpty {
                                    Text(school.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // 기본정보 카드
                        if let info = viewModel.basicInfo {
                            basicInfoCard(info)
                        }

                        // 학생 현황
                        if let stats = viewModel.stats {
                            studentCard(stats)
                        }

                        // 성별 현황
                        if let gender = viewModel.genderStats {
                            genderCard(gender)
                        }

                        // 교원 현황
                        if let teachers = viewModel.teacherStats {
                            teacherCard(teachers)
                        }

                        // 동아리
                        if !viewModel.clubs.isEmpty {
                            clubsCard(viewModel.clubs)
                        }

                        // 도서관
                        if let lib = viewModel.library {
                            libraryCard(lib)
                        }

                        // 교복 단가
                        if !viewModel.uniforms.isEmpty {
                            uniformCard(viewModel.uniforms)
                        }

                        // 학년별 학생수
                        if !viewModel.classDetails.isEmpty {
                            classDetailsCard(viewModel.classDetails)
                        }

                        // 수업일수
                        if !viewModel.classDays.isEmpty {
                            classDaysCard(viewModel.classDays)
                        }

                        // 방과후학교
                        if !viewModel.afterSchool.isEmpty {
                            afterSchoolCard(viewModel.afterSchool)
                        }

                        // AI 학교 진단
                        aiDiagnosisCard

                        // 지도
                        if let info = viewModel.basicInfo, info.latitude != 0 {
                            mapCard(lat: info.latitude, lng: info.longitude, name: info.name)
                        }

                        // 공공누리 출처
                        VStack(spacing: 8) {
                            Image("img_opentype01")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)

                            Text("출처: 학교알리미(schoolinfo.go.kr)\n교육부 · 한국교육학술정보원(KERIS)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)

                            Text("교육부의 공시 기준에 따라 각 학교의 주요 정보는 매년 6월에 업데이트되며, 이전까지는 전년도 정보를 기준으로 합니다.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("우리 학교")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    Menu {
                        ForEach((currentYear-3...currentYear).reversed(), id: \.self) { year in
                            Button(String(year) + "년") {
                                viewModel.selectedYear = year
                                Task { await viewModel.loadAll(school: school) }
                            }
                        }
                    } label: {
                        Text(String(viewModel.selectedYear) + "년")
                            .font(.caption.bold())
                    }
                }
            }
            .refreshable {
                await viewModel.loadAll(school: school)
            }
            .task {
                if viewModel.basicInfo == nil {
                    await viewModel.loadAll(school: school)
                }
            }
        }
    }

    // MARK: - 기본정보

    private func basicInfoCard(_ info: SchoolInfoService.BasicInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.name)
                        .font(.title2.bold())
                    Text(info.region)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(info.coedu)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            Divider()

            infoRow(icon: "mappin.and.ellipse", label: "주소", value: info.address)
            infoRow(icon: "phone", label: "대표", value: info.phone)
            if !info.phoneOffice.isEmpty && info.phoneOffice != info.phone {
                infoRow(icon: "phone.badge.waveform", label: "교무실", value: info.phoneOffice)
            }
            if !info.phoneAdmin.isEmpty && info.phoneAdmin != info.phone {
                infoRow(icon: "phone.fill", label: "행정실", value: info.phoneAdmin)
            }
            if !info.homepage.isEmpty {
                Button {
                    var urlStr = info.homepage
                    if !urlStr.hasPrefix("http") { urlStr = "https://\(urlStr)" }
                    if let url = URL(string: urlStr) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    infoRow(icon: "globe", label: "홈페이지", value: info.homepage)
                }
                .tint(.primary)
            }

            if !info.foundedDate.isEmpty {
                let year = String(info.foundedDate.prefix(4))
                infoRow(icon: "calendar", label: "설립", value: "\(year)년")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.callout)
                .lineLimit(2)
            Spacer()
        }
    }

    // MARK: - 학생 현황

    private func studentCard(_ stats: SchoolInfoService.SchoolStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3")
                    .foregroundStyle(Color.accentColor)
                Text("학생 현황")
                    .font(.headline)
                Spacer()
                Text(stats.totalStudents)
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(Array(stats.classesByGrade.enumerated()), id: \.offset) { idx, count in
                    VStack(spacing: 4) {
                        Text("\(idx + 1)학년")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\(count)반")
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Text("평균 \(stats.avgPerClass)명/반")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 성별 현황

    private func genderCard(_ gender: SchoolInfoService.GenderStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.stand")
                    .foregroundStyle(.blue)
                Text("성별 현황")
                    .font(.headline)
            }

            let total = max(gender.maleTotal + gender.femaleTotal, 1)
            let maleRatio = Double(gender.maleTotal) / Double(total)

            // 비율 바
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: geo.size.width * maleRatio)
                    Rectangle()
                        .fill(Color.pink.opacity(0.6))
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())

            HStack {
                Label("남 \(gender.maleTotal)명", systemImage: "figure.stand")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
                Label("여 \(gender.femaleTotal)명", systemImage: "figure.stand.dress")
                    .font(.caption)
                    .foregroundStyle(.pink)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 교원 현황

    private func teacherCard(_ teachers: SchoolInfoService.TeacherStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.rectangle")
                    .foregroundStyle(.green)
                Text("교원 현황")
                    .font(.headline)
                Spacer()
                Text("총 \(teachers.total)명")
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                statChip(label: "교장", count: teachers.principal, color: .orange)
                statChip(label: "교감", count: teachers.vicePrincipal, color: .purple)
                statChip(label: "교사", count: teachers.teachers, color: .green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statChip(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 지도

    private func mapCard(lat: Double, lng: Double, name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "map")
                    .foregroundStyle(.red)
                Text("위치")
                    .font(.headline)
            }

            Map {
                Marker(name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                let url = URL(string: "maps://?ll=\(lat),\(lng)&q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                UIApplication.shared.open(url)
            } label: {
                Label("Apple 지도에서 열기", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 동아리

    private func clubsCard(_ clubs: [SchoolInfoService.ClubInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.sequence")
                    .foregroundStyle(.purple)
                Text("동아리")
                    .font(.headline)
                Spacer()
                Text("\(clubs.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(clubs.prefix(10), id: \.name) { club in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(club.name)
                                .font(.caption)
                                .lineLimit(1)
                            if club.members > 0 {
                                Text("\(club.members)명")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            if clubs.count > 10 {
                Text("+\(clubs.count - 10)개 더")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 도서관

    private func libraryCard(_ lib: SchoolInfoService.LibraryInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "books.vertical")
                    .foregroundStyle(.brown)
                Text("학교도서관")
                    .font(.headline)
            }

            HStack(spacing: 8) {
                statChip(label: "장서", count: lib.totalBooks, color: .brown)
                statChip(label: "좌석", count: lib.seats, color: .indigo)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 교복 단가

    private func uniformCard(_ uniforms: [SchoolInfoService.UniformInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tshirt")
                    .foregroundStyle(.teal)
                Text("교복 단가")
                    .font(.headline)
            }

            ForEach(uniforms, id: \.item) { u in
                HStack {
                    Text(u.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                    Text(u.item)
                        .font(.callout)
                    Spacer()
                    if u.price > 0 {
                        Text("\(u.price.formatted())원")
                            .font(.callout.bold())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 방과후학교

    private func afterSchoolCard(_ programs: [SchoolInfoService.AfterSchoolInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(.cyan)
                Text("방과후학교")
                    .font(.headline)
                Spacer()
                Text("\(programs.count)개 프로그램")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(programs.prefix(8), id: \.programName) { p in
                HStack {
                    Text(p.programName)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer()
                    if p.participants > 0 {
                        Text("\(p.participants)명")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if programs.count > 8 {
                Text("+\(programs.count - 8)개 더")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 학년별 학생수

    private func classDetailsCard(_ details: [SchoolInfoService.ClassDetail]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.circle")
                    .foregroundStyle(.indigo)
                Text("학년별 학생수")
                    .font(.headline)
            }

            ForEach(details, id: \.grade) { d in
                HStack {
                    Text("\(d.grade)학년")
                        .font(.callout.bold())
                        .frame(width: 55, alignment: .leading)
                    Text("\(d.totalStudents)명")
                        .font(.callout)
                    Spacer()
                    Text("평균 \(String(format: "%.1f", d.avgPerClass))명/반")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 수업일수

    private func classDaysCard(_ days: [SchoolInfoService.ClassDays]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle")
                    .foregroundStyle(.mint)
                Text("수업일수")
                    .font(.headline)
            }

            HStack(spacing: 8) {
                ForEach(days, id: \.grade) { d in
                    VStack(spacing: 4) {
                        Text("\(d.grade)학년")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\(d.days)일")
                            .font(.title3.bold())
                            .foregroundStyle(.mint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.mint.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - AI 학교 진단

    private var aiDiagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("AI 학교 진단")
                    .font(.headline)
                Spacer()
                if viewModel.aiDiagnosis == nil && !viewModel.isLoadingAI {
                    Button {
                        Task { await viewModel.runAIDiagnosis(school: school) }
                    } label: {
                        Label("분석하기", systemImage: "play.circle")
                            .font(.caption)
                    }
                }
            }

            if viewModel.isLoadingAI {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("AI가 학교 데이터를 분석하고 있어요...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let diagnosis = viewModel.aiDiagnosis {
                SchoolAIDiagnosisView(diagnosis: diagnosis)

                Button {
                    Task { await viewModel.runAIDiagnosis(school: school) }
                } label: {
                    Label("다시 분석", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
            } else {
                Text("AI가 학교알리미 공공데이터를 분석하여\n장단점, 공부법 등을 알려줍니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct SchoolAIDiagnosisView: View {
    let diagnosis: SchoolAIDiagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(diagnosis.summary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            section("장점", diagnosis.strengths, icon: "checkmark.seal.fill", tint: .green)
            section("확인할 점", diagnosis.improvements, icon: "exclamationmark.triangle.fill", tint: .orange)
            section("추천 공부법", diagnosis.studyTips, icon: "book.fill", tint: .blue)
            section("참고 정보", diagnosis.notes, icon: "info.circle.fill", tint: .secondary)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [String], icon: String, tint: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(tint)
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
