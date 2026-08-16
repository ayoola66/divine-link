import SwiftUI

/// Settings → DivineView. Appearance only; Push still confirms in the operator window.
struct DivineViewSettingsTab: View {
    @ObservedObject private var settings = DivineViewSettings.shared
    @ObservedObject private var controller = DivineViewController.shared

    var body: some View {
        Form {
            Section {
                Picker("Background", selection: $settings.background) {
                    ForEach(DivineViewSettings.Background.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Open DivineView when a verse is pushed", isOn: $settings.openOnPush)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Black or white only in this version. Drag the DivineView window onto the projector display and use full screen. Pushing a verse brings the window forward without taking focus from the operator window.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Open DivineView") {
                    controller.requestOpenWindow()
                }

                Button("Show sample verse") {
                    controller.present(
                        reference: "John 3:16",
                        text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
                        translation: "KJV"
                    )
                }

                Button("Clear DivineView") {
                    controller.clear()
                }
            } header: {
                Text("Preview")
            } footer: {
                Text("Push One and Push All also update DivineView. The Clear button (F12 or ⌘+Esc) clears it along with ProPresenter.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .background(DivineViewWindowOpener())
    }
}
