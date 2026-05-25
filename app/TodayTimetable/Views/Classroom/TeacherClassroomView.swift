import SwiftUI
import PhotosUI

/// 교사 학급 관리 뷰
struct TeacherClassroomView: View {
    let school: School
    @AppStorage("teacherName") private var teacherName = ""
    @State private var isLoggedIn = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var classrooms: [ClassroomService.Classroom] = []
    @State private var showCreateClassroom = false
    @State private var selectedClassroom: ClassroomService.Classroom?

    var body: some View {
        NavigationStack {
            Group {
                if !isLoggedIn {
                    teacherLoginView
                } else {
                    classroomListView
                }
            }
            .navigationTitle("학급 공지")
            .task {
                isLoggedIn = ClassroomService.shared.isTeacherLoggedIn
                if isLoggedIn {
                    await loadClassrooms()
                }
            }
            .onAppear {
                if ClassroomService.shared.isTeacherLoggedIn && !isLoggedIn {
                    isLoggedIn = true
                }
                if isLoggedIn && classrooms.isEmpty {
                    Task { await loadClassrooms() }
                }
            }
        }
    }

    // MARK: - 교사 로그인

    private var teacherLoginView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            Text("교사 인증")
                .font(.title2.bold())
            Text("@korea.kr 이메일로만 인증 가능합니다")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("이메일 (@korea.kr)", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                SecureField("비밀번호", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 32)

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Button {
                Task { await login() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("로그인 / 회원가입")
                        .bold()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Text("처음이면 자동으로 가입되고\n인증 이메일이 발송됩니다")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await ClassroomService.shared.signInTeacher(email: email, password: password)
            isLoggedIn = true
            await loadClassrooms()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 학급 목록

    private var classroomListView: some View {
        List {
            if classrooms.isEmpty {
                ContentUnavailableView(
                    "학급이 없습니다",
                    systemImage: "person.3",
                    description: Text("학급을 개설해서 학생들에게 공지하세요")
                )
            } else {
                ForEach(classrooms) { classroom in
                    NavigationLink {
                        ClassroomDetailView(classroom: classroom)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(classroom.grade)학년 \(classroom.classNumber > 0 ? "\(classroom.classNumber)반" : "전체")")
                                    .font(.headline)
                                if !classroom.subject.isEmpty {
                                    Text(classroom.subject)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(classroom.code)
                                    .font(.caption.bold().monospaced())
                                    .foregroundStyle(.green)
                                Text("\(classroom.memberCount)명")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .refreshable { await loadClassrooms() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateClassroom = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Text(ClassroomService.shared.currentTeacherEmail ?? "")
                    Button("로그아웃", role: .destructive) {
                        try? ClassroomService.shared.signOut()
                        isLoggedIn = false
                    }
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
        .sheet(isPresented: $showCreateClassroom) {
            CreateClassroomSheet(school: school, teacherName: teacherName) {
                Task { await loadClassrooms() }
            }
        }
        .task { await loadClassrooms() }
    }

    private func loadClassrooms() async {
        classrooms = await ClassroomService.shared.getTeacherClassrooms()
    }
}

// MARK: - 학급 개설 시트

private struct CreateClassroomSheet: View {
    let school: School
    let teacherName: String
    var onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var grade = 1
    @State private var classNumber = 0
    @State private var subject = ""
    @State private var isCreating = false
    @State private var createdCode: String?
    @State private var classList: [String] = []
    @State private var maxGrade = 3
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if let code = createdCode {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    Text("학급이 개설되었어요!")
                        .font(.title3.bold())
                    Text("학생들에게 이 코드를 알려주세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: "오늘시간표 학급 코드: \(code)\n앱에서 이 코드를 입력하세요!") {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("완료") {
                        onCreated()
                        dismiss()
                    }
                    .padding(.top)
                }
                .padding()
            } else {
                Form {
                    Section("학급 정보") {
                        Picker("학년", selection: $grade) {
                            ForEach(1...maxGrade, id: \.self) { Text("\($0)학년") }
                        }
                        .onChange(of: grade) {
                            Task { await loadClasses() }
                        }
                        Picker("반", selection: $classNumber) {
                            Text("학년 전체").tag(0)
                            ForEach(classList, id: \.self) { cls in
                                Text("\(cls)반").tag(Int(cls) ?? 0)
                            }
                        }
                        TextField("과목 (선택)", text: $subject)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }

                    Section {
                        Button {
                            Task { await create() }
                        } label: {
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("학급 개설").bold()
                            }
                        }
                        .disabled(isCreating)
                    }
                }
                .navigationTitle("학급 개설")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                }
                .task {
                    let type = school.schoolType
                    maxGrade = type == .elementary ? 6 : 3
                    await loadClasses()
                }
            }
        }
    }

    private func loadClasses() async {
        do {
            classList = try await NEISService.shared.getClassList(
                regionCode: school.regionCode,
                schoolCode: school.code,
                schoolType: school.schoolType,
                grade: grade
            )
        } catch {
            classList = (1...15).map(String.init)
        }
    }

    private func create() async {
        isCreating = true
        defer { isCreating = false }
        do {
            let result = try await ClassroomService.shared.createClassroom(
                schoolCode: school.code,
                schoolName: school.name,
                grade: grade,
                classNumber: classNumber,
                subject: subject,
                teacherName: teacherName
            )
            createdCode = result.code
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 학급 상세 (공지 목록 + 작성)

struct ClassroomDetailView: View {
    let classroom: ClassroomService.Classroom
    @State private var notices: [ClassroomService.Notice] = []
    @State private var isLoading = false
    @State private var showCreateNotice = false
    @State private var selectedNotice: ClassroomService.Notice?
    @State private var deleteTarget: ClassroomService.Notice?

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(classroom.grade)학년 \(classroom.classNumber > 0 ? "\(classroom.classNumber)반" : "전체")")
                            .font(.headline)
                        if !classroom.subject.isEmpty {
                            Text(classroom.subject).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(classroom.code)
                            .font(.caption.bold().monospaced())
                            .foregroundStyle(.green)
                        Text("\(classroom.memberCount)명 참여")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("공지") {
                if isLoading && notices.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if notices.isEmpty {
                    Text("아직 공지가 없어요")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(notices) { notice in
                        Button {
                            selectedNotice = notice
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    noticeTypeBadge(notice.type)
                                    Text(notice.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                Text(MarkdownView.stripMarkdown(notice.content))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if !notice.examDate.isEmpty || !notice.examPeriod.isEmpty {
                                    HStack(spacing: 8) {
                                        if !notice.examDate.isEmpty {
                                            Label(formatExamDate(notice.examDate), systemImage: "calendar")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.orange)
                                        }
                                        if !notice.examPeriod.isEmpty {
                                            Label(notice.examPeriod, systemImage: "clock")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                // 리액션 요약
                                let total = notice.reactions.values.reduce(0, +)
                                if total > 0 {
                                    Text("반응 \(total)개")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTarget = notice
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("학급 관리")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateNotice = true
                } label: {
                    Label("공지 작성", systemImage: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showCreateNotice) {
            CreateNoticeSheet(classroomId: classroom.id, subject: classroom.subject) {
                Task { await load() }
            }
        }
        .sheet(item: $selectedNotice) { notice in
            TeacherNoticeDetailView(notice: notice, classroomId: classroom.id)
        }
        .alert("공지를 삭제할까요?", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let target = deleteTarget {
                    Task {
                        try? await ClassroomService.shared.deleteNotice(classroomId: classroom.id, noticeId: target.id)
                        await load()
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
        .task { await load() }
        .onAppear { if notices.isEmpty { Task { await load() } } }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        notices = await ClassroomService.shared.getNotices(classroomId: classroom.id)
    }

    private func formatExamDate(_ raw: String) -> String {
        guard raw.count == 8,
              let m = Int(raw.dropFirst(4).prefix(2)),
              let d = Int(raw.suffix(2))
        else { return raw }
        return "\(m)월 \(d)일"
    }

    private func noticeTypeBadge(_ type: String) -> some View {
        let color: Color = switch type {
        case "수행평가": .purple
        case "시험범위": .red
        case "자료공유": .blue
        default: .green
        }
        return Text(type)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - 교사 공지 상세

private struct TeacherNoticeDetailView: View {
    let notice: ClassroomService.Notice
    let classroomId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        noticeTypeBadge(notice.type)
                        Spacer()
                    }

                    Text(notice.title)
                        .font(.title2.bold())

                    if !notice.examDate.isEmpty || !notice.examPeriod.isEmpty {
                        HStack(spacing: 12) {
                            if !notice.examDate.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                    Text(formatExamDate(notice.examDate))
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            if !notice.examPeriod.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                    Text(notice.examPeriod)
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Divider()

                    if !notice.imageUrls.isEmpty {
                        ForEach(notice.imageUrls, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    MarkdownView(text: notice.content)

                    // 리액션 현황
                    let emojiMap: [(String, String)] = [("thumbsUp", "👍"), ("heart", "❤️"), ("fire", "🔥"), ("clap", "👏"), ("eyes", "👀")]
                    let total = notice.reactions.values.reduce(0, +)
                    if total > 0 {
                        Divider()
                        Text("반응 \(total)개")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(emojiMap, id: \.0) { key, display in
                                let count = notice.reactions[key] ?? 0
                                if count > 0 {
                                    Text("\(display) \(count)")
                                        .font(.subheadline)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("공지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func formatExamDate(_ raw: String) -> String {
        guard raw.count == 8,
              let m = Int(raw.dropFirst(4).prefix(2)),
              let d = Int(raw.suffix(2))
        else { return raw }
        return "\(m)월 \(d)일"
    }

    private func noticeTypeBadge(_ type: String) -> some View {
        let color: Color = switch type {
        case "수행평가": .purple
        case "시험범위": .red
        case "자료공유": .blue
        default: .green
        }
        return Text(type)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - 공지 작성 (리치 에디터)

private struct CreateNoticeSheet: View {
    let classroomId: String
    let subject: String
    var onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var type = "일반"
    @State private var examDate = Date()
    @State private var hasExamDate = false
    @State private var examPeriod = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    private let types = ["일반", "시험범위", "수행평가", "자료공유"]

    var body: some View {
        NavigationStack {
            Form {
                Section("공지 유형") {
                    Picker("유형", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("내용") {
                    TextField("제목", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 150)

                    // 마크다운 서식 버튼
                    HStack(spacing: 8) {
                        formatButton("제목") { insertSnippet("# ") }
                        formatButton("목록") { insertSnippet("- ") }
                        formatButton("강조") { insertSnippet("**텍스트**") }
                        formatButton("표") { insertSnippet("| 항목 | 내용 |\n| --- | --- |\n| 예시 | 입력 |") }
                        formatButton("주석") { insertSnippet("> ") }
                    }
                }

                // 이미지 첨부
                Section("이미지 (\(selectedImages.count)/5)") {
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 75)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Button {
                                            selectedImages.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                        .frame(height: 85)
                    }

                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label("사진 추가", systemImage: "photo.badge.plus")
                    }
                }

                if type == "수행평가" || type == "시험범위" {
                    Section("시험/수행 일정") {
                        Toggle("날짜 지정", isOn: $hasExamDate)
                        if hasExamDate {
                            DatePicker("날짜", selection: $examDate, displayedComponents: .date)
                        }
                        Picker("교시", selection: $examPeriod) {
                            Text("선택 안함").tag("")
                            ForEach(1...8, id: \.self) { p in
                                Text("\(p)교시").tag("\(p)교시")
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                                Text("발행 중...")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("공지 발행").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isCreating)
                }
            }
            .navigationTitle("공지 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onChange(of: selectedPhotos) {
                Task {
                    var images: [UIImage] = []
                    for item in selectedPhotos {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    selectedImages = images
                }
            }
        }
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        let dateStr = hasExamDate ? {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd"
            return df.string(from: examDate)
        }() : ""

        let imageDatas = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.6) }

        do {
            _ = try await ClassroomService.shared.createNotice(
                classroomId: classroomId,
                title: title,
                content: content,
                type: type,
                subject: subject,
                examDate: dateStr,
                examPeriod: examPeriod,
                images: imageDatas
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func insertSnippet(_ snippet: String) {
        if content.isEmpty {
            content = snippet
        } else {
            content += content.hasSuffix("\n") ? snippet : "\n" + snippet
        }
    }
}
