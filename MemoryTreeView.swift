import SwiftUI

struct MemoryTreeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var searchText: String = ""
    @State private var selectedConceptID: UUID? = nil

    private var engine: KnowledgeGraphEngine { appViewModel.engine }
    private var concepts: [Concept] { appViewModel.concepts }
    private var cards: [StudyCard] { appViewModel.cards }
    private var reviews: [ReviewRecord] { appViewModel.reviewRecords }

    // Filtered roots
    private var rootConcepts: [Concept] {
        let roots = concepts.filter { $0.parentID == nil }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return roots }
        let query = searchText.lowercased()
        return roots.filter { $0.name.lowercased().contains(query) || hasDescendantMatch($0, query: query) }
    }
    private func hasDescendantMatch(_ concept: Concept, query: String) -> Bool {
        let children = engine.childrenByConceptID[concept.id] ?? []
        for child in children {
            if child.name.lowercased().contains(query) || hasDescendantMatch(child, query: query) {
                return true
            }
        }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Search
                TextField("Search concepts", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.top, .horizontal])

                // Needs Attention
                let attention = engine.attentionConcepts(limit: 5)
                if !attention.isEmpty {
                    Section(header: Text("Needs Attention").font(.title2.bold()).padding(.horizontal)) {
                        ForEach(attention, id: \Concept.id) { concept in
                            Button(action: { selectedConceptID = concept.id }) {
                                HStack {
                                    Text(concept.name).font(.headline)
                                    Spacer()
                                    if let metrics = engine.nodeMetricsByID[concept.id] {
                                        Text("\(Int((metrics.mastery * 100).rounded()))%")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundColor(.primary)
                                        Text(healthLabel(metrics.healthState))
                                            .font(.subheadline)
                                            .foregroundColor(healthColor(metrics.healthState))
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedConceptID == concept.id ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Knowledge tree
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rootConcepts, id: \Concept.id) { concept in
                            ConceptTreeRow(
                                concept: concept,
                                engine: engine,
                                selectedConceptID: $selectedConceptID
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                Spacer()
            }
            .frame(minWidth: 350, maxWidth: 410)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Detail Panel
            if let selID = selectedConceptID, let concept = engine.conceptByID[selID] {
                ConceptDetailPanel(concept: concept, engine: engine, cards: cards, reviews: reviews)
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack {
                    Spacer()
                    Text("Select a concept")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    Spacer()
                }
            }
        }
    }

    private func healthLabel(_ state: KnowledgeGraphEngine.HealthState) -> String {
        switch state {
        case .strong: return "Strong"
        case .stable: return "Stable"
        case .weak: return "Weak"
        case .atRisk: return "At Risk"
        case .unlearned: return "Unlearned"
        }
    }
    private func healthColor(_ state: KnowledgeGraphEngine.HealthState) -> Color {
        switch state {
        case .strong: return .green
        case .stable: return .blue
        case .weak: return .orange
        case .atRisk: return .red
        case .unlearned: return .gray
        }
    }
}

private struct ConceptTreeRow: View {
    let concept: Concept
    let engine: KnowledgeGraphEngine
    @Binding var selectedConceptID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { selectedConceptID = concept.id }) {
                HStack {
                    Text(concept.name)
                        .fontWeight(selectedConceptID == concept.id ? .semibold : .regular)
                        .foregroundColor(selectedConceptID == concept.id ? .accentColor : .primary)
                    Spacer()
                    if let metrics = engine.nodeMetricsByID[concept.id] {
                        Text("\(Int((metrics.mastery * 100).rounded()))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.primary)
                        Text(healthLabel(metrics.healthState))
                            .font(.subheadline)
                            .foregroundColor(healthColor(metrics.healthState))
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            let children = engine.childrenByConceptID[concept.id] ?? []
            if !children.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(children, id: \Concept.id) { child in
                        ConceptTreeRow(
                            concept: child,
                            engine: engine,
                            selectedConceptID: $selectedConceptID
                        )
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private func healthLabel(_ state: KnowledgeGraphEngine.HealthState) -> String {
        switch state {
        case .strong: return "Strong"
        case .stable: return "Stable"
        case .weak: return "Weak"
        case .atRisk: return "At Risk"
        case .unlearned: return "Unlearned"
        }
    }
    private func healthColor(_ state: KnowledgeGraphEngine.HealthState) -> Color {
        switch state {
        case .strong: return .green
        case .stable: return .blue
        case .weak: return .orange
        case .atRisk: return .red
        case .unlearned: return .gray
        }
    }
}

private struct ConceptDetailPanel: View {
    let concept: Concept
    let engine: KnowledgeGraphEngine
    let cards: [StudyCard]
    let reviews: [ReviewRecord]

    var cardIDs: [UUID] { engine.cardsByConceptID[concept.id] ?? [] }
    var conceptCards: [StudyCard] { cards.filter { cardIDs.contains($0.id) } }
    var metrics: KnowledgeGraphEngine.NodeMetrics? { engine.nodeMetricsByID[concept.id] }
    var recentReviews: [ReviewRecord] {
        let ids = Set(cardIDs)
        return reviews.filter { ids.contains($0.cardID) }.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(concept.name)
                    .font(.largeTitle.bold())
                if let m = metrics {
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mastery")
                                .font(.headline)
                            Text("\(Int((m.mastery * 100).rounded()))%")
                                .font(.title2.bold())
                                .foregroundColor(healthColor(m.healthState))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health")
                                .font(.headline)
                            Text(healthLabel(m.healthState))
                                .font(.title2.bold())
                                .foregroundColor(healthColor(m.healthState))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cards")
                                .font(.headline)
                            Text("\(m.recursiveCardCount)")
                                .font(.title2.bold())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Review")
                                .font(.headline)
                            if let next = m.nextReviewDate {
                                Text(next, style: .date)
                                    .font(.title2.bold())
                            } else {
                                Text("None")
                                    .font(.title2.bold())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Divider().padding(.vertical, 4)
                Text("Cards")
                    .font(.headline)
                if conceptCards.isEmpty {
                    Text("No cards for this concept.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(conceptCards, id: \StudyCard.id) { card in
                        Text(card.question)
                            .font(.body)
                            .padding(.vertical, 2)
                    }
                }
                Divider()
                Text("Recent Performance")
                    .font(.headline)
                if recentReviews.isEmpty {
                    Text("No recent reviews.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recentReviews, id: \ReviewRecord.id) { review in
                        HStack {
                            Text(review.date, style: .date)
                                .frame(width: 90, alignment: .leading)
                            Text(gradeLabel(review.grade))
                                .foregroundColor(gradeColor(review.grade))
                        }
                        .font(.callout)
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding()
        }
    }

    private func healthLabel(_ state: KnowledgeGraphEngine.HealthState) -> String {
        switch state {
        case .strong: return "Strong"
        case .stable: return "Stable"
        case .weak: return "Weak"
        case .atRisk: return "At Risk"
        case .unlearned: return "Unlearned"
        }
    }
    private func healthColor(_ state: KnowledgeGraphEngine.HealthState) -> Color {
        switch state {
        case .strong: return .green
        case .stable: return .blue
        case .weak: return .orange
        case .atRisk: return .red
        case .unlearned: return .gray
        }
    }
    private func gradeLabel(_ grade: ReviewGrade) -> String {
        switch grade {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
    private func gradeColor(_ grade: ReviewGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard: return .orange
        case .good: return .blue
        case .easy: return .green
        }
    }
}
