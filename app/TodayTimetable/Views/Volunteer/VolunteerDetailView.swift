import SwiftUI
import MapKit
import KakaoSDKShare
import KakaoSDKTemplate

/// 봉사활동 상세
struct VolunteerDetailView: View {
    @Bindable var viewModel: VolunteerViewModel
    let progrmRegistNo: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingDetail {
                    ProgressView("불러오는 중...")
                } else if let detail = viewModel.selectedDetail {
                    detailContent(detail)
                } else {
                    ContentUnavailableView("정보를 불러올 수 없습니다", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("봉사 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // 공유
                        Menu {
                            Button {
                                if let detail = viewModel.selectedDetail {
                                    shareToKakao(detail)
                                }
                            } label: {
                                Label("카카오톡 공유", systemImage: "message")
                            }
                            Button {
                                if let detail = viewModel.selectedDetail {
                                    shareGeneral(detail)
                                }
                            } label: {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        // 북마크
                        Button {
                            viewModel.toggleBookmark(progrmRegistNo)
                        } label: {
                            Image(systemName: viewModel.isBookmarked(progrmRegistNo) ? "bookmark.fill" : "bookmark")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadDetail(progrmRegistNo)
            }
        }
    }

    private func detailContent(_ d: VolunteerDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 제목 + 상태
                VStack(alignment: .leading, spacing: 8) {
                    Text(d.progrmSj)
                        .font(.title3.bold())
                    HStack {
                        Text(d.progrmSttusSe)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(d.isRecruiting ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                            .foregroundStyle(d.isRecruiting ? .green : .secondary)
                            .clipShape(Capsule())
                        if d.isYouthEligible {
                            Text("청소년 가능")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }

                Divider()

                // 뱃지 행 (가족, 단체)
                if d.isFamilyEligible || d.isGroupEligible {
                    HStack(spacing: 6) {
                        if d.isFamilyEligible {
                            badge("가족 참여", color: .pink, icon: "figure.2.and.child.holdinghands")
                        }
                        if d.isGroupEligible {
                            badge("단체 가능", color: .indigo, icon: "person.3")
                        }
                    }
                }

                // 신청 현황 프로그레스 바
                if d.maxCapacity > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("신청 현황")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(d.currentApplicants)/\(d.maxCapacity)명")
                                .font(.caption.bold())
                                .foregroundStyle(d.isAlmostFull ? .red : .secondary)
                        }
                        ProgressView(value: min(d.capacityRatio, 1.0))
                            .tint(d.isAlmostFull ? .red : .green)
                        if d.isAlmostFull {
                            Text("마감 임박! 자리가 얼마 안 남았어요")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 활동 요일
                if !d.activeDays.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("활동 요일")
                            .font(.subheadline.bold())
                        HStack(spacing: 6) {
                            ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { day in
                                Text(day)
                                    .font(.caption.bold())
                                    .frame(width: 32, height: 32)
                                    .background(d.activeDays.contains(day) ? Color.blue.opacity(0.15) : Color(.tertiarySystemBackground))
                                    .foregroundStyle(d.activeDays.contains(day) ? Color.blue : Color.gray)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }

                // 봉사 시간 계산
                if d.dailyHours > 0 {
                    HStack(spacing: 16) {
                        VStack {
                            Text("\(d.dailyHours)")
                                .font(.title2.bold())
                                .foregroundStyle(.blue)
                            Text("일 시간")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if d.estimatedTotalHours > d.dailyHours {
                            VStack {
                                Text("~\(d.estimatedTotalHours)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.green)
                                Text("총 예상시간")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Divider()

                // 기본 정보
                infoRow("기관", d.nanmmbyNm)
                if !d.mnnstNm.isEmpty && d.mnnstNm != d.nanmmbyNm {
                    infoRow("등록기관", d.mnnstNm)
                }
                infoRow("기간", "\(formatDate(d.progrmBgnde)) ~ \(formatDate(d.progrmEndde))")
                if !d.timeText.isEmpty { infoRow("시간", d.timeText) }
                if !d.actPlace.isEmpty { infoRow("장소", d.actPlace) }
                if !d.srvcClCode.isEmpty { infoRow("분야", d.srvcClCode) }

                if !d.progrmCn.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("내용")
                            .font(.subheadline.bold())
                        // 링크 자동 감지
                        Text(decodeHTML(d.progrmCn))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // 연락처
                if !d.telno.isEmpty || !d.email.isEmpty || !d.nanmmbyNmAdmn.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("담당자 연락처")
                            .font(.subheadline.bold())
                        if !d.nanmmbyNmAdmn.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.circle")
                                    .font(.caption)
                                Text(d.nanmmbyNmAdmn)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        if !d.telno.isEmpty {
                            Link(destination: URL(string: "tel:\(d.telno.replacingOccurrences(of: "-", with: ""))")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "phone")
                                        .font(.caption)
                                    Text(d.telno)
                                        .font(.caption)
                                        .underline()
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        if !d.email.isEmpty {
                            Link(destination: URL(string: "mailto:\(d.email)")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope")
                                        .font(.caption)
                                    Text(d.email)
                                        .font(.caption)
                                        .underline()
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // 신청 버튼 (url 없으면 progrmRegistNo로 생성)
                // 봉사 장소 지도 (다중 장소 지원)
                let coords = d.allCoordinates
                if !coords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("봉사 장소", systemImage: "mappin.and.ellipse")
                            .font(.subheadline.bold())

                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: coords[0].lat, longitude: coords[0].lng),
                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                        ))) {
                            ForEach(Array(coords.enumerated()), id: \.offset) { _, c in
                                Marker(c.address.isEmpty ? (d.actPlace.isEmpty ? "봉사 장소" : d.actPlace) : String(c.address.prefix(20)),
                                       coordinate: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng))
                            }
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !d.postAdres.isEmpty {
                            Text(d.postAdres)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            let c = coords[0]
                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng)))
                            mapItem.name = d.actPlace
                            mapItem.openInMaps()
                        } label: {
                            Label("Apple 지도에서 열기", systemImage: "map")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 항상 progrmRegistNo로 URL 생성 (상세 API에 url 필드 없음)
                let applyUrlStr = "https://www.1365.go.kr/vols/P9210/partcptn/timeCptn.do?type=show&progrmRegistNo=\(d.progrmRegistNo)"
                if let url = URL(string: applyUrlStr) {
                    VStack(spacing: 8) {
                        Link(destination: url) {
                            Label("1365에서 신청하기", systemImage: "arrow.up.right.square")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Text("1365 로그인이 필요할 수 있어요")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)
                }

                // 공공누리 출처 표시 (제1유형)
                Divider()
                VStack(spacing: 6) {
                    Image("img_opentype01")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)
                    (Text("본 저작물은 '행정안전부'에서 작성하여 공공누리 제1유형으로 개방한 '자원봉사참여정보'를 이용하였으며, 해당 저작물은 1365 자원봉사포털(")
                        .foregroundStyle(.tertiary)
                    + Text("[www.1365.go.kr](https://www.1365.go.kr)")
                        .foregroundStyle(Color.accentColor)
                    + Text(")에서 무료로 이용 가능합니다.")
                        .foregroundStyle(.tertiary))
                        .font(.system(size: 10))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func badge(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }

    /// URL을 마크다운 링크로 변환
    private func decodeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&#xD;", with: "")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func linkify(_ text: String) -> String {
        let pattern = #"(https?://[^\s<>\)]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var result = text
        let matches = regex.matches(in: text, range: range).reversed()
        for match in matches {
            guard let r = Range(match.range, in: result) else { continue }
            let url = String(result[r])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
            result.replaceSubrange(r, with: "[\(url)](\(url))")
        }
        return result
    }

    private func formatDate(_ str: String) -> String {
        guard str.count >= 8 else { return str }
        let m = str.dropFirst(4).prefix(2)
        let d = str.suffix(2)
        return "\(Int(m) ?? 0)월 \(Int(d) ?? 0)일"
    }

    // MARK: - 카카오톡 공유

    private func shareToKakao(_ d: VolunteerDetail) {
        guard ShareApi.isKakaoTalkSharingAvailable() else {
            shareGeneral(d)
            return
        }

        let desc = """
        \(formatDate(d.progrmBgnde)) ~ \(formatDate(d.progrmEndde))
        기관: \(d.nanmmbyNm)
        장소: \(d.actPlace)
        \(d.isYouthEligible ? "청소년 참여 가능" : "")
        """

        let webLink = Link(
            webUrl: URL(string: d.url.isEmpty ? "https://www.1365.go.kr" : d.url),
            mobileWebUrl: URL(string: d.url.isEmpty ? "https://www.1365.go.kr" : d.url)
        )
        let appLink = Link(
            iosExecutionParams: ["type": "volunteer", "id": d.progrmRegistNo]
        )

        let feedTemplate = FeedTemplate(
            content: Content(
                title: d.progrmSj,
                imageUrl: URL(string: "https://www.1365.go.kr/images/common/logo.png")!,
                description: desc.trimmingCharacters(in: .whitespacesAndNewlines),
                link: appLink
            ),
            buttons: [
                Button(title: "앱에서 보기", link: appLink),
                Button(title: "1365에서 보기", link: webLink),
            ]
        )

        ShareApi.shared.shareDefault(templatable: feedTemplate) { result, error in
            if let result {
                UIApplication.shared.open(result.url, options: [:])
            }
        }
    }

    // MARK: - 일반 공유

    private func shareGeneral(_ d: VolunteerDetail) {
        let text = """
        [\(d.progrmSj)]
        기간: \(formatDate(d.progrmBgnde)) ~ \(formatDate(d.progrmEndde))
        기관: \(d.nanmmbyNm)
        장소: \(d.actPlace)
        \(d.isYouthEligible ? "청소년 참여 가능" : "")
        신청: \(d.url.isEmpty ? "https://www.1365.go.kr" : d.url)

        - 오늘시간표 앱에서 공유
        """

        let activityVC = UIActivityViewController(
            activityItems: [text.trimmingCharacters(in: .whitespacesAndNewlines)],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topVC = root
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
}
