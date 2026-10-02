import SwiftUI
import Charts

/// Large animated figure for one exercise: side / front / back / turning, drag to rotate, plus form cues.
struct FormDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let exerciseID: String

    @State private var angle: FormAngle = .side
    @State private var yaw: Double = 90
    @State private var dragStart: Double?

    private var exercise: Exercise? { ExerciseLibrary.byID[exerciseID] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomLeading) {
                        FormFigureView(exerciseID: exerciseID, yaw: yaw, spin: angle == .turn && dragStart == nil)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            .gesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { g in
                                        if dragStart == nil { dragStart = yaw }
                                        yaw = (dragStart ?? yaw) - g.translation.width * 0.6
                                    }
                                    .onEnded { _ in
                                        dragStart = nil
                                        if angle == .turn { angle = .side }
                                    }
                            )
                        Text("Drag to turn")
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(10)
                    }

                    Picker("View", selection: $angle) {
                        ForEach(FormAngle.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: angle) { _, a in
                        withAnimation(.easeInOut(duration: 0.5)) { yaw = a.yaw }
                    }

                    if let ex = exercise {
                        FlowLayout(spacing: 6) {
                            ForEach(ex.primary) { Chip(text: $0.displayName, style: .good) }
                            ForEach(ex.secondary) { Chip(text: $0.displayName) }
                            ForEach(ex.equipment.filter { $0 != .bodyweight }) { Chip(text: $0.displayName) }
                        }
                    }

                    let cues = FormLibrary.cues(for: exerciseID)
                    if !cues.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Form cues").font(.headline)
                            ForEach(Array(cues.enumerated()), id: \.offset) { i, cue in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("\(i + 1)").font(.subheadline.monospacedDigit().bold()).foregroundStyle(Theme.accent)
                                    Text(cue)
                                }
                            }
                        }
                    }
                    if let tip = FormLibrary.tip(for: exerciseID) {
                        Text(tip)
                            .font(.subheadline)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }

                    let points = store.oneRepMaxHistory(exerciseID)
                    if !points.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your estimated 1-rep max").font(.headline)
                            Chart(Array(points.enumerated()), id: \.offset) { _, p in
                                LineMark(x: .value("Date", p.0), y: .value("1RM", p.1))
                                PointMark(x: .value("Date", p.0), y: .value("1RM", p.1))
                            }
                            .foregroundStyle(Theme.accent)
                            .frame(height: 140)
                        }
                    }
                }
                .padding()
            }
            .forgeScreen()
            .navigationTitle(exercise?.name ?? "Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                yaw = FormLibrary.defaultYaw(for: exerciseID)
                angle = yaw == 0 ? .front : .side
            }
        }
    }
}
