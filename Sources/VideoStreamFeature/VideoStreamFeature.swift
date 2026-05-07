// VideoStreamFeature — Phase 2.3 6秒遅延映像配信 UI
//
// 撮影端末: 配信開始 / 録画
// ベンチ端末: 受信開始 / 6秒遅延ステータス表示

import ComposableArchitecture
import DesignSystem
import Foundation
import SwiftUI
import VideoSync

@Reducer
public struct VideoStreamFeature: Sendable {
    public enum Mode: String, CaseIterable, Sendable, Equatable {
        case broadcaster = "撮影 (配信)"
        case receiver    = "ベンチ (受信)"
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode = .broadcaster
        public var isStreaming: Bool = false
        public var isRecording: Bool = false
        public var bufferedFrameCount: Int = 0
        public var statusMessage: String = "停止中"
        public var errorMessage: String?

        public init() {}
    }

    public enum Action: Equatable {
        case modeChanged(Mode)
        case startTapped
        case stopTapped
        case streamStateChanged(isStreaming: Bool, isRecording: Bool)
        case bufferUpdated(Int)
        case errorOccurred(String)
        case errorDismissed
    }

    @Dependency(\.videoStreamService) var streamService

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .modeChanged(mode):
                state.mode = mode
                state.statusMessage = "停止中"
                return .none

            case .startTapped:
                let mode = state.mode
                return .run { send in
                    do {
                        switch mode {
                        case .broadcaster:
                            try await streamService.startBroadcasting()
                        case .receiver:
                            _ = try await streamService.startReceiving()
                        }
                        await send(.streamStateChanged(isStreaming: true, isRecording: false))
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .stopTapped:
                let mode = state.mode
                return .run { send in
                    switch mode {
                    case .broadcaster: await streamService.stopBroadcasting()
                    case .receiver: await streamService.stopReceiving()
                    }
                    await send(.streamStateChanged(isStreaming: false, isRecording: false))
                }

            case let .streamStateChanged(streaming, recording):
                state.isStreaming = streaming
                state.isRecording = recording
                state.statusMessage = streaming ? (state.mode == .broadcaster ? "配信中" : "受信中 (6秒遅延)") : "停止中"
                return .none

            case let .bufferUpdated(count):
                state.bufferedFrameCount = count
                return .none

            case let .errorOccurred(msg):
                state.errorMessage = msg
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

// MARK: - Dependency

private enum VideoStreamServiceKey: DependencyKey {
    static var liveValue: VideoStreamService {
        #if canImport(MultipeerConnectivity) && canImport(UIKit)
        return MultipeerVideoStreamService()
        #else
        return MockVideoStreamService()
        #endif
    }
    static let testValue: VideoStreamService = MockVideoStreamService()
    static let previewValue: VideoStreamService = MockVideoStreamService()
}

extension DependencyValues {
    public var videoStreamService: VideoStreamService {
        get { self[VideoStreamServiceKey.self] }
        set { self[VideoStreamServiceKey.self] = newValue }
    }
}

// MARK: - View

public struct VideoStreamView: View {
    @Bindable public var store: StoreOf<VideoStreamFeature>

    public init(store: StoreOf<VideoStreamFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 24) {
            Picker("モード", selection: Binding(
                get: { store.mode },
                set: { store.send(.modeChanged($0)) }
            )) {
                ForEach(VideoStreamFeature.Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            statusCard

            HStack(spacing: 16) {
                Button {
                    store.send(store.isStreaming ? .stopTapped : .startTapped)
                } label: {
                    Label(
                        store.isStreaming ? "停止" : "開始",
                        systemImage: store.isStreaming ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.isStreaming ? Color.Lumi.poor : Color.Lumi.excellent)
            }

            Text("Phase 2.3 では WebRTC + ローカル Wi-Fi で実装予定。\n現在は MockVideoStreamService で UI のみ確認可。")
                .font(.Lumi.caption)
                .foregroundStyle(Color.Lumi.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
        .alert("エラー", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("OK") {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(store.isStreaming ? Color.Lumi.excellent : Color.Lumi.textTertiary)
                    .frame(width: 12, height: 12)
                Text(store.statusMessage).font(.Lumi.headlineSmall)
            }
            HStack {
                Text("バッファ").foregroundStyle(Color.Lumi.textSecondary)
                Spacer()
                Text("\(store.bufferedFrameCount) frames").font(.Lumi.statMedium).monospacedDigit()
            }
            HStack {
                Text("録画").foregroundStyle(Color.Lumi.textSecondary)
                Spacer()
                Image(systemName: store.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundStyle(store.isRecording ? Color.Lumi.poor : Color.Lumi.textTertiary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.Lumi.surface))
    }
}
