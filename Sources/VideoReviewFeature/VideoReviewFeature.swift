// VideoReviewFeature — Phase 2.2 動画 × プレー seek + アノテーション

import ComposableArchitecture
import DesignSystem
import Foundation
import Models
import SwiftUI
import VideoSync

#if canImport(AVKit)
import AVKit
#endif

@Reducer
public struct VideoReviewFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var match: Match
        public var videoURL: URL?
        public var annotations: [PlayAnnotation] = []
        public var draftAnnotation: String = ""
        public var draftRallyId: UUID?
        public var draftPlayId: UUID?

        public init(match: Match) {
            self.match = match
            if let path = match.videoLocalPath {
                self.videoURL = URL(fileURLWithPath: path)
            }
        }
    }

    public enum Action: Equatable {
        case videoSelected(URL?)
        case markStartHere(seconds: TimeInterval)
        case playTapped(Play)
        case rallyTapped(Rally)
        case draftTextChanged(String)
        case draftRallyChanged(UUID?)
        case draftPlayChanged(UUID?)
        case addAnnotation
        case annotationsLoaded([PlayAnnotation])
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .videoSelected(url):
                state.videoURL = url
                state.match.videoLocalPath = url?.path
                return .none

            case let .markStartHere(seconds):
                state.match.videoStartOffsetSeconds = seconds
                return .none

            case .playTapped, .rallyTapped:
                // View 側で AVPlayer を seek する
                return .none

            case let .draftTextChanged(t):
                state.draftAnnotation = t
                return .none

            case let .draftRallyChanged(id):
                state.draftRallyId = id
                return .none

            case let .draftPlayChanged(id):
                state.draftPlayId = id
                return .none

            case .addAnnotation:
                guard let rallyId = state.draftRallyId, !state.draftAnnotation.isEmpty else { return .none }
                let ann = PlayAnnotation(
                    rallyId: rallyId,
                    playId: state.draftPlayId,
                    authorId: state.match.recorderId,
                    text: state.draftAnnotation
                )
                state.annotations.append(ann)
                state.draftAnnotation = ""
                state.draftRallyId = nil
                state.draftPlayId = nil
                return .none

            case let .annotationsLoaded(list):
                state.annotations = list
                return .none
            }
        }
    }
}

public struct VideoReviewView: View {
    @Bindable public var store: StoreOf<VideoReviewFeature>
    @State private var fileImporterPresented = false
    #if canImport(AVKit)
    @State private var player: AVPlayer?
    #endif

    public init(store: StoreOf<VideoReviewFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 12) {
            videoSection
            controlsSection
            timelineSection
            annotationSection
        }
        .padding(16)
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
        .fileImporter(
            isPresented: $fileImporterPresented,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.send(.videoSelected(url))
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var videoSection: some View {
        #if canImport(AVKit)
        Group {
            if let url = store.videoURL {
                VideoPlayer(player: player ?? makePlayer(url: url))
                    .frame(height: 360)
                    .onAppear { ensurePlayer(url: url) }
            } else {
                placeholderRect
            }
        }
        #else
        placeholderRect
        #endif
    }

    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.Lumi.surfaceElevated)
            .frame(height: 240)
            .overlay(Text("動画未読込").foregroundStyle(Color.Lumi.textTertiary))
    }

    @ViewBuilder
    private var controlsSection: some View {
        HStack(spacing: 8) {
            Button {
                fileImporterPresented = true
            } label: {
                Label("動画選択", systemImage: "video")
            }
            .buttonStyle(.bordered)

            Button {
                #if canImport(AVKit)
                let cur = player?.currentTime().seconds ?? 0
                store.send(.markStartHere(seconds: cur))
                #endif
            } label: {
                Label("ここを試合開始", systemImage: "flag.checkered")
            }
            .buttonStyle(.bordered)

            Spacer()

            if let off = store.match.videoStartOffsetSeconds {
                Text("開始オフセット: \(String(format: "%.1f", off))s")
                    .font(.Lumi.caption)
                    .foregroundStyle(Color.Lumi.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.match.sets) { set in
                    Text("Set \(set.setNumber)").font(.Lumi.headlineSmall).padding(.top, 8)
                    ForEach(set.rallies) { rally in
                        Button {
                            store.send(.rallyTapped(rally))
                            seekToRally(rally)
                        } label: {
                            HStack {
                                Text("R\(rally.rallyNumber)").frame(width: 40, alignment: .leading)
                                Text(rally.winner?.rawValue ?? "-").foregroundStyle(rally.winner == .own ? Color.Lumi.excellent : Color.Lumi.poor)
                                Spacer()
                                if let off = VideoSync.videoOffset(at: rally.startedAt, match: store.match) {
                                    Text(String(format: "%02d:%02d", Int(off) / 60, Int(off) % 60))
                                        .font(.Lumi.statSmall).monospacedDigit()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.Lumi.surface))
    }

    private func seekToRally(_ rally: Rally) {
        #if canImport(AVKit)
        guard let off = VideoSync.videoOffset(at: rally.startedAt, match: store.match) else { return }
        player?.seek(to: CMTime(seconds: off, preferredTimescale: 600))
        player?.play()
        #endif
    }

    @ViewBuilder
    private var annotationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("コメント (\(store.annotations.count))").font(.Lumi.headlineSmall)
            HStack {
                TextField("コメントを入力", text: Binding(
                    get: { store.draftAnnotation },
                    set: { store.send(.draftTextChanged($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                Button("追加") { store.send(.addAnnotation) }
                    .disabled(store.draftAnnotation.isEmpty || store.draftRallyId == nil)
            }
            ForEach(store.annotations) { a in
                Text("• \(a.text)").font(.Lumi.caption).foregroundStyle(Color.Lumi.textSecondary)
            }
        }
    }

    // MARK: - Player helpers

    #if canImport(AVKit)
    private func makePlayer(url: URL) -> AVPlayer {
        let p = AVPlayer(url: url)
        return p
    }

    private func ensurePlayer(url: URL) {
        if player == nil {
            player = AVPlayer(url: url)
        }
    }
    #endif
}
