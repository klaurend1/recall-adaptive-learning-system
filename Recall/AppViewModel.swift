import Foundation
import Combine

final class AppViewModel: ObservableObject {
    @Published var appVersion: String = "0.1"
    @Published var cards: [StudyCard] = []
    @Published var concepts: [Concept] = []
    @Published var reviewRecords: [ReviewRecord] = []
    @Published var currentCardIndex: Int = 0
    @Published var showingAnswer: Bool = false

    private var supportDirectory: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var cardsURL: URL { supportDirectory.appendingPathComponent("cards.json") }
    private var reviewsURL: URL { supportDirectory.appendingPathComponent("reviews.json") }

    private var cancellables = Set<AnyCancellable>()

    init(setup: Bool = false) {
        loadState()
        if cards.isEmpty { cards = MockData.cards }
        if concepts.isEmpty { concepts = MockData.concepts }

        // Temporary migration: if any card references a conceptID not in current concepts, replace cards with seeded MockData.cards (preserve reviewRecords)
        let validConceptIDs = Set(self.concepts.map { $0.id })
        let hasOrphans = self.cards.contains { card in
            card.conceptIDs.contains { !validConceptIDs.contains($0) }
        }
        if hasOrphans {
            self.cards = MockData.cards
        }

        #if DEBUG
        print("Recall cards:", cards.count)
        print("Recall concepts:", concepts.count)
        let conceptIDs = Set(concepts.map { $0.id })
        let allRefsResolve = cards.allSatisfy { card in card.conceptIDs.allSatisfy { conceptIDs.contains($0) } }
        print("All card conceptIDs resolve:", allRefsResolve)
        let tree = MemoryTreeEngine.build(concepts: concepts, cards: cards, reviews: reviewRecords)
        if let mcat = tree.roots.first(where: { $0.name == "MCAT" }) {
            print("MCAT aggregated cards:", mcat.cardCount)
        }
        #endif

        $cards
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
        $reviewRecords
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
    }

    func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do { let data = try encoder.encode(cards); try data.write(to: cardsURL) } catch { }
        do { let data = try encoder.encode(reviewRecords); try data.write(to: reviewsURL) } catch { }
    }

    func loadState() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: cardsURL), let decoded = try? decoder.decode([StudyCard].self, from: data) {
            self.cards = decoded
        }
        if let data = try? Data(contentsOf: reviewsURL), let decoded = try? decoder.decode([ReviewRecord].self, from: data) {
            self.reviewRecords = decoded
        }
    }

    func scheduleNextDueDate(for cardID: UUID, after grade: ReviewGrade) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let base = Calendar.current.startOfDay(for: Date())
        let next: Date
        switch grade {
        case .again: next = base
        case .hard: next = Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
        case .good: next = Calendar.current.date(byAdding: .day, value: 3, to: base) ?? base
        case .easy: next = Calendar.current.date(byAdding: .day, value: 7, to: base) ?? base
        }
        cards[index].dueDate = next
    }

    func latestGrade(for cardID: UUID) -> ReviewGrade? {
        reviewRecords.last(where: { $0.cardID == cardID })?.grade
    }

    func reviewsTodayCount() -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        return reviewRecords.filter { $0.date >= start }.count
    }

    func dueCount(on date: Date) -> Int {
        let dayStart = Calendar.current.startOfDay(for: date)
        return cards.filter { Calendar.current.startOfDay(for: $0.dueDate) <= dayStart }.count
    }

    // MARK: - Memory Tree Support

    enum MemoryHealth {
        case strong
        case stable
        case weak
        case atRisk

        var label: String {
            switch self {
            case .strong: return "Strong"
            case .stable: return "Stable"
            case .weak: return "Weak"
            case .atRisk: return "At Risk"
            }
        }

        var colorName: String {
            switch self {
            case .strong: return "green"
            case .stable: return "blue"
            case .weak: return "orange"
            case .atRisk: return "red"
            }
        }
    }

    /// Dictionary mapping parent concept ID to its immediate child concepts
    var conceptChildren: [UUID: [Concept]] {
        Dictionary(grouping: concepts.compactMap { $0.parentID != nil ? $0 : nil }, by: { $0.parentID! })
    }

    /// Dictionary mapping concept ID to the concept itself
    var conceptByID: [UUID: Concept] {
        Dictionary(uniqueKeysWithValues: concepts.map { ($0.id, $0) })
    }

    /// Dictionary mapping concept ID to array of cards belonging to that concept
    func cardsByConceptID() -> [UUID: [StudyCard]] {
        var result = [UUID: [StudyCard]]()
        for card in cards {
            for conceptID in card.conceptIDs {
                result[conceptID, default: []].append(card)
            }
        }
        return result
    }

    /// Converts mastery (0..1) to a MemoryHealth category based on thresholds:
    /// - nil mastery returns nil
    /// - ≥ 0.8: .strong
    /// - ≥ 0.6: .stable
    /// - ≥ 0.4: .weak
    /// - else: .atRisk
    func health(for mastery: Double?) -> MemoryHealth? {
        guard let m = mastery else { return nil }
        switch m {
        case 0.8...1.0: return .strong
        case 0.6..<0.8: return .stable
        case 0.4..<0.6: return .weak
        case ..<0.4: return .atRisk
        default: return nil
        }
    }

    /// Returns up to `limit` leaf concepts with available mastery, sorted ascending by mastery.
    /// Each tuple contains (Concept, masteryPercent as Int, cardCount)
    func weakestLeafConcepts(limit: Int = 3) -> [(Concept, Int, Int)] {
        let data = MemoryTreeEngine.build(concepts: concepts, cards: cards, reviews: reviewRecords)
        // Map conceptID -> ConceptNode for quick lookup
        let flat = data.flat
        // For each Concept that is a leaf in the built tree and has mastery
        let results: [(Concept, Int, Int)] = concepts.compactMap { concept in
            guard let node = flat[concept.id], node.children.isEmpty, node.masteryPercent >= 0 else { return nil }
            let percent = Int((node.masteryPercent * 100).rounded())
            return (concept, percent, node.cardCount)
        }
        let sorted = results.sorted { $0.1 < $1.1 }
        return Array(sorted.prefix(limit))
    }
}

extension AppViewModel {
    var conceptRoots: [ConceptNode] {
        MemoryTreeEngine.build(concepts: concepts, cards: cards, reviews: reviewRecords).roots
    }

    var allConcepts: [ConceptNode] {
        Array(MemoryTreeEngine.build(concepts: concepts, cards: cards, reviews: reviewRecords).flat.values)
    }

    func parentConcept(of node: ConceptNode) -> ConceptNode? {
        let data = MemoryTreeEngine.build(concepts: concepts, cards: cards, reviews: reviewRecords)
        if let pid = data.parent[node.id] ?? nil, let p = data.flat[pid] { return p }
        return nil
    }

    var weakestLeaves: [ConceptNode] {
        let data = MemoryTreeEngine.build(concepts: concepts, cards: cards, reviews: reviewRecords)
        let leaves = data.flat.values.filter { $0.children.isEmpty && $0.masteryPercent >= 0 }
        return leaves.sorted { $0.masteryPercent < $1.masteryPercent }.prefix(3).map { $0 }
    }
}
