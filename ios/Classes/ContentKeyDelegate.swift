/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 `ContentKeyDelegate` is a class that implements the `AVContentKeySessionDelegate` protocol to respond to content key
 requests using FairPlay Streaming.
 */

import AVFoundation

class ContentKeyDelegate: NSObject, AVContentKeySessionDelegate {
    
    // MARK: Types
    
    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
    }
    
    // MARK: Properties
    
    /// The directory that is used to save persistable content keys.
    lazy var contentKeyDirectory: URL = {
        guard let documentPath =
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
                fatalError("Unable to determine library URL")
        }
        
        let documentURL = URL(fileURLWithPath: documentPath)
        
        let contentKeyDirectory = documentURL.appendingPathComponent(".keys", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: contentKeyDirectory.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: contentKeyDirectory,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
            } catch {
                fatalError("Unable to create directory for content keys at path: \(contentKeyDirectory.path)")
            }
        }
        
        return contentKeyDirectory
    }()
    
    /// A set containing the currently pending content key identifiers associated with persistable content key requests that have not been completed.
    var pendingPersistableContentKeyIdentifiers = Set<String>()
    
    /// A dictionary mapping content key identifiers to their associated stream name.
    var contentKeyToStreamNameMap = [String: String]()

    /// 証明書リクエスト URL
    let certUrl = "https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/fps-cert"
    /// ライセンスリクエスト URL
    let licenseUrl = "https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/fairplay"

    // MARK: - 証明書取得
    func requestApplicationCertificate() throws -> Data {
        print("[ContentKeyDelegate] requestApplicationCertificate() called.")

        let url = URL(string: certUrl)!
        var req = URLRequest(url: url)
        // 必要ならリクエストヘッダを指定
        req.addValue("application/pkix-cert", forHTTPHeaderField: "content-type")
        req.addValue("application/pkix-cert", forHTTPHeaderField: "Accept")
        
        let semaphore = DispatchSemaphore(value: 0)
        var data: Data? = nil
        var response: URLResponse? = nil
        var error: Error? = nil
        
        let task = URLSession.shared.dataTask(with: req) {
            data = $0
            response = $1
            error = $2
            semaphore.signal()
        }
        task.resume()
        
        semaphore.wait()
        
        if let e = error {
            print("[ContentKeyDelegate] Failed to get certificate with error: \(e.localizedDescription)")
            throw e
        }
        guard let res = response as? HTTPURLResponse else {
            print("[ContentKeyDelegate] Certificate request failed: no HTTP response.")
            throw ProgramError.missingApplicationCertificate
        }
        guard res.statusCode >= 200 && res.statusCode < 300 else {
            print("[ContentKeyDelegate] Certificate request HTTP status = \(res.statusCode)")
            throw ProgramError.missingApplicationCertificate
        }
        guard let cert = data else {
            print("[ContentKeyDelegate] Certificate request returned empty data.")
            throw ProgramError.missingApplicationCertificate
        }
        print("[ContentKeyDelegate] Certificate request successful. size=\(cert.count) bytes.")
        return cert
    }

    // MARK: - ライセンス取得
    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String) throws -> Data {
        print("[ContentKeyDelegate] requestContentKeyFromKeySecurityModule() called. assetID=\(assetID)")
        
        let semaphore = DispatchSemaphore(value: 0)
        let url = URL(string: licenseUrl)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        // 必要ならリクエストヘッダを指定
        req.addValue("application/json", forHTTPHeaderField: "content-type")
        
        // SPC を Base64 エンコードして JSON で送る想定
        let spcBase64 = spcData.base64EncodedString()
        let bodyJson = String(format: "{\"spc\": \"%@\"}", spcBase64)
        req.httpBody = bodyJson.data(using: .utf8)
        
        var data: Data? = nil
        var response: URLResponse? = nil
        var error: Error? = nil
        
        let task = URLSession.shared.dataTask(with: req) {
            data = $0
            response = $1
            error = $2
            semaphore.signal()
        }
        task.resume()
        
        semaphore.wait()
        
        if let e = error {
            print("[ContentKeyDelegate] License request error: \(e.localizedDescription)")
            throw e
        }
        guard let res = response as? HTTPURLResponse else {
            print("[ContentKeyDelegate] License request failed: no HTTP response.")
            throw ProgramError.missingApplicationCertificate
        }
        guard res.statusCode >= 200 && res.statusCode < 300 else {
            print("[ContentKeyDelegate] License request HTTP status = \(res.statusCode)")
            throw ProgramError.noCKCReturnedByKSM
        }
        guard let json = data else {
            print("[ContentKeyDelegate] License request returned empty data.")
            throw ProgramError.noCKCReturnedByKSM
        }
        
        // ここでは簡易的に JSON をパース → "ckc" フィールド取り出し
        let licenseDict = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: String]
        guard let ckcBase64 = licenseDict?["ckc"] else {
            print("[ContentKeyDelegate] License response JSON did not contain 'ckc' field.")
            throw ProgramError.noCKCReturnedByKSM
        }
        guard let ckcData = Data(base64Encoded: ckcBase64) else {
            print("[ContentKeyDelegate] Failed to decode base64 'ckc' from license response.")
            throw ProgramError.noCKCReturnedByKSM
        }
        
        print("[ContentKeyDelegate] License request succeeded. CKC size=\(ckcData.count) bytes.")
        return ckcData
    }

    
    /// Returns whether or not a content key should be persistable on disk.
    func shouldRequestPersistableContentKey(withIdentifier identifier: String) -> Bool {
        return pendingPersistableContentKeyIdentifiers.contains(identifier)
    }
    
    // MARK: - AVContentKeySessionDelegate Methods
    /// Called when a new content key request is created (on-demand or proactively).
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        print("[ContentKeyDelegate] didProvide keyRequest: ID=\(String(describing: keyRequest.identifier))")
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }
    
    /// Called when renewing an existing content key (e.g. lease about to expire).
    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        print("[ContentKeyDelegate] didProvideRenewingContentKeyRequest: ID=\(String(describing: keyRequest.identifier))")
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }
    
    /// Called when a key request should be retried (e.g. time-out, obsolete content key, etc).
    func contentKeySession(_ session: AVContentKeySession,
                           shouldRetry keyRequest: AVContentKeyRequest,
                           reason retryReason: AVContentKeyRequest.RetryReason) -> Bool {
        
        print("[ContentKeyDelegate] shouldRetry keyRequest: reason=\(retryReason.rawValue), ID=\(String(describing: keyRequest.identifier))")

        var shouldRetry = false
        
        switch retryReason {
        case .timedOut:
            shouldRetry = true
        case .receivedResponseWithExpiredLease:
            shouldRetry = true
        case .receivedObsoleteContentKey:
            shouldRetry = true
        default:
            shouldRetry = false
        }
        
        if shouldRetry {
            print("[ContentKeyDelegate] -> Will retry key request.")
        } else {
            print("[ContentKeyDelegate] -> Will NOT retry key request.")
        }
        
        return shouldRetry
    }
    
    /// Called when a content key request fails irrecoverably.
    func contentKeySession(_ session: AVContentKeySession,
                           contentKeyRequest keyRequest: AVContentKeyRequest,
                           didFailWithError err: Error) {
        print("[ContentKeyDelegate] contentKeySession didFailWithError: \(err.localizedDescription)")
        // ここは fatalError ではなく、本番アプリならエラー処理を適宜行う
        fatalError(err.localizedDescription)
    }
    
    // MARK: - Streaming Content Key Request Handling
    
    func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        print("[ContentKeyDelegate] handleStreamingContentKeyRequest() start.")
        
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
              let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString),
              let assetIDString = contentKeyIdentifierURL.host,
              let assetIDData = assetIDString.data(using: .utf8) else {
            print("[ContentKeyDelegate] handleStreamingContentKeyRequest() -> Missing or invalid assetID.")
            return
        }
        
        print("[ContentKeyDelegate] handleStreamingContentKeyRequest() -> assetID=\(assetIDString)")
        
        // ラムダでオンラインキー処理をまとめる
        let provideOnlinekey: () -> Void = { [weak self] in
            guard let strongSelf = self else { return }
            do {
                // アプリケーション証明書（FairPlay用）を取得
                let applicationCertificate = try strongSelf.requestApplicationCertificate()
                
                // SPC 生成の completionHandler
                let completionHandler = { (spcData: Data?, error: Error?) in
                    if let err = error {
                        print("[ContentKeyDelegate] makeStreamingContentKeyRequestData error: \(err.localizedDescription)")
                        keyRequest.processContentKeyResponseError(err)
                        return
                    }
                    
                    guard let spcData = spcData else {
                        print("[ContentKeyDelegate] makeStreamingContentKeyRequestData returned nil spcData.")
                        return
                    }
                    
                    do {
                        // SPC をライセンスサーバに送り CKC を取得
                        let ckcData = try strongSelf.requestContentKeyFromKeySecurityModule(spcData: spcData, assetID: assetIDString)
                        
                        // 取得した CKC を keyResponse として設定
                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                        keyRequest.processContentKeyResponse(keyResponse)
                        
                        print("[ContentKeyDelegate] handleStreamingContentKeyRequest -> processContentKeyResponse (CKC) success.")
                    } catch {
                        print("[ContentKeyDelegate] CKC acquisition error: \(error.localizedDescription)")
                        keyRequest.processContentKeyResponseError(error)
                    }
                }
                
                // SPC 生成
                keyRequest.makeStreamingContentKeyRequestData(
                    forApp: applicationCertificate,
                    contentIdentifier: assetIDData,
                    options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                    completionHandler: completionHandler
                )
                
            } catch {
                print("[ContentKeyDelegate] requestApplicationCertificate error: \(error.localizedDescription)")
                keyRequest.processContentKeyResponseError(error)
            }
        }

//        #if os(iOS)
//        if shouldRequestPersistableContentKey(withIdentifier: assetIDString) ||
//            persistableContentKeyExistsOnDisk(withContentKeyIdentifier: assetIDString) {
//            
//            do {
//                try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
//                print("[ContentKeyDelegate] -> respondByRequestingPersistableContentKeyRequestAndReturnError() called.")
//            } catch {
//                print("[ContentKeyDelegate] respondByRequestingPersistableContentKeyRequest failed, fallback to online key. error=\(error.localizedDescription)")
//                provideOnlinekey()
//            }
//            
//            return
//        }
//        #endif
        
        // オンラインキーを取得
        provideOnlinekey()
    }
}
