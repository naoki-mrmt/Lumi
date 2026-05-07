// VideoPlaybackDependency — VideoPlaybackService の TCA Dependency 登録
//
// 本番では LiveVideoPlaybackService (AVPlayer)。AVKit が利用できない環境では Mock。

import Dependencies
import Foundation

private enum VideoPlaybackServiceKey: DependencyKey {
    static var liveValue: any VideoPlaybackService {
        #if canImport(AVKit)
        return LiveVideoPlaybackService()
        #else
        return MockVideoPlaybackService()
        #endif
    }
    static let testValue: any VideoPlaybackService = MockVideoPlaybackService()
    static let previewValue: any VideoPlaybackService = MockVideoPlaybackService()
}

extension DependencyValues {
    public var videoPlaybackService: any VideoPlaybackService {
        get { self[VideoPlaybackServiceKey.self] }
        set { self[VideoPlaybackServiceKey.self] = newValue }
    }
}
