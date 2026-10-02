import SwiftUI

/// Edits one equipment setup: free-weight toggles, machine toggles, and a typed machine list.
struct EquipmentEditor: View {
    @Binding var profile: EquipmentProfile
    @Binding var customMap: [String: String]
    var showName = true

    @State private var typed = ""
    @FocusState private var typing: Bool

    private var parsed: MachineCatalog.Result { MachineCatalog.parse(typed, custom: customMap) }

    var body: some View {
        Group {
            if showName {
                Section("Name") {
                    TextField("Name", text: $profile.name)
                }
            }

            Section {
                TextField("e.g. leg press, pec deck, smith machine, cable crossover", text: $typed, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($typing)
                    .textInputAutocapitalization(.never)
                let r = parsed
                if !r.recognized.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recognised").font(.caption.bold()).foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(r.recognized) { m in
                                Chip(text: "\(m.text) → \(m.equipment.map(\.displayName).joined(separator: ", "))", style: .good)
                            }
                        }
                    }
                }
                if !r.unknown.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not recognised — tap to say what it's like").font(.caption.bold()).foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(r.unknown, id: \.self) { item in
                                Menu {
                                    ForEach(Equipment.selectable) { eq in
                                        Button(eq.displayName) { customMap[item.lowercased()] = eq.rawValue }
                                    }
                                } label: {
                                    Chip(text: item, style: .warn)
                                }
                            }
                        }
                    }
                }
                if !r.cardio.isEmpty {
                    Text("Not planned yet (Forge plans treadmill and elliptical cardio): \(r.cardio.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    profile.equipment.formUnion(r.equipment)
                    profile.machineText = [profile.machineText, typed].filter { !$0.isEmpty }.joined(separator: ", ")
                    typed = ""
                    typing = false
                } label: {
                    Label("Add \(r.equipment.count) to this setup", systemImage: "plus.circle.fill")
                }
                .disabled(r.equipment.isEmpty)
            } header: {
                Text("Type the machines you have")
            } footer: {
                Text("Separate with commas. Forge recognises common machine names. Your workouts and program only use exercises this setup can do.")
            }

            Section("Free weights & stations") {
                ForEach(Equipment.freeWeights) { eq in toggle(eq) }
            }
            Section {
                ForEach(Equipment.machines) { eq in toggle(eq) }
            } header: {
                Text("Machines")
            } footer: {
                let n = ExerciseLibrary.available(with: profile.equipment).count
                Text("\(n) exercises available with this setup (bodyweight exercises always included).")
            }
        }
        .onAppear { typed = "" }
    }

    private func toggle(_ eq: Equipment) -> some View {
        Toggle(isOn: Binding(
            get: { profile.equipment.contains(eq) || (profile.equipment.contains(.machine) && Equipment.machines.contains(eq)) },
            set: { on in
                if profile.equipment.contains(.machine) {
                    profile.equipment.remove(.machine)
                    profile.equipment.formUnion(Equipment.machines)
                }
                if on { profile.equipment.insert(eq) } else { profile.equipment.remove(eq) }
            }
        )) {
            Label(eq.displayName, systemImage: eq.symbol)
        }
    }
}

struct Chip: View {
    enum Style { case good, warn, neutral }
    let text: String
    var style: Style = .neutral

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }
    private var background: Color {
        switch style {
        case .good: return ForgeColors.positive.opacity(0.15)
        case .warn: return Color.orange.opacity(0.18)
        case .neutral: return Color.secondary.opacity(0.12)
        }
    }
    private var foreground: Color {
        switch style {
        case .good: return ForgeColors.positive
        case .warn: return .orange
        case .neutral: return .primary
        }
    }
}

/// Wraps children onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
