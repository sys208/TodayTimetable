import Foundation
import Observation

@MainActor
@Observable
final class BarcodeCardStore {
    static let shared = BarcodeCardStore()

    private let defaults = UserDefaults.standard
    private let key = "barcodeCards"

    private(set) var cards: [BarcodeCard] = []

    private init() {
        load()
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BarcodeCard].self, from: data)
        else {
            cards = []
            return
        }
        cards = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ card: BarcodeCard) {
        var updated = card
        updated.updatedAt = Date()

        if let index = cards.firstIndex(where: { $0.id == updated.id }) {
            cards[index] = updated
        } else {
            cards.insert(updated, at: 0)
        }
        persist()
    }

    func delete(_ card: BarcodeCard) {
        cards.removeAll { $0.id == card.id }
        persist()
    }

    private func persist() {
        cards.sort { $0.updatedAt > $1.updatedAt }
        if let data = try? JSONEncoder().encode(cards) {
            defaults.set(data, forKey: key)
        }
    }
}

