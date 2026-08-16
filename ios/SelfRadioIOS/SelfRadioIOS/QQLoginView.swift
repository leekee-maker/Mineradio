import SwiftUI
import WebKit
import Photos

struct QQLoginView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(\.dismiss) private var dismiss
    @State private var status = "同机可保存二维码，再从 QQ 扫一扫的相册识别"
    @State private var saveQRCodeTrigger = 0

    var body: some View {
        NavigationStack {
            QQLoginWebView(saveQRCodeTrigger: saveQRCodeTrigger) { message in
                status = message
            } onCookie: { cookie in
                status = "正在验证 QQ 音乐播放权限…"
                Task {
                    if await accounts.syncQQ(cookie: cookie) {
                        dismiss()
                    } else {
                        status = accounts.errorMessage ?? "验证失败，请重试"
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        saveQRCodeTrigger += 1
                    } label: {
                        Label("同机扫码登录", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(accounts.isSyncing)

                    HStack(spacing: 10) {
                        if accounts.isSyncing { ProgressView() }
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(12).background(.regularMaterial)
            }
            .navigationTitle("登录 QQ 音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
    }
}

struct NeteaseLoginView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var status = "正在获取网易云二维码…"
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
                } else if !failed {
                    ProgressView().controlSize(.large)
                }
                Text(status).font(.subheadline).foregroundStyle(failed ? .red : .secondary).multilineTextAlignment(.center)
                if failed {
                    Button("重新获取") { failed = false; Task { await loginFlow() } }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("登录网易云")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
        .task { await loginFlow() }
    }

    @MainActor
    private func loginFlow() async {
        failed = false
        qrImage = nil
        status = "正在获取网易云二维码…"
        do {
            let keyData = try await SelfRadioAPI.shared.request(path: "api/login/qr/key")
            let keyRoot = try JSONSerialization.jsonObject(with: keyData) as? [String: Any]
            guard let key = keyRoot?["key"] as? String, !key.isEmpty else { throw APIError.server("二维码密钥获取失败") }
            let imageData = try await SelfRadioAPI.shared.request(path: "api/login/qr/create", query: [.init(name: "key", value: key)])
            let imageRoot = try JSONSerialization.jsonObject(with: imageData) as? [String: Any]
            guard let raw = imageRoot?["img"] as? String, let image = decodeDataImage(raw) else { throw APIError.server("二维码生成失败") }
            qrImage = image
            status = "请使用网易云音乐 App 扫码"

            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(2))
                let checkData = try await SelfRadioAPI.shared.request(path: "api/login/qr/check", query: [.init(name: "key", value: key)])
                let root = try JSONSerialization.jsonObject(with: checkData) as? [String: Any]
                let code = (root?["code"] as? NSNumber)?.intValue ?? 0
                switch code {
                case 800: throw APIError.server("二维码已过期，请重新获取")
                case 801: status = "等待网易云音乐 App 扫码"
                case 802: status = "已扫码，请在网易云音乐 App 中确认"
                case 803:
                    await accounts.refreshNetease()
                    guard accounts.netease.playbackReady else { throw APIError.server("扫码成功，但账号会话尚未生效") }
                    dismiss()
                    return
                default: status = root?["message"] as? String ?? "正在确认登录状态…"
                }
            }
        } catch is CancellationError {
            return
        } catch {
            failed = true
            status = error.localizedDescription
        }
    }

    private func decodeDataImage(_ value: String) -> UIImage? {
        let base64 = value.split(separator: ",", maxSplits: 1).last.map(String.init) ?? value
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

struct QishuiLoginView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var status = "正在获取汽水二维码…"
    @State private var failed = false
    @State private var terminalFailure = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none).resizable().scaledToFit()
                        .frame(width: 260, height: 260).padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
                    Button { save(qrImage) } label: { Label("保存二维码到相册", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.bordered)
                } else if !failed {
                    ProgressView().controlSize(.large)
                }
                Text(status).font(.subheadline).foregroundStyle(failed ? .red : .secondary).multilineTextAlignment(.center)
                if failed && !terminalFailure {
                    Button("重新获取") { failed = false; Task { await loginFlow() } }.buttonStyle(.borderedProminent)
                } else if terminalFailure {
                    VStack(spacing: 10) {
                        Text("请先完成汽水账号连接后再使用。")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Link("查看官方授权要求", destination: URL(string: "https://developer.open-douyin.com/docs/resource/zh-CN/dop/develop/sdk/mobile-app/permission/overall-permission/")!)
                            .font(.footnote.bold())
                    }
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("登录汽水音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
        .task { await loginFlow() }
    }

    @MainActor
    private func loginFlow() async {
        failed = false
        terminalFailure = false
        qrImage = nil
        status = "正在获取汽水二维码…"
        do {
            let createData = try await SelfRadioAPI.shared.request(path: "api/qishui/login/qr/create")
            let createRoot = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
            guard let token = createRoot?["token"] as? String, !token.isEmpty,
                  let raw = createRoot?["qrcode"] as? String, let image = decodeDataImage(raw) else {
                throw APIError.server(createRoot?["message"] as? String ?? "汽水二维码生成失败")
            }
            qrImage = image
            status = "请使用另一台设备的抖音 App 扫码确认；同机可先保存二维码"
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(2))
                let checkData = try await SelfRadioAPI.shared.request(path: "api/qishui/login/qr/check", query: [.init(name: "token", value: token)])
                let root = try JSONSerialization.jsonObject(with: checkData) as? [String: Any]
                status = root?["message"] as? String ?? "等待抖音 App 确认"
                if root?["terminal"] as? Bool == true {
                    terminalFailure = true
                    throw APIError.server(status)
                }
                if root?["loggedIn"] as? Bool == true {
                    await accounts.refreshQishui()
                    guard accounts.qishui.playbackReady else { throw APIError.server("登录已确认，但汽水会话尚未生效") }
                    dismiss()
                    return
                }
                let retryAfter = (root?["retryAfterMs"] as? NSNumber)?.doubleValue ?? 0
                if retryAfter > 2000 { try await Task.sleep(for: .milliseconds(Int(retryAfter - 2000))) }
            }
        } catch is CancellationError {
            return
        } catch {
            failed = true
            status = error.localizedDescription
            terminalFailure = status.contains("扫码入口当前不可用")
        }
    }

    private func decodeDataImage(_ value: String) -> UIImage? {
        let base64 = value.split(separator: ",", maxSplits: 1).last.map(String.init) ?? value
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private func save(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { authorization in
            guard authorization == .authorized || authorization == .limited else {
                Task { @MainActor in status = "请允许随心听添加照片" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in status = success ? "二维码已保存，请在另一台设备或抖音扫码页从相册识别" : "二维码保存失败" }
            }
        }
    }
}

private struct QQLoginWebView: UIViewRepresentable {
    let saveQRCodeTrigger: Int
    let onStatus: (String) -> Void
    let onCookie: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onStatus: onStatus, onCookie: onCookie) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        webView.load(URLRequest(url: URL(string: "https://y.qq.com/n/ryqq/profile")!))
        context.coordinator.startWatching(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.saveQRCodeAndOpenQQ(trigger: saveQRCodeTrigger, webView: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) { coordinator.stopWatching() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let onCookie: (String) -> Void
        private let onStatus: (String) -> Void
        private var timer: Timer?
        private var submitted = false
        private var warmupStarted = false
        private var warmupChecks = 0
        private var openedLogin = false
        private var lastSaveQRCodeTrigger = 0

        init(onStatus: @escaping (String) -> Void, onCookie: @escaping (String) -> Void) {
            self.onStatus = onStatus
            self.onCookie = onCookie
        }

        func saveQRCodeAndOpenQQ(trigger: Int, webView: WKWebView) {
            guard trigger > 0, trigger != lastSaveQRCodeTrigger else { return }
            lastSaveQRCodeTrigger = trigger
            onStatus("正在保存二维码…")
            webView.takeSnapshot(with: nil) { [weak self] image, error in
                guard let self, let image, error == nil else {
                    self?.onStatus("二维码保存失败，请重试")
                    return
                }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { authorization in
                    guard authorization == .authorized || authorization == .limited else {
                        Task { @MainActor in self.onStatus("请允许随心听添加照片") }
                        return
                    }
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    } completionHandler: { success, _ in
                        Task { @MainActor in
                            guard success else {
                                self.onStatus("二维码保存失败，请重试")
                                return
                            }
                            self.onStatus("二维码已保存，请在 QQ 扫一扫中从相册选择")
                            self.openQQScanner()
                        }
                    }
                }
            }
        }

        private func openQQScanner() {
            let scannerURL = URL(string: "mqqapi://qrcode/scan_qrcode?version=1&src_type=app")!
            UIApplication.shared.open(scannerURL) { [weak self] opened in
                guard !opened else { return }
                guard let qqURL = URL(string: "mqq://") else { return }
                UIApplication.shared.open(qqURL) { fallbackOpened in
                    if !fallbackOpened { self?.onStatus("未安装 QQ，二维码已保存到相册") }
                }
            }
        }

        func startWatching(_ webView: WKWebView) {
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self, weak webView] _ in
                Task { @MainActor in
                    guard let self, let webView, !self.submitted else { return }
                    let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
                    let qqCookies = cookies.filter { $0.domain.hasSuffix("qq.com") }
                    let names = Set(qqCookies.map(\.name))
                    let hasUser = names.contains("uin") || names.contains("p_uin") || names.contains("wxuin")
                    let hasLoginTicket = !names.intersection(["qm_keyst", "qqmusic_key", "music_key", "p_skey", "skey", "psrf_qqaccess_token", "wxrefresh_token", "wxskey"]).isEmpty
                    let hasPlaybackTicket = !names.intersection(["qm_keyst", "qqmusic_key", "music_key", "wxskey"]).isEmpty
                    guard hasUser, hasLoginTicket else { return }
                    if !hasPlaybackTicket, !self.warmupStarted {
                        self.warmupStarted = true
                        self.onStatus("QQ 已确认，正在获取音乐播放凭证…")
                        webView.pageZoom = 1
                        webView.load(URLRequest(url: URL(string: "https://y.qq.com/n/ryqq/player")!))
                        return
                    }
                    if !hasPlaybackTicket, self.warmupStarted {
                        self.warmupChecks += 1
                        if self.warmupChecks >= 5 {
                            self.onStatus("QQ 已登录，但未取得播放凭证，请使用密码登录或重新扫码")
                        }
                        return
                    }
                    self.submitted = true
                    self.onCookie(qqCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "))
                }
            }
        }

        func stopWatching() { timer?.invalidate(); timer = nil }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard webView.url?.host?.hasSuffix("y.qq.com") == true, !openedLogin, !warmupStarted else {
                webView.pageZoom = 1
                return
            }
            openedLogin = true
            let script = """
            if (location.hostname.endsWith('y.qq.com')) {
              setTimeout(() => {
                const login = [...document.querySelectorAll('a,button,span')]
                  .find(el => el.textContent.trim() === '登录' && el.offsetParent !== null);
                if (login) login.click();
                let checks = 0;
                const timer = setInterval(() => {
                  const frame = [...document.querySelectorAll('iframe')]
                    .find(el => el.offsetParent !== null && /^https:/i.test(el.src || ''));
                  if (frame && frame.src) {
                    clearInterval(timer);
                    frame.style.position = 'fixed';
                    frame.style.inset = '0';
                    frame.style.width = '100vw';
                    frame.style.height = '100vh';
                    frame.style.maxWidth = 'none';
                    frame.style.maxHeight = 'none';
                    frame.style.zIndex = '2147483647';
                    frame.style.border = '0';
                    document.documentElement.style.overflow = 'hidden';
                    document.body.style.overflow = 'hidden';
                  } else if (++checks > 20) {
                    clearInterval(timer);
                  }
                }, 500);
              }, 800);
            }
            """
            webView.evaluateJavaScript(script)
            Task { @MainActor [weak webView] in
                try? await Task.sleep(for: .seconds(3))
                if webView?.url?.host?.hasSuffix("y.qq.com") == true { webView?.pageZoom = 1.8 }
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
    }
}
