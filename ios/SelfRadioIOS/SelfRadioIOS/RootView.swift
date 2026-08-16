import SwiftUI
import Foundation
import UIKit
import CryptoKit
import ImageIO
import WebKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "系统"
    case light = "浅色"
    case dark = "深色"

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private enum AppTab: Int, CaseIterable {
    case home, catalog, profile, player

    static let menuCases: [AppTab] = [.home, .catalog, .profile]
    var title: String {
        switch self { case .home: "首页"; case .catalog: "曲库"; case .profile: "我的"; case .player: "播放" }
    }
    var icon: String {
        switch self { case .home: "house.fill"; case .catalog: "square.grid.2x2.fill"; case .profile: "person.crop.circle"; case .player: "play.circle.fill" }
    }
}

private enum GlowPalette {
    static let ink = Color(uiColor: .label)
    static let violet = Color(red: 0.55, green: 0.39, blue: 0.96)
    static let blue = Color(red: 0.33, green: 0.78, blue: 0.98)
    static let rose = Color(red: 1.00, green: 0.48, blue: 0.62)
    static let canvas = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
    static let separator = Color(uiColor: .separator)
    static let secondary = Color(uiColor: .secondaryLabel)
}

private enum AppMetrics {
    static let pagePadding: CGFloat = 20
    static let pageSpacing: CGFloat = 26
    static let groupRadius: CGFloat = 16
    static let rowHeight: CGFloat = 56
}

private enum AppFont {
    static let pageTitle = Font.system(size: 17, weight: .semibold)
    static let sectionTitle = Font.system(size: 13, weight: .semibold)
    static let rowTitle = Font.system(size: 15, weight: .medium)
    static let rowValue = Font.system(size: 12)
    static let caption = Font.system(size: 12)
    static let small = Font.system(size: 10)
}

struct RootView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
#if DEBUG
    @State private var selection: AppTab = ProcessInfo.processInfo.arguments.contains("--open-profile") ? .profile : .home
#else
    @State private var selection: AppTab = .home
#endif
    @State private var hidesBottomNavigation = false
    @State private var showingLaunchSplash = true
    @AppStorage("selfradio.miniPlayer.collapsed") private var miniPlayerCollapsed = false

    private var launchSplashHoldDuration: UInt64 {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--hold-launch-splash") {
            return 8_000_000_000
        }
#endif
        return reduceMotion ? 650_000_000 : 2_050_000_000
    }

    var body: some View {
        @Bindable var player = player
        ZStack {
            SoftGlowBackground()
            Group {
                switch selection {
                case .home: NavigationStack { HomeView(hidesBottomNavigation: $hidesBottomNavigation) }
                case .catalog: NavigationStack { CatalogView(hidesBottomNavigation: $hidesBottomNavigation) }
                case .player: PlayerView { selection = .home }
                case .profile: NavigationStack { ProfileView(hidesBottomNavigation: $hidesBottomNavigation) }
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: launchSplashHoldDuration)
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.35)) {
                showingLaunchSplash = false
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selection != .player {
                VStack(spacing: 0) {
                    if !hidesBottomNavigation, player.current != nil && !miniPlayerCollapsed {
                        MiniPlayerView(selection: $selection, isCollapsed: $miniPlayerCollapsed)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                    if !hidesBottomNavigation { BottomNavigation(selection: $selection) }
                }
            }
        }
        .overlay {
            if selection != .player, !hidesBottomNavigation, player.current != nil, miniPlayerCollapsed {
                FloatingMiniPlayerBubble(
                    isCollapsed: $miniPlayerCollapsed,
                    avoidsBottomNavigation: !hidesBottomNavigation
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay {
            if showingLaunchSplash {
                LaunchSplashView()
                    .transition(.opacity)
            }
        }
        .alert("无法播放", isPresented: Binding(
            get: { player.playbackError != nil },
            set: { if !$0 { player.playbackError = nil } }
        )) { Button("知道了") { player.playbackError = nil } } message: { Text(player.playbackError ?? "") }
        .tint(GlowPalette.violet)
        .foregroundStyle(GlowPalette.ink)
    }
}

private struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var depthShifted = false
    @State private var centerPulsed = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Image("LaunchSplashFusionDynamic")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(reduceMotion ? 1 : (depthShifted ? 1.045 : 1.025))
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : (depthShifted ? -1.6 : 1.6)),
                        axis: (x: 0.15, y: 1, z: 0),
                        perspective: 0.45
                    )
                    .offset(y: reduceMotion ? 0 : (depthShifted ? -4 : 4))
                    .opacity(appeared ? 1 : 0)
                    .accessibilityHidden(true)

                Image("LaunchSplashFusionDynamic")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(reduceMotion ? 1 : (centerPulsed ? 1.035 : 0.99), anchor: UnitPoint(x: 0.5, y: 0.42))
                    .offset(y: reduceMotion ? 0 : (centerPulsed ? -8 : 4))
                    .opacity(reduceMotion ? 0 : (centerPulsed ? 0.32 : 0.08))
                    .blendMode(.screen)
                    .mask {
                        RadialGradient(
                            colors: [.white, .white.opacity(0.9), .clear],
                            center: UnitPoint(x: 0.5, y: 0.42),
                            startRadius: 35,
                            endRadius: min(proxy.size.width, proxy.size.height) * 0.22
                        )
                    }
                    .accessibilityHidden(true)

                LaunchSpectrumPulse(animates: !reduceMotion)
                    .frame(width: proxy.size.width * 0.74, height: proxy.size.width * 0.74)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.42)
                    .opacity(appeared ? 1 : 0)
                    .accessibilityHidden(true)

                LaunchLoadingRing(animates: !reduceMotion)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, proxy.size.height * 0.08)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .background(Color(red: 0.005, green: 0.008, blue: 0.022))
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("随心听，你的私人音乐现场")
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                appeared = true
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8)) {
                depthShifted = true
            }
            withAnimation(.interpolatingSpring(stiffness: 210, damping: 8).repeatForever(autoreverses: true)) {
                centerPulsed = true
            }
        }
    }
}

private struct LaunchSpectrumPulse: View {
    let animates: Bool
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(GlowPalette.blue.opacity(0.28), lineWidth: 1)
                .padding(18)
            Circle()
                .stroke(GlowPalette.violet.opacity(0.24), lineWidth: 1)
                .padding(45)
            Circle()
                .stroke(GlowPalette.rose.opacity(0.20), lineWidth: 1)
                .padding(72)
        }
        .scaleEffect(animates ? (expanded ? 1.08 : 0.95) : 1)
        .opacity(animates ? (expanded ? 0.04 : 0.34) : 0)
        .onAppear {
            guard animates else { return }
            withAnimation(.easeOut(duration: 0.95).repeatForever(autoreverses: false)) {
                expanded = true
            }
        }
    }
}

private struct LaunchLoadingRing: View {
    let animates: Bool
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle().trim(from: 0.00, to: 0.22)
                .stroke(GlowPalette.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            Circle().trim(from: 0.34, to: 0.58)
                .stroke(GlowPalette.violet, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            Circle().trim(from: 0.70, to: 0.94)
                .stroke(GlowPalette.rose, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .frame(width: 34, height: 34)
        .rotationEffect(.degrees(rotation))
        .shadow(color: GlowPalette.violet.opacity(0.55), radius: 5)
        .onAppear {
            guard animates else { return }
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

private struct SoftGlowBackground: View {
    var body: some View {
        ZStack {
            GlowPalette.canvas.ignoresSafeArea()
            Circle().fill(GlowPalette.blue.opacity(0.20)).frame(width: 320).blur(radius: 70).offset(x: -150, y: -280)
            Circle().fill(GlowPalette.rose.opacity(0.19)).frame(width: 340).blur(radius: 80).offset(x: 170, y: -80)
            Circle().fill(GlowPalette.violet.opacity(0.16)).frame(width: 300).blur(radius: 75).offset(x: -120, y: 380)
        }
    }
}

private struct BottomNavigation: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.menuCases, id: \.rawValue) { item in
                Button { selection = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon).font(.system(size: 19, weight: .semibold))
                        Text(item.title).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == item ? GlowPalette.violet : GlowPalette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct HomeView: View {
    @Binding var hidesBottomNavigation: Bool
    @State private var feed = HomeFeedCache.load()
    @State private var isLoading = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppMetrics.pageSpacing) {
                HomeSearchEntry(hidesBottomNavigation: $hidesBottomNavigation)

                if isLoading && feed.isEmpty {
                    ProgressView("正在加载推荐…").frame(maxWidth: .infinity).padding(.vertical, 35)
                } else {
                    ForEach(feed.sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(section.title).font(AppFont.pageTitle)
                                if !section.subtitle.isEmpty {
                                    Text(section.subtitle).font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(section.playlists) { playlist in
                                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                            VStack(alignment: .leading, spacing: 9) {
                                                ZStack(alignment: .topLeading) {
                                                    ArtworkView(url: playlist.coverURL, symbol: playlist.provider.symbol)
                                                        .frame(width: 136, height: 136)
                                                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                                                    Text(playlist.provider.rawValue)
                                                        .font(AppFont.small.weight(.semibold))
                                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                                        .foregroundStyle(.white)
                                                        .background(.black.opacity(0.5), in: Capsule())
                                                        .padding(9)
                                                }
                                                Text(playlist.name).font(AppFont.rowTitle).lineLimit(2, reservesSpace: true)
                                                    .frame(width: 136, alignment: .leading)
                                            }
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    if feed.trendingSongs.isEmpty {
                        EmptyState(icon: "person.crop.circle.badge.plus", title: "登录后获取私人推荐", detail: "PC 与 iOS 共用同一套平台账号和推荐接口")
                    } else {
                        Text("热门歌曲").font(AppFont.pageTitle)
                        LazyVStack(spacing: 4) {
                            ForEach(feed.trendingSongs.prefix(12)) { SongRow(song: $0, queue: feed.trendingSongs) }
                        }
                    }
                }
            }.padding(.horizontal, AppMetrics.pagePadding).padding(.top, 18).padding(.bottom, 150)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if feed.isEmpty { isLoading = true }
        defer { isLoading = false }
        guard let freshFeed = try? await SelfRadioAPI.shared.homeFeed() else { return }
        feed = freshFeed
        HomeFeedCache.save(freshFeed)
    }
}

private struct CatalogView: View {
    @Binding var hidesBottomNavigation: Bool
    @State private var feed = HomeFeedCache.load()
    @State private var isLoading = false

    private var songs: [Song] {
        var seen = Set<String>()
        return (feed.trendingSongs + feed.dailySongs).filter { seen.insert("\($0.provider.apiValue):\($0.id)").inserted }
    }

    private var artists: [Song] {
        var seen = Set<String>()
        return songs.filter { !$0.artist.isEmpty && seen.insert($0.artist).inserted }
    }

    private var albums: [Song] {
        var seen = Set<String>()
        return songs.filter { !$0.album.isEmpty && seen.insert($0.album).inserted }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppMetrics.pageSpacing) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("曲库").font(AppFont.pageTitle)
                    Text("按分类浏览，也可以直接搜索与发现音乐").font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                }

                HomeSearchEntry(hidesBottomNavigation: $hidesBottomNavigation)

                Text("分类").font(AppFont.pageTitle)
                HStack(spacing: 10) {
                    CatalogCategory(title: "排行榜", icon: "chart.bar.fill", query: "热歌榜", hidesBottomNavigation: $hidesBottomNavigation)
                    CatalogCategory(title: "新歌", icon: "sparkles", query: "华语新歌", hidesBottomNavigation: $hidesBottomNavigation)
                    CatalogCategory(title: "经典", icon: "music.note", query: "经典歌曲", hidesBottomNavigation: $hidesBottomNavigation)
                    CatalogCategory(title: "助眠", icon: "moon.zzz.fill", query: "助眠音乐", hidesBottomNavigation: $hidesBottomNavigation)
                }

                if isLoading && feed.isEmpty {
                    ProgressView("正在加载曲库…").frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    if !artists.isEmpty {
                        CatalogSearchRail(title: "歌手", songs: Array(artists.prefix(10)), usesAlbum: false, hidesBottomNavigation: $hidesBottomNavigation)
                    }
                    if !albums.isEmpty {
                        CatalogSearchRail(title: "专辑", songs: Array(albums.prefix(10)), usesAlbum: true, hidesBottomNavigation: $hidesBottomNavigation)
                    }
                    if !feed.playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("推荐歌单").font(AppFont.pageTitle)
                            LazyVStack(spacing: 10) {
                                ForEach(feed.playlists.prefix(6)) { playlist in
                                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) { PlaylistRow(playlist: playlist) }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("全部歌曲").font(AppFont.pageTitle)
                        if songs.isEmpty {
                            EmptyState(icon: "music.note.list", title: "暂无歌曲", detail: "联网刷新或登录音乐平台后显示")
                        } else {
                            LazyVStack(spacing: 4) { ForEach(songs.prefix(30)) { SongRow(song: $0, queue: songs) } }
                        }
                    }
                }
            }.padding(.horizontal, AppMetrics.pagePadding).padding(.top, 18).padding(.bottom, 150)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if feed.isEmpty { isLoading = true }
        defer { isLoading = false }
        guard let freshFeed = try? await SelfRadioAPI.shared.homeFeed() else { return }
        feed = freshFeed
        HomeFeedCache.save(freshFeed)
    }
}

private struct CatalogCategory: View {
    let title: String
    let icon: String
    let query: String
    @Binding var hidesBottomNavigation: Bool

    var body: some View {
        NavigationLink(destination: SearchView(initialQuery: query)
            .onAppear { hidesBottomNavigation = true }
            .onDisappear { hidesBottomNavigation = false }
        ) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(AppFont.caption.weight(.semibold))
            }.frame(maxWidth: .infinity, minHeight: 76).background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
        }.buttonStyle(.plain)
    }
}

private struct CatalogSearchRail: View {
    let title: String
    let songs: [Song]
    let usesAlbum: Bool
    @Binding var hidesBottomNavigation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(AppFont.pageTitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(songs) { song in
                        let query = usesAlbum ? song.album : song.artist
                        NavigationLink(destination: SearchView(initialQuery: query)
                            .onAppear { hidesBottomNavigation = true }
                            .onDisappear { hidesBottomNavigation = false }
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(url: song.artworkURL, symbol: usesAlbum ? "square.stack.fill" : "person.fill")
                                    .frame(width: 112, height: 112).clipShape(RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                                Text(query).font(AppFont.rowTitle).lineLimit(1).frame(width: 112, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let action: String
    let perform: () -> Void
    var body: some View {
        HStack { Text(title).font(AppFont.pageTitle); Spacer(); Button(action, action: perform).font(AppFont.caption.weight(.semibold)).foregroundStyle(GlowPalette.secondary) }
    }
}

private struct FeatureTile: View {
    let title: String; let subtitle: String; let icon: String; let colors: [Color]; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Spacer()
                Text(title).font(AppFont.rowTitle).lineLimit(2)
                Text(subtitle).font(AppFont.caption).opacity(0.8)
            }
            .foregroundStyle(.white).padding(16).frame(maxWidth: .infinity, minHeight: 144, alignment: .leading)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
        }.buttonStyle(.plain)
    }
}

private struct HomeSearchEntry: View {
    @Binding var hidesBottomNavigation: Bool

    var body: some View {
        NavigationLink(destination: SearchView()
            .onAppear { hidesBottomNavigation = true }
            .onDisappear { hidesBottomNavigation = false }
        ) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(GlowPalette.secondary)
                Text("搜索歌曲、歌手或专辑")
                    .font(AppFont.rowTitle)
                    .foregroundStyle(GlowPalette.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(GlowPalette.secondary.opacity(0.7))
            }
            .padding(.horizontal, 17)
            .frame(height: 56)
            .background(GlowPalette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.36)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("SelfRadio.search.history") private var historyRaw = ""
    @State private var query = ""
    @State private var provider: MusicProvider = .netease
    @State private var results: [Song] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hotList: SearchHotList = .popular
    @State private var showDeferredContent = false
    @FocusState private var searchFocused: Bool
    private let initialQuery: String

    init(initialQuery: String = "") {
        self.initialQuery = initialQuery
        _query = State(initialValue: initialQuery)
    }

    private let discoveries = ["周杰伦", "陈奕迅", "华语新歌", "经典粤语", "夜间助眠", "Hi-Res", "国风", "粤语"]
    private let popular = [
        HotSearchItem(title: "晴天", subtitle: "周杰伦 · 长期热播"),
        HotSearchItem(title: "十年", subtitle: "陈奕迅 · 华语经典"),
        HotSearchItem(title: "海阔天空", subtitle: "Beyond · 粤语热搜"),
        HotSearchItem(title: "若月亮没来", subtitle: "本周人气上升"),
        HotSearchItem(title: "唯一", subtitle: "循环播放热门"),
        HotSearchItem(title: "句号", subtitle: "G.E.M.邓紫棋 · 高热播放"),
        HotSearchItem(title: "起风了", subtitle: "买辣椒也用券 · 经典回流"),
        HotSearchItem(title: "稻香", subtitle: "周杰伦 · 治愈热搜"),
    ]
    private let rising = [
        HotSearchItem(title: "暮色回响", subtitle: "新歌热度上升"),
        HotSearchItem(title: "爱错", subtitle: "翻唱热度上升"),
        HotSearchItem(title: "跳楼机", subtitle: "全平台热搜"),
        HotSearchItem(title: "珠玉", subtitle: "热门影视原声"),
        HotSearchItem(title: "大展鸿图", subtitle: "今日搜索增长"),
        HotSearchItem(title: "悬溺", subtitle: "短视频热度上升"),
        HotSearchItem(title: "向云端", subtitle: "治愈系上升"),
        HotSearchItem(title: "可能", subtitle: "本周搜索增长"),
    ]
    private let newSongs = [
        HotSearchItem(title: "华语新歌", subtitle: "每日更新推荐"),
        HotSearchItem(title: "新歌速递", subtitle: "全平台新发行"),
        HotSearchItem(title: "本周新声", subtitle: "独立音乐人"),
        HotSearchItem(title: "影视新歌", subtitle: "近期影视原声"),
        HotSearchItem(title: "说唱新作", subtitle: "中文说唱更新"),
        HotSearchItem(title: "电子新声", subtitle: "氛围电子精选"),
        HotSearchItem(title: "民谣新歌", subtitle: "安静听歌"),
        HotSearchItem(title: "流行新碟", subtitle: "新专辑热搜"),
    ]
    private let sleepSongs = [
        HotSearchItem(title: "夜间助眠", subtitle: "睡前轻听"),
        HotSearchItem(title: "白噪音", subtitle: "专注与放松"),
        HotSearchItem(title: "雨声钢琴", subtitle: "低干扰背景"),
        HotSearchItem(title: "冥想音乐", subtitle: "平静呼吸"),
        HotSearchItem(title: "Lo-Fi", subtitle: "学习工作背景"),
        HotSearchItem(title: "轻音乐", subtitle: "舒缓纯音"),
        HotSearchItem(title: "自然声", subtitle: "森林海浪"),
        HotSearchItem(title: "睡前故事", subtitle: "播客助眠"),
    ]

    private var history: [String] {
        historyRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private var universeCandidate: Song? {
        let target = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let exact = results.first { song in
            guard let artistId = song.artistId, !artistId.isEmpty else { return false }
            return song.artist
                .split(separator: "/")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .contains(target)
        }
        return exact ?? results.first(where: { ($0.artistId ?? "").isEmpty == false })
    }

    private var universeArtistName: String {
        let target = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if universeCandidate?.artist.split(separator: "/").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).contains(target) == true {
            return target
        }
        return universeCandidate?.artist ?? target
    }

    var body: some View {
        ZStack {
            SoftGlowBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 44, height: 48)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(GlowPalette.secondary)
                            TextField("搜索歌曲、歌手、专辑", text: $query)
                                .focused($searchFocused)
                                .submitLabel(.search)
                                .onSubmit { Task { await search() } }
                            if !query.isEmpty {
                                Button { query = ""; results = []; errorMessage = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 48)
                        .background(GlowPalette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                        .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.30)))

                        Button("搜索") { Task { await search() } }
                            .font(AppFont.rowTitle.weight(.semibold))
                            .frame(width: 48, height: 48)
                            .buttonStyle(.plain)
                    }

                    HStack(spacing: 0) {
                        ForEach(MusicProvider.allCases) { item in
                            Button {
                                provider = item
                                if !query.isEmpty { Task { await search() } }
                            } label: {
                            Label(item.rawValue, systemImage: item.symbol)
                                    .font(AppFont.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 38)
                                    .foregroundStyle(provider == item ? GlowPalette.violet : GlowPalette.secondary)
                                    .background(provider == item ? GlowPalette.violet.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(GlowPalette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                    .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.22)))

                    if isLoading {
                        ProgressView("正在搜索 \(provider.rawValue)…")
                            .frame(maxWidth: .infinity).padding(.vertical, 70)
                    } else if let errorMessage {
                        EmptyState(icon: "wifi.exclamationmark", title: "搜索失败", detail: errorMessage)
                    } else if results.isEmpty {
                        SearchShortcutGrid(action: search)

                        if showDeferredContent && !history.isEmpty {
                            SearchSuggestionStrip(title: "搜索历史", items: Array(history.prefix(8))) {
                                historyRaw = ""
                            } action: {
                                search($0)
                            }
                        }

                        if showDeferredContent {
                            SearchSuggestionStrip(title: "搜索发现", items: discoveries, action: search)

                            HotSearchPanel(selection: $hotList, popular: popular, rising: rising, newSongs: newSongs, sleepSongs: sleepSongs, action: search)
                        }
                    } else {
                        if provider == .netease, universeCandidate != nil {
                            NavigationLink(destination: ArtistUniverseView(artistName: universeArtistName)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkles.tv")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(GlowPalette.violet)
                                        .frame(width: 42, height: 42)
                                        .background(GlowPalette.violet.opacity(0.14), in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("打开 \(universeArtistName) 音乐宇宙")
                                            .font(AppFont.rowTitle.weight(.semibold))
                                        Text("查看历史专辑与全部歌曲")
                                            .font(AppFont.caption)
                                            .foregroundStyle(GlowPalette.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(GlowPalette.secondary)
                                }
                                .padding(14)
                                .background(GlowPalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                                .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.violet.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            Text("搜索结果").font(AppFont.pageTitle)
                            Spacer()
                            Text("\(provider.rawValue) · \(results.count) 首")
                                .font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                        }
                        LazyVStack(spacing: 4) {
                            ForEach(results) { SongRow(song: $0, queue: results) }
                        }
                    }
                }
                .padding(.horizontal, AppMetrics.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if !showDeferredContent {
                try? await Task.sleep(nanoseconds: 80_000_000)
                showDeferredContent = true
            }
            if !initialQuery.isEmpty && results.isEmpty { await search() }
        }
    }

    private func search(_ value: String) {
        query = value
        Task { await search() }
    }

    private func search() async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        query = keyword
        saveHistory(keyword)
        isLoading = true; errorMessage = nil
        do { results = try await SelfRadioPlatformService(provider: provider).search(keyword) }
        catch { results = []; errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func saveHistory(_ keyword: String) {
        var values = history.filter { $0.caseInsensitiveCompare(keyword) != .orderedSame }
        values.insert(keyword, at: 0)
        historyRaw = values.prefix(8).joined(separator: "\n")
    }
}

private struct SearchShortcut: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(GlowPalette.elevatedSurface, in: Circle())
                Text(title).font(AppFont.caption.weight(.semibold))
            }
            .foregroundStyle(GlowPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchShortcutGrid: View {
    let action: (String) -> Void
    private let items = [
        ("歌手", "person.2.fill", "热门歌手"),
        ("热歌榜", "chart.bar.fill", "热歌"),
        ("新歌", "sparkles", "华语新歌"),
        ("助眠", "moon.zzz.fill", "助眠音乐")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                SearchShortcut(title: items[index].0, symbol: items[index].1) {
                    action(items[index].2)
                }
                if index < items.count - 1 {
                    Divider().frame(height: 34)
                }
            }
        }
        .padding(.vertical, 8)
        .background(GlowPalette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.22)))
    }
}

private struct SearchSectionTitle: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(AppFont.sectionTitle).foregroundStyle(GlowPalette.secondary)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: "trash")
                        .foregroundStyle(GlowPalette.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum SearchHotList: String, CaseIterable, Identifiable {
    case popular = "热门"
    case rising = "上升"
    case newSongs = "新歌"
    case sleep = "助眠"
    var id: String { rawValue }
}

private struct HotSearchItem: Identifiable {
    let title: String
    let subtitle: String
    var id: String { title }
}

private struct HotSearchPanel: View {
    @Binding var selection: SearchHotList
    let popular: [HotSearchItem]
    let rising: [HotSearchItem]
    let newSongs: [HotSearchItem]
    let sleepSongs: [HotSearchItem]
    let action: (String) -> Void

    private var activeItems: [HotSearchItem] {
        switch selection {
        case .popular: Array(popular.prefix(8))
        case .rising: Array(rising.prefix(8))
        case .newSongs: Array(newSongs.prefix(8))
        case .sleep: Array(sleepSongs.prefix(8))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("热搜榜").font(AppFont.pageTitle)
                Spacer()
                Text("\(activeItems.count) 首")
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchHotList.allCases) { item in
                        Button {
                            selection = item
                        } label: {
                            Text(item.rawValue)
                                .font(AppFont.caption.weight(.semibold))
                                .foregroundStyle(selection == item ? GlowPalette.ink : GlowPalette.secondary)
                                .padding(.horizontal, 13)
                                .frame(height: 32)
                                .background(selection == item ? GlowPalette.elevatedSurface : GlowPalette.elevatedSurface.opacity(0.35), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)

            VStack(spacing: 0) {
                ForEach(Array(activeItems.enumerated()), id: \.element.id) { index, item in
                    Button { action(item.title) } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(AppFont.rowTitle.monospacedDigit())
                                .foregroundStyle(index < 3 ? GlowPalette.rose : GlowPalette.secondary)
                                .frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(AppFont.rowTitle).lineLimit(1)
                                Text(item.subtitle).font(AppFont.small).foregroundStyle(GlowPalette.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if item.id != activeItems.last?.id {
                        Divider().padding(.leading, 34)
                    }
                }
            }
        }
        .padding(16)
        .background(GlowPalette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.36)))
    }
}

private struct SearchSuggestionStrip: View {
    let title: String
    let items: [String]
    var clearAction: (() -> Void)? = nil
    let action: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(GlowPalette.secondary)
                .frame(width: 62, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button { action(item) } label: {
                            Text(item)
                                .font(AppFont.caption)
                                .foregroundStyle(GlowPalette.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(GlowPalette.violet.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
            if let clearAction {
                Button(action: clearAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(GlowPalette.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索历史")
            }
        }
        .frame(minHeight: 36)
    }
}

private struct FlowSuggestions: View {
    let items: [String]; let action: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Button { action(item) } label: {
                            Text(item)
                                .font(AppFont.caption)
                                .foregroundStyle(GlowPalette.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(GlowPalette.violet.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct LibraryView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(PlayerStore.self) private var player
    @State private var playlists: [MusicPlaylist] = []
    @State private var provider: MusicProvider = .qq
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var accounts = accounts
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageTitle("我的歌单", subtitle: "已连接平台的收藏与自建歌单")

                if !player.favoritePlaylists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("我的收藏").font(AppFont.pageTitle)
                        ForEach(player.favoritePlaylists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                PlaylistRow(playlist: playlist)
                            }.buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(MusicProvider.allCases) { item in
                        Button {
                            provider = item
                            Task { await load() }
                        } label: {
                            Label(item.rawValue, systemImage: item.symbol)
                                .font(AppFont.caption.weight(.semibold)).padding(.horizontal, 12).frame(height: 36)
                                .foregroundStyle(provider == item ? .white : GlowPalette.ink)
                                .background(provider == item ? GlowPalette.violet : GlowPalette.surface, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }

                HStack { Text("\(provider.rawValue)歌单").font(AppFont.pageTitle); Spacer(); Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") } }
                if isLoading { ProgressView().frame(maxWidth: .infinity).padding(50) }
                else if !accounts.status(for: provider).playbackReady {
                    LoginPrompt(provider: provider.rawValue, detail: "登录后同步喜欢、收藏与自建歌单") {
                        if provider == .qq { accounts.showingQQLogin = true }
                        else if provider == .netease { accounts.showingNeteaseLogin = true }
                        else { accounts.showingQishuiLogin = true }
                    }
                } else if let errorMessage { EmptyState(icon: "exclamationmark.triangle", title: "歌单加载失败", detail: errorMessage) }
                else if playlists.isEmpty { EmptyState(icon: "music.note.list", title: "还没有歌单", detail: "刷新或去平台创建一个歌单") }
                else {
                    LazyVStack(spacing: 12) {
                        ForEach(playlists) { playlist in NavigationLink(destination: PlaylistDetailView(playlist: playlist)) { PlaylistRow(playlist: playlist) }.buttonStyle(.plain) }
                    }
                }
            }.padding(.horizontal, AppMetrics.pagePadding).padding(.top, 18).padding(.bottom, 150)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $accounts.showingQQLogin, onDismiss: { Task { await load() } }) { QQLoginView() }
        .sheet(isPresented: $accounts.showingNeteaseLogin, onDismiss: { Task { await load() } }) { NeteaseLoginView() }
        .sheet(isPresented: $accounts.showingQishuiLogin, onDismiss: { Task { await load() } }) { QishuiLoginView() }
        .alert("提示", isPresented: Binding(get: { accounts.errorMessage != nil }, set: { if !$0 { accounts.errorMessage = nil } })) {
            Button("知道了") { accounts.errorMessage = nil }
        } message: { Text(accounts.errorMessage ?? "") }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        await accounts.refreshAll()
        guard accounts.status(for: provider).playbackReady else { playlists = []; isLoading = false; return }
        do { playlists = try await SelfRadioAPI.shared.playlists(for: provider) }
        catch { playlists = []; errorMessage = error.localizedDescription }
        isLoading = false
    }
}

private struct LibraryShortcut: View {
    let title: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(color); Text(title).font(AppFont.caption.weight(.semibold)).lineLimit(1) }
            .padding(14).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
    }
}

private struct LoginPrompt: View {
    let provider: String; let detail: String; let action: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 34)).foregroundStyle(GlowPalette.violet)
            Text("连接\(provider)").font(AppFont.rowTitle); Text(detail).font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
            Button("去登录", action: action).buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }.frame(maxWidth: .infinity).padding(24).background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
    }
}

private struct PlaylistDetailView: View {
    @Environment(PlayerStore.self) private var player
    let playlist: MusicPlaylist
    @State private var tracks: [Song] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            SoftGlowBackground()
            ScrollView {
                VStack(spacing: 20) {
                    PlaylistHeroHeader(playlist: playlist)
                    PlaylistActionBar(
                        playlist: playlist,
                        isFavorite: player.isFavoritePlaylist(playlist),
                        play: { if let first = tracks.first { player.play(first, queue: tracks) } },
                        toggleFavorite: { player.toggleFavoritePlaylist(playlist) }
                    )
                    if isLoading { ProgressView().padding(40) }
                    else if let errorMessage { EmptyState(icon: "wifi.exclamationmark", title: "加载失败", detail: errorMessage) }
                    else { LazyVStack(spacing: 4) { ForEach(tracks) { PlaylistSongRow(song: $0, queue: tracks) } } }
                }.padding(AppMetrics.pagePadding).padding(.bottom, 80)
            }
        }.navigationBarTitleDisplayMode(.inline).task { await load() }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do { tracks = try await SelfRadioAPI.shared.playlistTracks(playlist) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

private struct PlaylistHeroHeader: View {
    let playlist: MusicPlaylist

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack(alignment: .topLeading) {
                ArtworkView(url: playlist.coverURL, symbol: "music.note.list")
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 6)

                Text("歌单 · \(playlist.provider.rawValue)")
                    .font(AppFont.small.weight(.semibold))
                    .tracking(0.45)
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.44), in: Capsule())
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(playlist.name)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text([playlist.creator, "\(playlist.trackCount) 首", playlist.provider.rawValue].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
                if !playlist.summary.isEmpty {
                    Text(playlist.summary)
                        .font(AppFont.caption)
                        .foregroundStyle(GlowPalette.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

private struct PlaylistActionBar: View {
    let playlist: MusicPlaylist
    let isFavorite: Bool
    let play: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: play) {
                HStack(spacing: 13) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(GlowPalette.violet, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("播放全部").font(AppFont.pageTitle)
                        Text("\(playlist.trackCount) 首").font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isFavorite ? GlowPalette.rose : GlowPalette.ink)
                    .frame(width: 48, height: 48)
                    .background(GlowPalette.elevatedSurface.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "取消收藏歌单" : "收藏歌单")
        }
        .padding(12)
        .background(GlowPalette.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(GlowPalette.separator.opacity(0.22)))
    }
}

private struct PlaylistSongRow: View {
    @Environment(PlayerStore.self) private var player
    let song: Song
    let queue: [Song]

    var body: some View {
        HStack(spacing: 8) {
            Button { player.play(song, queue: queue) } label: {
                HStack(spacing: 13) {
                    ArtworkView(url: song.artworkURL, symbol: song.provider.symbol)
                        .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title).font(AppFont.rowTitle).lineLimit(1)
                        Text("\(song.artist) · \(song.provider.rawValue)").font(AppFont.caption).foregroundStyle(GlowPalette.secondary).lineLimit(1)
                    }
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)

            Menu {
                Button { player.playNext(song) } label: { Label("下一首播放", systemImage: "text.insert") }
                Button { player.enqueue(song) } label: { Label("加入播放队列", systemImage: "text.badge.plus") }
                Button { player.toggleFavorite(song) } label: {
                    Label(player.isFavorite(song) ? "取消我的喜欢" : "添加到我的喜欢", systemImage: player.isFavorite(song) ? "heart.slash" : "heart")
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 40, height: 40).contentShape(Rectangle())
            }
        }.frame(minHeight: AppMetrics.rowHeight)
    }
}

private struct ProfileView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AccountStore.self) private var accounts
    @AppStorage("SelfRadio.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @Binding var hidesBottomNavigation: Bool

    private var readyCount: Int {
        [accounts.qq, accounts.netease, accounts.qishui].filter(\.playbackReady).count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Text("我的").font(.system(size: 30, weight: .bold))
                    Spacer()
                    NavigationLink(destination: PlatformAccountsView()) {
                        ZStack {
                            Circle().stroke(GlowPalette.violet.opacity(0.65), lineWidth: 1.5)
                            Image(systemName: "waveform")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(GlowPalette.violet)
                        }
                        .frame(width: 46, height: 46)
                        .accessibilityLabel("平台账号，已连接 \(readyCount) 个")
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    NavigationLink(destination: PersonalSongsView(kind: .favorites)) {
                        ProfileQuickAccess(icon: "heart.fill", title: "我的喜欢", value: player.favoriteSongs.count, color: GlowPalette.rose)
                    }
                    NavigationLink(destination: PersonalSongsView(kind: .recent)) {
                        ProfileQuickAccess(icon: "clock", title: "最近播放", value: player.recentSongs.count, color: GlowPalette.blue)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("最近常听").font(AppFont.pageTitle)
                        Spacer()
                        NavigationLink(destination: PersonalSongsView(kind: .recent)) {
                            HStack(spacing: 5) {
                                Text("查看全部").font(AppFont.caption)
                                Image(systemName: "chevron.right").font(AppFont.caption)
                            }
                            .foregroundStyle(GlowPalette.secondary)
                        }
                    }

                    if player.recentSongs.isEmpty {
                        Text("播放过的歌曲会出现在这里")
                            .font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(player.recentSongs.prefix(3))) { song in
                                    ProfileRecentSongCard(song: song)
                                }
                            }
                        }
                        .contentMargins(.horizontal, 0, for: .scrollContent)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("我的歌单").font(AppFont.pageTitle)
                        Spacer()
                        NavigationLink(destination: LibraryView()) {
                            HStack(spacing: 5) {
                                Text("查看全部").font(AppFont.caption)
                                Image(systemName: "chevron.right").font(AppFont.caption)
                            }
                            .foregroundStyle(GlowPalette.secondary)
                        }
                    }

                    if player.favoritePlaylists.isEmpty {
                        NavigationLink(destination: LibraryView()) {
                            Label("还没有收藏歌单", systemImage: "music.note.list")
                                .font(AppFont.rowTitle).foregroundStyle(GlowPalette.secondary)
                                .frame(maxWidth: .infinity, minHeight: 76)
                                .background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(player.favoritePlaylists.prefix(5))) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    ProfilePlaylistRow(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                                if playlist.id != player.favoritePlaylists.prefix(5).last?.id {
                                    Divider().padding(.leading, 74)
                                }
                            }
                        }
                    }
                }

                DisclosureGroup {
                    VStack(spacing: 0) {
                        NavigationLink(destination: PlaybackSettingsView()
                            .onAppear { hidesBottomNavigation = true }
                            .onDisappear { hidesBottomNavigation = false }
                        ) {
                            ProfileRow(icon: "waveform", title: "播放与音质", color: GlowPalette.violet)
                        }
                        ProfileDivider()
                        NavigationLink(destination: VisualSettingsView()) {
                            ProfileRow(icon: "sparkles", title: "播放动效", color: GlowPalette.violet)
                        }
                        ProfileDivider()
                        HStack(spacing: 12) {
                            Image(systemName: "circle.lefthalf.filled").foregroundStyle(GlowPalette.violet).frame(width: 28)
                            Text("外观").font(AppFont.rowTitle)
                            Spacer()
                            Picker("外观", selection: $appearanceRaw) {
                                ForEach(AppAppearance.allCases) { Text($0.rawValue).tag($0.rawValue) }
                            }
                            .pickerStyle(.segmented).frame(width: 174)
                        }
                        .padding(.horizontal, 16).frame(minHeight: AppMetrics.rowHeight)
                    }
                    .buttonStyle(.plain)
                    .background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                } label: {
                    Text("偏好设置").font(AppFont.caption.weight(.semibold)).foregroundStyle(GlowPalette.secondary)
                }

                Label("数据本地加密存储 · 隐私保护中", systemImage: "lock")
                    .font(.system(size: 11))
                    .foregroundStyle(GlowPalette.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 150)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await accounts.refreshAll() }
    }
}

private struct ProfileQuickAccess: View {
    let icon: String
    let title: String
    let value: Int
    let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppFont.rowTitle).lineLimit(1)
                Text("\(value)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            LinearGradient(
                colors: [color.opacity(0.13), GlowPalette.surface.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.groupRadius)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

private struct ProfileRecentSongCard: View {
    @Environment(PlayerStore.self) private var player
    let song: Song
    var body: some View {
        Button { player.play(song, queue: player.recentSongs) } label: {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(url: song.artworkURL, symbol: song.provider.symbol)
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 34, height: 34).background(.black.opacity(0.62), in: Circle()).padding(8)
                    }
                Text(song.title).font(AppFont.rowTitle).lineLimit(1)
                Text(song.artist).font(AppFont.caption).foregroundStyle(GlowPalette.secondary).lineLimit(1)
            }
            .frame(width: 108, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfilePlaylistRow: View {
    let playlist: MusicPlaylist
    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: playlist.coverURL, symbol: "music.note.list")
                .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(playlist.name)
                    .font(AppFont.rowTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(playlist.trackCount) 首 · \(playlist.provider.rawValue)")
                    .font(AppFont.caption).foregroundStyle(GlowPalette.secondary).lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(GlowPalette.secondary)
                .frame(width: 20)
        }
        .frame(minHeight: 78).contentShape(Rectangle())
    }
}

private struct PlatformConnectionSummary: View {
    let accounts: AccountStore
    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(MusicProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                let status = accounts.status(for: provider)
                HStack(spacing: 5) {
                    Circle().fill(status.playbackReady ? Color.green : GlowPalette.secondary).frame(width: 6, height: 6)
                    Text(provider.rawValue).font(AppFont.small).foregroundStyle(GlowPalette.secondary)
                }
                if index < MusicProvider.allCases.count - 1 { Text("·").foregroundStyle(GlowPalette.secondary) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(AppFont.small).foregroundStyle(GlowPalette.secondary)
        }
        .frame(minHeight: 38).contentShape(Rectangle())
    }
}

private struct ProfileRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title).font(AppFont.rowTitle)
            Spacer()
            if let value {
                Text(value)
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
            }
            Image(systemName: "chevron.right")
                .font(AppFont.caption.weight(.semibold))
                .foregroundStyle(GlowPalette.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: AppMetrics.rowHeight)
        .contentShape(Rectangle())
    }
}

private struct ProfileDivider: View {
    var body: some View {
        Divider().padding(.leading, 56)
    }
}

private enum PersonalCollectionKind {
    case recent, favorites

    var title: String { self == .recent ? "最近播放" : "我的喜欢" }
    var icon: String { self == .recent ? "clock.fill" : "heart.fill" }
}

private struct PersonalSongsView: View {
    @Environment(PlayerStore.self) private var player
    let kind: PersonalCollectionKind

    private var songs: [Song] { kind == .recent ? player.recentSongs : player.favoriteSongs }

    var body: some View {
        ZStack {
            SoftGlowBackground()
            ScrollView(showsIndicators: false) {
                if songs.isEmpty {
                    EmptyState(
                        icon: kind.icon,
                        title: "还没有\(kind.title)",
                        detail: kind == .recent ? "播放过的歌曲会自动出现在这里" : "在播放页点击爱心即可收藏"
                    )
                    .padding(.top, 90)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(songs) { SongRow(song: $0, queue: songs) }
                    }
                    .padding(AppMetrics.pagePadding)
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlatformAccountsView: View {
    @Environment(AccountStore.self) private var accounts
    var body: some View {
        @Bindable var accounts = accounts
        ZStack {
            SoftGlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("连接后可同步收藏、歌单和播放内容。")
                        .font(AppFont.caption).foregroundStyle(GlowPalette.secondary).padding(.bottom, 6)
                    AccountRow(provider: .qq, account: accounts.qq) { accounts.showingQQLogin = true } logout: { Task { await accounts.logout(provider: .qq) } }
                    AccountRow(provider: .netease, account: accounts.netease) { accounts.showingNeteaseLogin = true } logout: { Task { await accounts.logout(provider: .netease) } }
                    AccountRow(provider: .qishui, account: accounts.qishui) { accounts.showingQishuiLogin = true } logout: { Task { await accounts.logout(provider: .qishui) } }
                }.padding(AppMetrics.pagePadding)
            }
        }
        .navigationTitle("音乐平台").navigationBarTitleDisplayMode(.inline)
        .task { await accounts.refreshAll() }
        .sheet(isPresented: $accounts.showingQQLogin) { QQLoginView() }
        .sheet(isPresented: $accounts.showingNeteaseLogin) { NeteaseLoginView() }
        .sheet(isPresented: $accounts.showingQishuiLogin) { QishuiLoginView() }
        .alert("还未完成", isPresented: Binding(get: { accounts.errorMessage != nil }, set: { if !$0 { accounts.errorMessage = nil } })) { Button("知道了") {} } message: { Text(accounts.errorMessage ?? "") }
    }
}

private struct AccountRow: View {
    let provider: MusicProvider; let account: PlatformAccountStatus; let action: () -> Void; let logout: () -> Void
    private var connected: Bool { account.loggedIn || account.playbackReady }
    var body: some View {
        HStack(spacing: 15) {
            Button(action: action) {
                HStack(spacing: 15) {
                    Image(systemName: provider.symbol).font(.system(size: 18, weight: .medium)).frame(width: 44, height: 44).background(GlowPalette.violet.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 5) { Text(provider.rawValue).font(AppFont.rowTitle); Text(account.playbackReady ? "已连接 · 可播放" : account.detail).font(AppFont.caption).foregroundStyle(GlowPalette.secondary) }
                    Spacer(); Image(systemName: account.playbackReady ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(account.playbackReady ? .green : GlowPalette.secondary)
                }
            }.buttonStyle(.plain)
            if connected {
                Button("退出登录", action: logout)
                    .font(AppFont.caption.weight(.semibold))
                    .foregroundStyle(GlowPalette.rose)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(GlowPalette.rose.opacity(0.10), in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: AppMetrics.rowHeight)
        .background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
    }
}

private struct PlaybackSettingsView: View {
    @Environment(PlayerStore.self) private var player
    @State private var lyricSyncExpanded = false
    private let primaryQualities: [PlaybackQuality] = [.smart, .standard, .high, .lossless]

    var body: some View {
        @Bindable var player = player
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PlaybackQualityHeroCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("音质选择").font(AppFont.pageTitle)
                    HStack(spacing: 8) {
                        ForEach(primaryQualities) { quality in
                            QualityOptionButton(quality: quality, isSelected: player.qualityPreference == quality) {
                                player.applyQualityPreference(quality)
                            }
                        }
                    }
                    Label("受平台授权和账号状态影响", systemImage: "info.circle")
                        .font(AppFont.caption)
                        .foregroundStyle(GlowPalette.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("播放策略").font(AppFont.pageTitle)
                    VStack(spacing: 0) {
                        PlaybackToggleRow(title: "严格匹配换源", subtitle: "无法播放时匹配同一首歌的可用音源", icon: "arrow.triangle.2.circlepath", isOn: $player.automaticSourceFallback)
                    }
                    .background(GlowPalette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                    .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.30)))
                }

                if let notice = player.playbackNotice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(AppFont.caption)
                        .foregroundStyle(.orange)
                }

                DisclosureGroup(isExpanded: $lyricSyncExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: $player.lyricOffset, in: -5...5, step: 0.1)
                        HStack {
                            Text("正值表示歌词提前显示").font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                            Spacer()
                            Button("重置") { player.resetLyricOffset() }
                                .font(AppFont.caption.weight(.semibold))
                                .foregroundStyle(GlowPalette.violet)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Label("歌词同步", systemImage: "text.line.first.and.arrowtriangle.forward")
                        Spacer()
                        Text(String(format: "%+.1f 秒", player.lyricOffset))
                            .font(AppFont.caption.monospacedDigit())
                            .foregroundStyle(GlowPalette.secondary)
                    }
                }
                .font(AppFont.rowTitle)
                .tint(GlowPalette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(GlowPalette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.30)))

                Text("切换后会重新获取当前音源；部分固定音源无法切换。")
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
            }
            .padding(.horizontal, AppMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(SoftGlowBackground())
        .navigationTitle("播放与音质")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlaybackQualityHeroCard: View {
    @Environment(PlayerStore.self) private var player

    private var qualityTitle: String {
        guard let quality = player.playbackQuality else { return player.qualityPreference.rawValue }
        let codec = quality.codec.isEmpty ? "" : " \(quality.codec.uppercased())"
        return "\(quality.label)\(codec)"
    }

    private var qualitySubtitle: String {
        guard let quality = player.playbackQuality else { return "播放后显示实际可用规格" }
        var parts: [String] = []
        if quality.bitrate > 0 { parts.append("\(Int(round(Double(quality.bitrate) / 1000)))kbps") }
        if quality.sampleRate > 0 { parts.append("\(quality.sampleRate / 1000)kHz") }
        if quality.bitDepth > 0 { parts.append("\(quality.bitDepth)bit") }
        if quality.trial { parts.append("试听") }
        return parts.isEmpty ? "当前音源已连接" : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ArtworkView(url: player.current?.artworkURL, symbol: "music.note")
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.current?.title ?? "尚未开始播放")
                        .font(.system(size: 19, weight: .semibold))
                        .lineLimit(1)
                    Text(player.current?.artist ?? "播放歌曲后显示实际音质")
                        .font(AppFont.rowTitle)
                        .foregroundStyle(GlowPalette.secondary)
                        .lineLimit(1)
                    Label(player.playbackProvider?.rawValue ?? player.current?.provider.rawValue ?? "未连接音源", systemImage: "music.note.list")
                        .font(AppFont.caption)
                        .foregroundStyle(GlowPalette.secondary)
                }
                Spacer(minLength: 8)
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(GlowPalette.violet, in: Circle())
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(GlowPalette.separator.opacity(0.45))
            VStack(alignment: .leading, spacing: 5) {
                Text("当前音质").font(AppFont.caption).foregroundStyle(GlowPalette.secondary)
                Text(qualityTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(GlowPalette.violet)
                Text(qualitySubtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
            }
        }
        .padding(18)
        .background(GlowPalette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(GlowPalette.separator.opacity(0.35)))
    }
}

private struct QualityOptionButton: View {
    let quality: PlaybackQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(quality.rawValue).font(AppFont.rowTitle.weight(.semibold))
                Text(quality == .smart ? "自动匹配" : quality == .standard ? "128K" : quality == .high ? "MP3" : "FLAC")
                    .font(AppFont.small)
                    .foregroundStyle(isSelected ? .white.opacity(0.78) : GlowPalette.secondary)
            }
            .foregroundStyle(isSelected ? .white : GlowPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isSelected ? GlowPalette.violet : GlowPalette.elevatedSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择音质：\(quality.rawValue)")
    }
}

private struct PlaybackToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .foregroundStyle(GlowPalette.violet)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(AppFont.rowTitle)
                    Text(subtitle).font(AppFont.caption).foregroundStyle(GlowPalette.secondary).lineLimit(1)
                }
            }
        }
        .tint(GlowPalette.violet)
        .padding(.horizontal, 16)
        .frame(minHeight: 68)
    }
}

private struct VisualSettingsView: View {
    @Environment(PlayerStore.self) private var player
    var body: some View {
        @Bindable var player = player
        Form {
            Section("现在播放") {
                Picker("视觉预设", selection: $player.visualStyle) {
                    ForEach(PlayerVisualStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("歌词样式", selection: $player.lyricDisplayStyle) {
                    ForEach(LyricDisplayStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                NavigationLink(destination: ArtworkStyleGalleryView()) {
                    HStack {
                        Label("播放页展示", systemImage: "rectangle.3.group.fill")
                        Spacer()
                        Text(player.artworkPresentation.title)
                            .foregroundStyle(GlowPalette.secondary)
                    }
                }
                Toggle("播放页动效", isOn: $player.playbackMotionEnabled)
                Toggle("封面主色流光", isOn: $player.coverGlowEnabled)
                Toggle("歌词动效", isOn: $player.lyricMotionEnabled)
                Toggle("律动粒子", isOn: $player.particleVisualEnabled)
            }
            Section {
                Text("粒子限制为 20 帧并控制数量；低电量、减少动态效果或进入后台时自动暂停。关闭后保留静态界面，进一步降低耗电。")
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
            }
        }.scrollContentBackground(.hidden).background(SoftGlowBackground()).navigationTitle("播放动效")
    }
}

private struct ArtworkStyleGalleryView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("选择展示方式")
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(GlowPalette.ink)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 22) {
                    ForEach(PlayerArtworkPresentation.allCases) { style in
                        ArtworkStyleCard(style: style, isSelected: player.artworkPresentation == style) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                player.artworkPresentation = style
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(SoftGlowBackground())
        .navigationTitle("播放页展示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}

private struct ArtworkStyleCard: View {
    let style: PlayerArtworkPresentation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ArtworkStylePreview(style: style)
                    .frame(height: 184)
                    .frame(maxWidth: .infinity)
                    .background(GlowPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white, GlowPalette.violet)
                                .padding(10)
                                .accessibilityLabel("已选中")
                        }
                    }
                Text(style.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GlowPalette.ink)
                Text(style.subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .topLeading)
            }
            .padding(7)
            .background(isSelected ? GlowPalette.violet.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(isSelected ? GlowPalette.violet : GlowPalette.separator.opacity(0.35), lineWidth: isSelected ? 1.6 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(style.title)")
        .accessibilityValue(isSelected ? "当前已选" : "")
    }
}

private struct ArtworkStylePreview: View {
    let style: PlayerArtworkPresentation

    var body: some View {
        ZStack {
            previewBackground
            ArtworkPresentationVisual(style: style, artworkURL: nil, isPreview: true)
                .padding(style == .cover ? 20 : 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(style == .cover ? "随心听" : "NOW PLAYING")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .padding(12)
        }
    }

    @ViewBuilder private var previewBackground: some View {
        switch style {
        case .cover:
            LinearGradient(colors: [GlowPalette.blue.opacity(0.92), GlowPalette.violet.opacity(0.82), GlowPalette.rose.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vinyl:
            LinearGradient(colors: [Color(red: 0.30, green: 0.05, blue: 0.10), Color(red: 0.09, green: 0.04, blue: 0.11)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct SettingsCard: View {
    let icon: String; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(GlowPalette.violet).frame(width: 44, height: 44).background(GlowPalette.elevatedSurface, in: Circle())
            VStack(alignment: .leading, spacing: 5) { Text(title).font(AppFont.rowTitle); Text(detail).font(AppFont.caption).foregroundStyle(GlowPalette.secondary) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(GlowPalette.secondary)
        }.padding(.horizontal, 16).frame(minHeight: AppMetrics.rowHeight).background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
    }
}

private struct PageTitle: View {
    let title: String; let subtitle: String
    init(_ title: String, subtitle: String) { self.title = title; self.subtitle = subtitle }
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(AppFont.pageTitle); Text(subtitle).font(AppFont.caption).foregroundStyle(GlowPalette.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }
}

private struct PlaylistRow: View {
    let playlist: MusicPlaylist
    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: playlist.coverURL, symbol: "music.note.list").frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) { Text(playlist.name).font(AppFont.rowTitle).lineLimit(1); Text("\(playlist.trackCount) 首 · \(playlist.provider.rawValue)").font(AppFont.caption).foregroundStyle(GlowPalette.secondary) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(GlowPalette.secondary)
        }.padding(.horizontal, 16).frame(minHeight: AppMetrics.rowHeight).background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
    }
}

private struct SongRow: View {
    @Environment(PlayerStore.self) private var player
    let song: Song; var queue: [Song] = Song.previews
    var body: some View {
        Button { player.play(song, queue: queue) } label: {
            HStack(spacing: 13) {
                ArtworkView(url: song.artworkURL, symbol: song.provider.symbol).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) { Text(song.title).font(AppFont.rowTitle).lineLimit(1); Text("\(song.artist) · \(song.provider.rawValue)").font(AppFont.caption).foregroundStyle(GlowPalette.secondary).lineLimit(1) }
                Spacer(); Image(systemName: "play.fill").foregroundStyle(GlowPalette.secondary).frame(width: 36, height: 36)
            }.frame(minHeight: AppMetrics.rowHeight).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private actor ArtworkImageCache {
    static let shared = ArtworkImageCache()
    private static let maxPixelSize = 320

    private let memory = NSCache<NSURL, UIImage>()
    private let directory: URL
    private var inFlight: [String: Task<Data?, Never>] = [:]

    private init() {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = root.appendingPathComponent("SelfRadioArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 160
        memory.totalCostLimit = 40 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        let cacheKey = url as NSURL
        if let image = memory.object(forKey: cacheKey) { return image }

        let fileURL = directory.appendingPathComponent(fileName(for: url))
        if let data = try? Data(contentsOf: fileURL), let image = decodeImage(data) {
            memory.setObject(image, forKey: cacheKey, cost: imageCost(image))
            return image
        }

        let key = url.absoluteString
        let task: Task<Data?, Never>
        if let existing = inFlight[key] {
            task = existing
        } else {
            task = Task {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 15
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      decodeImage(data) != nil else { return nil }
                return data
            }
            inFlight[key] = task
        }

        let data = await task.value
        inFlight[key] = nil
        guard let data, let image = decodeImage(data) else { return nil }
        memory.setObject(image, forKey: cacheKey, cost: imageCost(image))
        try? data.write(to: fileURL, options: .atomic)
        return image
    }

    private func decodeImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private func imageCost(_ image: UIImage) -> Int {
        Int(image.size.width * image.size.height * 4.0)
    }

    private func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined() + ".img"
    }
}

private struct ArtworkView: View {
    let url: URL?; let symbol: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [GlowPalette.blue, GlowPalette.violet, GlowPalette.rose], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Image(systemName: symbol).font(.title).foregroundStyle(.white))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let loaded = await ArtworkImageCache.shared.image(for: url), !Task.isCancelled {
                image = loaded
            }
        }
    }
}

private struct EmptyState: View {
    let icon: String; let title: String; let detail: String
    var body: some View { VStack(spacing: 12) { Image(systemName: icon).font(.system(size: 28, weight: .medium)); Text(title).font(AppFont.rowTitle); Text(detail).font(AppFont.caption).foregroundStyle(GlowPalette.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(32) }
}

private struct MiniPlayerView: View {
    @Environment(PlayerStore.self) private var player
    @Binding var selection: AppTab
    @Binding var isCollapsed: Bool
    var body: some View {
        HStack(spacing: 12) {
            Button { selection = .player } label: {
                HStack(spacing: 11) {
                    ArtworkView(url: player.current?.artworkURL, symbol: "music.note").frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) { Text(player.current?.title ?? "").font(AppFont.rowTitle).lineLimit(1); Text(player.current?.artist ?? "").font(AppFont.caption).foregroundStyle(GlowPalette.secondary).lineLimit(1) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Spacer()
            Button { player.toggle() } label: {
                ZStack {
                    Circle()
                        .stroke(GlowPalette.separator.opacity(0.45), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: max(0, min(1, player.progress)))
                        .stroke(GlowPalette.violet, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(width: 42, height: 42)
                .background(GlowPalette.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            Button { player.next() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一首")

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isCollapsed = true
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("收起为悬浮球")
        }
        .padding(8).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(GlowPalette.separator.opacity(0.45)))
    }
}

private struct FloatingMiniPlayerBubble: View {
    @Environment(PlayerStore.self) private var player
    @Binding var isCollapsed: Bool
    let avoidsBottomNavigation: Bool
    @AppStorage("selfradio.miniPlayer.bubbleY") private var storedYFraction = 0.66
    @State private var dragStartY: CGFloat?
    @State private var draggedY: CGFloat?
    @State private var artworkIsRotating = false

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.safeAreaInsets.top + 46
            let bottomClearance: CGFloat = avoidsBottomNavigation ? 108 : 54
            let maxY = max(minY, proxy.size.height - proxy.safeAreaInsets.bottom - bottomClearance)
            let restingY = min(max(CGFloat(storedYFraction) * proxy.size.height, minY), maxY)
            let currentY = min(max(draggedY ?? restingY, minY), maxY)

            ZStack {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        isCollapsed = false
                    }
                } label: {
                    ZStack {
                        ArtworkView(url: player.current?.artworkURL, symbol: "music.note")
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                            .rotationEffect(.degrees(artworkIsRotating ? 360 : 0))
                            .animation(
                                artworkIsRotating
                                    ? .linear(duration: 8).repeatForever(autoreverses: false)
                                    : .easeOut(duration: 0.2),
                                value: artworkIsRotating
                            )
                        Circle()
                            .trim(from: 0, to: max(0, min(1, player.progress)))
                            .stroke(GlowPalette.violet, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 58, height: 58)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("展开迷你播放器")
                .accessibilityHint("上下拖动可调整悬浮球位置")

                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.72), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            }
            .onAppear { artworkIsRotating = player.isPlaying }
            .onChange(of: player.isPlaying) { _, isPlaying in
                artworkIsRotating = false
                if isPlaying {
                    DispatchQueue.main.async { artworkIsRotating = true }
                }
            }
            .frame(width: 62, height: 62)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.48), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            .position(x: proxy.size.width - 42, y: currentY)
            .highPriorityGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { gesture in
                        if dragStartY == nil { dragStartY = restingY }
                        draggedY = min(max((dragStartY ?? restingY) + gesture.translation.height, minY), maxY)
                    }
                    .onEnded { _ in
                        let finalY = min(max(draggedY ?? restingY, minY), maxY)
                        storedYFraction = Double(finalY / proxy.size.height)
                        dragStartY = nil
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            draggedY = nil
                        }
                    }
            )
        }
    }
}

private struct PlayerView: View {
    @Environment(PlayerStore.self) private var player
    let onClose: () -> Void
    @State private var showingQueue = false
    @State private var showingLyrics = false
    @State private var showingSongInfo = false
    @State private var showingPlaybackSettings = false
    @State private var showingVisualSettings = false
    @State private var showingLandscapeLyrics = false
    @State private var edgeBackOffset: CGFloat = 0
    @State private var isDismissing = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                SoftGlowBackground()
                PlayerMotionBackground()
                PlayerParticleStage()
                if isLandscape {
                    LandscapePlayerLayout(
                        onClose: onClose,
                        showLyrics: { showingLandscapeLyrics = true },
                        showQueue: { showingQueue = true },
                        showSongInfo: { showingSongInfo = true },
                        showPlaybackSettings: { showingPlaybackSettings = true },
                        showVisualSettings: { showingVisualSettings = true }
                    )
                } else {
                    PortraitPlayerLayout(
                        onClose: onClose,
                        showLyrics: { showingLyrics = true },
                        showQueue: { showingQueue = true },
                        showSongInfo: { showingSongInfo = true },
                        showPlaybackSettings: { showingPlaybackSettings = true },
                        showVisualSettings: { showingVisualSettings = true }
                    )
                }
                if showingLandscapeLyrics {
                    LandscapeImmersiveLyricsView { showingLandscapeLyrics = false }
                        .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(x: edgeBackOffset)
            .contentShape(Rectangle())
            .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                    .onChanged { gesture in
                        guard !isDismissing,
                              gesture.startLocation.x <= 28,
                              gesture.translation.width > 0,
                              gesture.translation.width > abs(gesture.translation.height) else { return }
                        edgeBackOffset = min(max(gesture.translation.width, 0), proxy.size.width)
                    }
                    .onEnded { gesture in
                        let shouldClose = gesture.startLocation.x <= 28
                            && gesture.translation.width > 92
                            && gesture.translation.width > abs(gesture.translation.height)
                        guard !isDismissing else { return }
                        if shouldClose {
                            isDismissing = true
                            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88)) { edgeBackOffset = proxy.size.width }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { onClose() }
                        } else {
                            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88)) { edgeBackOffset = 0 }
                        }
                    }
            )
            .animation(.easeOut(duration: 0.22), value: showingLandscapeLyrics)
        }
        .sheet(isPresented: $showingQueue) { QueueView() }
        .sheet(isPresented: $showingLyrics) { FullLyricsView() }
        .sheet(isPresented: $showingSongInfo) { SongInfoSheet() }
        .sheet(isPresented: $showingPlaybackSettings) {
            NavigationStack { PlaybackSettingsView() }
        }
        .sheet(isPresented: $showingVisualSettings) {
            NavigationStack { VisualSettingsView() }
        }
    }

}

private struct PlayerHeaderBar: View {
    @Environment(PlayerStore.self) private var player
    let onClose: () -> Void
    let showSongInfo: () -> Void
    let showPlaybackSettings: () -> Void
    let showVisualSettings: () -> Void
    var compact = false

    var body: some View {
        if compact {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回首页")

                Spacer()

                HStack(spacing: 8) {
                    Button(action: showSongInfo) {
                        Text("正在播放")
                            .font(.headline)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看歌曲信息")

                    Menu {
                        Button(action: showSongInfo) {
                            Label("歌曲信息", systemImage: "info.circle")
                        }
                        Button(action: showPlaybackSettings) {
                            Label("播放与音质效果", systemImage: "waveform")
                        }
                        Button(action: showVisualSettings) {
                            Label("播放动效", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .frame(width: 36, height: 44)
                    }
                    .accessibilityLabel("更多播放选项")
                }

                Spacer()

                Button { player.toggleFavorite(player.current) } label: {
                    Image(systemName: player.isFavorite(player.current) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(player.isFavorite(player.current) ? GlowPalette.rose : GlowPalette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isFavorite(player.current) ? "取消喜欢" : "添加到我的喜欢")
            }
        } else {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回首页")
                Spacer()
                Button(action: showSongInfo) {
                    VStack(spacing: 2) {
                        Text("正在播放").font(.headline)
                        Text("查看歌曲信息")
                            .font(AppFont.small.weight(.medium))
                            .foregroundStyle(GlowPalette.secondary)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看歌曲信息")
                Spacer()
                Menu {
                    Button(action: showSongInfo) {
                        Label("歌曲信息", systemImage: "info.circle")
                    }
                    Button(action: showPlaybackSettings) {
                        Label("播放与音质效果", systemImage: "waveform")
                    }
                    Button(action: showVisualSettings) {
                        Label("播放动效", systemImage: "sparkles")
                    }
                    Divider()
                    Button { player.toggleFavorite(player.current) } label: {
                        Label(player.isFavorite(player.current) ? "取消喜欢" : "添加到我的喜欢", systemImage: player.isFavorite(player.current) ? "heart.slash" : "heart")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("更多播放选项")
            }
        }
    }
}

private struct PortraitPlayerLayout: View {
    @Environment(PlayerStore.self) private var player
    let onClose: () -> Void
    let showLyrics: () -> Void
    let showQueue: () -> Void
    let showSongInfo: () -> Void
    let showPlaybackSettings: () -> Void
    let showVisualSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlayerHeaderBar(onClose: onClose, showSongInfo: showSongInfo, showPlaybackSettings: showPlaybackSettings, showVisualSettings: showVisualSettings)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            if player.artworkAspectRatio < 1 {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        PlayerArtworkPage(isScrollable: true)
                        LyricPreviewView(action: showLyrics)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: .infinity)

                VStack(spacing: 18) {
                    PlayerProgressView()
                    PlayerControlsView(showQueue: showQueue)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            } else {
                PlayerArtworkPage()

                VStack(spacing: 22) {
                    LyricPreviewView(action: showLyrics)
                    PlayerProgressView()
                    PlayerControlsView(showQueue: showQueue)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct LandscapePlayerLayout: View {
    let onClose: () -> Void
    let showLyrics: () -> Void
    let showQueue: () -> Void
    let showSongInfo: () -> Void
    let showPlaybackSettings: () -> Void
    let showVisualSettings: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeTop = max(8, proxy.safeAreaInsets.top + 4)
            let safeBottom = max(14, proxy.safeAreaInsets.bottom + 8)
            let contentHeight = max(260, proxy.size.height - safeTop - safeBottom)
            let artworkSize = min(258, max(156, contentHeight * 0.46))
            let sidePadding = max(26, min(84, proxy.size.width * 0.055))
            let columnSpacing = max(28, min(72, proxy.size.width * 0.045))

            VStack(spacing: 0) {
                PlayerHeaderBar(onClose: onClose, showSongInfo: showSongInfo, showPlaybackSettings: showPlaybackSettings, showVisualSettings: showVisualSettings, compact: true)
                    .padding(.horizontal, 28)
                    .padding(.top, safeTop)

                HStack(alignment: .center, spacing: columnSpacing) {
                    LandscapeArtworkPanel(artworkSize: artworkSize)
                        .frame(width: min(330, proxy.size.width * 0.34))

                    VStack(spacing: 18) {
                        LyricPreviewView(action: showLyrics, isLandscapeStage: true)
                            .frame(maxWidth: 680)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(GlowPalette.surface.opacity(0.16), in: RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(GlowPalette.separator.opacity(0.18)))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, sidePadding)
                .padding(.top, 10)

                PlayerProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, sidePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                PlayerControlsView(showQueue: showQueue)
                    .padding(.bottom, safeBottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct LandscapeArtworkPanel: View {
    @Environment(PlayerStore.self) private var player
    let artworkSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VinylArtwork(url: player.current?.artworkURL)
                .frame(width: artworkSize, height: artworkSize)
                .shadow(color: GlowPalette.blue.opacity(0.24), radius: 24, x: -8)
                .shadow(color: GlowPalette.rose.opacity(0.22), radius: 24, x: 8)

            VStack(spacing: 4) {
                Text(player.current?.title ?? "未播放")
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
                Text(player.current?.artist ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GlowPalette.secondary)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 260)
        }
    }
}

private struct PlayerArtworkPage: View {
    @Environment(PlayerStore.self) private var player
    let isScrollable: Bool
    @State private var breathing = false

    init(isScrollable: Bool = false) {
        self.isScrollable = isScrollable
    }

    private var artworkAspectRatio: CGFloat { player.artworkAspectRatio }
    private var displayAspectRatio: CGFloat {
        player.artworkPresentation == .cover ? artworkAspectRatio : 1
    }

    var body: some View {
        VStack(spacing: 22) {
            if !isScrollable { Spacer(minLength: 18) }
            VinylArtwork(url: player.current?.artworkURL)
                .aspectRatio(displayAspectRatio, contentMode: .fit)
                .shadow(color: GlowPalette.blue.opacity(0.30), radius: 35, x: -12).shadow(color: GlowPalette.rose.opacity(0.28), radius: 35, x: 12)
                .scaleEffect(player.playbackMotionEnabled && player.isPlaying ? (breathing ? 1.018 : 0.99) : 0.97)
                .animation(player.playbackMotionEnabled && player.isPlaying ? .easeInOut(duration: 2.8).repeatForever(autoreverses: true) : .easeInOut(duration: 0.25), value: breathing)
                .animation(.easeInOut(duration: 0.25), value: player.isPlaying)
                .padding(.horizontal, 46)
                .id(player.current?.id ?? "empty-artwork")
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            VStack(spacing: 5) {
                Text(player.current?.title ?? "未播放")
                    .font(.system(size: 25, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(player.current?.artist ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(GlowPalette.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 34)
            .id(player.current?.id ?? "empty-title")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            if !isScrollable { Spacer(minLength: 20) }
        }
        .animation(player.playbackMotionEnabled ? .easeInOut(duration: 0.28) : nil, value: player.current?.id)
        .onAppear { breathing = true }
    }
}

private struct VinylArtwork: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let url: URL?
    @State private var pausedAngle = 0.0
    @State private var startedAt = Date()

    private var shouldSpin: Bool {
        player.artworkPresentation != .cover && player.playbackMotionEnabled && player.isPlaying
            && !accessibilityReduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !shouldSpin)) { context in
            let angle = shouldSpin
                ? (pausedAngle + context.date.timeIntervalSince(startedAt) * 22).truncatingRemainder(dividingBy: 360)
                : pausedAngle

            Group {
                ArtworkPresentationVisual(style: player.artworkPresentation, artworkURL: url)
                    .rotationEffect(.degrees(player.artworkPresentation == .cover ? 0 : angle))
                    .scaleEffect(player.artworkPresentation == .cover ? 1 : 0.95)
                    .id("\(player.current?.id ?? "empty-artwork")-\(player.artworkPresentation.rawValue)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.035)),
                        removal: .opacity.combined(with: .scale(scale: 0.94))
                    ))
            }
            .animation(player.playbackMotionEnabled ? .easeOut(duration: 0.32) : nil, value: player.current?.id)
            .animation(.easeInOut(duration: 0.24), value: player.artworkPresentation)
        }
        .onChange(of: shouldSpin) { wasSpinning, isSpinning in
            if wasSpinning {
                pausedAngle = (pausedAngle + Date().timeIntervalSince(startedAt) * 22).truncatingRemainder(dividingBy: 360)
            }
            if isSpinning { startedAt = Date() }
        }
        .onAppear { startedAt = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前歌曲\(player.artworkPresentation.title)")
    }
}

private struct ArtworkPresentationVisual: View {
    let style: PlayerArtworkPresentation
    let artworkURL: URL?
    var isPreview = false

    var body: some View {
        Group {
            switch style {
            case .cover:
                ArtworkView(url: artworkURL, symbol: "music.note")
                    .clipShape(RoundedRectangle(cornerRadius: isPreview ? 24 : 42, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: isPreview ? 24 : 42, style: .continuous).stroke(GlowPalette.separator.opacity(0.45)))
            case .vinyl:
                VinylDisc()
            }
        }
    }
}

private struct VinylDisc: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 0.23, green: 0.24, blue: 0.28), Color.black.opacity(0.98), Color(red: 0.08, green: 0.09, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            ForEach([8.0, 15, 23, 32, 41], id: \.self) { inset in
                Circle().stroke(Color.white.opacity(inset < 20 ? 0.18 : 0.10), lineWidth: 1).padding(inset)
            }
            Circle().trim(from: 0.06, to: 0.23).stroke(GlowPalette.violet.opacity(0.78), style: StrokeStyle(lineWidth: 2.6, lineCap: .round)).padding(7)
            Circle().fill(LinearGradient(colors: [GlowPalette.violet.opacity(0.68), GlowPalette.rose.opacity(0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)).padding(37)
            Circle().fill(Color(red: 0.07, green: 0.05, blue: 0.13).opacity(0.86)).padding(49)
            Circle().fill(.white.opacity(0.68)).frame(width: 5, height: 5)
        }
        .shadow(color: .black.opacity(0.36), radius: 15, x: 8, y: 8)
    }
}

private struct PlayerMotionBackground: View {
    @Environment(PlayerStore.self) private var player
    @State private var drift = false

    private var artworkAccent: Color { Color(uiColor: player.artworkAccentColor) }

    var body: some View {
        ZStack {
            Circle()
                .fill((player.coverGlowEnabled ? artworkAccent : GlowPalette.blue).opacity(0.22))
                .frame(width: 280)
                .blur(radius: 80)
                .offset(x: drift ? -120 : -190, y: drift ? -120 : 80)
            Circle()
                .fill((player.coverGlowEnabled ? artworkAccent.opacity(0.72) : GlowPalette.rose).opacity(0.20))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: drift ? 150 : 80, y: drift ? 190 : 80)
            Circle()
                .fill(GlowPalette.violet.opacity(0.18))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: drift ? -20 : 90, y: drift ? 260 : 340)
        }
        .opacity(player.playbackMotionEnabled && player.isPlaying ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: player.playbackMotionEnabled)
        .animation(.easeInOut(duration: 0.35), value: player.isPlaying)
        .animation(.easeInOut(duration: 0.5), value: player.artworkAccentColor)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PlayerParticleStage: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var isActive: Bool {
        player.playbackMotionEnabled && player.particleVisualEnabled && player.isPlaying
            && scenePhase == .active && !accessibilityReduceMotion && !lowPowerMode
    }

    var body: some View {
        Group {
            if isActive {
                TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let energy = 0.72 + sin(time * 2.4) * 0.18
                        let center = CGPoint(x: size.width / 2, y: size.height * 0.38)

                        for index in 0..<16 {
                            let seed = Double(index) * 1.73
                            let angle = seed + time * (0.08 + Double(index % 3) * 0.025)
                            let radius = (58 + Double(index * 13 % 150)) * energy
                            let diameter = 2.5 + Double(index % 4)
                            let point = CGPoint(
                                x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius * 0.72
                            )
                            let rect = CGRect(x: point.x, y: point.y, width: diameter, height: diameter)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(index.isMultiple(of: 2) ? GlowPalette.violet.opacity(0.38) : GlowPalette.blue.opacity(0.30))
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: isActive)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LyricPreviewView: View {
    @Environment(PlayerStore.self) private var player
    let action: () -> Void
    var isLandscapeStage = false

    private var previewLines: [(Int, LyricLine)] {
        guard !player.lyrics.isEmpty else { return [] }
        let active = min(max(player.activeLyricIndex, 0), player.lyrics.count - 1)
        let start = max(0, active - 1)
        let end = min(player.lyrics.count - 1, active + 1)
        return (start...end).map { ($0, player.lyrics[$0]) }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                if player.lyricsLoading {
                    Text("正在加载歌词…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(GlowPalette.secondary)
                } else if previewLines.isEmpty {
                    Text("暂无同步歌词")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(GlowPalette.secondary)
                } else {
                    ForEach(previewLines, id: \.1.id) { index, line in
                        switch player.lyricDisplayStyle {
                        case .plain:
                            PlainLyricPreviewLine(index: index, line: line, isLandscapeStage: isLandscapeStage)
                        case .nebula, .moonsea, .starWars:
                            ImmersiveLyricPreviewLine(index: index, line: line, style: player.lyricDisplayStyle, isLandscapeStage: isLandscapeStage)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: isLandscapeStage ? 116 : 88)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看完整歌词")
    }
}

private struct PlainLyricPreviewLine: View {
    @Environment(PlayerStore.self) private var player
    let index: Int
    let line: LyricLine
    let isLandscapeStage: Bool

    private var isActive: Bool { index == player.activeLyricIndex }

    var body: some View {
        Text(line.text)
            .font(.system(size: isActive ? (isLandscapeStage ? 30 : 18) : (isLandscapeStage ? 19 : 13), weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? GlowPalette.ink : GlowPalette.secondary.opacity(isLandscapeStage ? 0.64 : 0.48))
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .lineLimit(isActive ? 2 : 1)
            .offset(y: player.lyricMotionEnabled && isActive ? -2 : 0)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(player.lyricMotionEnabled ? .easeOut(duration: 0.22) : nil, value: player.activeLyricIndex)
    }
}

private struct ImmersiveLyricPreviewLine: View {
    @Environment(PlayerStore.self) private var player
    let index: Int
    let line: LyricLine
    let style: LyricDisplayStyle
    let isLandscapeStage: Bool

    private var relative: CGFloat { CGFloat(index - player.activeLyricIndex) }
    private var isActive: Bool { index == player.activeLyricIndex }

    var body: some View {
        Text(line.text)
            .font(.system(size: isActive ? (isLandscapeStage ? 30 : 20) : (isLandscapeStage ? 19 : 14), weight: isActive ? .bold : .medium, design: .rounded))
            .tracking(isActive ? 0.5 : 0.15)
            .foregroundStyle(isActive ? .white : GlowPalette.secondary.opacity(0.48))
            .shadow(color: style == .nebula ? GlowPalette.rose.opacity(isActive ? 0.42 : 0.10) : Color(red: 1, green: 0.72, blue: 0.48).opacity(isActive ? 0.36 : 0.08), radius: isActive ? 10 : 3)
            .multilineTextAlignment(.center)
            .lineLimit(isActive ? 2 : 1)
            .scaleEffect(isActive ? 1.0 : 0.88)
            .rotation3DEffect(.degrees(style == .nebula ? relative * 6 : relative * 3), axis: (x: 1, y: 0, z: 0), anchor: .center, anchorZ: 0, perspective: 0.75)
            .offset(y: relative * (isLandscapeStage ? 31 : 24) - 6)
            .opacity(isActive ? 1 : 0.52)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(player.lyricMotionEnabled ? .easeOut(duration: 0.28) : nil, value: player.activeLyricIndex)
            .accessibilityLabel(line.text)
    }
}

private struct LandscapeImmersiveLyricsView: View {
    @Environment(PlayerStore.self) private var player
    let onClose: () -> Void

    private var visibleLines: [(Int, LyricLine)] {
        guard !player.lyrics.isEmpty else { return [] }
        let active = min(max(player.activeLyricIndex, 0), player.lyrics.count - 1)
        let range = max(0, active - 2)...min(player.lyrics.count - 1, active + 2)
        return range.map { ($0, player.lyrics[$0]) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            PlayerMotionBackground()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.down")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("退出沉浸歌词")
                    Spacer()
                    VStack(spacing: 3) {
                        Text(player.current?.title ?? "未播放")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(player.current?.artist ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlowPalette.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 360)
                    Spacer()
                    Text("轻触退出")
                        .font(AppFont.small)
                        .foregroundStyle(GlowPalette.secondary)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 24)

                Spacer()

                if player.lyricsLoading {
                    Text("正在加载歌词…")
                        .foregroundStyle(GlowPalette.secondary)
                } else if visibleLines.isEmpty {
                    Text("暂无同步歌词")
                        .foregroundStyle(GlowPalette.secondary)
                } else {
                    VStack(spacing: 19) {
                        ForEach(visibleLines, id: \.1.id) { index, line in
                            Text(line.text)
                                .font(.system(size: index == player.activeLyricIndex ? 36 : 20, weight: index == player.activeLyricIndex ? .bold : .regular))
                                .foregroundStyle(index == player.activeLyricIndex ? GlowPalette.ink : GlowPalette.secondary.opacity(0.54))
                                .multilineTextAlignment(.center)
                                .lineLimit(index == player.activeLyricIndex ? 2 : 1)
                                .scaleEffect(index == player.activeLyricIndex ? 1 : 0.94)
                                .opacity(index == player.activeLyricIndex ? 1 : 0.76)
                                .animation(player.lyricMotionEnabled ? .easeOut(duration: 0.24) : nil, value: player.activeLyricIndex)
                        }
                    }
                    .frame(maxWidth: 920)
                    .padding(.horizontal, 48)
                }

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
        .accessibilityElement(children: .contain)
    }
}

private struct PlayerProgressView: View {
    @Environment(PlayerStore.self) private var player

    private var progressBinding: Binding<Double> {
        Binding(
            get: { player.progress.isFinite ? player.progress : 0 },
            set: { player.seek(to: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: progressBinding, in: 0...1)
                .tint(GlowPalette.rose)
            HStack {
                Text(Self.timeText(player.elapsed))
                Spacer()
                Text(Self.timeText(player.duration))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(GlowPalette.secondary)
        }
    }

    private static func timeText(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

private struct PlayerControlsView: View {
    @Environment(PlayerStore.self) private var player
    @State private var playPulse = false
    let showQueue: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            PlaybackModeButton()
            PlayerIconButton(icon: "backward.fill", size: 27) { player.previous() }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(LinearGradient(colors: [GlowPalette.blue, GlowPalette.violet, GlowPalette.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .shadow(color: GlowPalette.violet.opacity(0.32), radius: 18, y: 10)
                    .scaleEffect(player.playbackMotionEnabled && playPulse ? 0.92 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            PlayerIconButton(icon: "forward.fill", size: 27) { player.next() }
            PlayerIconButton(icon: "music.note.list", size: 21, action: showQueue)
        }
        .onChange(of: player.isPlaying) { _, _ in
            guard player.playbackMotionEnabled else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { playPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) { playPulse = false }
            }
        }
    }
}

private struct PlaybackModeButton: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        Button { player.cyclePlaybackMode() } label: {
            VStack(spacing: 2) {
                Image(systemName: player.playbackMode.symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(player.playbackMode.shortTitle)
                    .font(AppFont.small.weight(.semibold))
            }
            .foregroundStyle(player.playbackMode == .listLoop ? GlowPalette.secondary : GlowPalette.violet)
            .frame(width: 52, height: 48)
            .background(player.playbackMode == .listLoop ? .clear : GlowPalette.violet.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("播放模式：\(player.playbackMode.rawValue)，点按切换")
    }
}

private struct PlayerIconButton: View {
    let icon: String
    let size: CGFloat
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isSelected ? GlowPalette.violet : GlowPalette.ink)
                .frame(width: 44, height: 44)
                .background(isSelected ? GlowPalette.violet.opacity(0.16) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct FullLyricsView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var player = player
        NavigationStack {
            Group {
                switch player.lyricDisplayStyle {
                case .plain:
                    LyricsPage()
                case .nebula, .moonsea, .starWars:
                    ImmersiveLyricsPage(style: player.lyricDisplayStyle)
                }
            }
                .background(ImmersiveLyricsSheetBackground(style: player.lyricDisplayStyle))
                .navigationTitle("歌词")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
                .safeAreaInset(edge: .top) {
                    Picker("歌词样式", selection: $player.lyricDisplayStyle) {
                        ForEach(LyricDisplayStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(ImmersiveLyricsSheetBackground(style: player.lyricDisplayStyle))
        .presentationDetents([.large])
    }
}

private struct ImmersiveLyricsSheetBackground: View {
    let style: LyricDisplayStyle

    var body: some View {
        switch style {
        case .plain:
            SoftGlowBackground()
        case .nebula:
            NebulaBackdropCanvas(time: 0)
        case .moonsea:
            MoonSeaBackdropCanvas(time: 0)
        case .starWars:
            StarWarsSheetBackdrop()
        }
    }
}

private struct StarWarsSheetBackdrop: View {
    var body: some View {
        ZStack {
            Image("StarWarsGalaxyBackground")
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.16), .clear, .black.opacity(0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            RadialGradient(colors: [Color(red: 0.02, green: 0.11, blue: 0.18).opacity(0.38), .clear], center: UnitPoint(x: 0.10, y: 0.50), startRadius: 8, endRadius: 420)
            RadialGradient(colors: [Color(red: 0.29, green: 0.03, blue: 0.16).opacity(0.22), .clear], center: UnitPoint(x: 0.88, y: 0.27), startRadius: 8, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

private struct LyricsPage: View {
    @Environment(PlayerStore.self) private var player
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    Spacer().frame(height: 170)
                    if player.lyricsLoading { ProgressView("正在加载歌词…") }
                    else if player.lyrics.isEmpty { EmptyState(icon: "quote.bubble", title: "暂无同步歌词", detail: "仍可正常播放，换源后会再次尝试获取") }
                    else {
                        ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                            Button { player.seek(to: player.duration > 0 ? max(0, line.time - player.lyricOffset) / player.duration : 0) } label: {
                                VStack(spacing: 7) {
                                    Text(line.text).font(.system(size: index == player.activeLyricIndex ? 27 : 19, weight: index == player.activeLyricIndex ? .bold : .medium, design: .rounded)).foregroundStyle(index == player.activeLyricIndex ? GlowPalette.ink : GlowPalette.secondary.opacity(0.40)).multilineTextAlignment(.center)
                                    if let translation = line.translation, !translation.isEmpty { Text(translation).font(.caption).foregroundStyle(GlowPalette.secondary.opacity(index == player.activeLyricIndex ? 0.8 : 0.35)) }
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).id(index)
                        }
                    }
                    Spacer().frame(height: 170)
                }.padding(.horizontal, 26)
            }
            .onChange(of: player.activeLyricIndex) { _, index in withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(index, anchor: .center) } }
        }
    }
}

private struct ImmersiveLyricsPage: View {
    @Environment(PlayerStore.self) private var player
    let style: LyricDisplayStyle

    private var crawlPosition: CGFloat {
        guard !player.lyrics.isEmpty else { return 0 }
        let active = min(max(player.activeLyricIndex, 0), player.lyrics.count - 1)
        let currentTime = player.lyrics[active].time
        let nextTime = active + 1 < player.lyrics.count ? player.lyrics[active + 1].time : max(player.duration, currentTime + 3)
        let span = max(0.8, nextTime - currentTime)
        let fraction = min(max((player.elapsed + player.lyricOffset - currentTime) / span, 0), 1)
        return CGFloat(active) + CGFloat(fraction)
    }

    private var visibleIndices: [Int] {
        guard !player.lyrics.isEmpty else { return [] }
        let cursor = Int(crawlPosition.rounded(.down))
        let start = max(0, cursor - 3)
        let end = min(player.lyrics.count - 1, cursor + 7)
        return Array(start...end)
    }

    var body: some View {
        Group {
            if style == .starWars {
                StarWarsLyricsWebView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(style == .moonsea ? 0.10 : 0.42).ignoresSafeArea()
                ImmersiveLyricsBackdrop(style: style)
                LinearGradient(
                    colors: style == .moonsea
                        ? [.black.opacity(0.12), .clear, .black.opacity(0.28)]
                        : [.black.opacity(0.50), .clear, .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if player.lyricsLoading {
                    ProgressView("正在加载歌词…")
                        .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.26))
                } else if player.lyrics.isEmpty {
                    EmptyState(icon: "quote.bubble", title: "暂无同步歌词", detail: "仍可正常播放，换源后会再次尝试获取")
                        .padding(.horizontal, 28)
                } else {
                    switch style {
                    case .nebula:
                        NebulaLyricStage(indices: visibleIndices, crawlPosition: crawlPosition, canvasSize: proxy.size)
                    case .moonsea:
                        MoonSeaLyricStage(indices: visibleIndices, crawlPosition: crawlPosition, canvasSize: proxy.size)
                    case .starWars:
                        EmptyView()
                    case .plain:
                        EmptyView()
                    }
                }
            }
            .animation(player.lyricMotionEnabled ? .linear(duration: 0.12) : nil, value: player.elapsed)
                }
            }
        }
    }
}

private struct ImmersiveLyricsBackdrop: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    let style: LyricDisplayStyle

    private var isAnimated: Bool {
        player.lyricMotionEnabled && player.particleVisualEnabled && player.isPlaying
            && scenePhase == .active && !accessibilityReduceMotion && !lowPowerMode
    }

    var body: some View {
        Group {
            if isAnimated {
                TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                    backdrop(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                backdrop(time: 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func backdrop(time: TimeInterval) -> some View {
        switch style {
        case .nebula:
            NebulaBackdropCanvas(time: time)
        case .moonsea:
            MoonSeaBackdropCanvas(time: time)
        case .starWars:
            EmptyView()
        case .plain:
            EmptyView()
        }
    }
}

private struct NebulaBackdropCanvas: View {
    let time: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RadialGradient(
                    colors: [Color(red: 0.015, green: 0.12, blue: 0.19), Color(red: 0.025, green: 0.025, blue: 0.10), .black],
                    center: UnitPoint(x: 0.24, y: 0.27),
                    startRadius: 10,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.82
                )

                Canvas { context, size in
                    let width = size.width
                    let height = size.height
                    let drift = CGFloat(time * 0.012)

                    for index in 0..<76 {
                        let seed = CGFloat(index)
                        let x = (seed * 67.0 + sin(seed * 1.7) * 23).truncatingRemainder(dividingBy: width)
                        let y = (seed * 109.0 + cos(seed * 0.8) * 19).truncatingRemainder(dividingBy: height)
                        let side = index.isMultiple(of: 11) ? 2.1 : 0.8 + CGFloat(index % 3) * 0.42
                        let twinkle = 0.13 + (sin(CGFloat(time) * 0.75 + seed) + 1) * 0.085
                        let color: Color = index.isMultiple(of: 7) ? GlowPalette.rose : (index.isMultiple(of: 5) ? GlowPalette.blue : .white)
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)), with: .color(color.opacity(twinkle)))
                    }

                    for layer in -5...5 {
                        let offset = CGFloat(layer) * 4.6
                        var ribbon = Path()
                        ribbon.move(to: CGPoint(x: width * 0.06, y: height * 0.12 + offset))
                        ribbon.addCurve(
                            to: CGPoint(x: width * 0.79, y: height * 0.41 + offset),
                            control1: CGPoint(x: width * (0.12 + drift), y: height * 0.26 + offset),
                            control2: CGPoint(x: width * (0.95 - drift), y: height * 0.16 + offset)
                        )
                        ribbon.addCurve(
                            to: CGPoint(x: width * 0.22, y: height * 0.70 + offset),
                            control1: CGPoint(x: width * 0.66, y: height * 0.57 + offset),
                            control2: CGPoint(x: width * 0.07, y: height * 0.50 + offset)
                        )
                        ribbon.addCurve(
                            to: CGPoint(x: width * 0.91, y: height * 1.07 + offset),
                            control1: CGPoint(x: width * 0.43, y: height * 0.90 + offset),
                            control2: CGPoint(x: width * 0.91, y: height * 0.84 + offset)
                        )
                        let intensity = 0.09 + (5 - abs(CGFloat(layer))) * 0.016
                        context.stroke(
                            ribbon,
                            with: .linearGradient(
                                Gradient(colors: [GlowPalette.blue.opacity(intensity), .white.opacity(intensity * 0.5), GlowPalette.rose.opacity(intensity * 1.35)]),
                                startPoint: CGPoint(x: 0, y: height * 0.16),
                                endPoint: CGPoint(x: width, y: height * 0.94)
                            ),
                            style: StrokeStyle(lineWidth: layer == 0 ? 2.3 : 1.25, lineCap: .round)
                        )
                    }
                }

                NebulaPlanet(size: 33, tint: GlowPalette.blue)
                    .position(x: proxy.size.width * 0.80, y: proxy.size.height * 0.28)
                NebulaPlanet(size: 43, tint: GlowPalette.rose)
                    .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.47)
                NebulaPlanet(size: 36, tint: GlowPalette.violet)
                    .position(x: proxy.size.width * 0.82, y: proxy.size.height * 0.69)
            }
        }
    }
}

private struct NebulaPlanet: View {
    let size: CGFloat
    let tint: Color

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.white.opacity(0.72), tint.opacity(0.72), Color.black.opacity(0.84)], center: UnitPoint(x: 0.32, y: 0.27), startRadius: 1, endRadius: size * 0.7))
            .overlay(Circle().stroke(.white.opacity(0.36), lineWidth: 0.8))
            .overlay(Circle().stroke(tint.opacity(0.72), lineWidth: 3).blur(radius: 4))
            .frame(width: size, height: size)
            .shadow(color: tint.opacity(0.68), radius: 12)
    }
}

private struct MoonSeaBackdropCanvas: View {
    let time: TimeInterval

    var body: some View {
        Image("MoonSeaLyricBackground")
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(colors: [.black.opacity(0.08), .clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
            }
            .clipped()
    }
}

private struct StarWarsLyricsWebView: UIViewRepresentable {
    @Environment(PlayerStore.self) private var player
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func makeCoordinator() -> Coordinator {
        Coordinator { time in
            guard player.duration > 0 else { return }
            player.seek(to: max(0, time - player.lyricOffset) / player.duration)
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "selfRadio")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.loadHTMLString(Self.document, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.deliver(
            lyrics: Self.lyricPayload(player.lyrics),
            clock: Self.clockPayload(
            elapsed: player.elapsed + player.lyricOffset,
            duration: player.duration,
            isPlaying: player.isPlaying,
            lyricMotionEnabled: player.lyricMotionEnabled && player.particleVisualEnabled
                && !accessibilityReduceMotion && scenePhase == .active
                && !ProcessInfo.processInfo.isLowPowerModeEnabled
            ),
            to: webView
        )
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "selfRadio")
        webView.stopLoading()
    }

    private static func lyricPayload(_ lyrics: [LyricLine]) -> String {
        let rows = lyrics.map { ["time": $0.time, "text": $0.text] as [String: Any] }
        guard let data = try? JSONSerialization.data(withJSONObject: rows), let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private static func clockPayload(elapsed: TimeInterval, duration: TimeInterval, isPlaying: Bool, lyricMotionEnabled: Bool) -> String {
        let object: [String: Any] = [
            "elapsed": elapsed.isFinite ? elapsed : 0,
            "duration": duration.isFinite ? duration : 0,
            "isPlaying": isPlaying,
            "motion": lyricMotionEnabled
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object), let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let onSeek: (TimeInterval) -> Void
        private var loaded = false
        private var pendingLyrics = "[]"
        private var pendingClock = "{}"
        private var deliveredLyrics = ""

        init(onSeek: @escaping (TimeInterval) -> Void) {
            self.onSeek = onSeek
        }

        func deliver(lyrics: String, clock: String, to webView: WKWebView) {
            pendingLyrics = lyrics
            pendingClock = clock
            guard loaded else { return }
            if pendingLyrics != deliveredLyrics {
                deliveredLyrics = pendingLyrics
                webView.evaluateJavaScript("window.selfRadioConfigure(\(pendingLyrics));")
            }
            webView.evaluateJavaScript("window.selfRadioTick(\(pendingClock));")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            deliver(lyrics: pendingLyrics, clock: pendingClock, to: webView)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "selfRadio",
                  let body = message.body as? [String: Any],
                  let seconds = (body["seek"] as? NSNumber)?.doubleValue else { return }
            onSeek(seconds)
        }
    }

    private static let document = #"""
    <!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>
    *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}#stage{position:relative;width:100%;height:100%;overflow:hidden;background:transparent}#stars{position:absolute;inset:0;width:100%;height:100%;opacity:.82}.viewport{position:absolute;inset:0;overflow:hidden;perspective:390px;mask-image:linear-gradient(transparent 1%,#000 8%,#000 95%,transparent 100%)}.track{position:absolute;left:0;right:0;top:42%;display:flex;flex-direction:column;align-items:center;gap:24px;transform-origin:50% 0;will-change:transform}.line{width:88%;max-width:88%;padding:0 8px;color:rgba(255,205,61,.43);text-align:center;font-size:clamp(18px,6.1vw,25px);font-weight:760;line-height:1.42;letter-spacing:.025em;white-space:normal;overflow-wrap:anywhere;word-break:break-word;text-shadow:0 0 14px rgba(255,177,55,.18);transition:opacity .18s ease,color .18s ease,filter .18s ease;cursor:pointer}.line.long{font-size:clamp(16px,5vw,21px);line-height:1.34}.line.current{color:#ffd45a;filter:drop-shadow(0 0 18px rgba(255,197,74,.46));text-shadow:0 0 20px rgba(255,183,48,.55)}.empty{position:absolute;inset:0;display:grid;place-items:center;color:rgba(255,255,255,.55);font-size:15px}
    </style></head><body><main id="stage"><canvas id="stars"></canvas><section class="viewport"><div id="track" class="track"></div></section></main><script>
    const canvas=document.getElementById('stars'),ctx=canvas.getContext('2d'),track=document.getElementById('track');let state={lyrics:[],elapsed:0,duration:0,isPlaying:false,motion:false,anchor:performance.now()},lineNodes=[],built=false,activeIndex=-1,showingEmpty=false;
    function resize(){const d=Math.min(devicePixelRatio||1,2);canvas.width=innerWidth*d;canvas.height=innerHeight*d;canvas.style.width=innerWidth+'px';canvas.style.height=innerHeight+'px';ctx.setTransform(d,0,0,d,0,0)}addEventListener('resize',resize);resize();
    function build(){if(built)return;built=true;track.innerHTML='';lineNodes=state.lyrics.map(line=>{const el=document.createElement('div');el.className='line';if(Array.from(line.text||'').length>18)el.classList.add('long');el.textContent=line.text;el.onclick=()=>window.webkit?.messageHandlers?.selfRadio?.postMessage({seek:line.time});track.appendChild(el);return el})}
    function activeAt(t){let active=0;for(let i=0;i<state.lyrics.length;i++)if(t>=state.lyrics[i].time)active=i;return active}
    function setActive(active){if(active===activeIndex)return;activeIndex=active;lineNodes.forEach((el,i)=>{const distance=Math.abs(i-active);el.classList.toggle('current',i===active);el.style.opacity=Math.max(.1,1-distance*.18)})}
    function render(elapsed){if(!state.lyrics.length){if(!showingEmpty){track.innerHTML='<div class="empty">暂无同步歌词</div>';showingEmpty=true}return}build();showingEmpty=false;const active=activeAt(elapsed),current=state.lyrics[active],next=state.lyrics[active+1];const span=Math.max(.8,(next?next.time:Math.max(state.duration,current.time+3))-current.time);const fraction=Math.max(0,Math.min(1,(elapsed-current.time)/span));track.style.transform='rotateX(62deg) translate3d(0,'+(104-(active+fraction)*62)+'px,0)';setActive(active)}
    function displayElapsed(now){return state.isPlaying&&state.motion?state.elapsed+Math.max(0,now-state.anchor)/1000:state.elapsed}
    function drawMeteor(now,w,h){if(!state.motion||!state.isPlaying)return;const cycle=(now%18000)/18000;if(cycle>.11)return;const p=cycle/.11,x=w*(.18+p*.68),y=h*(.17+p*.45),length=42+p*96;const glow=1-Math.abs(.5-p)*1.8;const g=ctx.createLinearGradient(x-length,y-length*.42,x,y);g.addColorStop(0,'rgba(174,135,255,0)');g.addColorStop(.82,'rgba(174,135,255,'+(glow*.38)+')');g.addColorStop(1,'rgba(255,246,220,'+(glow*.95)+')');ctx.strokeStyle=g;ctx.lineWidth=1.15;ctx.beginPath();ctx.moveTo(x-length,y-length*.42);ctx.lineTo(x,y);ctx.stroke();}
    function stars(now){const elapsed=displayElapsed(now);if(state.motion&&state.isPlaying)render(elapsed);const w=innerWidth,h=innerHeight;ctx.clearRect(0,0,w,h);const drift=state.motion&&state.isPlaying?now*.00004:0;for(let i=0;i<148;i++){const seed=i*47.13;const x=(seed*1.7+Math.sin(seed+drift)*12)%w;const y=(seed*3.1+Math.cos(seed*.7+drift)*10)%h;const pulse=state.motion&&state.isPlaying?(Math.sin(now*.0011+seed)+1)*.09:0;const bright=(i%11===0?.64:.14+(i%5)*.04)+pulse;ctx.fillStyle=i%13===0?'rgba(95,187,255,'+bright+')':i%17===0?'rgba(191,126,255,'+bright+')':'rgba(255,255,255,'+bright+')';ctx.fillRect(x,y,i%11===0?2:1,i%11===0?2:1)}drawMeteor(now,w,h);requestAnimationFrame(stars)}requestAnimationFrame(stars);
    window.selfRadioConfigure=lyrics=>{state.lyrics=lyrics||[];built=false;activeIndex=-1;showingEmpty=false;render(state.elapsed)};
    window.selfRadioTick=next=>{state={...state,...next,anchor:performance.now()};if(!state.motion||!state.isPlaying)render(state.elapsed)};
    </script></body></html>
    """#
}

private struct NebulaLyricStage: View {
    @Environment(PlayerStore.self) private var player
    let indices: [Int]
    let crawlPosition: CGFloat
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            ForEach(indices, id: \.self) { index in
                NebulaLyricLine(
                    index: index,
                    line: player.lyrics[index],
                    crawlPosition: crawlPosition,
                    canvasSize: canvasSize
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
    }
}

private struct NebulaLyricLine: View {
    @Environment(PlayerStore.self) private var player
    let index: Int
    let line: LyricLine
    let crawlPosition: CGFloat
    let canvasSize: CGSize

    private var depth: CGFloat { CGFloat(index) - crawlPosition }
    private var isCurrentLine: Bool { abs(depth) < 0.52 }
    private var accent: Color { Color(uiColor: player.artworkAccentColor) }
    private var lineColor: Color { isCurrentLine ? .white : .white.opacity(depth > 0 ? 0.38 : 0.20) }
    private var yPosition: CGFloat { canvasSize.height * 0.55 - depth * 102 }
    private var xPosition: CGFloat { canvasSize.width * 0.5 + sin(depth * 0.88) * canvasSize.width * 0.19 }
    private var scale: CGFloat {
        if isCurrentLine { return 1.0 }
        return max(0.42, min(1.15, 0.92 - depth * 0.075))
    }
    private var opacity: Double {
        if depth < -2.6 || depth > 5.8 { return 0 }
        return isCurrentLine ? 1 : max(0.08, min(0.70, Double(0.76 - abs(depth) * 0.10)))
    }

    var body: some View {
        Button {
            player.seek(to: player.duration > 0 ? max(0, line.time - player.lyricOffset) / player.duration : 0)
        } label: {
            VStack(spacing: 5) {
                VStack(spacing: 5) {
                    Text(line.text)
                        .font(.system(size: isCurrentLine ? 38 : 20, weight: isCurrentLine ? .bold : .medium, design: .rounded))
                        .tracking(isCurrentLine ? 0.8 : 0.25)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if isCurrentLine, let translation = line.translation, !translation.isEmpty {
                        Text(translation)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.72)
                    }
                }
                .foregroundStyle(lineColor)
                .overlay {
                    if isCurrentLine {
                        Text(line.text)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundStyle(LinearGradient(colors: [GlowPalette.blue, Color(red: 1, green: 0.94, blue: 0.77), GlowPalette.rose], startPoint: .leading, endPoint: .trailing))
                    }
                }
                if isCurrentLine {
                    LinearGradient(colors: [GlowPalette.blue.opacity(0.05), accent.opacity(0.95), GlowPalette.rose.opacity(0.92), GlowPalette.blue.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: min(canvasSize.width * 0.72, 420), height: 1)
                        .shadow(color: accent.opacity(0.78), radius: 10)
                }
            }
            .shadow(color: lineColor.opacity(isCurrentLine ? 0.78 : 0.16), radius: isCurrentLine ? 14 : 4)
            .frame(width: min(canvasSize.width * 0.82, 520))
            .frame(minHeight: isCurrentLine ? 92 : 44)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(depth * 7), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.68)
            .rotation3DEffect(.degrees(-depth * 4), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.68)
            .position(x: xPosition, y: yPosition)
            .opacity(opacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(line.text)
    }
}

private struct MoonSeaLyricStage: View {
    @Environment(PlayerStore.self) private var player
    let indices: [Int]
    let crawlPosition: CGFloat
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            ForEach(indices, id: \.self) { index in
                MoonSeaLyricLine(index: index, line: player.lyrics[index], crawlPosition: crawlPosition, canvasSize: canvasSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
    }
}

private struct MoonSeaLyricLine: View {
    @Environment(PlayerStore.self) private var player
    let index: Int
    let line: LyricLine
    let crawlPosition: CGFloat
    let canvasSize: CGSize

    private var depth: CGFloat { CGFloat(index) - crawlPosition }
    private var isCurrentLine: Bool { abs(depth) < 0.52 }
    private var yPosition: CGFloat { canvasSize.height * 0.49 + depth * 104 }
    private var scale: CGFloat { isCurrentLine ? 1 : max(0.48, 0.94 - abs(depth) * 0.085) }
    private var opacity: Double {
        if depth < -1.7 || depth > 4.9 { return 0 }
        return isCurrentLine ? 1 : max(0.07, 0.64 - Double(abs(depth)) * 0.105)
    }

    var body: some View {
        Button {
            player.seek(to: player.duration > 0 ? max(0, line.time - player.lyricOffset) / player.duration : 0)
        } label: {
            ZStack {
                Text(line.text)
                    .font(.system(size: isCurrentLine ? 34 : 21, weight: isCurrentLine ? .bold : .medium, design: .serif))
                    .tracking(isCurrentLine ? 0.7 : 0.1)
                    .foregroundStyle(isCurrentLine ? Color(red: 1, green: 0.89, blue: 0.71) : Color(red: 0.82, green: 0.70, blue: 0.59).opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: isCurrentLine ? Color(red: 1, green: 0.69, blue: 0.46).opacity(0.62) : .clear, radius: 16)

                if depth > -0.2 {
                    Text(line.text)
                        .font(.system(size: isCurrentLine ? 32 : 20, weight: .medium, design: .serif))
                        .tracking(0.7)
                        .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.56).opacity(isCurrentLine ? 0.27 : 0.13))
                        .scaleEffect(x: 1.02, y: -0.54, anchor: .center)
                        .blur(radius: isCurrentLine ? 1.4 : 2.2)
                        .mask(LinearGradient(colors: [.white.opacity(0.72), .clear], startPoint: .top, endPoint: .bottom))
                        .offset(y: isCurrentLine ? 46 : 35)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: min(canvasSize.width * 0.84, 540), height: isCurrentLine ? 102 : 56)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(depth * 3.2), axis: (x: 1, y: 0, z: 0), perspective: 0.72)
            .position(x: canvasSize.width * 0.5, y: yPosition)
            .opacity(opacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(line.text)
    }
}

private struct QualitySheet: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var player = player
        NavigationStack {
            Form {
                Section("优先音质") {
                    Picker("播放音质", selection: $player.qualityPreference) {
                        ForEach(PlaybackQuality.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("不可用时严格匹配换源", isOn: $player.automaticSourceFallback)
                }
                Section("当前实际音质") {
                    LabeledContent("音源", value: player.playbackProvider?.rawValue ?? "尚未播放")
                    LabeledContent("规格", value: player.playbackQuality?.detail ?? "播放后显示")
                    if let notice = player.playbackNotice {
                        Label(notice, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                if let current = player.current {
                    Section {
                        Button("以所选音质重新播放") { player.play(current); dismiss() }
                    }
                }
                Section {
                    Text("显示当前歌曲可用的实际音质信息。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("音质")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SongInfoSheet: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var player = player
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ArtworkView(url: player.current?.artworkURL, symbol: "music.note")
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                    VStack(spacing: 6) {
                        Text(player.current?.title ?? "未播放")
                            .font(.system(size: 22, weight: .semibold))
                            .multilineTextAlignment(.center)
                        Text(player.current?.artist ?? "")
                            .font(AppFont.rowTitle)
                            .foregroundStyle(GlowPalette.secondary)
                    }
                    if let notice = player.playbackNotice {
                        Label(notice, systemImage: "exclamationmark.triangle.fill")
                            .font(AppFont.caption.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                    VStack(spacing: 0) {
                        SongInfoRow(title: "歌手", value: player.current?.artist.isEmpty == false ? player.current?.artist ?? "" : "未知")
                        SongInfoRow(title: "专辑", value: player.current?.album.isEmpty == false ? player.current?.album ?? "" : "未知")
                        SongInfoRow(title: "来源平台", value: player.playbackProvider?.rawValue ?? player.current?.provider.rawValue ?? "未知")
                        SongInfoRow(title: "实际音质", value: player.playbackQuality?.detail ?? "播放后显示")
                        SongInfoRow(title: "歌曲时长", value: Self.timeText(player.duration > 0 ? player.duration : player.current?.duration ?? 0))
                        SongInfoRow(title: "歌词状态", value: player.lyrics.isEmpty ? (player.lyricsLoading ? "加载中" : "暂无同步歌词") : "\(player.lyrics.count) 行同步歌词")
                        SongInfoRow(title: "播放模式", value: player.playbackMode.rawValue)
                        Picker("歌词样式", selection: $player.lyricDisplayStyle) {
                            ForEach(LyricDisplayStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .font(AppFont.rowTitle)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(GlowPalette.surface, in: RoundedRectangle(cornerRadius: 24))
                }
                .padding(24)
            }
            .background(SoftGlowBackground())
            .navigationTitle("歌曲信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private static func timeText(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "未知" }
        let total = Int(seconds.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

private struct SongInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(GlowPalette.secondary)
            Spacer(minLength: 24)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct ArtistUniverseView: View {
    @Environment(PlayerStore.self) private var player
    let artistName: String
    @State private var universe: MusicArtistUniverse?
    @State private var selectedAlbumID: String?
    @State private var albumSongsByID: [String: [Song]] = [:]
    @State private var albumLoadingID: String?
    @State private var isLoading = true
    @State private var isExpandingUniverse = false
    @State private var errorMessage: String?
    @State private var presentation: ArtistUniversePresentation = .nebula

    private var selectedAlbum: MusicAlbumUniverse? {
        guard let universe else { return nil }
        var album: MusicAlbumUniverse?
        if let selectedAlbumID {
            album = universe.albums.first(where: { $0.id == selectedAlbumID })
        } else {
            album = universe.albums.first
        }
        guard var album else { return nil }
        album.songs = albumSongsByID[album.id] ?? []
        return album
    }

    private var displayedSongCount: Int {
        guard let universe else { return 0 }
        return universe.artist.songCount > 0 ? universe.artist.songCount : universe.totalSongs
    }

    var body: some View {
        ZStack {
            SoftGlowBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("正在构建 \(artistName) 音乐宇宙…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 120)
                    } else if let errorMessage {
                        EmptyState(icon: "sparkles.tv", title: "星云加载失败", detail: errorMessage)
                        } else if let universe {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(universe.artist.name).font(AppFont.pageTitle)
                            Text("\(universe.albums.count) 张专辑 · \(displayedSongCount) 首歌曲 · 网易云")
                                .font(AppFont.caption)
                                .foregroundStyle(GlowPalette.secondary)
                            if isExpandingUniverse {
                                Text("正在补充完整专辑列表…")
                                    .font(AppFont.small)
                                    .foregroundStyle(GlowPalette.secondary.opacity(0.72))
                            }
                        }

                        Picker("宇宙查看方式", selection: $presentation) {
                            ForEach(ArtistUniversePresentation.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("音乐宇宙查看方式")

                        if presentation == .nebula {
                            NebulaUniverseView(albums: universe.albums, selectedAlbumID: $selectedAlbumID, onSelectAlbum: selectAlbum)
                                .frame(height: 470)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(universe.albums) { album in
                                    Button {
                                        selectAlbum(album.id)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ArtworkView(url: album.coverURL, symbol: "square.stack.fill")
                                                .frame(width: 58, height: 58)
                                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(album.name).font(AppFont.rowTitle.weight(.semibold)).lineLimit(1)
                                                Text([album.releaseDate, albumSongsByID[album.id].map { "\($0.count) 首" } ?? "点击加载歌曲"].filter { !$0.isEmpty }.joined(separator: " · "))
                                                    .font(AppFont.caption)
                                                    .foregroundStyle(GlowPalette.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: selectedAlbumID == album.id ? "checkmark.circle.fill" : "chevron.right")
                                                .foregroundStyle(selectedAlbumID == album.id ? GlowPalette.violet : GlowPalette.secondary)
                                        }
                                        .padding(12)
                                        .background(selectedAlbumID == album.id ? GlowPalette.violet.opacity(0.13) : GlowPalette.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let selectedAlbum {
                            VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(selectedAlbum.name).font(AppFont.sectionTitle)
                                            Text(albumLoadingID == selectedAlbum.id ? "正在加载歌曲…" : (selectedAlbum.songs.isEmpty ? "点击专辑加载歌曲" : "点击歌曲播放 · \(selectedAlbum.songs.count) 首"))
                                                .font(AppFont.caption)
                                                .foregroundStyle(GlowPalette.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            guard let first = selectedAlbum.songs.first else { return }
                                            player.play(first, queue: selectedAlbum.songs)
                                        } label: {
                                            Label(albumLoadingID == selectedAlbum.id ? "加载中" : "播放整张", systemImage: albumLoadingID == selectedAlbum.id ? "hourglass" : "play.fill")
                                                .font(AppFont.caption.weight(.semibold))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(GlowPalette.violet)
                                        .disabled(selectedAlbum.songs.isEmpty || albumLoadingID == selectedAlbum.id)
                                    }
                                    if selectedAlbum.songs.isEmpty {
                                        Text("点按任意专辑封面后加载歌曲")
                                            .font(AppFont.caption)
                                            .foregroundStyle(GlowPalette.secondary)
                                            .frame(maxWidth: .infinity, minHeight: 70)
                                    } else {
                                        LazyVStack(spacing: 8) {
                                            ForEach(Array(selectedAlbum.songs.enumerated()), id: \.element.id) { index, song in
                                                QueueSongRow(index: index + 1, song: song, isCurrent: player.current == song) {
                                                    player.play(song, queue: selectedAlbum.songs)
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppMetrics.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("音乐宇宙")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let value = try await SelfRadioAPI.shared.artistUniverse(for: artistName, limit: 14)
            universe = value
            selectedAlbumID = value.albums.first?.id
            isLoading = false
            Task { await expandUniverse() }
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func expandUniverse() async {
        guard universe != nil else { return }
        isExpandingUniverse = true
        defer { isExpandingUniverse = false }
        guard let value = try? await SelfRadioAPI.shared.artistUniverse(for: artistName, limit: 60) else { return }
        let currentSelection = selectedAlbumID
        universe = value
        if let currentSelection, value.albums.contains(where: { $0.id == currentSelection }) {
            selectedAlbumID = currentSelection
        }
    }

    private func loadAlbumSongs(_ albumID: String) async {
        guard albumSongsByID[albumID] == nil else { return }
        albumLoadingID = albumID
        defer { albumLoadingID = nil }
        do {
            albumSongsByID[albumID] = try await SelfRadioAPI.shared.albumSongs(for: albumID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectAlbum(_ albumID: String) {
        selectedAlbumID = albumID
        Task { await loadAlbumSongs(albumID) }
    }
}

private enum ArtistUniversePresentation: String, CaseIterable, Identifiable {
    case nebula
    case list

    var id: String { rawValue }
    var title: String { self == .nebula ? "星云" : "列表" }
}

private struct StarfieldBackdrop: View {
    let intensity: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
            RadialGradient(
                colors: [GlowPalette.violet.opacity(0.30), .clear],
                center: UnitPoint(x: 0.68, y: 0.46),
                startRadius: 8,
                endRadius: 250
            )
            RadialGradient(
                colors: [Color.cyan.opacity(0.18), .clear],
                center: UnitPoint(x: 0.18, y: 0.72),
                startRadius: 4,
                endRadius: 230
            )
            Canvas { context, size in
                for index in 0..<96 {
                    let seed = Double(index + 1)
                    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let y = (sin(seed * 78.233) * 0.5 + 0.5) * size.height
                    let radius = CGFloat((sin(seed * 4.23) * 0.5 + 0.5) * 1.45 + 0.35)
                    let opacity = (0.14 + (sin(seed * 6.17) * 0.5 + 0.5) * 0.62) * intensity
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct NebulaUniverseView: View {
    let albums: [MusicAlbumUniverse]
    @Binding var selectedAlbumID: String?
    let onSelectAlbum: (String) -> Void
    @Environment(PlayerStore.self) private var player
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var orbitAngle = -0.72
    @State private var dragStartAngle = -0.72
    @State private var orbitZoom: CGFloat = 1.0
    @State private var pinchStartZoom: CGFloat = 1.0

    private var displayAlbums: [MusicAlbumUniverse] { Array(albums.prefix(14)) }
    private var selectedAlbum: MusicAlbumUniverse? {
        if let selectedAlbumID, let album = displayAlbums.first(where: { $0.id == selectedAlbumID }) { return album }
        return displayAlbums.first
    }
    private var shouldAnimate: Bool { !accessibilityReduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.50, y: size.height * 0.43)
            let orbitAlbums = displayAlbums.filter { $0.id != selectedAlbum?.id }
            let count = max(orbitAlbums.count, 1)

            ZStack {
                StarfieldBackdrop(intensity: 0.9)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.groupRadius))

                Ellipse()
                    .stroke(GlowPalette.violet.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [3, 8]))
                    .frame(width: size.width * 0.90, height: size.height * 0.48)
                    .rotationEffect(.degrees(-8))
                    .offset(y: 12)

                ForEach(Array(orbitAlbums.enumerated()), id: \.element.id) { index, album in
                    let angle = orbitAngle + (Double(index) / Double(count)) * .pi * 2
                    let depth = (sin(angle) + 1) / 2
                    let scale = 0.56 + depth * 0.40
                    let x = center.x + cos(angle) * size.width * 0.38
                    let y = center.y + sin(angle) * size.height * 0.20
                    NebulaAlbumPlanet(album: album, scale: scale, isNext: index == 0) {
                        selectedAlbumID = album.id
                        onSelectAlbum(album.id)
                    }
                    .position(x: center.x + (x - center.x) * orbitZoom, y: center.y + (y - center.y) * orbitZoom)
                    .zIndex(depth)
                    .opacity(0.32 + depth * 0.68)
                    .rotation3DEffect(.degrees((0.5 - depth) * 24), axis: (x: 1, y: 0, z: 0), perspective: 0.56)
                }

                if let selectedAlbum {
                    NebulaAlbumCore(album: selectedAlbum) {
                        selectedAlbumID = selectedAlbum.id
                        onSelectAlbum(selectedAlbum.id)
                    }
                    .position(center)
                    .zIndex(2)
                }

                if player.current != nil {
                    NebulaMiniPlayerBadge()
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                VStack(spacing: 3) {
                    Text("拖动星云浏览专辑")
                        .font(AppFont.caption.weight(.medium))
                    Text("点专辑查看歌曲 · 下方可切换列表")
                        .font(AppFont.small)
                        .foregroundStyle(GlowPalette.secondary)
                }
                .foregroundStyle(GlowPalette.secondary)
                .position(x: center.x, y: size.height - 28)
                .accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { gesture in
                        orbitAngle = dragStartAngle + Double(gesture.translation.width / max(size.width, 1)) * .pi * 1.3
                    }
                    .onEnded { _ in dragStartAngle = orbitAngle }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        orbitZoom = min(1.55, max(0.72, pinchStartZoom * value))
                    }
                    .onEnded { _ in pinchStartZoom = orbitZoom }
            )
            .onTapGesture(count: 2) {
                orbitZoom = 1.0
                pinchStartZoom = 1.0
            }
            .animation(shouldAnimate ? .easeOut(duration: 0.22) : nil, value: orbitAngle)
            .animation(shouldAnimate ? .easeInOut(duration: 0.26) : nil, value: selectedAlbumID)
        }
        .background(GlowPalette.surface.opacity(0.46), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.30)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("专辑星云，共 \(displayAlbums.count) 张轨道专辑，可双指缩放")
    }
}

private struct NebulaMiniPlayerBadge: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        Button { player.toggle() } label: {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.62))
                ArtworkView(url: player.current?.artworkURL, symbol: "music.note")
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
                Circle()
                    .stroke(.white.opacity(0.70), lineWidth: 2)
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.58), in: Circle())
            }
            .frame(width: 82, height: 82)
            .shadow(color: GlowPalette.violet.opacity(0.32), radius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "暂停当前歌曲" : "播放当前歌曲")
    }
}

private struct NebulaAlbumPlanet: View {
    let album: MusicAlbumUniverse
    let scale: CGFloat
    let isNext: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ArtworkView(url: album.coverURL, symbol: "square.stack.fill")
                    .frame(width: 74 * scale, height: 74 * scale)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isNext ? GlowPalette.violet.opacity(0.74) : .white.opacity(0.18), lineWidth: isNext ? 2 : 1))
                    .shadow(color: isNext ? GlowPalette.violet.opacity(0.48) : .black.opacity(0.30), radius: isNext ? 15 : 8)
                if isNext {
                    Text("下一张")
                        .font(AppFont.small.weight(.semibold))
                        .foregroundStyle(GlowPalette.violet)
                }
            }
            .frame(minWidth: 54, minHeight: 54)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((isNext ? "下一张，" : "") + album.name + "，\(album.songs.count) 首，点按查看")
    }
}

private struct NebulaAlbumCore: View {
    let album: MusicAlbumUniverse
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(GlowPalette.violet.opacity(0.24), lineWidth: 13).frame(width: 154, height: 154)
                    ArtworkView(url: album.coverURL, symbol: "square.stack.fill")
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.74), lineWidth: 1.5))
                }
                Text(album.name)
                    .font(AppFont.rowTitle.weight(.semibold))
                    .lineLimit(1)
                Text([album.releaseDate, "\(album.songs.count) 首"].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(AppFont.small)
                    .foregroundStyle(GlowPalette.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("当前专辑，\(album.name)，点按查看歌曲")
    }
}

private struct QueueView: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: QueuePresentation = .list

    var body: some View {
        NavigationStack {
            ZStack {
                SoftGlowBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("查看方式", selection: $presentation) {
                            ForEach(QueuePresentation.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("播放队列查看方式")

                        HStack(spacing: 10) {
                            QueueSummaryPill(icon: player.playbackMode.symbol, text: player.playbackMode.rawValue)
                            QueueSummaryPill(icon: "music.note", text: "\(player.queue.count) 首")
                        }
                        .padding(.top, 6)

                        Button {
                            player.toggleShuffle()
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text(player.playbackMode == .shuffle ? "随机播放已开启" : "开启随机播放")
                                Spacer()
                                Image(systemName: player.playbackMode == .shuffle ? "checkmark.circle.fill" : "circle")
                            }
                            .font(AppFont.rowTitle)
                            .foregroundStyle(player.playbackMode == .shuffle ? GlowPalette.violet : GlowPalette.ink)
                            .padding(14)
                            .background(GlowPalette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
                        }
                        .buttonStyle(.plain)

                        if presentation == .nebula {
                            QueueNebulaBrowser(songs: player.queue, current: player.current) { song in
                                player.play(song)
                                dismiss()
                            }
                            .frame(height: 430)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, song in
                                    QueueSongRow(index: index + 1, song: song, isCurrent: song == player.current) {
                                        player.play(song)
                                        dismiss()
                                    }
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, AppMetrics.pagePadding)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private enum QueuePresentation: String, CaseIterable, Identifiable {
    case list
    case nebula

    var id: String { rawValue }
    var title: String { self == .list ? "列表" : "星云" }
}

private struct QueueNebulaBrowser: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let songs: [Song]
    let current: Song?
    let play: (Song) -> Void
    @State private var orbitAngle = -0.72
    @State private var dragStartAngle = -0.72

    private var displaySongs: [Song] {
        let source = songs.isEmpty ? (current.map { [$0] } ?? []) : songs
        return Array(source.prefix(18))
    }

    private var currentSong: Song? {
        current ?? displaySongs.first
    }

    private var orbitSongs: [Song] {
        guard let currentSong else { return displaySongs }
        var removedCurrent = false
        return displaySongs.filter { song in
            if !removedCurrent && song.id == currentSong.id {
                removedCurrent = true
                return false
            }
            return true
        }
    }

    private var shouldAnimate: Bool {
        player.playbackMotionEnabled && !accessibilityReduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.50, y: size.height * 0.47)
            let orbitCount = max(orbitSongs.count, 1)

            ZStack {
                Ellipse()
                    .stroke(GlowPalette.violet.opacity(0.17), style: StrokeStyle(lineWidth: 1, dash: [4, 7]))
                    .frame(width: size.width * 0.84, height: size.height * 0.46)
                    .rotationEffect(.degrees(-7))
                    .offset(y: 8)

                ForEach(Array(orbitSongs.enumerated()), id: \.offset) { index, song in
                    let angle = orbitAngle + (Double(index) / Double(orbitCount)) * .pi * 2
                    let depth = (sin(angle) + 1) / 2
                    let scale = 0.60 + depth * 0.34
                    let x = center.x + cos(angle) * size.width * 0.36
                    let y = center.y + sin(angle) * size.height * 0.18

                    NebulaSongPlanet(song: song, isNext: index == 0, scale: scale) {
                        play(song)
                    }
                    .position(x: x, y: y)
                    .zIndex(depth)
                    .opacity(0.42 + depth * 0.58)
                    .rotation3DEffect(.degrees((0.5 - depth) * 22), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                }

                if let currentSong {
                    NebulaCurrentPlanet(song: currentSong) {
                        play(currentSong)
                    }
                    .position(center)
                    .zIndex(2)
                }

                VStack(spacing: 3) {
                    Text("拖动星云浏览队列")
                        .font(AppFont.caption.weight(.medium))
                    Text("点封面立即播放 · 可随时切回列表")
                        .font(AppFont.small)
                        .foregroundStyle(GlowPalette.secondary)
                }
                .foregroundStyle(GlowPalette.secondary)
                .position(x: center.x, y: size.height - 25)
                .accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { gesture in
                        orbitAngle = dragStartAngle + Double(gesture.translation.width / max(size.width, 1)) * .pi * 1.3
                    }
                    .onEnded { _ in
                        dragStartAngle = orbitAngle
                    }
            )
            .animation(shouldAnimate ? .easeOut(duration: 0.22) : nil, value: orbitAngle)
            .animation(shouldAnimate ? .easeInOut(duration: 0.26) : nil, value: player.current?.id)
        }
        .background(GlowPalette.surface.opacity(0.52), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(GlowPalette.separator.opacity(0.28)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("星云播放队列，共 \(displaySongs.count) 首歌曲")
    }
}

private struct NebulaSongPlanet: View {
    let song: Song
    let isNext: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ArtworkView(url: song.artworkURL, symbol: song.provider.symbol)
                    .frame(width: 70 * scale, height: 70 * scale)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isNext ? GlowPalette.violet.opacity(0.72) : .white.opacity(0.17), lineWidth: isNext ? 2 : 1))
                    .shadow(color: isNext ? GlowPalette.violet.opacity(0.48) : .black.opacity(0.28), radius: isNext ? 14 : 8)
                if isNext {
                    Text("下一首")
                        .font(AppFont.small.weight(.semibold))
                        .foregroundStyle(GlowPalette.violet)
                }
            }
            .frame(minWidth: 56, minHeight: 56)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((isNext ? "下一首，" : "") + song.title + "，\(song.artist)，点按播放")
    }
}

private struct NebulaCurrentPlanet: View {
    let song: Song
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    Circle().stroke(GlowPalette.violet.opacity(0.26), lineWidth: 12).frame(width: 142, height: 142)
                    ArtworkView(url: song.artworkURL, symbol: song.provider.symbol)
                        .frame(width: 118, height: 118)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.26)))
                }
                Text(song.title)
                    .font(AppFont.rowTitle.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 180)
                Text(song.artist.isEmpty ? song.provider.rawValue : song.artist)
                    .font(AppFont.caption)
                    .foregroundStyle(GlowPalette.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180)
            }
            .multilineTextAlignment(.center)
            .frame(minWidth: 180, minHeight: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("正在播放，\(song.title)，\(song.artist)，点按重新播放")
    }
}

private struct QueueSummaryPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(AppFont.caption.weight(.semibold))
            .foregroundStyle(GlowPalette.secondary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(GlowPalette.surface.opacity(0.72), in: Capsule())
    }
}

private struct QueueSongRow: View {
    let index: Int
    let song: Song
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    ArtworkView(url: song.artworkURL, symbol: song.provider.symbol)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    if isCurrent {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(GlowPalette.violet, in: Circle())
                            .offset(x: 5, y: 5)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(song.title)
                            .font(AppFont.rowTitle.weight(isCurrent ? .semibold : .medium))
                            .lineLimit(1)
                        if isCurrent {
                            Text("播放中")
                                .font(AppFont.small.weight(.semibold))
                                .foregroundStyle(GlowPalette.violet)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(GlowPalette.violet.opacity(0.13), in: Capsule())
                        }
                    }
                    Text(song.artist.isEmpty ? song.provider.rawValue : "\(song.artist) · \(song.provider.rawValue)")
                        .font(AppFont.caption)
                        .foregroundStyle(GlowPalette.secondary)
                        .lineLimit(1)
                }

                Spacer()
                Text("\(index)")
                    .font(AppFont.small.monospacedDigit())
                    .foregroundStyle(GlowPalette.secondary.opacity(0.7))
                    .frame(width: 24)
            }
            .padding(12)
            .background(isCurrent ? GlowPalette.violet.opacity(0.12) : GlowPalette.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: AppMetrics.groupRadius))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.groupRadius).stroke(isCurrent ? GlowPalette.violet.opacity(0.38) : GlowPalette.separator.opacity(0.24)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EffectsView: View {
    @Environment(PlayerStore.self) private var player
    @State private var beat = true; @State private var automix = false
    var body: some View {
        @Bindable var player = player
        NavigationStack {
            Form {
                Section("沉浸视觉") { Picker("柔光风格", selection: $player.visualStyle) { ForEach(PlayerVisualStyle.allCases) { Text($0.rawValue).tag($0) } }; Toggle("跟随节拍", isOn: $beat) }
                Section("连续混音") { Toggle("AutoMix 智能过渡", isOn: $automix); Text("根据节拍和段落选择自然的切歌时机。").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("音效空间").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium, .large])
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] { stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) } }
}
