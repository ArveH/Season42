import SwiftUI

/// The Settings tab: the user's preferences about the app. Every rule about what a
/// preference is and where it is kept lives in `AppSettings`; this view only offers the
/// choices.
struct SettingsView: View {
    @Bindable var settings: AppSettings

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
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
