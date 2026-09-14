// Configures the audio session so the game never silences the player's own music.

import Foundation

#if canImport(AVFoundation) && os(iOS)
import AVFoundation
#endif

/// Audio session policy shared by every game in the portfolio.
public enum JuiceAudioSession {
    /// Whether another app is currently playing audio the game should not interrupt.
    ///
    /// Games check this before starting background music. Sound effects still play —
    /// they are short and mix cleanly — but a music bed on top of the player's own
    /// playlist is what gets a one-star review.
    public static var shouldSuppressBackgroundMusic: Bool {
        #if canImport(AVFoundation) && os(iOS)
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        #else
        false
        #endif
    }

    /// Activates an ambient, mixing session.
    ///
    /// `.ambient` keeps the game silent under the ring/silent switch, and
    /// `.mixWithOthers` lets Spotify or Podcasts keep playing underneath.
    /// Casual players very often have something else playing.
    @discardableResult
    public static func activate() -> Bool {
        #if canImport(AVFoundation) && os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            return true
        } catch {
            // Audio is never worth blocking gameplay over.
            return false
        }
        #else
        return true
        #endif
    }

    /// Deactivates the session. Call when leaving gameplay for a long time.
    public static func deactivate() {
        #if canImport(AVFoundation) && os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}
