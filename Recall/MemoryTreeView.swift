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

                // Concept List (roots filtered by search)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rootConcepts, id: \.id) { concept in
                            ConceptTreeRow(
                                concept: concept,
                                engine: engine,
                                selectedConceptID: $selectedConceptID
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                Spacer()
            }
            .frame(minWidth: 350, maxWidth: 410)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Detail Panel with MemoryTreeCanvas embedded
            if let selID = selectedConceptID, let concept = engine.conceptByID[selID] {
                DetailPanelWithConceptMap(
                    concept: concept,
                    engine: engine,
                    cards: cards,
                    reviews: reviews,
                    selectedConceptID: $selectedConceptID
                )
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

private struct DetailPanelWithConceptMap: View {
    let concept: Concept
    let engine: KnowledgeGraphEngine
    let cards: [StudyCard]
    let reviews: [ReviewRecord]
    @Binding var selectedConceptID: UUID?

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

                Text("Concept Map")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                // Embed MemoryTreeCanvas here with zooming and panning support
                MemoryTreeCanvas(
                    engine: engine,
                    selectedConceptID: $selectedConceptID
                )
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 12)

                Divider()
                Text("Cards")
                    .font(.headline)
                if conceptCards.isEmpty {
                    Text("No cards for this concept.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(conceptCards, id: \.id) { card in
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
                    ForEach(recentReviews, id: \.id) { review in
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
                    ForEach(children, id: \.id) { child in
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
    private func displayName(for concept: Concept) -> String {
        switch concept.name {
        case "Psychology / Sociology":
            return "Psych / Soc"
        case "Critical Analysis and Reasoning Skills (CARS)":
            return "CARS"
        case "General Chemistry":
            return "Gen Chem"
        case "Organic Chemistry":
            return "Organic Chem"
        default:
            return concept.name
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

// MARK: - MemoryTreeCanvas: Custom top-down tree visualization of selected concept neighborhood with zoom and pan

private struct MemoryTreeCanvas: View {
    let engine: KnowledgeGraphEngine
    @Binding var selectedConceptID: UUID?

    // Gesture states for zoom and pan
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var gestureZoomScale: CGFloat = 1.0
    @State private var gesturePanOffset: CGSize = .zero

    // Layout constants (increased spacing to reduce node collisions)
    private let nodeMinDiameter: CGFloat = 50
    private let nodeMaxDiameter: CGFloat = 90
    private let verticalSpacing: CGFloat = 160
    private let horizontalSpacing: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let selID = selectedConceptID,
                      let selConcept = engine.conceptByID[selID] else {
                    return
                }

                // Compute nodes to display: selected concept, its ancestors, direct children, and optionally siblings
                let conceptsToShow = conceptsForSelected(selConcept)

                // Compute positions for these nodes
                let positions = computeNodePositions(
                    size: size,
                    concepts: conceptsToShow,
                    selectedConceptID: selID
                )

                // Center the graph on selected concept (its position)
                guard !positions.isEmpty else { return }

                let minX = positions.values.map(\.x).min() ?? 0
                let maxX = positions.values.map(\.x).max() ?? 0
                let minY = positions.values.map(\.y).min() ?? 0

                let graphCenterX = (minX + maxX) / 2

                let offsetX = size.width / 2 - graphCenterX
                let offsetY: CGFloat = 45 - minY

                // Apply pan and zoom transforms combined with centering on selected node
                context.translateBy(x: offsetX + panOffset.width + gesturePanOffset.width,
                                    y: offsetY + panOffset.height + gesturePanOffset.height)
                
                let scale = zoomScale * gestureZoomScale
                context.scaleBy(x: scale, y: scale)
                
                // Draw edges first
                for (conceptID, pos) in positions {
                    let children = engine.childrenByConceptID[conceptID] ?? []
                    for child in children where positions.keys.contains(child.id) {
                        if let childPos = positions[child.id] {
                            var path = Path()
                            path.move(to: CGPoint(
                                x: pos.x,
                                y: pos.y + nodeDiameter(for: conceptID) / 2
                            ))
                            path.addLine(to: CGPoint(
                                x: childPos.x,
                                y: childPos.y - nodeDiameter(for: child.id) / 2
                            ))

                            // Edge color dims siblings
                            let isSiblingEdge = isSiblingEdge(parentID: conceptID, childID: child.id, selectedID: selID)
                            let baseColor = edgeColor(for: conceptID)
                            let strokeColor = isSiblingEdge ? baseColor.opacity(0.15) : baseColor.opacity(0.5)

                            context.stroke(path, with: .color(strokeColor), lineWidth: 2)
                        }
                    }
                }

                // Draw nodes
                for concept in conceptsToShow {
                    if let pos = positions[concept.id] {
                        let diameter = nodeDiameter(for: concept.id)
                        let rect = CGRect(
                            x: pos.x - diameter / 2,
                            y: pos.y - diameter / 2,
                            width: diameter,
                            height: diameter
                        )

                        // Fill color softer for siblings, normal for selected and related nodes
                        let fillColor = nodeFillColor(for: concept.id)
                        let isSelected = (concept.id == selID)
                        let isAncestor = isAncestor(of: concept.id, selectedID: selID)
                        let isChild = isChild(of: concept.id, selectedID: selID)
                        let isSibling = isSibling(concept.id, selectedID: selID)

                        let fillOpacity: Double = {
                            if isSelected {
                                return 0.9
                            } else if isAncestor || isChild {
                                return 0.7
                            } else if isSibling {
                                return 0.3
                            } else {
                                return 0.4
                            }
                        }()

                        // Stroke color: bright outline for selected node
                        let strokeColor: Color = isSelected ? Color.accentColor : Color.clear
                        let strokeLineWidth: CGFloat = isSelected ? 4 : 0

                        context.fill(
                            Ellipse().path(in: rect),
                            with: .color(fillColor.opacity(fillOpacity))
                        )
                        if strokeLineWidth > 0 {
                            context.stroke(
                                Ellipse().path(in: rect),
                                with: .color(strokeColor),
                                lineWidth: strokeLineWidth
                            )
                        }

                        // Text styling: smaller labels, no overflow
                        let maxTextWidth = diameter * 0.75
                        let nameText = Text(displayName(for: concept))
                            .font(.system(
                                size: 12,
                                weight: isSelected ? .bold : .regular
                            ))
                            .foregroundColor(.white)

                        context.draw(
                            nameText,
                            at: CGPoint(x: rect.midX, y: rect.midY),
                            anchor: .center
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        gestureZoomScale = value
                    }
                    .onEnded { value in
                        zoomScale = max(0.5, min(zoomScale * value, 5.0))
                        gestureZoomScale = 1.0
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        gesturePanOffset = value.translation
                    }
                    .onEnded { value in
                        panOffset.width += value.translation.width
                        panOffset.height += value.translation.height
                        gesturePanOffset = .zero
                    }
            )
            .background(Color.black)
            .clipped()
            .onTapGesture { location in
                // No direct location available here, so use simultaneous gesture approach in Canvas if needed
                // Instead handle tap via SpatialTapGesture below
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let selID = selectedConceptID,
                              let selConcept = engine.conceptByID[selID] else { return }
                        let conceptsToShow = conceptsForSelected(selConcept)
                        let positions = computeNodePositions(
                            size: geo.size,
                            concepts: conceptsToShow,
                            selectedConceptID: selID
                        )
                        guard !positions.isEmpty else { return }

                        let minX = positions.values.map(\.x).min() ?? 0
                        let maxX = positions.values.map(\.x).max() ?? 0
                        let minY = positions.values.map(\.y).min() ?? 0

                        let graphCenterX = (minX + maxX) / 2

                        let offsetX =
                            geo.size.width / 2 - graphCenterX
                            + panOffset.width
                            + gesturePanOffset.width

                        let offsetY =
                            45 - minY
                            + panOffset.height
                            + gesturePanOffset.height
                        // Adjust tap location by inverse transform
                        let transformedPoint = CGPoint(
                            x: (value.location.x - offsetX) / (zoomScale * gestureZoomScale),
                            y: (value.location.y - offsetY) / (zoomScale * gestureZoomScale)
                        )

                        // Hit test for nodes
                        for (conceptID, pos) in positions {
                            let radius = nodeDiameter(for: conceptID) / 2
                            let dx = transformedPoint.x - pos.x
                            let dy = transformedPoint.y - pos.y
                            if dx * dx + dy * dy <= radius * radius {
                                selectedConceptID = conceptID
                                break
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Helpers for concept relationships displayed in graph
    private func displayName(for concept: Concept) -> String {
        switch concept.name {
        case "Psychology / Sociology":
            return "Psych / Soc"
        case "Critical Analysis and Reasoning Skills (CARS)":
            return "CARS"
        case "General Chemistry":
            return "Gen Chem"
        case "Organic Chemistry":
            return "Organic Chem"
        default:
            return concept.name
        }
    }
    
    /// Returns the concepts to show in the graph: selected node, ancestors up to root, direct children, and siblings
    private func conceptsForSelected(_ selected: Concept) -> [Concept] {
        var resultSet = Set<Concept>()

        // Add selected concept
        resultSet.insert(selected)

        // Add ancestors up to root
        var current = selected
        while let parentID = current.parentID, let parent = engine.conceptByID[parentID] {
            resultSet.insert(parent)
            current = parent
        }

        // Add direct children of selected concept
        let children = engine.childrenByConceptID[selected.id] ?? []
        children.forEach { resultSet.insert($0) }

        // Add siblings (other children of selected's parent)
        if let parentID = selected.parentID,
           let siblings = engine.childrenByConceptID[parentID] {
            siblings.forEach { resultSet.insert($0) }
        }

        // Return as array sorted by name for consistent order
        return Array(resultSet).sorted { $0.name < $1.name }
    }

    /// Compute node diameter based on recursive card count scaled between min and max diameter
    private func nodeDiameter(for conceptID: UUID) -> CGFloat {
        guard let metrics = engine.nodeMetricsByID[conceptID] else { return nodeMinDiameter }
        // Clamp recursiveCardCount between 1 and 20 for sizing
        let count = max(1, min(metrics.recursiveCardCount, 20))
        // Map count linearly to diameter
        let ratio = CGFloat(count - 1) / 19 // (0...1)
        return nodeMinDiameter + ratio * (nodeMaxDiameter - nodeMinDiameter)
    }

    /// Compute node fill color based on health state, soft for selected and related nodes
    private func nodeFillColor(for conceptID: UUID) -> Color {
        guard let metrics = engine.nodeMetricsByID[conceptID] else { return Color.gray.opacity(0.7) }
        return healthColor(metrics.healthState)
    }

    /// Compute edge color based on parent concept health state
    private func edgeColor(for conceptID: UUID) -> Color {
        guard let metrics = engine.nodeMetricsByID[conceptID] else { return Color.gray }
        return healthColor(metrics.healthState)
    }

    /// Check if node is ancestor of selected node
    private func isAncestor(of nodeID: UUID, selectedID: UUID) -> Bool {
        var currentID = selectedID
        while let currentConcept = engine.conceptByID[currentID], let parentID = currentConcept.parentID {
            if parentID == nodeID { return true }
            currentID = parentID
        }
        return false
    }

    /// Check if node is direct child of selected node
    private func isChild(of nodeID: UUID, selectedID: UUID) -> Bool {
        guard let selectedConcept = engine.conceptByID[selectedID] else { return false }
        let children = engine.childrenByConceptID[selectedID] ?? []
        return children.contains(where: { $0.id == nodeID })
    }

    /// Check if node is sibling of selected node
    private func isSibling(_ nodeID: UUID, selectedID: UUID) -> Bool {
        guard let selectedConcept = engine.conceptByID[selectedID],
              let parentID = selectedConcept.parentID,
              let siblings = engine.childrenByConceptID[parentID] else {
            return false
        }
        return siblings.contains(where: { $0.id == nodeID && $0.id != selectedID })
    }

    /// Check if edge is between siblings (used to dim edges)
    private func isSiblingEdge(parentID: UUID, childID: UUID, selectedID: UUID) -> Bool {
        guard let selectedConcept = engine.conceptByID[selectedID],
              let selectedParentID = selectedConcept.parentID else {
            return false
        }
        // Edge between siblings if parent is selected's parent and both nodes are siblings
        return parentID == selectedParentID && isSibling(childID, selectedID: selectedID)
    }

    /// Compute node positions using a simplified top-down layout for selected concept neighborhood
    /// Centers the selected concept horizontally, places ancestors above, children below, siblings side
    ///
    /// The layout groups nodes by "level":
    /// - Level 0: selected concept (centered)
    /// - Level -1: ancestors up to root (stacked above)
    /// - Level 1: children (horizontal layout below)
    /// - Level 0 siblings: siblings arranged horizontally beside selected concept with dimmed style
    private func computeNodePositions(
        size: CGSize,
        concepts: [Concept],
        selectedConceptID: UUID
    ) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]

        // Determine ancestors chain (level -1 to -N)
        var ancestors: [Concept] = []
        var currentID = selectedConceptID
        while let currentConcept = engine.conceptByID[currentID], let parentID = currentConcept.parentID {
            if let parent = engine.conceptByID[parentID] {
                ancestors.append(parent)
                currentID = parentID
            } else {
                break
            }
        }
        ancestors.reverse() // root at top

        // Determine children
        let children = engine.childrenByConceptID[selectedConceptID] ?? []

        // Determine siblings
        var siblings: [Concept] = []
        if let selectedConcept = engine.conceptByID[selectedConceptID], let parentID = selectedConcept.parentID {
            siblings = engine.childrenByConceptID[parentID]?.filter { $0.id != selectedConceptID } ?? []
        }

        // Layout parameters
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Layout selected concept at center
        positions[selectedConceptID] = CGPoint(x: centerX, y: centerY)

        // Layout ancestors vertically above selected concept, stacked with verticalSpacing between centers
        var currentY = centerY - verticalSpacing
        for ancestor in ancestors {
            positions[ancestor.id] = CGPoint(x: centerX, y: currentY)
            currentY -= verticalSpacing
        }

        // Layout children horizontally below selected concept, spaced by horizontalSpacing + node diameter
        let childCount = children.count
        if childCount > 0 {
            // Compute total width needed for children
            let childrenWidths = children.map { nodeDiameter(for: $0.id) }
            let totalChildrenWidth = childrenWidths.reduce(0, +) + horizontalSpacing * CGFloat(childCount - 1)
            // Start X for first child
            var startX = centerX - totalChildrenWidth / 2
            for (index, child) in children.enumerated() {
                let diameter = nodeDiameter(for: child.id)
                let posX = startX + diameter / 2
                let posY = centerY + verticalSpacing
                positions[child.id] = CGPoint(x: posX, y: posY)
                startX += diameter + horizontalSpacing
            }
        }

        // Layout siblings horizontally on the same level as selected concept, but offset left or right with spacing
        let siblingCount = siblings.count
        if siblingCount > 0 {
            // Determine direction for siblings: split evenly left and right
            let half = siblingCount / 2
            // Layout left siblings
            for i in 0..<half {
                let sib = siblings[i]
                let diameter = nodeDiameter(for: sib.id)
                let posX = centerX - horizontalSpacing * CGFloat(half - i) - diameter * CGFloat(half - i)
                let posY = centerY
                positions[sib.id] = CGPoint(x: posX, y: posY)
            }
            // Layout right siblings
            for i in half..<siblingCount {
                let sib = siblings[i]
                let diameter = nodeDiameter(for: sib.id)
                let posX = centerX + horizontalSpacing * CGFloat(i - half + 1) + diameter * CGFloat(i - half)
                let posY = centerY
                positions[sib.id] = CGPoint(x: posX, y: posY)
            }
        }

        return positions
    }

    /// Color helpers for health states
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
