import SwiftUI

struct SettingsTab: View {

    @Environment(\.managedObjectContext) var moc
    @EnvironmentObject var connectivity: Connectivity

    @FetchRequest(
        entity: SubstancesFile.entity(),
        sortDescriptors: [ NSSortDescriptor(keyPath: \SubstancesFile.creationDate, ascending: false) ]
    ) var storedFile: FetchedResults<SubstancesFile>

    @AppStorage(PersistenceController.isEyeOpenKey) var isEyeOpen: Bool = false

    @State private var isShowingErrorAlert = false
    @State private var alertMessage = ""
    @State private var isFetching = false

    var body: some View {
        NavigationView {
            List {

                Section(
                    header: Text("Last Fetch"),
                    footer: Text("Source: PsychonautWiki").font(.system(size: 11))
                ) {
                    if isFetching {
                        Text("Fetching...")
                    } else {
                        Button(action: fetchNewSubstances, label: {
                            Label(
                                storedFile.first?.creationDateUnwrapped.asDateAndTime ?? "No Substances",
                                systemImage: "arrow.clockwise"
                            )
                        })
                    }
                }
                .alert(isPresented: $isShowingErrorAlert) {
                    Alert(
                        title: Text("Fetch Failed"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("Ok"))
                    )
                }

                if let file = storedFile.first {
                    if isEyeOpen {
                        Section(header: Text("Choose Interactions")) {
                            NavigationLink(
                                destination: ChooseInteractionsView(file: file),
                                label: {
                                    Label(
                                        "Interactions",
                                        systemImage: "burst.fill"
                                    )
                                }
                            )
                        }

                        Section(header: Text("Choose Favorites")) {
                            NavigationLink(
                                destination: ChooseFavoritesView(file: file),
                                label: {
                                    Label("Favorites", systemImage: "star.fill")
                                }
                            )
                        }
                    }
                    Section(
                        footer: HStack {
                            Spacer()
                            (isEyeOpen ? Image("Eye Open") : Image("Eye Closed"))
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.secondary)
                                .frame(width: 30, height: 30, alignment: .center)
                                .onTapGesture(count: 3, perform: toggleEye)
                            Spacer()
                        }
                    ) { }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func toggleEye() {
        isEyeOpen.toggle()
        PersistenceController.shared.toggleEye(to: isEyeOpen, modifyFile: storedFile.first!)
        connectivity.sendEyeState(isEyeOpen: isEyeOpen)
    }

    private func fetchNewSubstances() {
        isFetching = true
        performPsychonautWikiAPIRequest { result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    self.alertMessage = "Request to PsychonautWiki API failed."
                    self.isShowingErrorAlert.toggle()
                    self.isFetching = false
                }
            case .success(let data):
                tryToDecodeData(data: data)
            }
        }
    }

    private func tryToDecodeData(data: Data) {
        do {
            try PersistenceController.shared.decodeAndSaveFile(from: data)
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Not enough substances could be parsed."
                self.isShowingErrorAlert.toggle()
            }
        }
        DispatchQueue.main.async {
            self.isFetching = false
        }
    }
}

struct SettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTab()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
            .environmentObject(Connectivity())
            .accentColor(Color.blue)
    }
}
