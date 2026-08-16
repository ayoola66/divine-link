import SwiftUI

/// Audience-facing presentation surface. Keep this quiet: verse, reference, translation.
struct DivineViewScreen: View {
    @ObservedObject private var controller = DivineViewController.shared
    @ObservedObject private var settings = DivineViewSettings.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                settings.background.fill
                    .ignoresSafeArea()

                if controller.isShowingVerse {
                    VStack(spacing: max(16, geo.size.height * 0.045)) {
                        Text(controller.verseText)
                            .font(.system(
                                size: max(28, min(geo.size.width * 0.048, geo.size.height * 0.09)),
                                weight: .regular,
                                design: .serif
                            ))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.35)
                            .lineSpacing(6)

                        VStack(spacing: 8) {
                            Text(controller.reference)
                                .font(.system(
                                    size: max(16, geo.size.width * 0.022),
                                    weight: .semibold
                                ))

                            if !controller.translation.isEmpty {
                                Text(controller.translation)
                                    .font(.system(
                                        size: max(12, geo.size.width * 0.015),
                                        weight: .medium
                                    ))
                                    .opacity(0.65)
                            }
                        }
                    }
                    .foregroundStyle(settings.background.text)
                    .padding(.horizontal, max(32, geo.size.width * 0.08))
                    .padding(.vertical, max(24, geo.size.height * 0.08))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 360)
        .background(settings.background.fill)
    }
}

#Preview("DivineView — verse") {
    DivineViewScreen()
        .frame(width: 1280, height: 720)
        .onAppear {
            DivineViewController.shared.present(
                reference: "John 3:16",
                text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
                translation: "KJV"
            )
        }
}
