import Foundation
import OSLog

enum APIError: LocalizedError {
    case invalidConfiguration
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "服务未配置"
        case .server(let message): message
        }
    }
}

enum HomeFeedCache {
    private static let key = "selfradio.home.feed.v1"

    static func load() -> HomeFeed {
        guard let data = UserDefaults.standard.data(forKey: key) else { return HomeFeed() }
        var feed = (try? JSONDecoder().decode(HomeFeed.self, from: data)) ?? HomeFeed()
        feed.sections = deduplicatedHomeSections(feed.sections)
        return feed
    }

    static func save(_ feed: HomeFeed) {
        guard !feed.isEmpty, let data = try? JSONEncoder().encode(feed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private func deduplicatedHomeSections(_ sections: [HomeSection]) -> [HomeSection] {
    var seen = Set<String>()
    return sections.compactMap { section in
        let playlists = section.playlists.filter { playlist in
            seen.insert("\(playlist.provider.rawValue.lowercased()):\(playlist.id)").inserted
        }
        guard !playlists.isEmpty else { return nil }
        return HomeSection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            playlists: playlists
        )
    }
}

struct SelfRadioAPI {
    static let shared = SelfRadioAPI()
    private static let lyricLogger = Logger(subsystem: "cn.remjdor.selfradio", category: "lyrics")

    private var baseURL: URL? { SelfRadioSecrets.apiBaseURL }
    private var token: String { SelfRadioSecrets.apiToken }

    func request(path: String, query: [URLQueryItem] = [], method: String = "GET", body: [String: String]? = nil) async throws -> Data {
        guard let baseURL else { throw APIError.invalidConfiguration }
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = query
        guard let url = components?.url else { throw APIError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw APIError.server(object?["message"] as? String ?? object?["error"] as? String ?? "服务请求失败")
        }
        return data
    }

    func search(_ keyword: String, provider: MusicProvider) async throws -> [Song] {
        let path = provider == .qq ? "api/qq/search" : (provider == .qishui ? "api/qishui/search" : "api/search")
        let data = try await request(path: path, query: [.init(name: "keywords", value: keyword), .init(name: "limit", value: "20")])
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rows = root?["songs"] as? [[String: Any]] ?? []
        return decodeSongs(rows, provider: provider)
    }

    func artistUniverse(for name: String, provider: MusicProvider = .netease, limit: Int = 60) async throws -> MusicArtistUniverse {
        guard provider == .netease else { throw APIError.server("歌手星云暂支持网易云") }
        let targetName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var artistId = ""
        var resolvedArtistName = targetName

        if let artistSearchData = try? await request(path: "api/artist/search", query: [
            .init(name: "keywords", value: targetName),
            .init(name: "limit", value: "6")
        ]) {
            let artistSearchRoot = try? JSONSerialization.jsonObject(with: artistSearchData) as? [String: Any]
            let artistRows = artistSearchRoot?["artists"] as? [[String: Any]] ?? []
            let selectedArtist = artistRows.first(where: { string($0["name"]) == targetName }) ?? artistRows.first
            artistId = string(selectedArtist?["id"])
            if !string(selectedArtist?["name"]).isEmpty {
                resolvedArtistName = string(selectedArtist?["name"])
            }
        }

        let fallbackMatch: Song?
        if artistId.isEmpty {
            let matches = try await search(name, provider: provider)
            fallbackMatch = matches.first(where: { $0.artistId != nil && !$0.artistId!.isEmpty })
            artistId = fallbackMatch?.artistId ?? ""
            if let fallbackName = fallbackMatch?.artist, !fallbackName.isEmpty {
                resolvedArtistName = fallbackName
            }
        } else {
            fallbackMatch = nil
        }

        guard !artistId.isEmpty else {
            throw APIError.server("没有找到可展开的歌手资料")
        }
        let data = try await request(path: "api/artist/universe", query: [
            .init(name: "id", value: artistId),
            .init(name: "limit", value: String(max(8, min(60, limit)))),
            .init(name: "details", value: "0")
        ])
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let message = root?["error"] as? String, !message.isEmpty { throw APIError.server(message) }
        let artistRow = root?["artist"] as? [String: Any] ?? [:]
        let profile = MusicArtistProfile(
            id: string(artistRow["id"]).isEmpty ? artistId : string(artistRow["id"]),
            name: string(artistRow["name"]).isEmpty ? resolvedArtistName : string(artistRow["name"]),
            avatarURL: url(artistRow["avatar"]),
            brief: string(artistRow["brief"]),
            albumCount: int(artistRow["albumSize"]),
            songCount: int(artistRow["musicSize"])
        )
        let albums = (root?["albums"] as? [[String: Any]] ?? []).compactMap { row -> MusicAlbumUniverse? in
            let albumRow = row["album"] as? [String: Any] ?? row
            let id = string(albumRow["id"])
            let title = string(albumRow["name"])
            guard !id.isEmpty, !title.isEmpty else { return nil }
            let songs = decodeSongs(row["songs"] as? [[String: Any]] ?? [], provider: .netease)
            let releaseDate: String
            if let number = albumRow["releaseDate"] as? NSNumber, number.intValue > 0 {
                let year = Calendar(identifier: .gregorian).component(.year, from: Date(timeIntervalSince1970: number.doubleValue / 1000))
                releaseDate = String(year)
            } else {
                releaseDate = string(albumRow["releaseDate"])
            }
            return MusicAlbumUniverse(
                id: id,
                name: title,
                artist: string(albumRow["artist"]).isEmpty ? profile.name : string(albumRow["artist"]),
                coverURL: url(albumRow["cover"]),
                releaseDate: releaseDate,
                songs: songs
            )
        }
        return MusicArtistUniverse(artist: profile, albums: albums)
    }

    func albumSongs(for albumID: String, limit: Int = 120) async throws -> [Song] {
        let data = try await request(path: "api/album/detail", query: [
            .init(name: "id", value: albumID),
            .init(name: "limit", value: String(max(10, min(120, limit))))
        ])
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let message = root?["error"] as? String, !message.isEmpty { throw APIError.server(message) }
        return decodeSongs(root?["songs"] as? [[String: Any]] ?? [], provider: .netease)
    }

    func accountStatus(for provider: MusicProvider) async throws -> PlatformAccountStatus {
        let path: String
        switch provider {
        case .netease: path = "api/login/status"
        case .qq: path = "api/qq/login/status"
        case .qishui: path = "api/qishui/login/status"
        }
        let data = try await request(path: path)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let loggedIn = root?["loggedIn"] as? Bool ?? false
        let ready: Bool
        let detail: String
        switch provider {
        case .qq:
            ready = loggedIn && (root?["playbackKeyReady"] as? Bool ?? false)
            detail = ready ? "已登录 · 可播放" : (loggedIn ? "已登录 · 播放授权未完成" : "未登录")
        case .qishui:
            let webSession = root?["webSession"] as? Bool ?? root?["cookieReady"] as? Bool ?? false
            let configured = root?["configured"] as? Bool ?? false
            let capabilities = root?["capabilities"] as? [String: Any]
            let playableUrl = capabilities?["playableUrl"] as? Bool ?? webSession
            ready = configured
            if webSession && playableUrl {
                detail = "已登录 · 可播放"
            } else if configured {
                detail = "已连接 · 仅推荐/匹配"
            } else {
                detail = root?["message"] as? String ?? "未登录"
            }
        case .netease:
            ready = loggedIn
            detail = ready ? "已登录 · 可播放" : "未登录"
        }
        let nickname = root?["nickname"] as? String ?? provider.rawValue
        return PlatformAccountStatus(loggedIn: loggedIn, playbackReady: ready, nickname: nickname, detail: detail)
    }

    func logout(provider: MusicProvider) async throws {
        let path: String
        switch provider {
        case .netease: path = "api/logout"
        case .qq: path = "api/qq/logout"
        case .qishui: path = "api/qishui/logout"
        }
        _ = try await request(path: path, method: "POST")
    }

    func playlists(for provider: MusicProvider) async throws -> [MusicPlaylist] {
        let path: String
        switch provider {
        case .netease: path = "api/user/playlists"
        case .qq: path = "api/qq/user/playlists"
        case .qishui: path = "api/qishui/user/playlists"
        }
        let data = try await request(path: path)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let available = (root?["loggedIn"] as? Bool == true) || (root?["configured"] as? Bool == true)
        guard available else { throw APIError.server("请先登录 \(provider.rawValue)") }
        let rows = root?["playlists"] as? [[String: Any]] ?? []
        return rows.compactMap { row in
            let id = string(row["id"])
            let name = row["name"] as? String ?? ""
            guard !id.isEmpty, !name.isEmpty else { return nil }
            return MusicPlaylist(
                id: id,
                name: name,
                trackCount: int(row["trackCount"]),
                coverURL: url(row["cover"]),
                provider: provider,
                creator: string(row["creator"]),
                summary: string(row["description"] ?? row["summary"]),
                playCount: int(row["playCount"])
            )
        }
    }

    func playlistTracks(_ playlist: MusicPlaylist) async throws -> [Song] {
        let path: String
        switch playlist.provider {
        case .netease: path = "api/playlist/tracks"
        case .qq: path = "api/qq/playlist/tracks"
        case .qishui: path = "api/qishui/playlist/tracks"
        }
        let data = try await request(
            path: path,
            query: [.init(name: "id", value: playlist.id), .init(name: "limit", value: "100")]
        )
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let message = root?["message"] as? String, root?["error"] != nil { throw APIError.server(message) }
        let rows = root?["tracks"] as? [[String: Any]] ?? []
        return decodeSongs(rows, provider: playlist.provider)
    }

    func homeFeed() async throws -> HomeFeed {
        let data = try await request(path: "api/discover/home")
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var songs = decodeSongs(root?["dailySongs"] as? [[String: Any]] ?? [], provider: .netease)
        var trendingSongs = decodeSongs(root?["trendingSongs"] as? [[String: Any]] ?? [], provider: .netease)
        var playlists = decodePlaylists(root?["playlists"] as? [[String: Any]] ?? [])
        var sections = (root?["sections"] as? [[String: Any]] ?? []).compactMap { row -> HomeSection? in
            let id = string(row["id"])
            let title = row["title"] as? String ?? ""
            let items = decodePlaylists(row["playlists"] as? [[String: Any]] ?? [])
            guard !id.isEmpty, !title.isEmpty, !items.isEmpty else { return nil }
            return HomeSection(id: id, title: title, subtitle: row["subtitle"] as? String ?? "", playlists: items)
        }
        if songs.isEmpty {
            for section in sections {
                guard let first = section.playlists.first,
                      let tracks = try? await playlistTracks(first), !tracks.isEmpty else { continue }
                songs = Array(tracks.prefix(20))
                break
            }
        }
        if songs.isEmpty {
            for provider in [MusicProvider.qq, .qishui] {
                guard let status = try? await accountStatus(for: provider), status.playbackReady,
                      let providerPlaylists = try? await self.playlists(for: provider), !providerPlaylists.isEmpty else { continue }
                playlists.append(contentsOf: providerPlaylists.prefix(8))
                if let first = providerPlaylists.first,
                   let tracks = try? await playlistTracks(first), !tracks.isEmpty {
                    songs = Array(tracks.prefix(20))
                    break
                }
            }
        }
        if sections.isEmpty, !playlists.isEmpty {
            sections = [HomeSection(id: "recommended", title: "推荐歌单", subtitle: "来自已连接的音乐平台", playlists: playlists)]
        }
        sections = deduplicatedHomeSections(sections)
        if trendingSongs.isEmpty { trendingSongs = songs }
        return HomeFeed(dailySongs: songs, trendingSongs: trendingSongs, playlists: playlists, sections: sections)
    }

    private func decodePlaylists(_ rows: [[String: Any]]) -> [MusicPlaylist] {
        rows.compactMap { row -> MusicPlaylist? in
            let id = string(row["id"])
            let name = row["name"] as? String ?? ""
            let coverURL = url(row["cover"] ?? row["picUrl"] ?? row["coverImgUrl"] ?? row["coverUrl"])
            guard !id.isEmpty, !name.isEmpty, coverURL != nil else { return nil }
            return MusicPlaylist(
                id: id,
                name: name,
                trackCount: int(row["trackCount"]),
                coverURL: coverURL,
                provider: provider(from: row["provider"] ?? row["source"]),
                creator: string(row["creator"]),
                summary: string(row["description"] ?? row["summary"]),
                playCount: int(row["playCount"])
            )
        }
    }

    private func provider(from value: Any?) -> MusicProvider {
        switch string(value).lowercased() {
        case "qq": return .qq
        case "qishui", "qishui_music": return .qishui
        default: return .netease
        }
    }

    func resolvedAudioURL(for song: Song, quality: PlaybackQuality, allowFallback: Bool) async throws -> ResolvedAudio {
        do {
            return try await audioURL(for: song, quality: quality)
        } catch let sourceError where allowFallback && song.provider != .netease {
            let candidates = try await search("\(song.title) \(song.artist)", provider: .netease)
            guard let fallback = bestFallback(for: song, candidates: candidates) else { throw sourceError }
            return try await audioURL(for: fallback, quality: quality)
        }
    }

    private func decodeSongs(_ rows: [[String: Any]], provider: MusicProvider) -> [Song] {
        rows.compactMap { row in
            let id = string(row["mid"] ?? row["providerSongId"] ?? row["trackId"] ?? row["id"])
            guard !id.isEmpty else { return nil }
            return Song(
                id: id,
                title: row["name"] as? String ?? row["title"] as? String ?? "未知歌曲",
                artist: row["artist"] as? String ?? "未知歌手",
                provider: row["provider"] == nil ? provider : self.provider(from: row["provider"]),
                artworkURL: url(row["cover"]),
                audioURL: nil,
                mediaMid: row["mediaMid"] as? String ?? row["media_mid"] as? String,
                artistId: string(row["artistId"] ?? row["artist_id"]).isEmpty ? nil : string(row["artistId"] ?? row["artist_id"]),
                album: row["album"] as? String ?? "",
                duration: durationSeconds(row["duration"])
            )
        }
    }

    private func durationSeconds(_ value: Any?) -> TimeInterval {
        let raw = Double(int(value))
        return raw > 1000 ? raw / 1000 : raw
    }

    private func string(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }

    private func int(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private func url(_ value: Any?) -> URL? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }
        let normalized = raw.replacingOccurrences(of: "http://", with: "https://", options: [.anchored, .caseInsensitive])
        return URL(string: normalized)
    }

    private func bestFallback(for song: Song, candidates: [Song]) -> Song? {
        let title = normalized(song.title)
        let artists = artistKeys(song.artist)
        return candidates.first {
            guard normalized($0.title) == title else { return false }
            guard !artists.isDisjoint(with: artistKeys($0.artist)) else { return false }
            if !song.album.isEmpty, !$0.album.isEmpty, normalized(song.album) != normalized($0.album) { return false }
            if song.duration > 0, $0.duration > 0, abs(song.duration - $0.duration) > 4 { return false }
            return true
        }
    }

    private func artistKeys(_ value: String) -> Set<String> {
        Set(value.components(separatedBy: CharacterSet(charactersIn: "/&,、"))
            .map(normalized).filter { !$0.isEmpty })
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    func audioURL(for song: Song, quality: PlaybackQuality) async throws -> ResolvedAudio {
        let path = song.provider == .qq ? "api/qq/song/url" : (song.provider == .qishui ? "api/qishui/song/url" : "api/song/url")
        var query = [URLQueryItem(name: song.provider == .qq ? "mid" : "id", value: song.id)]
        if let mediaMid = song.mediaMid { query.append(.init(name: "mediaMid", value: mediaMid)) }
        if !quality.apiValue.isEmpty { query.append(.init(name: "quality", value: quality.apiValue)) }
        query.append(.init(name: "name", value: song.title))
        query.append(.init(name: "artist", value: song.artist))
        if !song.album.isEmpty { query.append(.init(name: "album", value: song.album)) }
        if song.duration > 0 { query.append(.init(name: "duration", value: String(Int(song.duration * 1000)))) }
        let data = try await request(path: path, query: query)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let raw = root?["url"] as? String, !raw.isEmpty else {
            throw APIError.server(root?["message"] as? String ?? root?["error"] as? String ?? "暂时无法获取播放地址")
        }
        let directURL = URL(string: raw)
        let playbackURL = try proxiedPlaybackURL(raw, provider: song.provider) ?? directURL
        guard let url = playbackURL else { throw APIError.server("播放地址无效") }
        let level = string(root?["level"]).lowercased()
        let label = string(root?["quality"]).isEmpty ? qualityLabel(for: level) : string(root?["quality"])
        let codec = audioCodec(root: root, url: url)
        let trial = root?["trial"] as? Bool ?? false
        let actualRank = qualityRank(level: level, codec: codec, bitrate: int(root?["br"] ?? root?["bitrate"]))
        let info = AudioQualityInfo(
            level: level,
            label: label,
            codec: codec,
            bitrate: int(root?["br"] ?? root?["bitrate"]),
            sampleRate: int(root?["sampleRate"]),
            bitDepth: int(root?["bitDepth"]),
            trial: trial,
            degraded: quality.rank > 0 && actualRank > 0 && actualRank < quality.rank
        )
        return ResolvedAudio(url: url, provider: song.provider, quality: info)
    }

    private func proxiedPlaybackURL(_ raw: String, provider: MusicProvider) throws -> URL? {
        guard provider == .qishui else { return nil }
        guard let baseURL else { throw APIError.invalidConfiguration }
        var components = URLComponents(url: baseURL.appending(path: "api/audio"), resolvingAgainstBaseURL: false)
        components?.queryItems = [.init(name: "url", value: raw)]
        return components?.url
    }

    private func qualityLabel(for level: String) -> String {
        switch level {
        case "jymaster": return "超清母带"
        case "hires": return "Hi-Res"
        case "lossless": return "无损"
        case "exhigh": return "320K"
        case "standard", "aac": return "标准"
        default: return "实际音质未标记"
        }
    }

    private func audioCodec(root: [String: Any]?, url: URL) -> String {
        let explicit = string(root?["codec"] ?? root?["format"])
        if !explicit.isEmpty { return explicit.lowercased() }
        let filename = string(root?["filename"])
        let ext = URL(fileURLWithPath: filename).pathExtension
        if !ext.isEmpty { return ext.lowercased() }
        let magic = string(root?["probeMagic"]).lowercased()
        if magic.contains("flac") { return "flac" }
        if magic.contains("mp3") || magic.contains("mpeg") { return "mp3" }
        if magic.contains("mp4") { return "m4a" }
        return url.pathExtension.lowercased()
    }

    private func qualityRank(level: String, codec: String, bitrate: Int) -> Int {
        if level == "jymaster" || level == "hires" { return 4 }
        if level == "lossless" || ["flac", "alac", "wav"].contains(codec) { return 3 }
        if level == "exhigh" || bitrate >= 300_000 { return 2 }
        if level == "standard" || level == "aac" || bitrate > 0 { return 1 }
        return 0
    }

    func lyrics(for song: Song) async throws -> [LyricLine] {
        let path = song.provider == .qq ? "api/qq/lyric" : (song.provider == .qishui ? "api/qishui/lyric" : "api/lyric")
        var query = [URLQueryItem(name: song.provider == .qq ? "mid" : "id", value: song.id)]
        if song.provider == .qq { query.append(.init(name: "id", value: song.id)) }
        Self.lyricLogger.info("歌词请求 provider=\(song.provider.rawValue, privacy: .public) id=\(song.id, privacy: .private(mask: .hash))")
        let data = try await request(path: path, query: query)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let original = root?["lyric"] as? String ?? ""
        let translated = root?["tlyric"] as? String ?? root?["trans"] as? String ?? ""
        let nativeTiming = root?["yrc"] as? String ?? root?["qrc"] as? String ?? ""
        let translations = Dictionary(uniqueKeysWithValues: parseLRC(translated).map { (Int($0.time * 10), $0.text) })
        let timedLines = parseYRC(nativeTiming)
        let lines = (timedLines.isEmpty ? parseLRC(original) : timedLines).map { line in
            LyricLine(time: line.time, text: line.text, translation: translations[Int(line.time * 10)])
        }
        Self.lyricLogger.info("歌词结果 provider=\(song.provider.rawValue, privacy: .public) id=\(song.id, privacy: .private(mask: .hash)) source=\(timedLines.isEmpty ? "lrc" : "yrc", privacy: .public) lines=\(lines.count, privacy: .public) nativeChars=\(nativeTiming.count, privacy: .public)")
        return lines
    }

    /// 解析 QQ qrc / 网易 yrc 的逐字时间轴；客户端当前按行切换，但使用原生行起始时间可避免 LRC 降精度。
    private func parseYRC(_ text: String) -> [LyricLine] {
        let linePattern = #"^\[(\d+),(\d+)\](.*)$"#
        let wordPattern = #"\((\d+),(\d+),\d+\)([^()]*)"#
        guard let lineRegex = try? NSRegularExpression(pattern: linePattern),
              let wordRegex = try? NSRegularExpression(pattern: wordPattern) else { return [] }

        return text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = String(raw)
            let lineRange = NSRange(line.startIndex..., in: line)
            guard let match = lineRegex.firstMatch(in: line, range: lineRange),
                  let startRange = Range(match.range(at: 1), in: line),
                  let bodyRange = Range(match.range(at: 3), in: line),
                  let startMs = Double(String(line[startRange])) else { return nil }

            let body = String(line[bodyRange])
            let bodyRangeNS = NSRange(body.startIndex..., in: body)
            let wordMatches = wordRegex.matches(in: body, range: bodyRangeNS)
            let textValue: String
            if wordMatches.isEmpty {
                textValue = body.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            } else {
                textValue = wordMatches.compactMap { wordMatch in
                    guard let wordRange = Range(wordMatch.range(at: 3), in: body) else { return nil }
                    return String(body[wordRange])
                }.joined()
            }
            let trimmed = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return LyricLine(time: startMs / 1000, text: trimmed)
        }.sorted { $0.time < $1.time }
    }

    private func parseLRC(_ text: String) -> [LyricLine] {
        let pattern = #"\[(\d{1,3}):(\d{1,2})(?:[\.:](\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return text.split(whereSeparator: \.isNewline).flatMap { raw -> [LyricLine] in
            let line = String(raw)
            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, range: range)
            let lyric = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
            guard !lyric.isEmpty else { return [] }
            return matches.compactMap { match in
                guard match.numberOfRanges >= 3,
                      let minuteRange = Range(match.range(at: 1), in: line),
                      let secondRange = Range(match.range(at: 2), in: line) else { return nil }
                let minutes = Double(line[minuteRange]) ?? 0
                let seconds = Double(line[secondRange]) ?? 0
                var fraction = 0.0
                if match.numberOfRanges > 3, let fractionRange = Range(match.range(at: 3), in: line) {
                    let digits = String(line[fractionRange])
                    fraction = (Double(digits) ?? 0) / pow(10, Double(digits.count))
                }
                return LyricLine(time: minutes * 60 + seconds + fraction, text: lyric)
            }
        }.sorted { $0.time < $1.time }
    }
}

protocol MusicPlatformService {
    var provider: MusicProvider { get }
    func search(_ keyword: String) async throws -> [Song]
}

struct SelfRadioPlatformService: MusicPlatformService {
    let provider: MusicProvider
    func search(_ keyword: String) async throws -> [Song] {
        try await SelfRadioAPI.shared.search(keyword, provider: provider)
    }
}
