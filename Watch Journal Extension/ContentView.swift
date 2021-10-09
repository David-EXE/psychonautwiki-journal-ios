import SwiftUI

struct ContentView: View {

    @AppStorage(PersistenceController.hasBeenSetupBeforeKey) var hasBeenSetupBefore: Bool = false
    @AppStorage(PersistenceController.needsToUpdateWatchFaceKey) var needsToUpdateWatchFace: Bool = false

    @Environment(\.scenePhase) var scenePhase

    @FetchRequest(
        entity: Experience.entity(),
        sortDescriptors: [ NSSortDescriptor(keyPath: \Experience.creationDate, ascending: false) ]
    ) var experiences: FetchedResults<Experience>
    @FetchRequest(
        entity: SubstancesFile.entity(),
        sortDescriptors: [ NSSortDescriptor(keyPath: \SubstancesFile.creationDate, ascending: false) ]
    ) var storedFile: FetchedResults<SubstancesFile>

    @Environment(\.managedObjectContext) var moc

    @State private var selection = 2

    var body: some View {
        Group {
            if hasBeenSetupBefore {
                TabView(selection: $selection) {
                    SettingsTab()
                        .tag(1)
                    if let firstExperience = experiences.first {
                        IngestionObserverView(experience: firstExperience)
                            .tag(2)
                        IngestionsTab(experience: firstExperience)
                            .tag(3)
                    } else {
                        WatchFaceView(
                            ingestions: [],
                            clockHandStyle: .hourAndMinute,
                            timeStyle: .currentTime
                        )
                        .tag(2)
                    }
                }
                .onChange(
                    of: scenePhase,
                    perform: { newPhase in
                        if newPhase == .active {
                            maybeFetchAgain()
                        } else if newPhase == .background {
                            if needsToUpdateWatchFace {
                                needsToUpdateWatchFace.toggle()
                                ComplicationUpdater.updateActiveComplications()
                            }
                        }
                    }
                )
                .onAppear(perform: maybeFetchAgain)
            } else {
                WatchWelcome()
            }
        }
    }

    func maybeFetchAgain() {
        if shouldFetchAgain {
            if let file = storedFile.first {
                PsychonautWikiAPIController.fetchAndSaveNewSubstancesAndDeleteOldOnes(
                    oldFile: file
                )
            }
        }
    }

    var shouldFetchAgain: Bool {
        guard hasBeenSetupBefore else {return false}
        let twoWeeks: TimeInterval = 60 * 60 * 24 * 14
        guard let file = storedFile.first else {return true}
        guard file.creationDateUnwrapped.distance(to: Date()) > twoWeeks else {
            return false
        }
        return true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(Connectivity())
            .accentColor(Color.blue)
    }
}
