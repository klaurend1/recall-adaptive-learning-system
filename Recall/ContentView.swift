//
//  ContentView.swift
//  Recall
//
//  Created by Keith Laurendine Jr on 7/23/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var selection: Sidebar = .cards

    private enum Sidebar: Hashable {
        case cards, stats, tree
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Text("Cards").tag(Sidebar.cards)
                Text("Stats").tag(Sidebar.stats)
                Text("Memory Tree").tag(Sidebar.tree)
            }
            .navigationTitle("Recall")
        } detail: {
            switch selection {
            case .cards:
                CardsReviewView().navigationTitle("Cards")
            case .stats:
                StatsDashboardView().navigationTitle("Stats")
            case .tree:
                MemoryTreeView()
                    .environmentObject(app)
                    .navigationTitle("Memory Tree")
            }
        }
    }
}

struct CardsReviewView: View {
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var flipSpace

    private var total: Int { app.cards.count }
    private var remaining: Int { max(total - app.currentCardIndex - (app.showingAnswer ? 1 : 0), 0) }
    private var currentCard: StudyCard? { (app.currentCardIndex < app.cards.count) ? app.cards[app.currentCardIndex] : nil }

    var body: some View {
        VStack(spacing: 20) {
            header
            if app.currentCardIndex >= total {
                sessionComplete
            } else {
                flashcard
                controls
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .accentColor(.purple)
        .focusable()
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MCAT Master Deck")
                    .font(.system(size: 24, weight: .bold))
                Text(progressText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Remaining: \(max(total - app.currentCardIndex, 0))")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var progressText: String {
        guard total > 0 else { return "No cards" }
        return "Card \(min(app.currentCardIndex + 1, total)) of \(total)"
    }

    // MARK: - Flashcard
    private var flashcard: some View {
        ZStack {
            if let card = currentCard {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(
                        Group {
                            if app.showingAnswer {
                                VStack(spacing: 16) {
                                    Text(card.answer)
                                        .font(.system(size: 28, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .padding()
                                }
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            } else {
                                VStack(spacing: 24) {
                                    Text(card.question)
                                        .font(.system(size: 28, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .padding()
                                    Button(action: { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { app.showingAnswer = true } }) {
                                        Text("Show Answer")
                                            .font(.title2.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.purple)
                                    .keyboardShortcut(.space, modifiers: [])
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(32)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 12)
                    .frame(maxWidth: 800, maxHeight: 420)
                    .rotation3DEffect(.degrees(app.showingAnswer ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    .animation(.easeInOut(duration: 0.5), value: app.showingAnswer)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 460)
        .contentShape(Rectangle())
    }

    // MARK: - Controls
    private var controls: some View {
        VStack(spacing: 12) {
            if app.showingAnswer {
                HStack(spacing: 12) {
                    gradeButton(title: "Again", grade: .again, key: "1".first!, color: .red)
                    gradeButton(title: "Hard", grade: .hard, key: "2".first!, color: .orange)
                    gradeButton(title: "Good", grade: .good, key: "3".first!, color: .blue)
                    gradeButton(title: "Easy", grade: .easy, key: "4".first!, color: .green)
                }
                .frame(maxWidth: 800)
            } else {
                Text("Press Space to show the answer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func gradeButton(title: String, grade: ReviewGrade, key: Character, color: Color) -> some View {
        Button(action: { select(grade: grade) }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(String(key))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .keyboardShortcut(KeyEquivalent(key), modifiers: [])
    }

    // MARK: - Session Complete
    private var sessionComplete: some View {
        VStack(spacing: 16) {
            Text("Session Complete")
                .font(.system(size: 28, weight: .bold))
            Button("Review Again") {
                withAnimation(.spring()) {
                    resetSession()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Logic
    private func select(grade: ReviewGrade) {
        guard let card = currentCard else { return }
        // Record review
        let record = ReviewRecord(cardID: card.id, date: Date(), grade: grade)
        app.reviewRecords.append(record)
        app.scheduleNextDueDate(for: card.id, after: grade)
        advance()
    }

    private func advance() {
        withAnimation(.easeInOut) {
            app.showingAnswer = false
            app.currentCardIndex += 1
        }
    }

    private func resetSession() {
        app.currentCardIndex = 0
        app.showingAnswer = false
    }
}


// MARK: - MemoryTreeView and supporting views

struct MemoryTreeView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var query: String = ""
    @State private var expanded: Set<UUID> = []
    @State private var selectedConceptID: UUID? = nil

    private var filteredRoots: [ConceptNode] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return app.conceptRoots
        } else {
            // Filter concepts by query, keep ancestors
            let matches = app.allConcepts.filter { $0.name.localizedCaseInsensitiveContains(query) }
            let expandedIDs = Set(matches.flatMap { ancestors(of: $0) }.map(\.id))
            DispatchQueue.main.async {
                withAnimation {
                    expanded = expandedIDs
                }
            }
            // Return roots that are in the ancestor chain of matches
            // But for display, roots are always the top-level concepts, so return all roots filtered by if any descendant matches query
            return app.conceptRoots.filter { root in
                conceptOrDescendantsMatch(root: root, query: query)
            }
        }
    }

    /// Returns ancestors of a concept including itself, from root down to the concept
    private func ancestors(of concept: ConceptNode) -> [ConceptNode] {
        var ancestors: [ConceptNode] = []
        var current: ConceptNode? = concept
        while let c = current {
            ancestors.append(c)
            current = app.parentConcept(of: c)
        }
        return ancestors.reversed()
    }

    /// Returns true if concept or any descendant matches query
    private func conceptOrDescendantsMatch(root: ConceptNode, query: String) -> Bool {
        if root.name.localizedCaseInsensitiveContains(query) { return true }
        for child in root.children {
            if conceptOrDescendantsMatch(root: child, query: query) { return true }
        }
        return false
    }

    private var needsAttentionLeaves: [ConceptNode] {
        Array(app.weakestLeaves.prefix(3))
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > 900

            Group {
                if isWide {
                    HStack(spacing: 0) {
                        mainContent
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: .windowBackgroundColor))
                        if let selected = selectedConcept {
                            Divider()
                            selectedDetail
                                .frame(maxWidth: 360, maxHeight: .infinity)
                                .background(Color(nsColor: .windowBackgroundColor).opacity(0.97))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        mainContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: .windowBackgroundColor))
                        if let selected = selectedConcept {
                            Divider()
                            selectedDetail
                                .frame(maxWidth: .infinity)
                                .background(Color(nsColor: .windowBackgroundColor).opacity(0.97))
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                #if DEBUG
                print("TREE VIEW cards:", app.cards.count)
                print("TREE VIEW reviews:", app.reviewRecords.count)
                print("TREE VIEW concepts:", app.concepts.count)
                print("TREE VIEW roots:", app.conceptRoots.count)
                if let root = app.conceptRoots.first {
                    print("TREE ROOT:", root.name)
                    print("TREE ROOT cardCount:", root.cardCount)
                    print("TREE ROOT cards.count:", root.cards.count)
                    print("TREE ROOT mastery:", root.masteryPercent)
                }
                #endif
            }
        }
        .onChange(of: query) { newValue in
            if newValue.isEmpty {
                withAnimation {
                    expanded.removeAll()
                }
            }
        }
        .padding(16)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Search Field
                TextField("Find a concept", text: $query)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 12)

                // Needs Attention Section
                if !needsAttentionLeaves.isEmpty {
                    Text("Needs Attention")
                        .font(.title2.bold())
                        .padding(.bottom, 4)

                    VStack(spacing: 8) {
                        ForEach(needsAttentionLeaves) { concept in
                            Button {
                                withAnimation {
                                    selectedConceptID = concept.id
                                    // Expand ancestors so row is visible and expanded
                                    let ancestorIDs = Set(ancestors(of: concept).map(\.id))
                                    expanded.formUnion(ancestorIDs)
                                }
                            } label: {
                                HStack {
                                    Text(concept.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%.0f%%", concept.masteryPercent * 100))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundColor(.red)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.15))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
                }

                // Tree Section
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredRoots) { root in
                        ConceptNodeRow(
                            concept: root,
                            expanded: $expanded,
                            selectedConceptID: $selectedConceptID,
                            query: query,
                            app: app
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectedConcept: ConceptNode? {
        guard let id = selectedConceptID else { return nil }
        return app.allConcepts.first(where: { $0.id == id })
    }

    private var selectedDetail: some View {
        Group {
            if let concept = selectedConcept {
                ConceptDetailView(concept: concept)
                    .environmentObject(app)
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select a concept")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
        }
    }
}

private struct ConceptNodeRow: View {
    let concept: ConceptNode
    @Binding var expanded: Set<UUID>
    @Binding var selectedConceptID: UUID?
    let query: String
    @ObservedObject var app: AppViewModel

    private var isExpanded: Bool {
        expanded.contains(concept.id)
    }

    private var hasChildren: Bool {
        !concept.children.isEmpty
    }

    private var masteryText: String {
        if concept.hasEnoughReviewData {
            String(format: "%.0f%%", concept.masteryPercent * 100)
        } else {
            "Not enough review data"
        }
    }

    private var masteryColor: Color {
        if !concept.hasEnoughReviewData {
            return .secondary
        } else if concept.masteryPercent < 0.5 {
            return .red
        } else if concept.masteryPercent < 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    private var healthLabel: String {
        if !concept.hasEnoughReviewData {
            return "Health: -"
        } else if concept.masteryPercent < 0.5 {
            return "Health: Poor"
        } else if concept.masteryPercent < 0.8 {
            return "Health: Fair"
        } else {
            return "Health: Good"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    if hasChildren {
                        if isExpanded {
                            expanded.remove(concept.id)
                        } else {
                            expanded.insert(concept.id)
                        }
                    }
                    selectedConceptID = concept.id
                }
            } label: {
                HStack(spacing: 8) {
                    if hasChildren {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.15), value: isExpanded)
                    } else {
                        // Align text with chevron
                        Spacer().frame(width: 14)
                    }
                    Text(concept.name)
                        .fontWeight(selectedConceptID == concept.id ? .semibold : .regular)
                        .foregroundColor(selectedConceptID == concept.id ? .accentColor : .primary)
                    Spacer()
                    Text(masteryText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(masteryColor)
                        .frame(minWidth: 130, alignment: .trailing)
                    Text("\(concept.cardCount) card\(concept.cardCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 60, alignment: .trailing)
                    Text(healthLabel)
                        .font(.subheadline)
                        .foregroundColor(masteryColor)
                        .frame(minWidth: 90, alignment: .trailing)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedConceptID == concept.id ? Color.accentColor.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if hasChildren && isExpanded {
                VStack(spacing: 0) {
                    ForEach(concept.children) { child in
                        ConceptNodeRow(
                            concept: child,
                            expanded: $expanded,
                            selectedConceptID: $selectedConceptID,
                            query: query,
                            app: app
                        )
                        .padding(.leading, 20)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Detail view for a selected concept
private struct ConceptDetailView: View {
    @EnvironmentObject private var app: AppViewModel
    let concept: ConceptNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(concept.name)
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)

                HStack {
                    Text("Mastery:")
                        .font(.headline)
                    Spacer()
                    if concept.hasEnoughReviewData {
                        Text(String(format: "%.0f%%", concept.masteryPercent * 100))
                            .font(.headline.monospacedDigit())
                            .foregroundColor(concept.masteryPercentColor)
                    } else {
                        Text("Not enough review data")
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Card count:")
                        .font(.headline)
                    Spacer()
                    Text("\(concept.cardCount) card\(concept.cardCount == 1 ? "" : "s")")
                        .font(.headline)
                }

                HStack {
                    Text("Health:")
                        .font(.headline)
                    Spacer()
                    Text(concept.healthLabel)
                        .font(.headline)
                        .foregroundColor(concept.masteryPercentColor)
                }

                Divider()
                    .padding(.vertical, 12)

                if concept.cards.isEmpty {
                    Text("No cards for this concept.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cards")
                            .font(.title2.bold())
                        ForEach(concept.cards) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.question)
                                    .font(.headline)
                                Text(card.answer)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }
}


/// Extensions or helpers for ConceptNode

private extension ConceptNode {
    var hasEnoughReviewData: Bool {
        cards.isEmpty == false && masteryPercent >= 0 // Assuming masteryPercent returns 0 if no data, override if needed
    }

    var masteryPercentColor: Color {
        if !hasEnoughReviewData {
            return .secondary
        } else if masteryPercent < 0.5 {
            return .red
        } else if masteryPercent < 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    var healthLabel: String {
        if !hasEnoughReviewData {
            return "-"
        } else if masteryPercent < 0.5 {
            return "Poor"
        } else if masteryPercent < 0.8 {
            return "Fair"
        } else {
            return "Good"
        }
    }
}


/// Assumes AppViewModel has:
/// - conceptRoots: [ConceptNode] top-level concepts
/// - allConcepts: [ConceptNode] all concepts flat list
/// - parentConcept(of:) -> ConceptNode? returns parent of a concept
/// - weakestLeaves: [ConceptNode] returns weakest leaf concepts


#Preview {
    ContentView()
}

