import Foundation

enum MockData {
    static let mcatID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let biologyID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let biochemistryID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let genChemID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let orgChemID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let physicsID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let psychSocID = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    static let carsID = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
    static let cellBiologyID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    static let geneticsID = UUID(uuidString: "00000000-0000-0000-0000-00000000000a")!
    static let cellSignalingID = UUID(uuidString: "00000000-0000-0000-0000-00000000000b")!
    static let aminoAcidsID = UUID(uuidString: "00000000-0000-0000-0000-00000000000c")!
    static let enzymeKineticsID = UUID(uuidString: "00000000-0000-0000-0000-00000000000d")!
    static let metabolismID = UUID(uuidString: "00000000-0000-0000-0000-00000000000e")!
    static let fluidsID = UUID(uuidString: "00000000-0000-0000-0000-00000000000f")!
    static let circuitsID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let opticsID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

    static let concepts: [Concept] = [
        // Root
        Concept(id: mcatID, name: "MCAT", description: nil, parentID: nil),

        // Primary Sections
        Concept(id: biologyID, name: "Biology", description: nil, parentID: mcatID),
        Concept(id: biochemistryID, name: "Biochemistry", description: nil, parentID: mcatID),
        Concept(id: genChemID, name: "General Chemistry", description: nil, parentID: mcatID),
        Concept(id: orgChemID, name: "Organic Chemistry", description: nil, parentID: mcatID),
        Concept(id: physicsID, name: "Physics", description: nil, parentID: mcatID),
        Concept(id: psychSocID, name: "Psychology / Sociology", description: nil, parentID: mcatID),
        Concept(id: carsID, name: "Critical Analysis and Reasoning Skills (CARS)", description: nil, parentID: mcatID),

        // Biology Children
        Concept(id: cellBiologyID, name: "Cell Biology", description: nil, parentID: biologyID),
        Concept(id: geneticsID, name: "Genetics", description: nil, parentID: biologyID),
        Concept(id: cellSignalingID, name: "Cell Signaling", description: nil, parentID: biologyID),

        // Biochemistry Children
        Concept(id: aminoAcidsID, name: "Amino Acids", description: nil, parentID: biochemistryID),
        Concept(id: enzymeKineticsID, name: "Enzyme Kinetics", description: nil, parentID: biochemistryID),
        Concept(id: metabolismID, name: "Metabolism", description: nil, parentID: biochemistryID),

        // Physics Children
        Concept(id: fluidsID, name: "Fluids", description: nil, parentID: physicsID),
        Concept(id: circuitsID, name: "Circuits", description: nil, parentID: physicsID),
        Concept(id: opticsID, name: "Optics", description: nil, parentID: physicsID)
    ]

    static let cards: [StudyCard] = {
        let samplePairs: [(question: String, answer: String, conceptID: UUID)] = [
            ("What is the pH of a neutral solution at 25°C?", "7", genChemID),
            ("Define enzyme", "A biological catalyst that speeds up reactions", enzymeKineticsID),
            ("What organelle is the powerhouse of the cell?", "Mitochondrion", cellBiologyID),
            ("What is Newton's second law?", "F = m·a", physicsID),
            ("What is the function of the liver?", "Metabolism and detoxification", metabolismID),
            ("What is Mendel's law of segregation?", "Alleles separate during gamete formation", geneticsID),
            ("Define isomer", "Compounds with same formula, different arrangement", orgChemID),
            ("What is Le Châtelier's principle?", "System shifts to counteract changes", genChemID),
            ("What is a vector quantity?", "Has magnitude and direction", physicsID),
            ("Define action potential", "Rapid depolarization and repolarization of membrane", cellBiologyID),
            ("What is homeostasis?", "Maintenance of internal stability", cellBiologyID),
            ("What is a peptide bond?", "Amide bond between amino acids", aminoAcidsID),
            ("Define oxidation", "Loss of electrons", genChemID),
            ("Define reduction", "Gain of electrons", genChemID),
            ("What is the role of the ribosome?", "Protein synthesis", cellBiologyID),
            ("What is a catalyst?", "Lowers activation energy", aminoAcidsID),
            ("Define allele", "Variant form of a gene", geneticsID),
            ("What is torque?", "r × F causing rotation", physicsID),
            ("Define osmosis", "Diffusion of water across a membrane", cellBiologyID),
            ("What is the myelin sheath?", "Insulating layer around axons", cellBiologyID)
        ]

        return samplePairs.map { StudyCard(question: $0.question, answer: $0.answer, conceptIDs: [$0.conceptID]) }
    }()
}

