import Foundation
import Combine
import CoreData

class SearchViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {

    @Published var filteredSubstances: [Substance] = SubstanceRepo.shared.substances

    @Published var searchText = ""

    @Published var selectedCategories: [String] = []

    static let custom = "custom"

    let allCategories = [custom] + SubstanceRepo.shared.categories.map { cat in
        cat.name
    }

    func toggleCategory(category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.removeAll { cat in
                cat == category
            }
        } else {
            selectedCategories.append(category)
        }
    }

    func clearCategories() {
        selectedCategories.removeAll()
    }

    @Published private var customSubstances: [CustomSubstance] = []
    private let fetchController: NSFetchedResultsController<CustomSubstance>!

    var customFilteredWithCategories: [CustomSubstance] {
        if selectedCategories.isEmpty {
            return customSubstances
        } else if selectedCategories.contains(SearchViewModel.custom) {
            return customSubstances
        } else {
            return []
        }
    }

    var filteredCustomSubstances: [CustomSubstance] {
        let lowerCaseSearchText = searchText.lowercased()
        if searchText.count < 3 {
            return customFilteredWithCategories.filter { cust in
                cust.nameUnwrapped.lowercased().hasPrefix(lowerCaseSearchText)
            }
        } else {
            return customFilteredWithCategories.filter { cust in
                cust.nameUnwrapped.lowercased().contains(lowerCaseSearchText)
            }
        }
    }

    override init() {
        let fetchRequest = CustomSubstance.fetchRequest()
        fetchRequest.sortDescriptors = [ NSSortDescriptor(keyPath: \CustomSubstance.name, ascending: true) ]
        fetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: PersistenceController.shared.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        super.init()
        fetchController.delegate = self
        do {
            try fetchController.performFetch()
            self.customSubstances = fetchController?.fetchedObjects ?? []
        } catch {
            NSLog("Error: could not fetch CustomSubstances")
        }
        $searchText
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .userInitiated))
            .combineLatest($selectedCategories) { search, cats in
                let substancesFilteredWithCategoriesOnly = SubstanceRepo.shared.substances.filter { sub in
                    cats.allSatisfy { selected in
                        sub.categories.contains(selected)
                    }
                }
                let prefixResult = SearchViewModel.getSortedPrefixResults(substances: substancesFilteredWithCategoriesOnly, searchText: search)
                if search.count < 3 {
                    return prefixResult
                } else {
                    if prefixResult.count < 3 {
                        let containsResult = SearchViewModel.getSortedContainsResults(substances: substancesFilteredWithCategoriesOnly, searchText: search)
                        return (prefixResult + containsResult).uniqued { sub in
                            sub.name
                        }
                    } else {
                        return prefixResult
                    }
                }
            }.receive(on: DispatchQueue.main).assign(to: &$filteredSubstances)
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let customs = controller.fetchedObjects as? [CustomSubstance] else {return}
        self.customSubstances = customs
    }

    private static func getSortedPrefixResults(substances: [Substance], searchText: String) -> [Substance] {
        let lowerCaseSearchText = searchText.lowercased()
        let mainPrefixMatches =  substances.filter { sub in
            sub.name.lowercased().hasPrefix(lowerCaseSearchText)
        }
        if mainPrefixMatches.isEmpty {
            return substances.filter { sub in
                let names = sub.commonNames + [sub.name]
                return names.contains { name in
                    name.lowercased().hasPrefix(lowerCaseSearchText)
                }
            }
        } else {
            return mainPrefixMatches
        }
    }

    private static func getSortedContainsResults(substances: [Substance], searchText: String) -> [Substance] {
        let lowerCaseSearchText = searchText.lowercased()
        let mainPrefixMatches =  substances.filter { sub in
            sub.name.lowercased().contains(lowerCaseSearchText)
        }
        if mainPrefixMatches.isEmpty {
            return substances.filter { sub in
                let names = sub.commonNames + [sub.name]
                return names.contains { name in
                    name.lowercased().contains(lowerCaseSearchText)
                }
            }
        } else {
            return mainPrefixMatches
        }
    }


}
