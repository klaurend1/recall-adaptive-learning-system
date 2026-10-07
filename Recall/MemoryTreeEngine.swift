import Foundation

struct MemoryTreeEngine {
    static func build(concepts: [Concept], cards: [StudyCard], reviews: [ReviewRecord]) -> (roots: [ConceptNode], flat: [UUID: ConceptNode], parent: [UUID: UUID?]) {
        #if DEBUG
        print("ENGINE INPUT cards:", cards.count)
        print("ENGINE INPUT reviews:", reviews.count)
        print("ENGINE INPUT concepts:", concepts.count)
        #endif
        
        // Lookup maps
        let conceptByID: [UUID: Concept] = Dictionary(uniqueKeysWithValues: concepts.map { ($0.id, $0) })
        let childrenMap: [UUID?: [Concept]] = {
            var map: [UUID?: [Concept]] = [:]
            for c in concepts { map[c.parentID, default: []].append(c) }
            return map
        }()
        let cardsByConcept: [UUID: [StudyCard]] = {
            var map: [UUID: [StudyCard]] = [:]
            for card in cards {
                for cid in card.conceptIDs { map[cid, default: []].append(card) }
            }
            return map
        }()
        let reviewsByCardID: [UUID: [ReviewRecord]] = {
            var map: [UUID: [ReviewRecord]] = [:]
            for r in reviews { map[r.cardID, default: []].append(r) }
            return map
        }()
        
        #if DEBUG
        for card in cards {
            print("CARD:", card.question)
            print("conceptIDs:", card.conceptIDs)
        }
        #endif

        var flat: [UUID: ConceptNode] = [:]
        var parentMap: [UUID: UUID?] = [:]

        // DFS that returns aggregated cards for subtree
        func dfs(_ concept: Concept) -> ConceptNode {
            let children = childrenMap[concept.id] ?? []
            var childNodes: [ConceptNode] = []
            for child in children {
                parentMap[child.id] = concept.id
                let n = dfs(child)
                childNodes.append(n)
            }

            // Aggregate unique cards in subtree
            var aggregatedIDs = Set(cardsByConcept[concept.id]?.map { $0.id } ?? [])
            for ch in childNodes { aggregatedIDs.formUnion(ch.cards.map { $0.id }) }
            // Rebuild aggregated cards array preserving original order where possible
            var aggregatedCards: [StudyCard] = []
            aggregatedCards.reserveCapacity(aggregatedIDs.count)
            // Prefer direct cards order, then children order
            if let direct = cardsByConcept[concept.id] {
                for c in direct where aggregatedIDs.contains(c.id) {
                    aggregatedCards.append(c)
                    aggregatedIDs.remove(c.id)
                }
            }
            for ch in childNodes {
                for c in ch.cards where aggregatedIDs.contains(c.id) {
                    aggregatedCards.append(c)
                    aggregatedIDs.remove(c.id)
                }
            }

            // Compute mastery from reviews of aggregated cards
            var total = 0
            var success = 0
            for card in aggregatedCards {
                if let rs = reviewsByCardID[card.id] {
                    total += rs.count
                    success += rs.filter { $0.grade == .good || $0.grade == .easy }.count
                }
            }
            let mastery = (total > 0) ? Double(success) / Double(total) : nil

            let node = ConceptNode(
                id: concept.id,
                name: concept.name,
                children: childNodes,
                masteryPercent: mastery ?? -1.0,
                cardCount: aggregatedCards.count,
                cards: aggregatedCards
            )
            flat[concept.id] = node
            return node
        }

        // Roots are concepts with nil parent or missing parent in dataset
        let allIDs = Set(concepts.map { $0.id })
        let rootsConcepts = concepts.filter { $0.parentID == nil || ( $0.parentID != nil && allIDs.contains($0.parentID!) == false) }
        var roots: [ConceptNode] = []
        for root in rootsConcepts {
            parentMap[root.id] = nil
            roots.append(dfs(root))
        }
        
        #if DEBUG
        print("ENGINE ROOTS:", roots.count)
        for r in roots {
            print("ENGINE ROOT:", r.name, "cardCount:", r.cardCount, "cards:", r.cards.count, "mastery:", r.masteryPercent)
        }
        #endif
        
        return (roots, flat, parentMap)
    }
}
