import SwiftUI

struct StatsDashboardView: View {
    @EnvironmentObject private var app: AppViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                reviewStatus
                forecast
                memoryHealth
                reviewQuality
                priorityReview
            }
            .padding(24)
        }
        .accentColor(.purple)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Section 1: Review Status
    private var reviewStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Status")
                .font(.title2.bold())
            LazyVGrid(columns: columns, spacing: 12) {
                statCard(title: "Due Today", value: "\(dueToday)")
                statCard(title: "Reviewed Today", value: "\(reviewedToday)")
                statCard(title: "Current Retention", value: retentionText)
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(value).font(.system(size: 28, weight: .bold))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dueToday: Int { app.dueCount(on: Date()) }
    private var reviewedToday: Int { app.reviewsTodayCount() }

    private var retentionText: String {
        let recent = app.reviewRecords.suffix(50)
        let denom = recent.count
        guard denom > 0 else { return "Not enough data" }
        let success = recent.filter { $0.grade == .good || $0.grade == .easy }.count
        let pct = Int((Double(success) / Double(denom)) * 100.0)
        return "\(pct)%"
    }

    // MARK: - Section 2: Forecast
    private var forecast: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7‑Day Forecast").font(.title2.bold())
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                    let count = app.dueCount(on: day)
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 28, height: 80)
                            let height = CGFloat(min(max(count, 0), 40)) / 40.0 * 80.0
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple)
                                .frame(width: 28, height: height)
                        }
                        Text(shortDayName(for: day)).font(.caption)
                        Text("\(count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Text(forecastRecommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func shortDayName(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: date)
    }

    private var forecastRecommendation: String {
        let today = app.dueCount(on: Date())
        let next = (1...6).map { app.dueCount(on: Calendar.current.date(byAdding: .day, value: $0, to: Date())!) }
        if today > 0 && next.reduce(0, +) == 0 { return "Complete today’s reviews to protect retention." }
        if today == 0 && next.max() ?? 0 == 0 { return "Your review load is balanced." }
        if today > 0 && (next.max() ?? 0) == 0 { return "You have overdue cards." }
        if let maxNext = next.max(), maxNext > today * 2 { return "A heavy review day is approaching." }
        return "Your review load is balanced."
    }

    // MARK: - Section 3: Memory Health
    private var memoryHealth: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Health").font(.title2.bold())
            let stats = memoryHealthStats()
            HStack(spacing: 12) {
                healthCard(title: "Strong", value: stats.strong)
                healthCard(title: "Developing", value: stats.developing)
                healthCard(title: "At Risk", value: stats.atRisk)
            }
        }
    }

    private func healthCard(title: String, value: (count: Int, pct: Int)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(value.count)").font(.system(size: 28, weight: .bold))
                Text("\(value.pct)%").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func memoryHealthStats() -> (strong: (Int, Int), developing: (Int, Int), atRisk: (Int, Int)) {
        let total = max(app.cards.count, 1)
        var strong = 0, developing = 0, atRisk = 0
        for card in app.cards {
            let latest = app.latestGrade(for: card.id)
            let overdue = Calendar.current.startOfDay(for: card.dueDate) <= Calendar.current.startOfDay(for: Date())
            switch latest {
            case .some(.good), .some(.easy): strong += overdue ? 0 : 1
            case .some(.hard): developing += 1
            case .some(.again): atRisk += 1
            case .none: developing += 1
            }
        }
        let pct = { (n: Int) in Int((Double(n) / Double(total)) * 100.0) }
        return ((strong, pct(strong)), (developing, pct(developing)), (atRisk, pct(atRisk)))
    }

    // MARK: - Section 4: Review Quality
    private var reviewQuality: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Quality").font(.title2.bold())
            let counts = gradeCounts()
            VStack(spacing: 8) {
                distributionBar(counts: counts)
                HStack(spacing: 16) {
                    Text("Success Rate: \(percent(counts.good + counts.easy, of: counts.total))")
                    Text("Lapse Rate: \(percent(counts.again, of: counts.total))")
                    Text("Avg Reviews/Card: \(String(format: "%.1f", counts.total == 0 ? 0 : Double(counts.total) / Double(max(app.cards.count,1))))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func distributionBar(counts: (again: Int, hard: Int, good: Int, easy: Int, total: Int)) -> some View {
        let total = max(counts.total, 1)
        let wAgain = CGFloat(counts.again) / CGFloat(total)
        let wHard = CGFloat(counts.hard) / CGFloat(total)
        let wGood = CGFloat(counts.good) / CGFloat(total)
        let wEasy = CGFloat(counts.easy) / CGFloat(total)
        return GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                Color.red.frame(width: width * wAgain)
                Color.orange.frame(width: width * wHard)
                Color.blue.frame(width: width * wGood)
                Color.green.frame(width: width * wEasy)
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
            )
        }
        .frame(height: 16)
    }

    private func gradeCounts() -> (again: Int, hard: Int, good: Int, easy: Int, total: Int) {
        var again = 0, hard = 0, good = 0, easy = 0
        for r in app.reviewRecords {
            switch r.grade {
            case .again: again += 1
            case .hard: hard += 1
            case .good: good += 1
            case .easy: easy += 1
            }
        }
        let total = again + hard + good + easy
        return (again, hard, good, easy, total)
    }

    private func percent(_ part: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        let pct = Int((Double(part) / Double(total)) * 100.0)
        return "\(pct)%"
    }

    // MARK: - Section 5: Priority Review
    private var priorityReview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priority Review").font(.title2.bold())
            let items = prioritizedItems()
            if items.isEmpty {
                Text("Complete your first review session to unlock memory insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.id) { item in
                        HStack {
                            Text(item.title).font(.headline)
                            Spacer()
                            Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            Button("Start Priority Review") { }
                .disabled(true)
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.top, 4)
        }
    }

    private struct PriorityItem { let id: UUID; let title: String; let detail: String }

    private func prioritizedItems() -> [PriorityItem] {
        // 1. Overdue cards
        var items: [PriorityItem] = []
        let today = Calendar.current.startOfDay(for: Date())
        let overdue = app.cards.filter { Calendar.current.startOfDay(for: $0.dueDate) < today }
        for c in overdue.prefix(5) {
            items.append(PriorityItem(id: c.id, title: c.question, detail: "Overdue • Due \(formatDate(c.dueDate))"))
        }
        if items.count < 5 {
            // 2. Last graded Again
            let againIDs = Set(app.reviewRecords.filter { $0.grade == .again }.map { $0.cardID })
            let againCards = app.cards.filter { againIDs.contains($0.id) }
            for c in againCards.prefix(max(0, 5 - items.count)) {
                items.append(PriorityItem(id: c.id, title: c.question, detail: "Last graded Again • Due \(formatDate(c.dueDate))"))
            }
        }
        if items.count < 5 {
            // 3. Last graded Hard
            let hardIDs = Set(app.reviewRecords.filter { $0.grade == .hard }.map { $0.cardID })
            let hardCards = app.cards.filter { hardIDs.contains($0.id) }
            for c in hardCards.prefix(max(0, 5 - items.count)) {
                items.append(PriorityItem(id: c.id, title: c.question, detail: "Last graded Hard • Due \(formatDate(c.dueDate))"))
            }
        }
        // 4. Concepts with lowest mastery (placeholder heuristic: fewest Good/Easy reviews)
        if items.count < 5 {
            let byConcept: [(Concept, Int)] = app.concepts.map { concept in
                let cardIDs = Set(app.cards.filter { $0.conceptIDs.contains(concept.id) }.map { $0.id })
                let mastery = app.reviewRecords.filter { cardIDs.contains($0.cardID) && ($0.grade == .good || $0.grade == .easy) }.count
                return (concept, mastery)
            }
            let weakest = byConcept.sorted { $0.1 < $1.1 }.prefix(max(0, 5 - items.count))
            for (concept, mastery) in weakest {
                items.append(PriorityItem(id: concept.id, title: concept.name, detail: "Low mastery • \(mastery) good/easy reviews"))
            }
        }
        return items
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    StatsDashboardView().environmentObject(AppViewModel())
}
