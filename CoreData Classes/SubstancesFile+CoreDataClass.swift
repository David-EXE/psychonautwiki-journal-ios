import Foundation
import CoreData

public class SubstancesFile: NSManagedObject, Decodable {

    enum CodingKeys: String, CodingKey {
        case substances
    }

    enum DecodingError: Error {
        case notEnoughSubstancesParsed
    }

    private var substancesForParsing: [Substance] = []
    private var contextForParsing: NSManagedObjectContext!
    private var unresolvedsForParsing = Set<UnresolvedInteraction>()

    required convenience public init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[CodingUserInfoKey.managedObjectContext] as? NSManagedObjectContext else {
            fatalError("Missing managed object context")
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let throwableSubstances = try container.decode(
            [Throwable<Substance>].self,
            forKey: .substances)
        let substances = throwableSubstances.compactMap { try? $0.result.get() }
        if substances.count < 50 {
            throw DecodingError.notEnoughSubstancesParsed
        }
        self.init(context: context)
        self.substancesForParsing = substances
        self.contextForParsing = context
        goThroughSubstancesOneByOneAndCreateObjectsAndRelationships()
    }

    private func goThroughSubstancesOneByOneAndCreateObjectsAndRelationships() {
        createClasses()
        createEffectsAndAddThemToSubstances()
        // The following 2 methods must be called after the classes have been constructed
        createCrossTolerances()
        createInteractions()
    }

    private func createClasses() {
        var psychoactives = Set<PsychoactiveClass>()
        var chemicals = Set<ChemicalClass>()
        for substance in substancesForParsing {
            for psychoactiveName in substance.decodedClasses?.psychoactive ?? [] {
                let match = psychoactives.first { cat in
                    cat.nameUnwrapped.lowercased() == psychoactiveName.lowercased()
                }
                if let matchUnwrapped = match {
                    matchUnwrapped.addToSubstances(substance)
                } else {
                    let pClass = PsychoactiveClass(context: contextForParsing)
                    pClass.name = psychoactiveName
                    pClass.addToSubstances(substance)
                    psychoactives.insert(pClass)
                }
            }
            for chemicalName in substance.decodedClasses?.chemical ?? [] {
                let match = chemicals.first { cat in
                    cat.nameUnwrapped.lowercased() == chemicalName.lowercased()
                }
                if let matchUnwrapped = match {
                    matchUnwrapped.addToSubstances(substance)
                } else {
                    let cClass = ChemicalClass(context: contextForParsing)
                    cClass.name = chemicalName
                    cClass.addToSubstances(substance)
                    chemicals.insert(cClass)
                }
            }
        }
        self.psychoactiveClasses = psychoactives as NSSet
        self.chemicalClasses = chemicals as NSSet
    }

    private func createEffectsAndAddThemToSubstances() {
        var effects = Set<Effect>()
        for substance in substancesForParsing {
            for decodedEff in substance.decodedEffects {
                let match = effects.first { eff in
                    eff.nameUnwrapped.hasEqualMeaning(other: decodedEff.name)
                }
                if let matchUnwrapped = match {
                    substance.addToEffects(matchUnwrapped)
                } else {
                    let newEffect = Effect(context: contextForParsing)
                    newEffect.name = decodedEff.name.capitalized
                    newEffect.url = decodedEff.url
                    effects.insert(newEffect)
                    substance.addToEffects(newEffect)
                }
            }
        }
    }

    private func createCrossTolerances() {
        for substance in substancesForParsing {
            for toleranceName in substance.decodedCrossTolerances {
                // check if psychoactive
                let matchPsycho = self.psychoactiveClassesUnwrapped.first { psy in
                    psy.nameUnwrapped.hasEqualMeaning(other: toleranceName)
                }
                if let matchUnwrapped = matchPsycho {
                    substance.addToCrossTolerancePsychoactives(matchUnwrapped)
                    continue
                }
                // check if chemical
                let matchChemical = self.chemicalClassesUnwrapped.first { chem in
                    chem.nameUnwrapped.hasEqualMeaning(other: toleranceName)
                }
                if let matchUnwrapped = matchChemical {
                    substance.addToCrossToleranceChemicals(matchUnwrapped)
                    continue
                }
                // check if substance
                let matchSubstance = substancesForParsing.first { sub in
                    sub.nameUnwrapped.hasEqualMeaning(other: toleranceName)
                }
                if let matchUnwrapped = matchSubstance {
                    substance.addToCrossToleranceSubstances(matchUnwrapped)
                    continue
                }
            }
        }
    }

    private func createInteractions() {
        unresolvedsForParsing = Set<UnresolvedInteraction>()
        for substance in substancesForParsing {
            let uncertainNames = substance.decodedUncertain.map { $0.name }
            addToPsychoactivesChemicalsSubstancesOrUnresolved(
                addToSub: AddToUncertainSubstance(substance: substance),
                interactionNames: uncertainNames
            )
            let unsafeNames = substance.decodedUnsafe.map { $0.name }
            addToPsychoactivesChemicalsSubstancesOrUnresolved(
                addToSub: AddToUnsafeSubstance(substance: substance),
                interactionNames: unsafeNames
            )
            let dangerousNames = substance.decodedDangerous.map { $0.name }
            addToPsychoactivesChemicalsSubstancesOrUnresolved(
                addToSub: AddToDangerousSubstance(substance: substance),
                interactionNames: dangerousNames
            )
        }
    }

    private enum InteractionType {
        case uncertain, unsafe, dangerous
    }

    private func addToPsychoactivesChemicalsSubstancesOrUnresolved(
        addToSub: AddToSubstance,
        interactionNames: [String]
    ) {
        for interactionName in interactionNames {
            // check if psychoactive
            let matchPsycho = self.psychoactiveClassesUnwrapped.first { psy in
                psy.nameUnwrapped.hasEqualMeaning(other: interactionName)
            }
            if let psyUnwrap = matchPsycho {
                addToSub.addToPsychoactives(psychocative: psyUnwrap)
                continue
            }
            // check if chemical
            let matchChemical = self.chemicalClassesUnwrapped.first { chem in
                chem.nameUnwrapped.hasEqualMeaning(other: interactionName)
            }
            if let chemUnwrap = matchChemical {
                addToSub.addToChemicals(chemical: chemUnwrap)
                continue
            }
            // check if substance
            let matchSub = self.substancesForParsing.first { sub in
                sub.nameUnwrapped.hasEqualMeaning(other: interactionName)
            }
            if let subUnwrap = matchSub {
                addToSub.addToSubstances(substance: subUnwrap)
                continue
            }
            // if still here there was no match
            // check if there are already unresolved interactions
            let unrMatch = unresolvedsForParsing.first { unr in
                unr.nameUnwrapped.hasEqualMeaning(other: interactionName)
            }
            if let unrUnwrap = unrMatch {
                addToSub.addToUnresolved(unresolved: unrUnwrap)
            } else {
                let newUnresolved = UnresolvedInteraction(context: contextForParsing)
                newUnresolved.name = interactionName.capitalized
                addToSub.addToUnresolved(unresolved: newUnresolved)
                unresolvedsForParsing.insert(newUnresolved)
            }
        }
    }

    static let namesOfUncontrolledSubstances = [
        "Caffeine",
        "Myristicin",
        "Choline bitartrate",
        "Citicoline"
    ]
}

private protocol AddToSubstance {
    func addToChemicals(chemical: ChemicalClass)
    func addToPsychoactives(psychocative: PsychoactiveClass)
    func addToSubstances(substance: Substance)
    func addToUnresolved(unresolved: UnresolvedInteraction)
}

private struct AddToUncertainSubstance: AddToSubstance {

    let substance: Substance

    func addToChemicals(chemical: ChemicalClass) {
        substance.addToUncertainChemicals(chemical)
    }

    func addToPsychoactives(psychocative: PsychoactiveClass) {
        substance.addToUncertainPsychoactives(psychocative)
    }

    func addToSubstances(substance: Substance) {
        substance.addToUncertainSubstances(substance)
    }

    func addToUnresolved(unresolved: UnresolvedInteraction) {
        substance.addToUncertainUnresolveds(unresolved)
    }
}

private struct AddToUnsafeSubstance: AddToSubstance {

    let substance: Substance

    func addToChemicals(chemical: ChemicalClass) {
        substance.addToUnsafeChemicals(chemical)
    }

    func addToPsychoactives(psychocative: PsychoactiveClass) {
        substance.addToUnsafePsychoactives(psychocative)
    }

    func addToSubstances(substance: Substance) {
        substance.addToUnsafeSubstances(substance)
    }

    func addToUnresolved(unresolved: UnresolvedInteraction) {
        substance.addToUnsafeUnresolveds(unresolved)
    }
}

private struct AddToDangerousSubstance: AddToSubstance {

    let substance: Substance

    func addToChemicals(chemical: ChemicalClass) {
        substance.addToDangerousChemicals(chemical)
    }

    func addToPsychoactives(psychocative: PsychoactiveClass) {
        substance.addToDangerousPsychoactives(psychocative)
    }

    func addToSubstances(substance: Substance) {
        substance.addToDangerousSubstances(substance)
    }

    func addToUnresolved(unresolved: UnresolvedInteraction) {
        substance.addToDangerousUnresolveds(unresolved)
    }
}
