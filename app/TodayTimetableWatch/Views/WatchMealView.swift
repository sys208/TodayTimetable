import SwiftUI

struct WatchMealView: View {
    private var store: WatchDataStore { WatchDataStore.shared }

    var body: some View {
        NavigationStack {
            if store.todayMeals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("급식 정보 없음")
                        .font(.headline)
                    Text(store.hasSchoolInfo ? "워치에서 직접 불러오거나 iPhone 동기화를 기다릴 수 있어요" : "학교를 먼저 설정해주세요")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if store.hasSchoolInfo {
                        Button("새로고침") {
                            Task { await store.fetchDirectly() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    ForEach(store.todayMeals, id: \.type) { meal in
                        Section(meal.type) {
                            ForEach(meal.menu, id: \.self) { item in
                                Text(item)
                                    .font(.caption)
                            }
                            if !meal.calorie.isEmpty {
                                Text(meal.calorie)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("급식")
                .refreshable {
                    await store.fetchDirectly()
                }
            }
        }
    }
}
