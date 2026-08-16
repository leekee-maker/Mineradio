import Foundation

enum MusicProvider: String, CaseIterable, Identifiable, Codable {
    case netease = "网易云"
    case qq = "QQ音乐"
    case qishui = "汽水"

    var id: String { rawValue }
    var apiValue: String {
        switch self {
        case .netease: "netease"
        case .qq: "qq"
        case .qishui: "qishui"
        }
    }
    var symbol: String {
        switch self {
        case .netease: "waveform.circle.fill"
        case .qq: "music.note.list"
        case .qishui: "drop.circle.fill"
        }
    }
}

struct Song: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let artist: String
    let provider: MusicProvider
    var artworkURL: URL?
    var audioURL: URL?
    var mediaMid: String? = nil
    var artistId: String? = nil
    var album: String = ""
    var duration: TimeInterval = 0

    static let previews: [Song] = [
        .init(id: "preview-1", title: "让音乐成为私人现场", artist: "随心听", provider: .netease),
        .init(id: "preview-2", title: "今日随心听", artist: "每日推荐", provider: .qq),
        .init(id: "preview-3", title: "夜间电台", artist: "沉浸歌单", provider: .qishui)
    ]
}

struct MusicArtistProfile: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    var avatarURL: URL?
    var brief: String = ""
    var albumCount: Int = 0
    var songCount: Int = 0
}

struct MusicAlbumUniverse: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let artist: String
    let coverURL: URL?
    var releaseDate: String = ""
    var songs: [Song] = []
}

struct MusicArtistUniverse: Hashable, Codable {
    let artist: MusicArtistProfile
    let albums: [MusicAlbumUniverse]
    var totalSongs: Int { albums.reduce(0) { $0 + $1.songs.count } }
}

struct MusicPlaylist: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let trackCount: Int
    let coverURL: URL?
    let provider: MusicProvider
    var creator = ""
    var summary = ""
    var playCount = 0
}

struct PlatformAccountStatus: Sendable {
    var loggedIn = false
    var playbackReady = false
    var nickname = ""
    var detail = "未登录"
}

struct HomeFeed: Codable {
    var dailySongs: [Song] = []
    var trendingSongs: [Song] = []
    var playlists: [MusicPlaylist] = []
    var sections: [HomeSection] = []

    var isEmpty: Bool {
        dailySongs.isEmpty && trendingSongs.isEmpty && playlists.isEmpty && sections.isEmpty
    }
}

struct HomeSection: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let playlists: [MusicPlaylist]
}

struct ResolvedAudio {
    let url: URL
    let provider: MusicProvider
    let quality: AudioQualityInfo
}

enum PlaybackQuality: String, CaseIterable, Identifiable {
    case smart = "智能"
    case standard = "标准"
    case high = "320K"
    case lossless = "无损"
    case hires = "Hi-Res"

    var id: String { rawValue }
    var apiValue: String {
        switch self {
        case .smart: ""
        case .standard: "standard"
        case .high: "exhigh"
        case .lossless: "lossless"
        case .hires: "hires"
        }
    }
    var rank: Int {
        switch self {
        case .smart: 0
        case .standard: 1
        case .high: 2
        case .lossless: 3
        case .hires: 4
        }
    }
}

enum PlaybackMode: String, CaseIterable, Identifiable {
    case listLoop = "列表循环"
    case singleLoop = "单曲循环"
    case shuffle = "随机播放"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .listLoop: "repeat"
        case .singleLoop: "repeat.1"
        case .shuffle: "shuffle"
        }
    }
    var shortTitle: String {
        switch self {
        case .listLoop: "列表"
        case .singleLoop: "单曲"
        case .shuffle: "随机"
        }
    }
}

struct AudioQualityInfo {
    var level = ""
    var label = "未知音质"
    var codec = ""
    var bitrate = 0
    var sampleRate = 0
    var bitDepth = 0
    var trial = false
    var degraded = false

    var detail: String {
        var parts = [label]
        if !codec.isEmpty, !label.localizedCaseInsensitiveContains(codec) { parts.append(codec.uppercased()) }
        if bitrate > 0 { parts.append("\(Int(round(Double(bitrate) / 1000)))kbps") }
        if sampleRate > 0 { parts.append("\(sampleRate / 1000)kHz") }
        if bitDepth > 0 { parts.append("\(bitDepth)bit") }
        if trial { parts.append("试听") }
        return parts.joined(separator: " · ")
    }
}

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let text: String
    var translation: String? = nil
}

enum PlayerVisualStyle: String, CaseIterable, Identifiable {
    case softGlow = "柔光"
    case aurora = "极光"
    case quiet = "静谧"

    var id: String { rawValue }
}

enum PlayerArtworkPresentation: String, CaseIterable, Identifiable {
    case cover = "封面模式"
    case vinyl = "黑胶模式"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cover: "默认海报"
        case .vinyl: "经典黑胶"
        }
    }

    var subtitle: String {
        switch self {
        case .cover: "完整展示歌曲封面"
        case .vinyl: "黑胶纹理，播放时缓慢旋转"
        }
    }
}

enum LyricDisplayStyle: String, CaseIterable, Identifiable {
    case plain = "平铺歌词"
    case nebula = "星云诗幕"
    case moonsea = "月海回声"
    case starWars = "星际大战"

    var id: String { rawValue }

    static func stored(_ rawValue: String) -> LyricDisplayStyle {
        if rawValue == "3D 星空字幕" { return .nebula }
        return LyricDisplayStyle(rawValue: rawValue) ?? .plain
    }
}
