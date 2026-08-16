import AVFoundation
import MediaPlayer
import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class PlayerStore {
    private static let lyricLogger = Logger(subsystem: "cn.remjdor.selfradio", category: "lyrics")
    var current: Song?
    var queue: [Song] = []
    var isPlaying = false
    var progress = 0.0
    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 0
    var lyrics: [LyricLine] = []
    var lyricsLoading = false
    var visualStyle: PlayerVisualStyle = .softGlow
    var lyricDisplayStyle: LyricDisplayStyle {
        didSet { UserDefaults.standard.set(lyricDisplayStyle.rawValue, forKey: "selfradio.lyrics.displayStyle") }
    }
    var volume: Double = 1
    var showingNowPlaying = false
    var playbackError: String?
    var playbackProvider: MusicProvider?
    var playbackQuality: AudioQualityInfo?
    var playbackNotice: String?
    var recentSongs: [Song] = []
    var favoriteSongs: [Song] = []
    var favoritePlaylists: [MusicPlaylist] = []
    var playbackMode: PlaybackMode {
        didSet { UserDefaults.standard.set(playbackMode.rawValue, forKey: "selfradio.playback.mode") }
    }
    var qualityPreference: PlaybackQuality {
        didSet { UserDefaults.standard.set(qualityPreference.rawValue, forKey: "selfradio.playback.quality") }
    }
    var automaticSourceFallback: Bool {
        didSet { UserDefaults.standard.set(automaticSourceFallback, forKey: "selfradio.playback.fallback") }
    }
    var playbackMotionEnabled: Bool {
        didSet { UserDefaults.standard.set(playbackMotionEnabled, forKey: "selfradio.motion.playback") }
    }
    var lyricMotionEnabled: Bool {
        didSet { UserDefaults.standard.set(lyricMotionEnabled, forKey: "selfradio.motion.lyrics") }
    }
    var coverGlowEnabled: Bool {
        didSet { UserDefaults.standard.set(coverGlowEnabled, forKey: "selfradio.motion.coverGlow") }
    }
    var artworkPresentation: PlayerArtworkPresentation {
        didSet { UserDefaults.standard.set(artworkPresentation.rawValue, forKey: "selfradio.player.artworkPresentation") }
    }
    var lyricOffset: Double = 0 {
        didSet {
            guard let current = self.current else { return }
            self.lyricOffsets[self.lyricKey(for: current)] = self.lyricOffset
            self.persistLyricOffsets()
            Self.lyricLogger.info("歌词偏移 provider=\(current.provider.rawValue, privacy: .public) id=\(current.id, privacy: .private(mask: .hash)) offset=\(self.lyricOffset, privacy: .public)")
        }
    }
    var particleVisualEnabled: Bool {
        didSet { UserDefaults.standard.set(particleVisualEnabled, forKey: "selfradio.motion.particles") }
    }
    var artworkAccentColor: UIColor = .systemPurple
    var artworkAspectRatio: CGFloat = 1

    private let player = AVPlayer()
    private let artworkCache = NSCache<NSURL, UIImage>()
    private var timeObserver: Any?
    private var playbackEndedObserver: NSObjectProtocol?
    private var artworkLoadTask: Task<Void, Never>?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var lyricOffsets: [String: Double] = [:]

    init() {
        playbackMode = PlaybackMode(rawValue: UserDefaults.standard.string(forKey: "selfradio.playback.mode") ?? "") ?? .listLoop
        qualityPreference = PlaybackQuality(rawValue: UserDefaults.standard.string(forKey: "selfradio.playback.quality") ?? "") ?? .smart
        automaticSourceFallback = UserDefaults.standard.object(forKey: "selfradio.playback.fallback") as? Bool ?? true
        playbackMotionEnabled = UserDefaults.standard.object(forKey: "selfradio.motion.playback") as? Bool ?? true
        lyricMotionEnabled = UserDefaults.standard.object(forKey: "selfradio.motion.lyrics") as? Bool ?? true
        coverGlowEnabled = UserDefaults.standard.object(forKey: "selfradio.motion.coverGlow") as? Bool ?? true
        artworkPresentation = PlayerArtworkPresentation(rawValue: UserDefaults.standard.string(forKey: "selfradio.player.artworkPresentation") ?? "") ?? .cover
        lyricDisplayStyle = LyricDisplayStyle.stored(UserDefaults.standard.string(forKey: "selfradio.lyrics.displayStyle") ?? "")
        particleVisualEnabled = UserDefaults.standard.object(forKey: "selfradio.motion.particles") as? Bool ?? true
        lyricOffsets = loadLyricOffsets()
        loadLibraryState()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--profile-preview"), favoritePlaylists.isEmpty {
            favoritePlaylists = [
                MusicPlaylist(id: "preview-rise", name: "飙升榜", trackCount: 100, coverURL: recentSongs.indices.contains(0) ? recentSongs[0].artworkURL : nil, provider: .qq),
                MusicPlaylist(id: "preview-city", name: "【City Walk】城市节奏中漫步精选", trackCount: 89, coverURL: recentSongs.indices.contains(1) ? recentSongs[1].artworkURL : nil, provider: .netease),
                MusicPlaylist(id: "preview-focus", name: "治愈放松｜轻音乐精选", trackCount: 60, coverURL: recentSongs.indices.contains(2) ? recentSongs[2].artworkURL : nil, provider: .qq)
            ]
        }
#endif
        configureAudioSession()
        configureRemoteCommands()
        observeTime()
        observePlaybackEnd()
    }

    func play(_ song: Song, queue: [Song]? = nil) {
        current = song
        lyrics = []
        lyricsLoading = false
        lyricOffset = lyricOffsets[lyricKey(for: song)] ?? 0
        loadNowPlayingArtwork(for: song)
        if let queue { self.queue = queue }
        recordRecent(song)
        if let url = song.audioURL {
            start(ResolvedAudio(url: url, provider: song.provider, quality: AudioQualityInfo()))
        } else {
            isPlaying = false
            playbackQuality = nil
            playbackNotice = nil
            Task { [weak self] in
                guard let self else { return }
                do {
                    let resolved = try await SelfRadioAPI.shared.resolvedAudioURL(
                        for: song,
                        quality: self.qualityPreference,
                        allowFallback: self.automaticSourceFallback
                    )
                    guard self.current?.id == song.id, self.current?.provider == song.provider else { return }
                    self.start(resolved)
                }
                catch {
                    Self.lyricLogger.error("音源解析失败 provider=\(song.provider.rawValue, privacy: .public) id=\(song.id, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)")
                    self.playbackError = error.localizedDescription
                }
            }
        }
        updateNowPlaying()
    }

    private func start(_ resolved: ResolvedAudio) {
        player.replaceCurrentItem(with: AVPlayerItem(url: resolved.url))
        player.play()
        isPlaying = true
        playbackProvider = resolved.provider
        playbackQuality = resolved.quality
        if resolved.quality.trial {
            playbackNotice = "当前音源仅返回试听片段"
        } else if resolved.quality.degraded {
            playbackNotice = "未取得\(qualityPreference.rawValue)，已降至\(resolved.quality.label)"
        } else if resolved.provider != current?.provider {
            playbackNotice = "原平台不可播，已严格匹配到\(resolved.provider.rawValue)"
        } else {
            playbackNotice = nil
        }
        playbackError = nil
        if resolved.provider != current?.provider {
            Self.lyricLogger.warning("音源跨平台 provider=\(self.current?.provider.rawValue ?? "未知", privacy: .public) actual=\(resolved.provider.rawValue, privacy: .public)")
        }
        updateNowPlaying()
        Task { [weak self] in
            guard let self else { return }
            await self.loadLyrics()
        }
    }

    func toggle() {
        guard current != nil else {
            play(Song.previews[0], queue: Song.previews)
            return
        }
        guard player.currentItem != nil else {
            if let current { play(current) }
            return
        }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func applyQualityPreference(_ quality: PlaybackQuality) {
        qualityPreference = quality
        guard let current else { return }
        guard current.audioURL == nil else {
            playbackNotice = "当前歌曲使用固定音源，无法切换音质"
            return
        }
        Self.lyricLogger.info("切换音质 preference=\(quality.rawValue, privacy: .public) provider=\(current.provider.rawValue, privacy: .public)")
        play(current, queue: queue)
    }

    func next() {
        advance(afterCompletion: false)
    }

    private func advance(afterCompletion: Bool) {
        guard let current, let index = queue.firstIndex(of: current), !queue.isEmpty else { return }
        if afterCompletion, playbackMode == .singleLoop {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            updateNowPlaying()
            return
        }
        if playbackMode == .shuffle, queue.count > 1 {
            play(queue.filter { $0 != current }.randomElement() ?? queue[(index + 1) % queue.count])
        } else {
            play(queue[(index + 1) % queue.count])
        }
    }

    func previous() {
        guard let current, let index = queue.firstIndex(of: current), !queue.isEmpty else { return }
        play(queue[(index - 1 + queue.count) % queue.count])
    }

    func cyclePlaybackMode() {
        let modes = PlaybackMode.allCases
        let index = modes.firstIndex(of: playbackMode) ?? 0
        playbackMode = modes[(index + 1) % modes.count]
    }

    func toggleShuffle() {
        playbackMode = playbackMode == .shuffle ? .listLoop : .shuffle
    }

    func moveQueue(from offsets: IndexSet, to destination: Int) {
        let source = offsets.sorted()
        let moving = source.map { queue[$0] }
        for index in source.reversed() { queue.remove(at: index) }
        let insertion = max(0, min(queue.count, destination - source.filter { $0 < destination }.count))
        queue.insert(contentsOf: moving, at: insertion)
    }

    func enqueue(_ song: Song) {
        queue.append(song)
    }

    func playNext(_ song: Song) {
        guard song != current else { return }
        queue.removeAll { $0 == song }
        if let current, let index = queue.firstIndex(of: current) {
            queue.insert(song, at: index + 1)
        } else {
            queue.insert(song, at: 0)
        }
    }

    func isFavorite(_ song: Song?) -> Bool {
        guard let song else { return false }
        return favoriteSongs.contains(song)
    }

    func toggleFavorite(_ song: Song?) {
        guard let song else { return }
        if let index = favoriteSongs.firstIndex(of: song) {
            favoriteSongs.remove(at: index)
        } else {
            favoriteSongs.insert(song, at: 0)
        }
        persist(favoriteSongs, key: "selfradio.library.favorites")
    }

    func isFavoritePlaylist(_ playlist: MusicPlaylist) -> Bool {
        favoritePlaylists.contains { $0.id == playlist.id && $0.provider == playlist.provider }
    }

    func toggleFavoritePlaylist(_ playlist: MusicPlaylist) {
        if let index = favoritePlaylists.firstIndex(where: { $0.id == playlist.id && $0.provider == playlist.provider }) {
            favoritePlaylists.remove(at: index)
        } else {
            favoritePlaylists.insert(playlist, at: 0)
        }
        persistPlaylists()
    }

    func seek(to value: Double) {
        guard duration.isFinite, duration > 0 else { return }
        player.seek(to: CMTime(seconds: max(0, min(1, value)) * duration, preferredTimescale: 600))
    }

    var activeLyricIndex: Int {
        max(0, self.lyrics.lastIndex(where: { $0.time <= self.elapsed + self.lyricOffset }) ?? 0)
    }

    private func loadLyrics() async {
        guard let current else { return }
        let requestedSong = current
        guard playbackProvider == requestedSong.provider else {
            lyrics = []
            Self.lyricLogger.warning("跳过歌词：音源与歌词平台不一致 expected=\(requestedSong.provider.rawValue, privacy: .public) actual=\(self.playbackProvider?.rawValue ?? "未知", privacy: .public)")
            return
        }
        lyricsLoading = true
        defer { lyricsLoading = false }
        do {
            let loaded = try await SelfRadioAPI.shared.lyrics(for: requestedSong)
            guard self.current?.id == requestedSong.id,
                  self.current?.provider == requestedSong.provider,
                  self.playbackProvider == requestedSong.provider else {
                Self.lyricLogger.debug("丢弃过期歌词 id=\(requestedSong.id, privacy: .private(mask: .hash))")
                return
            }
            lyrics = loaded
            Self.lyricLogger.info("歌词加载完成 provider=\(requestedSong.provider.rawValue, privacy: .public) id=\(requestedSong.id, privacy: .private(mask: .hash)) lines=\(loaded.count, privacy: .public)")
        } catch {
            lyrics = []
            Self.lyricLogger.error("歌词加载失败 provider=\(requestedSong.provider.rawValue, privacy: .public) id=\(requestedSong.id, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func observeTime() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? time.seconds : 0
                let total = self.player.currentItem?.duration.seconds ?? 0
                self.duration = total.isFinite ? total : 0
                self.progress = self.duration > 0 ? self.elapsed / self.duration : 0
                self.updateNowPlaying()
            }
        }
    }

    func resetLyricOffset() {
        lyricOffset = 0
    }

    private func lyricKey(for song: Song) -> String {
        "\(song.provider.rawValue):\(song.id)"
    }

    private func loadLyricOffsets() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: "selfradio.lyrics.offsets") else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    private func persistLyricOffsets() {
        guard let data = try? JSONEncoder().encode(lyricOffsets) else { return }
        UserDefaults.standard.set(data, forKey: "selfradio.lyrics.offsets")
    }

    private func observePlaybackEnd() {
        playbackEndedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.advance(afterCompletion: true) }
        }
    }

    private func recordRecent(_ song: Song) {
        recentSongs.removeAll { $0 == song }
        recentSongs.insert(song, at: 0)
        if recentSongs.count > 100 { recentSongs.removeLast(recentSongs.count - 100) }
        persist(recentSongs, key: "selfradio.library.recent")
    }

    private func loadLibraryState() {
        recentSongs = restoredSongs(key: "selfradio.library.recent")
        favoriteSongs = restoredSongs(key: "selfradio.library.favorites")
        if let data = UserDefaults.standard.data(forKey: "selfradio.library.favoritePlaylists") {
            favoritePlaylists = (try? JSONDecoder().decode([MusicPlaylist].self, from: data)) ?? []
        }
    }

    private func restoredSongs(key: String) -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Song].self, from: data)) ?? []
    }

    private func persist(_ songs: [Song], key: String) {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func persistPlaylists() {
        guard let data = try? JSONEncoder().encode(favoritePlaylists) else { return }
        UserDefaults.standard.set(data, forKey: "selfradio.library.favoritePlaylists")
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        commands.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        commands.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        commands.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
    }

    private func loadNowPlayingArtwork(for song: Song) {
        artworkLoadTask?.cancel()
        nowPlayingArtwork = nil
        artworkAccentColor = .systemPurple
        artworkAspectRatio = 1
        guard let artworkURL = song.artworkURL else { return }

        let cacheKey = artworkURL as NSURL
        if let image = artworkCache.object(forKey: cacheKey) {
            nowPlayingArtwork = Self.makeNowPlayingArtwork(from: image)
            artworkAccentColor = Self.accentColor(from: image)
            artworkAspectRatio = Self.displayAspectRatio(for: image)
            return
        }

        let songID = song.id
        let provider = song.provider
        artworkLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: artworkURL)
                guard !Task.isCancelled else { return }
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else { return }
                }
                guard let image = UIImage(data: data) else { return }
                guard self.current?.id == songID, self.current?.provider == provider else { return }
                self.artworkCache.setObject(image, forKey: cacheKey)
                self.nowPlayingArtwork = Self.makeNowPlayingArtwork(from: image)
                self.artworkAccentColor = Self.accentColor(from: image)
                self.artworkAspectRatio = Self.displayAspectRatio(for: image)
                self.updateNowPlaying()
            } catch {
                return
            }
        }
    }

    nonisolated private static func makeNowPlayingArtwork(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
    }

    private static func accentColor(from image: UIImage) -> UIColor {
        guard let cgImage = image.cgImage else { return .systemPurple }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .systemPurple }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let color = UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil) else { return .systemPurple }
        return UIColor(hue: hue, saturation: max(0.45, saturation), brightness: max(0.62, brightness), alpha: 1)
    }

    private static func displayAspectRatio(for image: UIImage) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        let ratio = image.size.width / image.size.height
        return ratio < 0.86 ? max(0.68, ratio) : 1
    }

    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.artist,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPMediaItemPropertyPlaybackDuration: duration
        ]
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
