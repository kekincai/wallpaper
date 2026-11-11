import SwiftUI

/// Shared motion vocabulary.
///
/// - Direct feedback (selection, toggles) uses a short `.snappy` spring.
/// - Content changes (filtering, adding/removing, the current wallpaper changing) use `.smooth`.
/// - With Reduce Motion on, movement and scaling are replaced by a brief crossfade.
enum Motion {
    static let feedback: Animation = .snappy(duration: 0.22)
    static let content: Animation = .smooth(duration: 0.32)
    static let fade: Animation = .easeInOut(duration: 0.18)

    static func feedback(reduceMotion: Bool) -> Animation { reduceMotion ? fade : feedback }
    static func content(reduceMotion: Bool) -> Animation { reduceMotion ? fade : content }
}

extension AnyTransition {
    /// Appear by growing slightly into place; plain fade under Reduce Motion.
    static func pop(reduceMotion: Bool, from scale: CGFloat = 0.92) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: scale).combined(with: .opacity)
    }
}
