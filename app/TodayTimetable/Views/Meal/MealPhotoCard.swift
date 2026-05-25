import SwiftUI

/// 급식 사진 카드 (학교 홈페이지 크롤링)
struct MealPhotoCard: View {
    let school: School
    let date: Date
    @State private var photos: [MealPhotoService.MealPhoto] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var fullscreenIndex: Int?

    private var dayCacheKey: String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return "mealPhoto_\(school.code)_\(df.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.orange)
                Text("급식 사진")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }

            if let photo = photos.first {
                AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { fullscreenIndex = 0 }
                    } else if phase.error != nil {
                        placeholderView("사진을 불러올 수 없어요")
                    } else {
                        Color(.tertiarySystemBackground)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay { ProgressView() }
                    }
                }

                if !photo.menuSummary.isEmpty {
                    Text(photo.menuSummary.replacingOccurrences(of: "\n", with: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !photo.calorie.isEmpty {
                    Text(photo.calorie)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            } else if isLoading {
                Color(.tertiarySystemBackground)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("급식 사진 불러오는 중...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else if hasLoaded {
                placeholderView("이 날의 급식 사진이 없어요")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .fullScreenCover(item: $fullscreenIndex) { startIdx in
            FullscreenGalleryView(
                imageUrls: photos.map(\.imageUrl),
                startIndex: startIdx
            )
        }
        .task(id: date) {
            await loadPhotos()
        }
    }

    private func placeholderView(_ text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private func loadPhotos() async {
        // 날짜별 캐시 확인
        if let cached = loadFromCache() {
            photos = cached
            hasLoaded = true
            return
        }

        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        let regionCode = school.regionCode
        let schoolCode = school.code
        let homepage = await MealPhotoService.shared.getHomepageUrl(
            regionCode: regionCode, schoolCode: schoolCode
        )
        guard !homepage.isEmpty else { return }

        let d = date
        let result = await MealPhotoService.shared.getPhotos(homepageUrl: homepage, date: d)
        photos = result

        if !result.isEmpty {
            saveToCache(result)
        }
    }

    // MARK: - 날짜별 캐시

    private func saveToCache(_ photos: [MealPhotoService.MealPhoto]) {
        let data = photos.map { ["url": $0.imageUrl, "menu": $0.menuSummary, "cal": $0.calorie] }
        UserDefaults.standard.set(data, forKey: dayCacheKey)
    }

    private func loadFromCache() -> [MealPhotoService.MealPhoto]? {
        guard let data = UserDefaults.standard.array(forKey: dayCacheKey) as? [[String: String]] else { return nil }
        let result = data.compactMap { dict -> MealPhotoService.MealPhoto? in
            guard let url = dict["url"] else { return nil }
            return MealPhotoService.MealPhoto(
                imageUrl: url,
                menuSummary: dict["menu"] ?? "",
                calorie: dict["cal"] ?? ""
            )
        }
        return result.isEmpty ? nil : result
    }
}
