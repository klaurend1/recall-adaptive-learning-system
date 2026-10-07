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

    /// The knowledge graph engine instance built from current concepts, cards, and reviewRecords.
    @Published var engine: KnowledgeGraphEngine = KnowledgeGraphEngine(
        concepts: [],
        cards: [],
        reviews: []
    )
    
    private func rebuildEngine() {
        engine = KnowledgeGraphEngine(
            concepts: concepts,
            cards: cards,
            reviews: reviewRecords
        )
    }
    init(setup: Bool = false) {
        loadState()
        if cards.isEmpty { cards = MockData.cards }
        if concepts.isEmpty { concepts = MockData.concepts }

        // Temporary migration: if any card references a conceptID not in current concepts, replace cards with seeded MockData.cards (preserve reviewRecords)
        // Migrate older saved cards that do not have concept assignments
        let seededConceptsByQuestion = Dictionary(
            uniqueKeysWithValues: MockData.cards.map { ($0.question, $0.conceptIDs) }
        )

        for index in cards.indices {
            if cards[index].conceptIDs.isEmpty,
               let conceptIDs = seededConceptsByQuestion[cards[index].question] {
                cards[index].conceptIDs = conceptIDs
            }
        }

        // Repair any cards whose concept IDs still do not exist
        let validConceptIDs = Set(concepts.map { $0.id })

        let hasOrphans = cards.contains { card in
            card.conceptIDs.isEmpty ||
            card.conceptIDs.contains { !validConceptIDs.contains($0) }
        }

        if hasOrphans {
            print("Warning: Some cards still have invalid concept mappings")
        }
        
        rebuildEngine()
        engine = KnowledgeGraphEngine(
            concepts: concepts,
            cards: cards,
            reviews: reviewRecords
        )
        
        #if DEBUG
        print("Recall cards:", cards.count)
        print("Recall concepts:", concepts.count)
        let conceptIDs = Set(concepts.map { $0.id })
        let allRefsResolve = cards.allSatisfy { card in card.conceptIDs.allSatisfy { conceptIDs.contains($0) } }
        print("All card conceptIDs resolve:", allRefsResolve)
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

    // MARK: - Knowledge Graph Support

    enum MemoryHealth {
        case strong
        case stable
        case weak
        case atRisk
        case unlearned

        var label: String {
            switch self {
            case .strong: return "Strong"
            case .stable: return "Stable"
            case .weak: return "Weak"
            case .atRisk: return "At Risk"
            case .unlearned: return "Unlearned"
            }
        }

        var colorName: String {
            switch self {
            case .strong: return "green"
            case .stable: return "blue"
            case .weak: return "orange"
            case .atRisk: return "red"
            case .unlearned: return "gray"
            }
        }
    }

    // Expose conceptByID from engine
    var conceptByID: [UUID: Concept] {
        engine.conceptByID
    }

    // Expose parentByConceptID from engine (map conceptID to optional parent conceptID)
    var parentByConceptID: [UUID: UUID?] {
        // Pass concept IDs to engine, not full Concept objects
        engine.parentByConceptID
    }

    // Expose childrenByConceptID from engine, but map UUID children to Concept objects
    var childrenByConceptID: [UUID: [Concept]] {
        var result: [UUID: [Concept]] = [:]
        for (parentID, childIDs) in engine.childrenByConceptID {
            // Pass concept.id (UUID) to engine, mapping here just transforms UUIDs to Concepts
            result[parentID] = childIDs
        }
        return result
    }

    // Expose cardsByConceptID from engine, but map UUID card IDs to StudyCard objects
    var cardsByConceptID: [UUID: [StudyCard]] {
        var result: [UUID: [StudyCard]] = [:]
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        for (conceptID, cardIDs) in engine.cardsByConceptID {
            // Pass concept.id (UUID) to engine, mapping here just transforms UUIDs to StudyCards
            result[conceptID] = cardIDs.compactMap { cardsByID[$0] }
        }
        return result
    }

    /// Converts engine HealthState to MemoryHealth category
    func health(for healthState: KnowledgeGraphEngine.HealthState?) -> MemoryHealth? {
        guard let state = healthState else { return nil }
        switch state {
        case .strong: return .strong
        case .stable: return .stable
        case .weak: return .weak
        case .atRisk: return .atRisk
        case .unlearned: return .unlearned
        }
    }

    /// Returns concepts that need attention, sorted by attention index descending.
    var needsAttentionConcepts: [Concept] {
        // Pass concept IDs (UUID) to engine.attentionConcepts if needed, here engine manages internally
        engine.attentionConcepts(limit: 1000)
    }

    /// Record a review and update card data with engine logic, then reschedule the card.
    func recordReview(cardID: UUID, grade: ReviewGrade) {
        guard let cardIndex = cards.firstIndex(where: { $0.id == cardID }) else { return }

        // Create the new review record
        let reviewDate = Date()
        let newReview = ReviewRecord(cardID: cardID, date: reviewDate, grade: grade)
        reviewRecords.append(newReview)

        // Update card's spaced repetition data using the engine's logic
        var card = cards[cardIndex]

        engine.updateCard(card: &card, withReviewGrade: grade, at: reviewDate)

        engine.rescheduleCardAfterReview(
            card: &card,
            after: grade,
            at: reviewDate
        )

        cards[cardIndex] = card
        rebuildEngine()
    }
}
