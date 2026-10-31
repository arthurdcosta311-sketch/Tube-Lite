//
//  BackgroundAudioKeeper.swift
//  Tube Lite
//
//  Keeps the web view's audio playing after the app leaves the foreground:
//  the audio background mode plus a looping inaudible tone stop iOS from
//  suspending the process while music or a video keeps streaming.
//

import AVFoundation

final class BackgroundAudioKeeper {

    static let shared = BackgroundAudioKeeper()

    private var player: AVAudioPlayer?

    private init() {}

    func activate() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Without the session the system may still suspend us; best effort.
        }

        guard player == nil, let data = Self.silentWAVData() else { return }
        player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
        player?.numberOfLoops = -1
        player?.volume = 0.01
        player?.play()
    }

    func deactivate() {
        player?.stop()
        player = nil
    }

    /// One second of silence as a mono 8 kHz 16-bit PCM WAV, built in memory.
    private static func silentWAVData() -> Data? {
        let sampleRate = 8000
        let sampleCount = sampleRate

        var data = Data()
        func append(_ string: String) {
            data.append(contentsOf: string.utf8)
        }
        func appendUInt32(_ value: UInt32) {
            var v = value.littleEndian
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ value: UInt16) {
            var v = value.littleEndian
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }

        append("RIFF")
        appendUInt32(UInt32(36 + sampleCount * 2))
        append("WAVE")
        append("fmt ")
        appendUInt32(16)                  // PCM chunk size
        appendUInt16(1)                   // PCM format
        appendUInt16(1)                   // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2)) // byte rate
        appendUInt16(2)                   // block align
        appendUInt16(16)                  // bits per sample
        append("data")
        appendUInt32(UInt32(sampleCount * 2))
        data.append(contentsOf: [UInt8](repeating: 0, count: sampleCount * 2))

        return data
    }
}
