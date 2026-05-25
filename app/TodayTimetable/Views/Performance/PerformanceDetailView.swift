import SwiftUI

/// 수행평가 상세 + AI 코칭
struct PerformanceDetailView: View {
    let task: PerformanceTask
    @State private var aiCoaching: PerformanceCoaching?
    @State private var isLoadingCoaching = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 헤더
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.subject)
                                .font(.title2.bold())
                            Text(task.title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let dday = task.dDay {
                            Text(dday == 0 ? "D-Day" : dday > 0 ? "D-\(dday)" : "완료")
                                .font(.title3.bold())
                                .foregroundStyle(dday <= 3 && dday >= 0 ? .red : Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(dday <= 3 && dday >= 0 ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    // 날짜/교시
                    Label(task.dateText + (task.period > 0 ? " \(task.period)교시" : ""), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    // 상세 내용
                    if !task.description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("내용", systemImage: "doc.text")
                                .font(.subheadline.bold())
                            Text(task.description)
                                .font(.body)
                        }
                    }

                    // 준비물
                    if !task.materials.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("준비물", systemImage: "bag")
                                .font(.subheadline.bold())
                            ForEach(task.materials, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.green)
                                    Text(item)
                                }
                                .font(.body)
                            }
                        }
                    }

                    // 평가기준
                    if !task.criteria.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("평가기준", systemImage: "checklist")
                                .font(.subheadline.bold())
                            Text(task.criteria)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // AI 팁
                    if !task.aiTips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("AI 준비 팁", systemImage: "sparkles")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                            ForEach(Array(task.aiTips.enumerated()), id: \.offset) { idx, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(idx + 1).")
                                        .font(.body.bold())
                                        .foregroundStyle(.orange)
                                    Text(tip)
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Divider()

                    // AI 코칭
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("AI 코칭", systemImage: "brain.head.profile")
                                .font(.headline)
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            if aiCoaching == nil {
                                Button {
                                    Task { await loadCoaching() }
                                } label: {
                                    if isLoadingCoaching {
                                        ProgressView()
                                    } else {
                                        Label("분석 요청", systemImage: "sparkles")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(isLoadingCoaching)
                            }
                        }

                        if aiCoaching == nil && !isLoadingCoaching {
                            Text("평가기준에 따른 구체적인 준비 방법을 AI가 알려드려요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if isLoadingCoaching {
                            Text("AI가 평가기준을 분석하고 있어요...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let aiCoaching {
                            PerformanceCoachingView(coaching: aiCoaching)
                        }
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 삭제
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("수행평가 삭제", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("수행평가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert("수행평가를 삭제할까요?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    PerformanceTaskStore.shared.remove(id: task.id)
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            }
        }
    }

    // MARK: - AI 코칭 로드

    private func loadCoaching() async {
        isLoadingCoaching = true

        let prompt = """
        나는 중학교/고등학교 학생이야. 다음 수행평가를 준비해야 해.

        과목: \(task.subject)
        주제: \(task.title)
        내용: \(task.description)
        평가기준: \(task.criteria)
        준비물: \(task.materials.joined(separator: ", "))

        평가기준에 맞춰서 좋은 점수를 받을 수 있도록 구체적이고 실질적인 준비 방법을 알려줘.
        아래 JSON 형식으로만 답해줘.
        {
          "summary": "한두 문장 요약",
          "criteriaStrategies": ["평가기준별 대응 전략"],
          "preparationPlan": ["단계별 준비 계획"],
          "commonMistakes": ["흔히 하는 실수와 주의할 점"],
          "highScorePoints": ["고득점 포인트"]
        }

        학생 눈높이에 맞게 쉽고 친근하게 설명해줘.
        """

        if let coaching = await AIService.shared.askGroqJSON(prompt: prompt, as: PerformanceCoaching.self) {
            aiCoaching = coaching
        } else {
            aiCoaching = PerformanceCoaching(
                summary: "AI 분석에 실패했어요. 다시 시도해주세요.",
                criteriaStrategies: [],
                preparationPlan: [],
                commonMistakes: [],
                highScorePoints: []
            )
        }

        isLoadingCoaching = false
    }
}

private struct PerformanceCoaching: Codable {
    let summary: String
    let criteriaStrategies: [String]
    let preparationPlan: [String]
    let commonMistakes: [String]
    let highScorePoints: [String]
}

private struct PerformanceCoachingView: View {
    let coaching: PerformanceCoaching

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(coaching.summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            coachingSection("평가기준별 전략", coaching.criteriaStrategies, icon: "target")
            coachingSection("준비 계획", coaching.preparationPlan, icon: "calendar.badge.clock")
            coachingSection("주의할 실수", coaching.commonMistakes, icon: "exclamationmark.triangle")
            coachingSection("고득점 포인트", coaching.highScorePoints, icon: "star.fill")
        }
    }

    @ViewBuilder
    private func coachingSection(_ title: String, _ items: [String], icon: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.callout.bold())
                            .foregroundStyle(Color.accentColor)
                        Text(item)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
