import SwiftUI

struct ExperiencesList: View {

    @ObservedObject var viewModel: JournalScreen.ViewModel
    @Environment(\.isSearching) private var isSearching
    @Binding var isShowingCurrentExperience: Bool

    var body: some View {
        ZStack {
            List {
                if let first = viewModel.experiences.first,
                   let lastIngestionTime = first.sortedIngestionsUnwrapped.last?.time,
                   Date().timeIntervalSinceReferenceDate - lastIngestionTime.timeIntervalSinceReferenceDate < 12*60*60 {
                    Section("Current") {
                        CurrentExperienceRow(
                            experience: first,
                            isTimeRelative: viewModel.isTimeRelative,
                            isNavigated: $isShowingCurrentExperience
                        )
                    }
                    let rest = viewModel.experiences.suffix(viewModel.experiences.count-1)
                    Section("Previous") {
                        ForEach(rest) { exp in
                            ExperienceRow(experience: exp, isTimeRelative: viewModel.isTimeRelative)
                        }
                    }
                } else {
                    ForEach(viewModel.experiences) { exp in
                        ExperienceRow(experience: exp, isTimeRelative: viewModel.isTimeRelative)
                    }
                }
            }
            if isSearching && viewModel.experiences.isEmpty {
                Text("No Results")
                    .foregroundColor(.secondary)
            } else if viewModel.isFavoriteFilterEnabled && viewModel.experiences.isEmpty {
                Text("No Favorites")
                    .foregroundColor(.secondary)
            }
        }
    }
}
