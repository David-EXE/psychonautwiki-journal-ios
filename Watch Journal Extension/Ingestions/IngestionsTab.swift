import SwiftUI

struct IngestionsTab: View {

    @ObservedObject var experience: Experience
    @Environment(\.managedObjectContext) var moc
    @EnvironmentObject var connectivity: Connectivity

    @State private var isShowingAddIngestionSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(experience.sortedIngestionsUnwrapped, content: IngestionRow.init)
                    .onDelete(perform: deleteIngestions)

                if experience.sortedIngestionsUnwrapped.isEmpty {
                    Button(action: addIngestion) {
                        Label("Add Ingestion", systemImage: "plus")
                            .font(.body)
                    }
                } else {
                    Group {
                        Button(action: addIngestion) {
                            Label("Add Ingestion", systemImage: "plus")
                                .font(experience.sortedIngestionsUnwrapped.isEmpty ? .body : .footnote)
                        }
                        Button(action: deleteAllIngestions) {
                            Label("Restart", systemImage: "restart")
                        }
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle("Ingestions")
            .sheet(isPresented: $isShowingAddIngestionSheet) {
                ChooseSubstanceView(
                    dismiss: {isShowingAddIngestionSheet.toggle()},
                    experience: experience
                )
                    .environment(\.managedObjectContext, self.moc)
                    .environmentObject(connectivity)
                    .accentColor(Color.blue)
            }
        }
    }

    private func addIngestion() {
        isShowingAddIngestionSheet.toggle()
    }

    private func deleteIngestions(at offsets: IndexSet) {
        withAnimation {
            moc.perform {
                for offset in offsets {
                    let ingestion = experience.sortedIngestionsUnwrapped[offset]
                    moc.delete(ingestion)
                }
                try? moc.save()
            }
        }
        UserDefaults.standard.set(true, forKey: PersistenceController.needsToUpdateWatchFaceKey)

    }

    private func deleteAllIngestions() {
        withAnimation {
            moc.perform {
                for ingestion in experience.sortedIngestionsUnwrapped {
                    moc.delete(ingestion)
                }
                try? moc.save()
            }
        }
        UserDefaults.standard.set(true, forKey: PersistenceController.needsToUpdateWatchFaceKey)
    }

}

struct IngestionsTab_Previews: PreviewProvider {
    static var previews: some View {
        let helper = PersistenceController.preview.createPreviewHelper()
        IngestionsTab(experience: helper.experiences.first!)
    }
}
