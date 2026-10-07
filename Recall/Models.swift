import Foundation

struct StudyCard: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var question: String
    var answer: String
    var conceptIDs: [UUID] = []
    var dueDate: Date = Date()
}

struct Concept: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var parentID: UUID? = nil
}

enum ReviewGrade: String, Codable, CaseIterable {
    case again
    case hard
    case good
    case easy
}

struct ReviewRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var cardID: UUID
    var date: Date
    var grade: ReviewGrade
}
struct ConceptNode: Identifiable, Hashable {
    var id: UUID
    var name: String
    var children: [ConceptNode] = []
    // Aggregated stats for UI
    var masteryPercent: Double // 0.0...1.0; if not enough data, set to -1.0 and UI will treat as missing
    var cardCount: Int
    var cards: [StudyCard] // cards associated to this node (descendants aggregated for non-leaf if desired)
}

