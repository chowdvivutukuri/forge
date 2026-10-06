import SwiftUI
import WebKit

/// Realistic 3D body form guide (beta). Runs the bundled three.js viewer in FormBody/ offline:
/// a CC0 MakeHuman body with live joint angles and muscle highlights.
enum BodyForm {
    /// Exercises with their own hand-tuned page in FormBody/. Every other exercise with a form animation
    /// uses body.html, which poses the body from the same frames as the 2D figure.
    static let pages: [String: String] = ["db_curl": "curl"]

    /// forms.json as plain JSON, to hand the pattern to the web page.
    private static let raw: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "forms", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }()

    private static func formEntry(_ exerciseID: String) -> (exercise: [String: Any], pattern: [String: Any])? {
        guard let raw, let exs = raw["exercises"] as? [String: Any], let pats = raw["patterns"] as? [String: Any],
              let ex = exs[FormLibrary.key(exerciseID)] as? [String: Any], let p = ex["p"] as? String,
              let pat = pats[p] as? [String: Any] else { return nil }
        return (ex, pat)
    }

    static func has(_ exerciseID: String) -> Bool {
        if pages[exerciseID] != nil { return true }
        guard let ex = ExerciseLibrary.byID[exerciseID], !ex.isCardio, let entry = formEntry(exerciseID) else { return false }
        // Front-authored patterns (side plank, Copenhagen plank, windmill) don't map onto the body well yet.
        return entry.pattern["view"] as? String != "f"
    }

    static func page(for exerciseID: String) -> String { pages[exerciseID] ?? "body" }

    /// `window.FORGE_FORM = {...}` for body.html: the animation frames plus the names, muscles, cues and equipment.
    static func script(for exerciseID: String) -> String? {
        guard pages[exerciseID] == nil, let ex = ExerciseLibrary.byID[exerciseID], let entry = formEntry(exerciseID) else { return nil }
        let gear = ex.equipment.filter { $0 != .bodyweight }.map(\.displayName)
        var cues = FormLibrary.cues(for: exerciseID)
        if let tip = FormLibrary.tip(for: exerciseID) { cues.append(tip) }
        if let notes = ex.notes { cues.append(notes) }
        let payload: [String: Any] = [
            "id": exerciseID,
            "name": ex.name,
            "pattern": entry.pattern,
            "ex": entry.exercise,
            "ground": raw?["ground"] ?? 4,
            "primaryKeys": ex.primary.map(\.rawValue),
            "secondaryKeys": ex.secondary.map(\.rawValue),
            "primary": ex.primary.map(\.displayName),
            "secondary": ex.secondary.map(\.displayName),
            "cues": cues,
            "equipment": gear.isEmpty ? "Bodyweight only" : gear.joined(separator: " + "),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return "window.FORGE_FORM = \(json);"
    }
}

struct BodyFormView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let exerciseID: String

    var body: some View {
        NavigationStack {
            BodyFormWebView(page: BodyForm.page(for: exerciseID), script: BodyForm.script(for: exerciseID))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(ExerciseLibrary.byID[exerciseID]?.name ?? "3D body")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct BodyFormWebView: UIViewRepresentable {
    let page: String
    var script: String? = nil

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if let script {
            config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        if let file = Bundle.main.url(forResource: page, withExtension: "html", subdirectory: "FormBody") {
            web.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}
