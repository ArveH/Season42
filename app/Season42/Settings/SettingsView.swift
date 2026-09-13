import SwiftUI

/// The Settings tab: the user's preferences about the app, what build they are running, and
/// the app's one permanent TMDB notice. Every rule about what a preference is and where it is
/// kept lives in `AppSettings`; this view only offers the choices.
///
/// About and the attribution are here because this is the tab that is always reachable and
/// never transient — the notice TMDB's terms ask of the application belongs somewhere the user
/// and a reviewer can find without adding a series first (ADR-0019).
struct SettingsView: View {
    /// The two pages the repo publishes under `site/`, which are also the URLs App Store
    /// Connect is given (`docs/app-store-connect.md`). The app links to them rather than
    /// carrying a copy: one wording, published once.
    private static let privacyPage = URL(string: "https://arveh.github.io/Season42/privacy/")!
    private static let supportPage = URL(string: "https://arveh.github.io/Season42/support/")!

    @Bindable var settings: AppSettings

    private let build = AppBuild.main

    var body: some View {
        NavigationStack {
            Form {
                // All three side by side, as the Watching Orders are, so the one in force
                // is readable without tapping.
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { appearance in
                            Text(appearance.label)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows the device's own setting.")
                }

                aboutSection

                // Last in the Form, bare and headerless, exactly as the search sheets drop
                // it into theirs.
                TmdbAttribution(.wholeApp)
            }
            .navigationTitle("Settings")
        }
    }

    /// The version the user quotes in a bug report, and the two pages that tell them what the
    /// app does with their data and how to report one.
    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: build.label)
            Link("Privacy policy", destination: Self.privacyPage)
            Link("Support", destination: Self.supportPage)
        } header: {
            Text("About")
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}

#Preview("Dark") {
    SettingsView(settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .preferredColorScheme(.dark)
}
