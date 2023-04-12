// Copyright (c) 2022. Isaak Hanimann.
// This file is part of PsychonautWiki Journal.
//
// PsychonautWiki Journal is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public Licence as published by
// the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// PsychonautWiki Journal is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with PsychonautWiki Journal. If not, see https://www.gnu.org/licenses/gpl-3.0.en.html.

import Foundation

struct InteractionChecker {

    static let additionalInteractionsToCheck = [
        "Alcohol",
        "Caffeine",
        "Cannabis",
        "Grapefruit",
        "Hormonal birth control",
        "Nicotine"
    ]

    static func getInteractionBetween(aName: String, bName: String) -> Interaction? {
        if let interactionType = getInteractionTypeBetween(aName: aName, bName: bName) {
            return Interaction(
                aName: aName,
                bName: bName,
                interactionType: interactionType
            )
        } else {
            return nil
        }
    }

    static func getInteractionTypeBetween(aName: String, bName: String) -> InteractionType? {
        let interactionFromAToB = getInteraction(fromName: aName, toName: bName)
        let interactionFromBToA = getInteraction(fromName: bName, toName: aName)
        if let interactionFromAToB, let interactionFromBToA {
            let isAtoB = interactionFromAToB.dangerCount >= interactionFromBToA.dangerCount
            let interactionType = isAtoB ? interactionFromAToB : interactionFromBToA
            return interactionType
        } else if let interactionFromAToB {
            return interactionFromAToB
        } else if let interactionFromBToA {
            return interactionFromBToA
        } else {
            return nil
        }
    }

    private static func getInteraction(fromName: String, toName: String) -> InteractionType? {
        guard let substance = SubstanceRepo.shared.getSubstance(name: fromName) else {return nil}
        guard let interactions = substance.interactions else {return nil}
        if let toSubstance = SubstanceRepo.shared.getSubstance(name: toName) {
            if let directInteraction = getDirectInteraction(interactions: interactions, substanceName: toName) {
                return directInteraction
            }
            if let wildCardInteraction = getWildCardInteraction(interactions: interactions, substanceName: toName) {
                return wildCardInteraction
            }
            if let classInteraction = getClassInteraction(interactions: interactions, substance: toSubstance) {
                return classInteraction
            }
            return nil
        } else {
            if (interactions.dangerous.contains(toName)) {
                return InteractionType.dangerous
            } else if (interactions.unsafe.contains(toName)) {
                return InteractionType.unsafe
            } else if (interactions.uncertain.contains(toName)) {
                return InteractionType.uncertain
            } else {
                return nil
            }
        }
    }

    private static func getDirectInteraction(
        interactions: Interactions,
        substanceName: String
    ) -> InteractionType? {
        if isDirectMatch(interactions: interactions.dangerous, substanceName: substanceName) {
            return .dangerous
        } else if isDirectMatch(interactions: interactions.unsafe, substanceName: substanceName) {
            return .unsafe
        } else if isDirectMatch(interactions: interactions.uncertain, substanceName: substanceName) {
            return .uncertain
        } else {
            return nil
        }
    }

    private static func isDirectMatch(interactions: [String], substanceName: String) -> Bool {
        let extendedInteractions = replaceSubstitutedAmphetaminesAndSerotoninReleasers(interactions: interactions)
        return extendedInteractions.contains(substanceName)
    }

    private static func getClassInteraction(interactions: Interactions, substance: Substance) -> InteractionType? {
        let categories = substance.categories
        if isClassMatch(interactions: interactions.dangerous, categories: categories) {
            return .dangerous
        } else if isClassMatch(interactions: interactions.unsafe, categories: categories) {
            return .unsafe
        } else if isClassMatch(interactions: interactions.uncertain, categories: categories) {
            return .uncertain
        } else {
            return nil
        }
    }

    private static func isClassMatch(
        interactions: [String],
        categories: [String]
    ) -> Bool {
        let extendedInteractions = replaceSubstitutedAmphetaminesAndSerotoninReleasers(interactions: interactions)
        let isSubstanceInDangerClass =
        categories.contains { categoryName in
            extendedInteractions.contains { interactionName in
                interactionName.localizedCaseInsensitiveContains(categoryName)
            }
        }
        return isSubstanceInDangerClass
    }

    private static func getWildCardInteraction(interactions: Interactions, substanceName: String) -> InteractionType? {
        if isWildCardMatchWithAnyInteraction(interactions: interactions.dangerous, substanceName: substanceName) {
            return .dangerous
        } else if isWildCardMatchWithAnyInteraction(interactions: interactions.unsafe, substanceName: substanceName) {
            return .unsafe
        } else if isWildCardMatchWithAnyInteraction(interactions: interactions.uncertain, substanceName: substanceName) {
            return .uncertain
        } else {
            return nil
        }
    }

    private static func isWildCardMatchWithAnyInteraction(
        interactions: [String],
        substanceName: String
    ) -> Bool {
        let extendedInteractions = replaceSubstitutedAmphetaminesAndSerotoninReleasers(interactions: interactions)
        return extendedInteractions.contains { interaction in
            hasXAndMatches(wordWithX: interaction, matchWith: substanceName)
        }
    }

    static func hasXAndMatches(wordWithX: String, matchWith unchangedWord: String) -> Bool {
        guard wordWithX.contains("x") else {return false}
        let modifiedPattern = "^" + wordWithX.replacingOccurrences(of: "x", with: "[\\S]*") + "$"
        guard let regex = try? NSRegularExpression(pattern: modifiedPattern, options: .caseInsensitive) else {return false}
        let range = NSRange(location: 0, length: unchangedWord.utf16.count)
        return regex.firstMatch(in: unchangedWord, options: [], range: range) != nil
    }

    private static func replaceSubstitutedAmphetaminesAndSerotoninReleasers(interactions: [String]) -> [String] {
        interactions.flatMap { name in
            switch (name) {
            case "Substituted amphetamines":
                return substitutedAmphetamines
            case "Serotonin releasers":
                return serotoninReleasers
            default:
                return [name]
            }
        }.uniqued()
    }

    private static let serotoninReleasers = [
        "MDMA",
        "MDA",
        "Mephedrone"
    ]

    private static let substitutedAmphetamines = [
        "Amphetamine",
        "Methamphetamine",
        "Ethylamphetamine",
        "Propylamphetamine",
        "Isopropylamphetamine",
        "Bromo-DragonFLY",
        "Lisdexamfetamine",
        "Clobenzorex",
        "Dimethylamphetamine",
        "Selegiline",
        "Benzphetamine",
        "Ortetamine",
        "3-Methylamphetamine",
        "4-Methylamphetamine",
        "4-MMA",
        "Xylopropamine",
        "ß-methylamphetamine",
        "3-phenylmethamphetamine",
        "2-FA",
        "2-FMA",
        "2-FEA",
        "3-FA",
        "3-FMA",
        "3-FEA",
        "Fenfluramine",
        "Norfenfluramine",
        "4-FA",
        "4-FMA",
        "4-CA",
        "4-BA",
        "4-IA",
        "DCA",
        "4-HA",
        "4-HMA",
        "3,4-DHA",
        "OMA",
        "3-MA",
        "MMMA",
        "MMA",
        "PMA",
        "PMMA",
        "PMEA",
        "4-ETA",
        "TMA-2",
        "TMA-6",
        "4-MTA",
        "5-API",
        "Cathine",
        "Phenmetrazine",
        "3-FPM",
        "Prolintane"
    ]

}

struct Interaction {
    let aName: String
    let bName: String
    let interactionType: InteractionType
}

extension Interaction: Hashable, Identifiable {
    var id: Int {
        hashValue
    }

    func hash(into hasher: inout Hasher) {
        var hash: String = interactionType.hashValue.formatted()
        if aName < bName {
            hash = hash + aName + bName
        } else {
            hash = hash + bName + aName
        }
        hasher.combine(hash)
    }
}
