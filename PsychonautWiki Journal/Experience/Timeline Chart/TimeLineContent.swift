import SwiftUI

struct TimeLineContent: View {

    let startTime: Date
    let endTime: Date
    let lineModels: [IngestionLineModel]

    private let innerHorizontalPadding: CGFloat = 30
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    @State private var currentTime = Date()

    var isCurrentTimeInChart: Bool {
        currentTime > startTime && currentTime < endTime
    }

    init(sortedIngestions: [Ingestion]) {
        self.startTime = sortedIngestions.first?.timeUnwrapped ?? Date()
        self.endTime = Experience.getEndTime(for: sortedIngestions) ?? Date().addingTimeInterval(5*60*60)
        self.lineModels = HelperMethods.getLineModels(sortedIngestions: sortedIngestions)

    }

    var body: some View {
        GeometryReader { geo in
            VStack {
                ZStack(alignment: .bottom) {
                    ForEach(0..<lineModels.count, id: \.self) { index in
                        LineView(ingestionLineModel: lineModels[index])
                    }
                    .frame(width: geo.size.width, height: geo.size.height)

                    if isCurrentTimeInChart {
                        CurrentTimeView(
                            currentTime: currentTime,
                            graphStartTime: startTime,
                            graphEndTime: endTime
                        )
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                TimeLabels(startTime: startTime, endTime: endTime, totalWidth: geo.size.width)
                    .position(x: 0, y: 0)
                    .frame(width: geo.size.width)
                    .padding(.top, 5)
            }
        }
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
    }
}

struct TimeLineContent_Previews: PreviewProvider {
    static var previews: some View {
        let helper = PersistenceController.preview.createPreviewHelper()
        TimeLineContent(sortedIngestions: helper.experiences.first!.sortedIngestionsUnwrapped)
            .frame(height: 300)
    }
}
