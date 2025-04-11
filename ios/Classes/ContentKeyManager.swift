
import AVFoundation

class ContentKeyManager {
    static let shared = ContentKeyManager()

    let contentKeySession: AVContentKeySession
    let contentKeyDelegate: ContentKeyDelegate
    let contentKeyDelegateQueue = DispatchQueue(label: "com.example.drm.ContentKeyDelegateQueue")

    private init() {
        contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        contentKeyDelegate = ContentKeyDelegate()
        contentKeySession.setDelegate(contentKeyDelegate, queue: contentKeyDelegateQueue)
    }
}
