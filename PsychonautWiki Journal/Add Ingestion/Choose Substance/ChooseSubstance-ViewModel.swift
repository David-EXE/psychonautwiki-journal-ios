//
//  ChooseSubstance-ViewModel.swift
//  PsychonautWiki Journal
//
//  Created by Isaak Hanimann on 14.12.22.
//

import Foundation
import CoreData

extension ChooseSubstanceScreen {
    @MainActor
    class ViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
        
        @Published var searchText = ""
        @Published var isShowingOpenEyeToast = false
        @Published var filteredSuggestions: [Suggestion] =  []
        @Published var filteredSubstances: [Substance] = []
        @Published var filteredCustomSubstances: [CustomSubstanceModel] = []
        @Published var customSubstanceModels: [CustomSubstanceModel]
        @Published var isEyeOpen = false {
            didSet {
                UserDefaults.standard.set(isEyeOpen, forKey: PersistenceController.isEyeOpenKey2)
            }
        }

        private let allPossibleSuggestions: [Suggestion]
        private let fetchController: NSFetchedResultsController<CustomSubstance>?

        override init() {
            self.isEyeOpen = UserDefaults.standard.bool(forKey: PersistenceController.isEyeOpenKey2)
            let ingestionFetchRequest = Ingestion.fetchRequest()
            ingestionFetchRequest.sortDescriptors = [ NSSortDescriptor(keyPath: \Ingestion.time, ascending: false) ]
            ingestionFetchRequest.fetchLimit = 100
            let sortedIngestions = (try? PersistenceController.shared.viewContext.fetch(ingestionFetchRequest)) ?? []
            self.allPossibleSuggestions = SuggestionsCreator(sortedIngestions: sortedIngestions).suggestions
            let request = CustomSubstance.fetchRequest()
            request.sortDescriptors = []
            fetchController = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: PersistenceController.shared.viewContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            try? fetchController?.performFetch()
            let customSubstances = fetchController?.fetchedObjects ?? []
            self.customSubstanceModels = customSubstances.map { cust in
                CustomSubstanceModel(name: cust.nameUnwrapped, units: cust.unitsUnwrapped)
            }
            super.init()
            fetchController?.delegate = self
            $searchText
                .combineLatest($isEyeOpen) { search, isEyeOpen in
                    let allSubstances = SubstanceRepo.shared.substances
                    let originalFiltered = SearchViewModel.getFilteredSubstancesSorted(substances: allSubstances, searchText: search)
                    if isEyeOpen {
                        return originalFiltered
                    } else {
                        let isContainingIllegal = originalFiltered.contains { sub in
                            !namesOfLegalSubstances.contains(sub.name)
                        }
                        if search.count > 4 && isContainingIllegal {
                            self.openEyeAndAnimate()
                            return originalFiltered
                        } else {
                            return originalFiltered.filter { sub in
                                namesOfLegalSubstances.contains(sub.name)
                            }
                        }
                    }
                }.assign(to: &$filteredSubstances)
            $searchText
                .combineLatest($customSubstanceModels) { search, customs in
                    if search.isEmpty {
                        return customs
                    } else {
                        let searchLowerCased = search.lowercased()
                        return customs.filter { custModel in
                            custModel.name.lowercased().contains(searchLowerCased)
                        }
                    }
                }.assign(to: &$filteredCustomSubstances)
            $filteredSubstances.combineLatest($filteredCustomSubstances) { filteredSubstances, filteredCustom in
                self.allPossibleSuggestions.filter { suggestion in
                    filteredSubstances.contains { substance in
                        substance.name == suggestion.substanceName
                    } || filteredCustom.contains { custom in
                        custom.name == suggestion.substanceName
                    }
                }
            }.assign(to: &$filteredSuggestions)
        }

        private func openEyeAndAnimate() {
            isShowingOpenEyeToast = true
            isEyeOpen = true
        }

        nonisolated public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            Task {
                await MainActor.run(body: {
                    guard let custs = controller.fetchedObjects as? [CustomSubstance] else {return}
                    self.customSubstanceModels = custs.map { cust in
                        CustomSubstanceModel(name: cust.nameUnwrapped, units: cust.unitsUnwrapped)
                    }
                })
            }
        }
    }
}

