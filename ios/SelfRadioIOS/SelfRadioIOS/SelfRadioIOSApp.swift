import SwiftUI

@main
struct SelfRadioIOSApp: App {
    @State private var player = PlayerStore()
    @State private var accounts = AccountStore()
    @State private var showMainApp = false
    @AppStorage("SelfRadio.appearance") private var appearanceRaw = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            Group {
                if showMainApp {
                    RootView()
                        .environment(player)
                        .environment(accounts)
                        .overlay(alignment: .topTrailing) {
                            // 隐蔽的退出按钮：长按右上角区域2.5秒退出到日历
                            Color.clear
                                .frame(width: 80, height: 40)
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 2.5) {
                                    showMainApp = false
                                }
                        }
                } else {
                    CalendarDisguiseView()
                        .environment(player)
                        .environment(accounts)
                }
            }
            .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: .enterMainApp)) { _ in
                showMainApp = true
            }
        }
    }
}
