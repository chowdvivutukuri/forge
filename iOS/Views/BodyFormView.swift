import SwiftUI
import WebKit

/// Realistic 3D body form guide (beta). Runs the bundled three.js viewer in FormBody/ offline:
/// a CC0 MakeHuman body, male or female from the profile, with live joint angles and muscle highlights.
enum BodyForm {
    /// Exercises that have a realistic-body page in FormBody/.
    static let pages: [String: String] = ["db_curl": "curl"]

    static func has(_ exerciseID: String) -> Bool { pages[exerciseID] != nil }
}

struct BodyFormView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let exerciseID: String

    var body: some View {
        NavigationStack {
            BodyFormWebView(page: BodyForm.pages[exerciseID] ?? "curl",
                            sex: store.settings.sex == .female ? "female" : "male")
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(ExerciseLibrary.byID[exerciseID]?.name ?? "3D body")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct BodyFormWebView: UIViewRepresentable {
    let page: String
    let sex: String

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        if let file = Bundle.main.url(forResource: page, withExtension: "html", subdirectory: "FormBody"),
           var parts = URLComponents(url: file, resolvingAgainstBaseURL: false) {
            parts.queryItems = [URLQueryItem(name: "sex", value: sex)]
            web.loadFileURL(parts.url ?? file, allowingReadAccessTo: file.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}
