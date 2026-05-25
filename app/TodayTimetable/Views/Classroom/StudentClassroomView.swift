import SwiftUI

/// 학생 학급 참여 + 공지 수신 뷰
struct StudentClassroomView: View {
    let school: School
    @State private var classrooms: [ClassroomService.Classroom] = []
    @State private var isLoading = false
    @State private var showJoin = false
    @State private var selectedClassroom: ClassroomService.Classroom?
    @State private var leaveTarget: ClassroomService.Classroom?

    var body: some View {
        NavigationStack {
            List {
                if isLoading && classrooms.isEmpty {
                    HStack { Spacer(); ProgressView("불러오는 중..."); Spacer() }
                        .listRowBackground(Color.clear)
                } else if classrooms.isEmpty {
                    ContentUnavailableView(
                        "참여한 학급이 없어요",
                        systemImage: "person.3",
                        description: Text("선생님이 알려준 코드를 입력하세요")
                    )
                }

                ForEach(classrooms) { classroom in
                    NavigationLink {
                        StudentNoticeListView(classroom: classroom)
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
                            Text(classroom.teacherName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            leaveTarget = classroom
                        } label: {
                            Label("나가기", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .navigationTitle("학급 공지")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showJoin = true
                    } label: {
                        Label("참여", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showJoin) {
                JoinClassroomSheet(school: school) {
                    Task { await load() }
                }
            }
            .task { await load() }
            .onAppear { if classrooms.isEmpty { Task { await load() } } }
            .refreshable { await load() }
            .alert("학급에서 나갈까요?", isPresented: .init(
                get: { leaveTarget != nil },
                set: { if !$0 { leaveTarget = nil } }
            )) {
                Button("나가기", role: .destructive) {
                    if let target = leaveTarget {
                        Task {
                            await ClassroomService.shared.leaveClassroom(classroomId: target.id)
                            await load()
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                if let target = leaveTarget {
                    Text("\(target.grade)학년 \(target.classNumber)반 학급에서 나가면 공지를 더 이상 받을 수 없어요")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        classrooms = await ClassroomService.shared.getMyClassrooms()
    }
}

// MARK: - 코드 입력 시트

private struct JoinClassroomSheet: View {
    let school: School
    var onJoined: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedClassroom: ClassroomService.Classroom?

    var body: some View {
        NavigationStack {
            if let joined = joinedClassroom {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    Text("참여 완료!")
                        .font(.title3.bold())
                    Text("\(joined.schoolName) \(joined.teacherName) 선생님")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("확인") {
                        onJoined()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("선생님이 알려준\n8자리 코드를 입력하세요")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    TextField("ABCD1234", text: $code)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .padding(.horizontal, 40)

                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }

                    Button {
                        Task { await join() }
                    } label: {
                        if isJoining {
                            ProgressView()
                        } else {
                            Text("참여하기").bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)
                    .disabled(code.count != 8 || isJoining)

                    Spacer()
                }
                .navigationTitle("학급 참여")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                }
            }
        }
    }

    private func join() async {
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }
        do {
            let result = try await ClassroomService.shared.joinClassroom(
                code: code,
                studentName: "",
                grade: school.grade,
                classNumber: Int(school.classNumber) ?? 0
            )
            joinedClassroom = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 학생 공지 목록

struct StudentNoticeListView: View {
    let classroom: ClassroomService.Classroom
    @State private var notices: [ClassroomService.Notice] = []
    @State private var isLoading = false
    @State private var selectedNotice: ClassroomService.Notice?

    var body: some View {
        List {
            if isLoading && notices.isEmpty {
                HStack { Spacer(); ProgressView("불러오는 중..."); Spacer() }
                    .listRowBackground(Color.clear)
            } else if notices.isEmpty {
                Text("아직 공지가 없어요")
                    .foregroundStyle(.secondary)
            }

            ForEach(notices) { notice in
                Button {
                    selectedNotice = notice
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            noticeTypeBadge(notice.type)
                            Text(notice.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        Text(MarkdownView.stripMarkdown(notice.content))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack {
                            Text(notice.teacherName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !notice.examDate.isEmpty {
                                Text(notice.examDate)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("\(classroom.grade)-\(classroom.classNumber) 공지")
        .task { await load() }
        .onAppear { if notices.isEmpty { Task { await load() } } }
        .refreshable { await load() }
        .sheet(item: $selectedNotice) { notice in
            StudentNoticeDetailView(notice: notice, classroomId: classroom.id)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        notices = await ClassroomService.shared.getNotices(classroomId: classroom.id)
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

// MARK: - 공지 상세

private struct StudentNoticeDetailView: View {
    let notice: ClassroomService.Notice
    var classroomId: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var localReactions: [String: Int] = [:]
    @State private var reactedEmojis: Set<String> = []

    private let emojiMap: [(key: String, display: String)] = [
        ("thumbsUp", "👍"), ("heart", "❤️"), ("fire", "🔥"), ("clap", "👏"), ("eyes", "👀")
    ]

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

                    // 시험/수행 날짜 + 교시 (큼직하게)
                    if !notice.examDate.isEmpty || !notice.examPeriod.isEmpty {
                        HStack(spacing: 12) {
                            if !notice.examDate.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.title3)
                                    Text(formatExamDate(notice.examDate))
                                        .font(.headline)
                                }
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            if !notice.examPeriod.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.title3)
                                    Text(notice.examPeriod)
                                        .font(.headline)
                                }
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    Divider()

                    // 본문 이미지
                    if !notice.imageUrls.isEmpty {
                        ForEach(notice.imageUrls, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(height: 150)
                                        .overlay { ProgressView() }
                                }
                            }
                        }
                    }

                    MarkdownView(text: notice.content)

                    HStack {
                        Text(notice.teacherName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Divider()

                    // 리액션
                    HStack(spacing: 12) {
                        ForEach(emojiMap, id: \.key) { emoji in
                            let count = localReactions[emoji.key] ?? 0
                            let reacted = reactedEmojis.contains(emoji.key)
                            Button {
                                guard !reacted else { return }
                                reactedEmojis.insert(emoji.key)
                                localReactions[emoji.key, default: 0] += 1
                                Task {
                                    await ClassroomService.shared.reactToNotice(
                                        classroomId: classroomId,
                                        noticeId: notice.id,
                                        emoji: emoji.key
                                    )
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(emoji.display)
                                        .font(.title3)
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.caption.bold())
                                            .foregroundStyle(reacted ? .blue : .secondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(reacted ? Color.blue.opacity(0.1) : Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
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
            .onAppear {
                localReactions = notice.reactions
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
