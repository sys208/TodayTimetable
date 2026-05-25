import SwiftUI

struct WatchNextClassView: View {
    private var store: WatchDataStore { WatchDataStore.shared }

    var body: some View {
        if let next = store.nextClass {
            VStack(spacing: 8) {
                Text("다음 수업")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(next.subjectName)
                    .font(.title2.bold())

                Text("\(next.period)교시")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            .padding()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("남은 수업이 없습니다")
                    .font(.caption)
            }
        }
    }
}
