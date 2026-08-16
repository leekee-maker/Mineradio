import SwiftUI

@main
struct SelfRadioIOSApp: App {
    @State private var player = PlayerStore()
    @State private var accounts = AccountStore()
    @AppStorage("SelfRadio.appearance") private var appearanceRaw = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(accounts)
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
