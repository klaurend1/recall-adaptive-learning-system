import Foundation

final class KnowledgeGraphEngine {
    enum HealthState {
        case strong, stable, weak, atRisk, unlearned
    }
    
    struct NodeMetrics {
        var mastery: Double
        var recursiveCardCount: Int
        var nextReviewDate: Date?
        var attentionIndex: Double
        var healthState: HealthState
    }
    
    let conceptByID: [UUID: Concept]
    let childrenByConceptID: [UUID: [Concept]]
    let cardsByConceptID: [UUID: [UUID]]
    let parentByConceptID: [UUID: UUID]
    let reviewsByCardID: [UUID: [ReviewRecord]]
    let nodeMetricsByID: [UUID: NodeMetrics]
    
    private let now: Date
    
    init(concepts: [Concept], cards: [StudyCard], reviews: [ReviewRecord], referenceDate: Date = Date()) {
        self.now = referenceDate
        self.conceptByID = Dictionary(uniqueKeysWithValues: concepts.map { ($0.id, $0) })
        
        // Build childrenByConceptID
        var childrenMap = [UUID: [Concept]]()
        for concept in concepts {
            if let parent = concept.parentID {
                childrenMap[parent, default: []].append(concept)
            }
        }
        self.childrenByConceptID = childrenMap
        
        // cardsByConceptID
        var cardsMap = [UUID: [UUID]]()
        for card in cards {
            for cid in card.conceptIDs {
                cardsMap[cid, default: []].append(card.id)
            }
        }
        self.cardsByConceptID = cardsMap
        
        // parentByConceptID
        var parentMap = [UUID: UUID]()
        for concept in concepts {
            if let pid = concept.parentID {
                parentMap[concept.id] = pid
            }
        }
        self.parentByConceptID = parentMap
        
        // reviewsByCardID
        var reviewsMap = [UUID: [ReviewRecord]]()
        for review in reviews {
            reviewsMap[review.cardID, default: []].append(review)
        }
        for (key, arr) in reviewsMap {
            reviewsMap[key] = arr.sorted { $0.date > $1.date }
        }
        self.reviewsByCardID = reviewsMap
        
        // nodeMetricsByID (conceptID and cardID keys)
        var nodeMetricsTemp = [UUID: NodeMetrics]()
        var cardMetrics = [UUID: NodeMetrics]()
        // Card metrics
        for card in cards {
            let metrics = KnowledgeGraphEngine.cardMetrics(for: card, now: now)
            cardMetrics[card.id] = metrics
            nodeMetricsTemp[card.id] = metrics
        }
        // Concept metrics - bottom-up
        for concept in concepts {
            let metrics = KnowledgeGraphEngine.conceptMetrics(
                conceptID: concept.id,
                cardsByConceptID: cardsByConceptID,
                childrenByConceptID: childrenByConceptID,
                nodeMetricsByID: cardMetrics,
                conceptByID: conceptByID
            )
            nodeMetricsTemp[concept.id] = metrics
        }
        self.nodeMetricsByID = nodeMetricsTemp
    }
    
    // MARK: Card Metrics
    static func cardMetrics(for card: StudyCard, now: Date) -> NodeMetrics {
        guard let lastReviewed = card.lastReviewed, card.stability > 0 else {
            return NodeMetrics(mastery: 0, recursiveCardCount: 1, nextReviewDate: card.dueDate, attentionIndex: 1, healthState: .unlearned)
        }
        let elapsedDays = max(0, now.timeIntervalSince(lastReviewed) / 86400)
        let retention = pow(0.9, elapsedDays / card.stability)
        let stabilityFactor = min(card.stability / 365.0, 1.0)
        let mastery = max(0, min(1, stabilityFactor * retention))
        let health = healthState(for: mastery)
        let attention = 1.0 - mastery + (card.dueDate < now ? 0.5 : 0) + min(Double(card.lapses) * 0.1, 0.5)
        return NodeMetrics(mastery: mastery, recursiveCardCount: 1, nextReviewDate: card.dueDate, attentionIndex: attention, healthState: health)
    }
    
    // MARK: Concept Metrics
    static func conceptMetrics(
        conceptID: UUID,
        cardsByConceptID: [UUID: [UUID]],
        childrenByConceptID: [UUID: [Concept]],
        nodeMetricsByID: [UUID: NodeMetrics],
        conceptByID: [UUID: Concept]
    ) -> NodeMetrics {
        let cardIDs = cardsByConceptID[conceptID] ?? []
        let directCards = cardIDs.compactMap { nodeMetricsByID[$0] }
        let children = childrenByConceptID[conceptID] ?? []
        var descendantMetrics: [NodeMetrics] = []
        var totalRecursiveCards = 0
        for child in children {
            let metrics = conceptMetrics(conceptID: child.id, cardsByConceptID: cardsByConceptID, childrenByConceptID: childrenByConceptID, nodeMetricsByID: nodeMetricsByID, conceptByID: conceptByID)
            descendantMetrics.append(metrics)
            totalRecursiveCards += metrics.recursiveCardCount
        }
        let allMetrics = directCards + descendantMetrics
        let totalCards = directCards.count + totalRecursiveCards
        let weightedMastery: Double
        if totalCards > 0 {
            weightedMastery = allMetrics.reduce(0) { $0 + $1.mastery * Double($1.recursiveCardCount) } / Double(allMetrics.reduce(0) { $0 + $1.recursiveCardCount })
        } else {
            weightedMastery = 0
        }
        let nextReview = (allMetrics.compactMap { $0.nextReviewDate }).min()
        let health = healthState(for: weightedMastery)
        let attention = 1.0 - weightedMastery
        return NodeMetrics(mastery: weightedMastery, recursiveCardCount: totalCards, nextReviewDate: nextReview, attentionIndex: attention, healthState: health)
    }
    
    private static func healthState(for mastery: Double) -> HealthState {
        if mastery == 0 { return .unlearned }
        if mastery < 0.25 { return .atRisk }
        if mastery < 0.5 { return .weak }
        if mastery < 0.8 { return .stable }
        return .strong
    }
    
    // MARK: API
    func attentionConcepts(limit: Int) -> [Concept] {
        let scored = conceptByID.keys.compactMap { cid -> (Concept, Double)? in
            guard let c = conceptByID[cid], let m = nodeMetricsByID[cid]?.attentionIndex else { return nil }
            return (c, m)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }
    
    func updateCard(card: inout StudyCard, withReviewGrade grade: ReviewGrade, at date: Date) {
        switch grade {
        case .again:
            card.lapses += 1
            card.stability = max(card.stability * 0.2, 0.25)
        case .hard:
            card.repetitions += 1
            card.stability = max(card.stability * 1.2, 1.0)
        case .good:
            card.repetitions += 1
            card.stability = max(card.stability * 2.5, 1.0)
        case .easy:
            card.repetitions += 1
            card.stability = max(card.stability * 3.0, 1.0)
        }
        card.lastReviewed = date
        rescheduleCardAfterReview(card: &card, after: grade, at: date)
    }
    
    func rescheduleCardAfterReview(card: inout StudyCard, after grade: ReviewGrade, at date: Date) {
        let interval: TimeInterval
        switch grade {
        case .again:
            interval = 1 * 86400
        case .hard:
            interval = 1 * 86400
        case .good:
            interval = 3 * 86400
        case .easy:
            interval = 7 * 86400
        }
        card.dueDate = date.addingTimeInterval(interval)
    }
}
