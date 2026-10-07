import Foundation

enum NodeType: String, Codable, CaseIterable {
    case subject
    case topic
    case subtopic
    case concept
}

struct StudyCard: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var question: String
    var answer: String
    var conceptIDs: [UUID] = []
    var dueDate: Date = Date()
    var stability: Double = 0.0
    var difficulty: Double = 0.3
    var repetitions: Int = 0
    var lapses: Int = 0
    var lastReviewed: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, question, answer, conceptIDs, dueDate, stability, difficulty, repetitions, lapses, lastReviewed
    }

    init(id: UUID = UUID(), question: String, answer: String, conceptIDs: [UUID] = [], dueDate: Date = Date(), stability: Double = 0.0, difficulty: Double = 0.3, repetitions: Int = 0, lapses: Int = 0, lastReviewed: Date? = nil) {
        self.id = id
        self.question = question
        self.answer = answer
        self.conceptIDs = conceptIDs
        self.dueDate = dueDate
        self.stability = stability
        self.difficulty = difficulty
        self.repetitions = repetitions
        self.lapses = lapses
        self.lastReviewed = lastReviewed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        question = try container.decode(String.self, forKey: .question)
        answer = try container.decode(String.self, forKey: .answer)
        conceptIDs = (try? container.decode([UUID].self, forKey: .conceptIDs)) ?? []
        dueDate = (try? container.decode(Date.self, forKey: .dueDate)) ?? Date()
        stability = (try? container.decode(Double.self, forKey: .stability)) ?? 0.0
        difficulty = (try? container.decode(Double.self, forKey: .difficulty)) ?? 0.3
        repetitions = (try? container.decode(Int.self, forKey: .repetitions)) ?? 0
        lapses = (try? container.decode(Int.self, forKey: .lapses)) ?? 0
        lastReviewed = try? container.decodeIfPresent(Date.self, forKey: .lastReviewed)
    }
}

struct Concept: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var parentID: UUID? = nil
    var nodeType: NodeType = .concept
    var prerequisiteIDs: [UUID] = []

    enum CodingKeys: String, CodingKey {
        case id, name, description, parentID, nodeType, prerequisiteIDs
    }

    init(id: UUID = UUID(), name: String, description: String? = nil, parentID: UUID? = nil, nodeType: NodeType = .concept, prerequisiteIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.parentID = parentID
        self.nodeType = nodeType
        self.prerequisiteIDs = prerequisiteIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        parentID = try? container.decodeIfPresent(UUID.self, forKey: .parentID)
        nodeType = (try? container.decode(NodeType.self, forKey: .nodeType)) ?? .concept
        prerequisiteIDs = (try? container.decode([UUID].self, forKey: .prerequisiteIDs)) ?? []
    }
}

enum ReviewGrade: String, Codable, CaseIterable, Hashable, Equatable {
    case again
    case hard
    case good
    case easy
}

struct ReviewRecord: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var cardID: UUID
    var date: Date
    var grade: ReviewGrade
}
