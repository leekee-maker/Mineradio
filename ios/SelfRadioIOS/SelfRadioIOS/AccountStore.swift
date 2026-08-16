import Foundation
import Observation

@MainActor
@Observable
final class AccountStore {
    var netease = PlatformAccountStatus(nickname: "网易云")
    var qq = PlatformAccountStatus(nickname: "QQ 音乐")
    var qishui = PlatformAccountStatus(nickname: "汽水")
    var showingQQLogin = false
    var showingNeteaseLogin = false
    var showingQishuiLogin = false
    var isSyncing = false
    var errorMessage: String?

    func refreshQQ() async {
        do {
            qq = try await SelfRadioAPI.shared.accountStatus(for: .qq)
        } catch {
            qq = PlatformAccountStatus(nickname: "QQ 音乐", detail: error.localizedDescription)
        }
    }

    func refreshAll() async {
        async let neteaseStatus = try? SelfRadioAPI.shared.accountStatus(for: .netease)
        async let qqStatus = try? SelfRadioAPI.shared.accountStatus(for: .qq)
        async let qishuiStatus = try? SelfRadioAPI.shared.accountStatus(for: .qishui)
        if let value = await neteaseStatus { netease = value }
        if let value = await qqStatus { qq = value }
        if let value = await qishuiStatus { qishui = value }
    }

    func refreshNetease() async {
        do { netease = try await SelfRadioAPI.shared.accountStatus(for: .netease) }
        catch { netease = PlatformAccountStatus(nickname: "网易云", detail: error.localizedDescription) }
    }

    func refreshQishui() async {
        do { qishui = try await SelfRadioAPI.shared.accountStatus(for: .qishui) }
        catch { qishui = PlatformAccountStatus(nickname: "汽水", detail: error.localizedDescription) }
    }

    func status(for provider: MusicProvider) -> PlatformAccountStatus {
        switch provider {
        case .netease: netease
        case .qq: qq
        case .qishui: qishui
        }
    }

    func logout(provider: MusicProvider) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await SelfRadioAPI.shared.logout(provider: provider)
            switch provider {
            case .netease: await refreshNetease()
            case .qq: await refreshQQ()
            case .qishui: await refreshQishui()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncQQ(cookie: String) async -> Bool {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let data = try await SelfRadioAPI.shared.request(path: "api/qq/login/cookie", method: "POST", body: ["cookie": cookie])
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard object?["loggedIn"] as? Bool == true,
                  object?["playbackKeyReady"] as? Bool == true else {
                throw APIError.server("QQ 已登录，但未取得音乐播放凭证")
            }
            await refreshQQ()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
