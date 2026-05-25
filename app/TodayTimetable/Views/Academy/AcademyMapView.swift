import MapKit
import SwiftUI

struct AcademyMapView: View {
    let school: School
    private let academyPageSize = 200
    private let maxAcademyPages = 3
    private let maxVisibleMarkerCount = 200

    @State private var query = ""
    @State private var academies: [Academy] = []
    @State private var selectedAcademy: Academy?
    @State private var detailAcademy: Academy?
    @State private var selectedField = "전체"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var position = MapCameraPosition.automatic
    @State private var showList = true
    @State private var locationService = LocationService.shared
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var searchCenter: CLLocationCoordinate2D?
    @State private var showSearchHere = false
    @State private var searchAreaName = "현재 위치"

    private var fields: [String] {
        ["전체"] + Array(Set(academies.map(\.fieldName).filter { !$0.isEmpty })).sorted()
    }

    private var fieldFilteredAcademies: [Academy] {
        selectedField == "전체" ? academies : academies.filter { $0.fieldName == selectedField }
    }

    private var visibleAcademies: [Academy] {
        guard let visibleRegion else { return fieldFilteredAcademies }
        return fieldFilteredAcademies.filter { academy in
            guard let coordinate = academy.coordinate else { return true }
            return visibleRegion.contains(coordinate)
        }
    }

    private var mappedAcademies: [Academy] {
        visibleAcademies.filter { $0.coordinate != nil }.prefix(maxVisibleMarkerCount).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $position) {
                    UserAnnotation()

                    ForEach(mappedAcademies) { academy in
                        if let coordinate = academy.coordinate {
                            Annotation(academy.name, coordinate: coordinate) {
                                Button {
                                    selectedAcademy = academy
                                    focus(on: academy)
                                } label: {
                                    AcademyMapMarker(
                                        icon: markerIcon(for: academy),
                                        color: markerColor(for: academy),
                                        isSelected: selectedAcademy?.id == academy.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.school])))
                .mapControls {
                    MapCompass()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    mapCenter = context.region.center
                    visibleRegion = context.region
                    if searchCenter != nil {
                        showSearchHere = true
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    floatingSearchHeader
                    if showSearchHere {
                        searchHereButton
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                    if showList {
                        bottomSheet
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        collapsedListButton
                    }
                }
            }
            .navigationTitle("학원 지도")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadAcademies(center: mapCenter ?? searchCenter ?? locationService.currentLocation?.coordinate, keepMapPosition: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $detailAcademy) { academy in
                AcademyDetailView(academy: academy)
                    .presentationDetents([.large])
            }
            .task {
                if academies.isEmpty {
                    await AcademyStore.syncFromFirestore()
                    locationService.requestLocation()
                    try? await Task.sleep(for: .milliseconds(500))
                    await loadAcademies(center: locationService.currentLocation?.coordinate)
                }
            }
        }
    }

    private var floatingSearchHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("학원명 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await loadAcademies(center: mapCenter ?? searchCenter ?? locationService.currentLocation?.coordinate) }
                    }
                Button("검색") {
                    Task { await loadAcademies(center: mapCenter ?? searchCenter ?? locationService.currentLocation?.coordinate) }
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .clipShape(Capsule())

                Button {
                    locationService.requestLocation()
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        await loadAcademies(center: locationService.currentLocation?.coordinate)
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var searchHereButton: some View {
        Button {
            Task {
                query = ""
                await loadAcademies(center: mapCenter, keepMapPosition: true)
            }
        } label: {
            Label("이 위치에서 재검색", systemImage: "arrow.clockwise")
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var bottomSheet: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.secondary.opacity(0.28))
                .frame(width: 42, height: 5)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLoading ? "학원 찾는 중" : "\(visibleAcademies.count)개 학원")
                        .font(.headline)
                    Text(mappedAcademies.isEmpty ? "\(searchAreaName) 기준 검색" : "\(searchAreaName) 기준 · 화면 내 \(mappedAcademies.count)개 표시")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showList = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                        .frame(width: 34, height: 34)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)

            fieldFilterBar

            if let selectedAcademy {
                selectedAcademySummaryCard(selectedAcademy)
                    .padding(.horizontal, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Group {
                if isLoading {
                    loadingCard
                } else if visibleAcademies.isEmpty {
                    emptyCard
                } else {
                    academyCardList
                }
            }
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: -6)
        .padding(.horizontal, 0)
        .padding(.bottom, 0)
    }

    private var fieldFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(fields, id: \.self) { field in
                    Button {
                        selectedField = field
                    } label: {
                        Text(field)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedField == field ? Color.accentColor : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedField == field ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func selectedAcademySummaryCard(_ academy: Academy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(academy.name.isEmpty ? "이름 없는 학원" : academy.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(academySummaryText(for: academy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedAcademy = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Label(academy.tuitionAmountSummary, systemImage: "won")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Label(academy.registrationStatusName.isEmpty ? "상태 미상" : academy.registrationStatusName, systemImage: academy.isOpen ? "checkmark.circle.fill" : "questionmark.circle")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            Label(academy.fullAddress.isEmpty ? "주소 정보 없음" : academy.fullAddress, systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 10) {
                Button {
                    detailAcademy = academy
                } label: {
                    Label("상세보기", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openInAppleMaps(academy)
                } label: {
                    Label("Apple 지도", systemImage: "map.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(academy.coordinate == nil)
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
    }

    private var academyCardList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(visibleAcademies.prefix(maxVisibleMarkerCount).map { $0 }) { academy in
                    Button {
                        selectedAcademy = academy
                        focus(on: academy)
                    } label: {
                        AcademyRow(academy: academy)
                            .padding(14)
                            .background(Color(.systemBackground).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
        }
        .frame(maxHeight: selectedAcademy == nil ? 300 : 170)
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("학원 정보를 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 14)
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("학원 정보 없음")
                .font(.headline)
            Text("검색어를 바꾸거나 지역을 넓혀서 다시 검색해보세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 14)
    }

    private var collapsedListButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                showList = true
            }
        } label: {
            Label("\(visibleAcademies.count)개 학원 보기", systemImage: "list.bullet")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 22)
    }

    private func loadAcademies(center: CLLocationCoordinate2D? = nil, keepMapPosition: Bool = false) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let center = center ?? searchCenter ?? locationService.currentLocation?.coordinate
            let zone = await zoneName(for: center) ?? administrativeZone(from: school.address)
            let raw = try await loadAcademyPages(zone: zone)
            let sorted = await AcademyService.shared.nearestAcademies(raw, from: center, limit: raw.count)
            academies = await AcademyService.shared.geocode(sorted, limit: min(sorted.count, maxVisibleMarkerCount))
            selectedField = "전체"
            searchCenter = center ?? academies.compactMap(\.coordinate).first
            searchAreaName = zone ?? "현재 위치"
            showSearchHere = false
            if !keepMapPosition {
                updateMapPosition(center: searchCenter)
            }
        } catch {
            errorMessage = "학원 정보를 불러오지 못했어요. 네트워크를 확인해주세요."
        }
    }

    private func loadAcademyPages(zone: String?) async throws -> [Academy] {
        var merged = try await fetchAcademyPages(zone: zone)

        if zone != nil && merged.count < 10 {
            let fallback = try await fetchAcademyPages(zone: nil)
            var seenIDs = Set(merged.map(\.id))
            for academy in fallback where !seenIDs.contains(academy.id) {
                seenIDs.insert(academy.id)
                merged.append(academy)
            }
        }

        if let selectedAcademy, !merged.contains(where: { $0.id == selectedAcademy.id }) {
            merged.append(selectedAcademy)
        }

        return merged
    }

    private func fetchAcademyPages(zone: String?) async throws -> [Academy] {
        var merged: [Academy] = []
        var seenIDs = Set<String>()

        for page in 1...maxAcademyPages {
            let pageItems = try await AcademyService.shared.searchAcademies(
                educationOfficeCode: school.regionCode,
                administrativeZone: zone,
                query: query,
                page: page,
                pageSize: academyPageSize
            )

            for academy in pageItems where !seenIDs.contains(academy.id) {
                seenIDs.insert(academy.id)
                merged.append(academy)
            }

            if pageItems.count < academyPageSize {
                break
            }
        }

        return merged
    }

    private func updateMapPosition(center: CLLocationCoordinate2D? = nil) {
        if let center = center ?? academies.compactMap(\.coordinate).first {
            position = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            ))
        }
    }

    private func focus(on academy: Academy) {
        guard let coordinate = academy.coordinate else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))
        }
    }

    private func openInAppleMaps(_ academy: Academy) {
        guard let coordinate = academy.coordinate else { return }
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = academy.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
        ])
    }

    private func academySummaryText(for academy: Academy) -> String {
        [
            academy.fieldName,
            academy.courseName,
            academy.totalCapacity > 0 ? "정원 \(academy.totalCapacity)명" : "",
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: " · ")
    }

    private func administrativeZone(from address: String) -> String? {
        let parts = address.components(separatedBy: " ").filter { !$0.isEmpty }
        if let city = parts.first(where: { $0.hasSuffix("시") || $0.hasSuffix("군") || $0.hasSuffix("구") }) {
            return city
        }
        return nil
    }

    private func zoneName(for coordinate: CLLocationCoordinate2D?) async -> String? {
        guard let coordinate else { return nil }
        return await AcademyService.shared.administrativeZone(for: coordinate)
    }

    private func markerIcon(for academy: Academy) -> String {
        if academy.fieldName.contains("예능") || academy.fieldName.contains("예체능") { return "paintpalette.fill" }
        if academy.fieldName.contains("외국어") { return "textformat.abc" }
        if academy.fieldName.contains("보습") || academy.fieldName.contains("입시") { return "book.fill" }
        return "building.2.fill"
    }

    private func markerColor(for academy: Academy) -> Color {
        if !academy.isOpen { return .gray }
        if academy.fieldName.contains("예능") || academy.fieldName.contains("예체능") { return .pink }
        if academy.fieldName.contains("외국어") { return .blue }
        if academy.fieldName.contains("보습") || academy.fieldName.contains("입시") { return .orange }
        return .green
    }
}

private struct AcademyRow: View {
    let academy: Academy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(academy.name.isEmpty ? "이름 없는 학원" : academy.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(academy.registrationStatusName.isEmpty ? "상태 미상" : academy.registrationStatusName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(academy.isOpen ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                    .foregroundStyle(academy.isOpen ? .green : .gray)
                    .clipShape(Capsule())
            }

            Label(academy.fullAddress.isEmpty ? "주소 정보 없음" : academy.fullAddress, systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if AcademyStore.isSaved(academy) {
                    Label("저장됨", systemImage: "bookmark.fill")
                        .foregroundStyle(.blue)
                }
                if academy.tuitionPublic.uppercased() == "Y" {
                    Label("수강료 공개", systemImage: "won")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption2.bold())
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        [academy.fieldName, academy.courseName]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
            .nilIfEmpty ?? "분야 정보 없음"
    }
}

private struct AcademyMapMarker: View {
    let icon: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
                .frame(width: isSelected ? 42 : 34, height: isSelected ? 42 : 34)
                .shadow(color: color.opacity(0.35), radius: 8, y: 5)

            Image(systemName: icon)
                .font(.system(size: isSelected ? 18 : 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .offset(y: 9)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let minLatitude = center.latitude - span.latitudeDelta / 2
        let maxLatitude = center.latitude + span.latitudeDelta / 2
        let minLongitude = center.longitude - span.longitudeDelta / 2
        let maxLongitude = center.longitude + span.longitudeDelta / 2
        return (minLatitude...maxLatitude).contains(coordinate.latitude)
            && (minLongitude...maxLongitude).contains(coordinate.longitude)
    }
}

private extension View {
    func academyCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AcademyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSaved: Bool
    @State private var tagVotes: [String: Int]
    @State private var showScheduleSheet = false
    @State private var aiSummary: AcademyAISummary?
    @State private var isLoadingAI = false
    let academy: Academy

    init(academy: Academy) {
        self.academy = academy
        _isSaved = State(initialValue: AcademyStore.isSaved(academy))
        _tagVotes = State(initialValue: AcademyStore.tagVotes(for: academy))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    insightGrid
                    tuitionVisualCard
                    aiCard
                    tagReviewCard
                    publicDataCard
                    scheduleCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("학원 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showScheduleSheet) {
                AcademyScheduleEditor(academy: academy)
                    .presentationDetents([.medium])
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(academy.name.isEmpty ? "이름 없는 학원" : academy.name)
                        .font(.title2.bold())
                        .lineLimit(3)
                    Text([academy.fieldName, academy.courseName].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                statusPill
            }

            Label(academy.fullAddress.isEmpty ? "주소 정보 없음" : academy.fullAddress, systemImage: "mappin.and.ellipse")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Button {
                    AcademyStore.toggleSaved(academy)
                    isSaved.toggle()
                } label: {
                    Label(isSaved ? "저장됨" : "저장", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showScheduleSheet = true
                } label: {
                    Label("일정", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .academyCard()
    }

    private var statusPill: some View {
        Text(academy.registrationStatusName.isEmpty ? "상태 미상" : academy.registrationStatusName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(academy.isOpen ? Color.green.opacity(0.14) : Color.gray.opacity(0.14))
            .foregroundStyle(academy.isOpen ? .green : .gray)
            .clipShape(Capsule())
    }

    private var insightGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard("정원", value: academy.totalCapacity > 0 ? "\(academy.totalCapacity)명" : "-", icon: "person.3.fill", tint: .blue)
            metricCard("수용", value: academy.temporaryCapacity > 0 ? "\(academy.temporaryCapacity)명" : "-", icon: "rectangle.3.group.fill", tint: .teal)
            metricCard("수강료", value: academy.tuitionAmountSummary, icon: "won", tint: .orange)
            metricCard("기숙사", value: academy.dormitoryText, icon: "bed.double.fill", tint: .indigo)
        }
    }

    private func metricCard(_ title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .academyCard(padding: 12)
    }

    private var tuitionVisualCard: some View {
        let amounts = academy.tuitionAmounts
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("수강료 시각화", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                Text(academy.tuitionPublicText)
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }

            if amounts.isEmpty {
                Text(academy.tuitionContent.isEmpty ? "수강료 금액 정보가 없어요." : academy.tuitionContent)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                HStack(spacing: 10) {
                    tuitionSummaryPill("최저", amount: amounts.min())
                    tuitionSummaryPill("최고", amount: amounts.max())
                    tuitionSummaryPill("항목", text: "\(amounts.count)개")
                }

                VStack(spacing: 8) {
                    ForEach(Array(amounts.prefix(5).enumerated()), id: \.offset) { index, amount in
                        tuitionBar(index: index, amount: amount, maxAmount: amounts.max() ?? amount)
                    }
                }

                if !academy.tuitionContent.isEmpty {
                    Text(academy.tuitionContent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .academyCard()
    }

    private func tuitionSummaryPill(_ title: String, amount: Int? = nil, text: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(text ?? amount.map(Academy.formatWon) ?? "-")
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tuitionBar(index: Int, amount: Int, maxAmount: Int) -> some View {
        let progress = maxAmount > 0 ? CGFloat(amount) / CGFloat(maxAmount) : 0
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("항목 \(index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Academy.formatWon(amount))
                    .font(.caption.bold())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.orange.opacity(0.14))
                    Capsule()
                        .fill(Color.orange.gradient)
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 학원 요약", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await loadAISummary() }
                } label: {
                    if isLoadingAI {
                        ProgressView()
                    } else {
                        Text(aiSummary == nil ? "분석" : "다시")
                    }
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .disabled(isLoadingAI)
            }

            if let aiSummary {
                AcademyAISummaryView(summary: aiSummary)
            } else {
                Text("공공데이터를 바탕으로 분야, 규모, 수강료 공개 여부, 확인할 점을 짧게 정리해요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .academyCard()
    }

    private var tagReviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("학생 태그", systemImage: "tag.fill")
                    .font(.headline)
                Spacer()
                Text("\(tagVotes.values.reduce(0, +))표")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(AcademyStore.reviewTags, id: \.self) { tag in
                    Button {
                        AcademyStore.vote(tag: tag, for: academy)
                        tagVotes = AcademyStore.tagVotes(for: academy)
                    } label: {
                        HStack(spacing: 6) {
                            Text(tag)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(tagVotes[tag, default: 0])")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .academyCard()
    }

    private var publicDataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("공공데이터 핵심 정보", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)

            infoRow("운영", [academy.academyInstituteTypeName, academy.registrationStatusName])
            infoRow("지역", [academy.educationOfficeName, academy.administrativeZoneName])
            infoRow("교습", [academy.teachingOrderName, academy.courseListName, academy.courseName])
            infoRow("수강료", [academy.tuitionContent, academy.tuitionPublicText])
            infoRow("등록", ["등록 \(academy.formattedRegisteredDate)", "개설 \(academy.formattedEstablishedDate)"])
            infoRow("연락", [academy.phoneNumber, academy.roadPostalCode])
            if !academy.formattedClosureBeginDate.isEmpty || !academy.formattedClosureEndDate.isEmpty {
                infoRow("휴원", [academy.formattedClosureBeginDate, academy.formattedClosureEndDate])
            }
            infoRow("식별", [academy.academyNumber, "수정 \(academy.formattedUpdatedAt)"])
        }
        .academyCard()
    }

    private var scheduleCard: some View {
        let schedules = AcademyStore.schedules(for: academy)
        return Group {
            if !schedules.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("내 학원 일정", systemImage: "calendar")
                        .font(.headline)
                    ForEach(schedules) { schedule in
                        HStack {
                            Text(weekdayName(schedule.weekday))
                                .font(.caption.bold())
                                .frame(width: 30, height: 30)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(timeText(schedule.startTime))-\(timeText(schedule.endTime))")
                                    .font(.subheadline.bold())
                                if !schedule.memo.isEmpty {
                                    Text(schedule.memo)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .academyCard()
            }
        }
    }

    private func infoRow(_ title: String, _ values: [String]) -> some View {
        let visible = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != "-" }
        return HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Text(visible.isEmpty ? "-" : visible.joined(separator: " · "))
                .font(.subheadline)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadAISummary() async {
        guard !isLoadingAI else { return }
        isLoadingAI = true
        defer { isLoadingAI = false }

        let prompt = """
        다음 학원 공공데이터를 학부모와 학생이 이해하기 쉽게 분석해줘.
        장점 단정은 피하고 확인할 점을 함께 말해줘.
        아래 JSON 형식으로만 답해줘.
        {
          "summary": "한두 문장 요약",
          "facts": ["공공데이터에서 확인되는 정보"],
          "checkpoints": ["상담이나 등록 전에 확인할 점"],
          "questions": ["학원에 물어볼 질문"]
        }

        학원명: \(academy.name)
        분야: \(academy.fieldName)
        교습과정: \(academy.courseName)
        교습목록: \(academy.courseListName)
        지역: \(academy.administrativeZoneName)
        주소: \(academy.fullAddress)
        등록상태: \(academy.registrationStatusName)
        정원: \(academy.totalCapacity)
        일시수용능력: \(academy.temporaryCapacity)
        수강료: \(academy.tuitionContent)
        수강료공개여부: \(academy.tuitionPublicText)
        기숙사여부: \(academy.dormitoryText)
        """

        aiSummary = await AIService.shared.askGroqJSON(prompt: prompt, as: AcademyAISummary.self)
            ?? AcademyAISummary(
                summary: "AI 요약을 가져오지 못했어요. 잠시 후 다시 시도해주세요.",
                facts: [],
                checkpoints: [],
                questions: []
            )
    }

    private func weekdayName(_ weekday: Int) -> String {
        ["월", "화", "수", "목", "금", "토", "일"][max(0, min(weekday - 1, 6))]
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct AcademyAISummary: Codable {
    let summary: String
    let facts: [String]
    let checkpoints: [String]
    let questions: [String]
}

private struct AcademyAISummaryView: View {
    let summary: AcademyAISummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            section("확인된 정보", summary.facts, icon: "info.circle")
            section("확인할 점", summary.checkpoints, icon: "checklist")
            section("질문해볼 것", summary.questions, icon: "questionmark.circle")
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [String], icon: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct AcademyScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let academy: Academy
    @State private var weekday = 1
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(academy.name) {
                    Picker("요일", selection: $weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(["월", "화", "수", "목", "금", "토", "일"][day - 1]).tag(day)
                        }
                    }
                    DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("끝", selection: $endTime, displayedComponents: .hourAndMinute)
                    TextField("메모", text: $memo)
                }
            }
            .navigationTitle("학원 일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        AcademyStore.addSchedule(AcademySchedule(
                            academyNumber: academy.id,
                            academyName: academy.name,
                            weekday: weekday,
                            startTime: startTime,
                            endTime: endTime,
                            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}
