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

        app.recordReview(cardID: card.id, grade: grade)

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

#Preview {
    ContentView()
}
