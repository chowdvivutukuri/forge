import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject var store: WorkoutStore

    var body: some View {
        let recovery = store.recovery
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        BodyMapView(side: .front, recovery: recovery)
                        BodyMapView(side: .back, recovery: recovery)
                    }
                    .frame(height: 340)
                    .padding(.vertical, 8)
                    HStack(spacing: 16) {
                        legend(0.1, "Fatigued")
                        legend(0.5, "Recovering")
                        legend(1, "Fresh")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }

                Section("Muscles") {
                    ForEach(Muscle.allCases.sorted { (recovery[$0] ?? 1) < (recovery[$1] ?? 1) }) { muscle in
                        let value = recovery[muscle] ?? 1
                        HStack {
                            Text(muscle.displayName)
                            Spacer()
                            ProgressView(value: value)
                                .tint(Theme.recoveryColor(value))
                                .frame(width: 110)
                            Text("\(Int(value * 100))%")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .forgeScreen()
            .navigationTitle("Recovery")
        }
    }

    private func legend(_ value: Double, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.recoveryColor(value)).frame(width: 9, height: 9)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

/// A stylised body drawn from rounded shapes in a 100 × 200 grid, coloured by recovery.
struct BodyMapView: View {
    enum Side { case front, back }
    let side: Side
    let recovery: [Muscle: Double]

    private struct Region {
        let muscle: Muscle?
        let rect: CGRect
        let corner: CGFloat
        init(_ muscle: Muscle?, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ corner: CGFloat = 4) {
            self.muscle = muscle
            self.rect = CGRect(x: x, y: y, width: w, height: h)
            self.corner = corner
        }
    }

    private static let shared: [Region] = [
        Region(nil, 42, 2, 16, 18, 8),       // head
        Region(nil, 46, 19, 8, 7, 2),        // neck
        Region(nil, 15, 106, 9, 11, 4),      // hands
        Region(nil, 76, 106, 9, 11, 4),
        Region(nil, 35, 187, 11, 9, 3),      // feet
        Region(nil, 54, 187, 11, 9, 3),
        Region(.forearms, 16, 68, 9, 37, 4),
        Region(.forearms, 75, 68, 9, 37, 4),
        Region(.calves, 36, 142, 9, 44, 4),
        Region(.calves, 55, 142, 9, 44, 4),
    ]

    private static let front: [Region] = [
        Region(.frontDelts, 25, 27, 13, 14, 7),
        Region(.frontDelts, 62, 27, 13, 14, 7),
        Region(.sideDelts, 20, 31, 6, 13, 3),
        Region(.sideDelts, 74, 31, 6, 13, 3),
        Region(.chest, 37, 29, 12.5, 18, 4),
        Region(.chest, 50.5, 29, 12.5, 18, 4),
        Region(.biceps, 21, 44, 10, 23, 5),
        Region(.biceps, 69, 44, 10, 23, 5),
        Region(.abs, 41, 49, 18, 37, 4),
        Region(.obliques, 34, 51, 6, 32, 3),
        Region(.obliques, 60, 51, 6, 32, 3),
        Region(.quads, 34, 89, 11, 50, 5),
        Region(.quads, 55, 89, 11, 50, 5),
        Region(.adductors, 45.5, 91, 4, 26, 2),
        Region(.adductors, 50.5, 91, 4, 26, 2),
    ]

    private static let back: [Region] = [
        Region(.traps, 37, 22, 26, 12, 5),
        Region(.rearDelts, 25, 28, 13, 14, 7),
        Region(.rearDelts, 62, 28, 13, 14, 7),
        Region(.upperBack, 38, 34, 24, 14, 3),
        Region(.lats, 34, 48, 13, 24, 4),
        Region(.lats, 53, 48, 13, 24, 4),
        Region(.triceps, 21, 44, 10, 23, 5),
        Region(.triceps, 69, 44, 10, 23, 5),
        Region(.lowerBack, 42, 72, 16, 14, 3),
        Region(.glutes, 35, 86, 14.5, 18, 7),
        Region(.glutes, 50.5, 86, 14.5, 18, 7),
        Region(.hamstrings, 34, 105, 12, 35, 5),
        Region(.hamstrings, 54, 105, 12, 35, 5),
    ]

    private var regions: [Region] { Self.shared + (side == .front ? Self.front : Self.back) }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 100, geo.size.height / 200)
            let ox = (geo.size.width - 100 * s) / 2
            let oy = (geo.size.height - 200 * s) / 2
            ZStack(alignment: .topLeading) {
                ForEach(Array(regions.enumerated()), id: \.offset) { _, r in
                    RoundedRectangle(cornerRadius: r.corner * s)
                        .fill(fill(r.muscle))
                        .frame(width: r.rect.width * s, height: r.rect.height * s)
                        .offset(x: ox + r.rect.minX * s, y: oy + r.rect.minY * s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .overlay(alignment: .bottom) {
            Text(side == .front ? "Front" : "Back")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .offset(y: 14)
        }
    }

    private func fill(_ muscle: Muscle?) -> Color {
        guard let muscle else { return Color.secondary.opacity(0.18) }
        return Theme.recoveryColor(recovery[muscle] ?? 1)
    }
}
