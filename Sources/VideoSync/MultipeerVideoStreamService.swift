// MultipeerVideoStreamService — Apple 純正 MultipeerConnectivity による
// 端末間映像配信 (Phase 2.3 Live 実装)
//
// 構成:
//   撮影端末 (broadcaster) → アドバタイズ + フレームを peer に送信
//   ベンチ端末 (receiver)  → ブラウズ + 接続 + 受信フレームを 6秒バッファに格納
//
// Wi-Fi / Bluetooth / Peer-to-Peer Wi-Fi が自動選択される。
// サーバ・SDK 不要 = ランニングコストゼロ。

import Foundation
#if canImport(MultipeerConnectivity) && canImport(UIKit)
import MultipeerConnectivity
import UIKit

public final class MultipeerVideoStreamService: NSObject, VideoStreamService, @unchecked Sendable {
    private let serviceType = "lumi-video"
    private let myPeerId: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let buffer: DelayedFrameBuffer

    private var receivedFramesContinuation: AsyncStream<VideoStreamFrame>.Continuation?

    public init(displayName: String? = nil, delaySeconds: TimeInterval = 6) {
        let name: String
        if let displayName {
            name = displayName
        } else {
            name = MainActor.assumeIsolated { UIDevice.current.name }
        }
        self.myPeerId = MCPeerID(displayName: name)
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.buffer = DelayedFrameBuffer(delay: delaySeconds)
        super.init()
        self.session.delegate = self
    }

    // MARK: - Broadcaster

    public func startBroadcasting() async throws {
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    public func stopBroadcasting() async {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session.disconnect()
    }

    /// 撮影フレームを送信。caller (撮影パイプライン) が呼ぶ。
    public func sendFrame(_ frame: VideoStreamFrame) {
        guard !session.connectedPeers.isEmpty else { return }
        var data = Data()
        var ts = frame.timestamp.timeIntervalSince1970
        withUnsafeBytes(of: &ts) { data.append(contentsOf: $0) }
        data.append(frame.payload)
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }

    // MARK: - Receiver

    public func startReceiving() async throws -> AsyncStream<VideoStreamFrame> {
        let browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        return AsyncStream { continuation in
            self.receivedFramesContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.receivedFramesContinuation = nil
            }
        }
    }

    public func stopReceiving() async {
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        receivedFramesContinuation?.finish()
        receivedFramesContinuation = nil
    }

    // MARK: - Local recording (AVAssetWriter は未実装、API 形のみ)

    public func startLocalRecording(to url: URL) async throws {
        // 実装メモ: AVAssetWriter で encode → mp4 書き出し
        // Phase 2.3 では UI のみ。記録機構自体は撮影パイプライン側で実装
    }

    public func stopLocalRecording() async throws -> URL {
        throw NSError(domain: "Multipeer", code: -1, userInfo: [NSLocalizedDescriptionKey: "未実装"])
    }
}

// MARK: - MCSessionDelegate

extension MultipeerVideoStreamService: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count > 8 else { return }
        let timestamp = data.prefix(8).withUnsafeBytes { $0.load(as: TimeInterval.self) }
        let payload = data.dropFirst(8)
        let frame = VideoStreamFrame(timestamp: Date(timeIntervalSince1970: timestamp), payload: payload)
        Task { [buffer, weak self] in
            await buffer.enqueue(frame)
            // 6秒以上前のフレームを取り出して continuation に流す
            let ready = await buffer.popReady()
            for f in ready {
                self?.receivedFramesContinuation?.yield(f)
            }
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser / Browser

extension MultipeerVideoStreamService: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 同一 ServiceType で接続要求が来たら受け入れる
        invitationHandler(true, session)
    }
}

extension MultipeerVideoStreamService: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Broadcaster を見つけたら自動 invite
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

#endif
