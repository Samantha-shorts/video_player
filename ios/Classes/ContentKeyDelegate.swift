import AVFoundation

class ContentKeyDelegate: NSObject, AVContentKeySessionDelegate {

    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
    }

    lazy var contentKeyDirectory: URL = {
        guard let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
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

    var pendingPersistableContentKeyIdentifiers = Set<String>()
    var contentKeyToStreamNameMap = [String: String]()

    var certUrl = ""
    var licenseUrl = ""
    var header: [String: String]? = [:]

    func setDrmDataSource(certUrl: String, licenseUrl: String, headers: [String: String]?) {
        self.certUrl = certUrl
        self.licenseUrl = licenseUrl
        self.header = headers
    }

    func requestApplicationCertificate() throws -> Data {
        print("[ContentKeyDelegate] requestApplicationCertificate() called.")
        print("[DEBUG] certUrl: \(certUrl)")

        let url = URL(string: certUrl)!
        var req = URLRequest(url: url)
        req.addValue("application/pkix-cert", forHTTPHeaderField: "content-type")
        req.addValue("application/pkix-cert", forHTTPHeaderField: "Accept")

        if let headers = header {
            for (key, value) in headers {
                req.addValue(value, forHTTPHeaderField: key)
            }
        }

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
        print("[DEBUG] cert HTTP status: \(res.statusCode)")
        if let cert = data {
            let responseText = String(data: cert, encoding: .utf8) ?? "<binary or non-UTF8 data>"
            print("[DEBUG] cert response body: \(responseText)")
        } else {
            print("[DEBUG] cert response body: <no data>")
        }
        guard res.statusCode >= 200 && res.statusCode < 300 else {
            throw ProgramError.missingApplicationCertificate
        }
        guard let cert = data else {
            print("[ContentKeyDelegate] Certificate request returned empty data.")
            throw ProgramError.missingApplicationCertificate
        }
        print("[DEBUG] cert data size: \(cert.count) bytes")
        return cert
    }

    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String) throws -> Data {
        print("[ContentKeyDelegate] requestContentKeyFromKeySecurityModule() called. assetID=\(assetID)")

        let semaphore = DispatchSemaphore(value: 0)
        let url = URL(string: licenseUrl)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "content-type")

        if let headers = header {
            for (key, value) in headers {
                req.addValue(value, forHTTPHeaderField: key)
            }
        }

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
        print("[DEBUG] license HTTP status: \(res.statusCode)")
        guard res.statusCode >= 200 && res.statusCode < 300 else {
            throw ProgramError.noCKCReturnedByKSM
        }
        guard let json = data else {
            print("[ContentKeyDelegate] License request returned empty data.")
            throw ProgramError.noCKCReturnedByKSM
        }

        print("[DEBUG] raw license JSON: \(String(data: json, encoding: .utf8) ?? "<parse error>")")
        let licenseDict = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: String]
        guard let ckcBase64 = licenseDict?["ckc"] else {
            print("[ContentKeyDelegate] License response JSON did not contain 'ckc' field.")
            throw ProgramError.noCKCReturnedByKSM
        }
        guard let ckcData = Data(base64Encoded: ckcBase64) else {
            print("[ContentKeyDelegate] Failed to decode base64 'ckc' from license response.")
            throw ProgramError.noCKCReturnedByKSM
        }

        print("[DEBUG] CKC Base64 decode size: \(ckcData.count) bytes")
        return ckcData
    }

    func shouldRequestPersistableContentKey(withIdentifier identifier: String) -> Bool {
        return pendingPersistableContentKeyIdentifiers.contains(identifier)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        print("[ContentKeyDelegate] didProvide keyRequest: ID=\(String(describing: keyRequest.identifier))")

        guard let assetID = keyRequest.identifier as? String else {
            return keyRequest.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
        }

        // 保存済み PCK のファイルを探す
        let fileURL = persistableContentKeyURL(forAssetID: assetID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let pckData = try Data(contentsOf: fileURL)
                let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: pckData)
                keyRequest.processContentKeyResponse(response)
                print("[DEBUG] Reused persistable key for assetID=\(assetID)")
                return
            } catch {
                print("[ERROR] Failed to load persistable key: \(error)")
                keyRequest.processContentKeyResponseError(error)
                return
            }
        }

        // 保存が無ければオンライン用の処理へ
        do {
            try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
        } catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        print("[ContentKeyDelegate] didProvideRenewingContentKeyRequest: ID=\(String(describing: keyRequest.identifier))")

        guard let assetID = keyRequest.identifier as? String else {
            return keyRequest.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
        }

        // 保存済み PCK があるか確認
        let fileURL = persistableContentKeyURL(forAssetID: assetID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let pckData = try Data(contentsOf: fileURL)
                let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: pckData)
                keyRequest.processContentKeyResponse(response)
                print("[DEBUG] Reused persistable key for renewing request, assetID=\(assetID)")
                return
            } catch {
                print("[ERROR] Failed to load persistable key: \(error)")
                keyRequest.processContentKeyResponseError(error)
                return
            }
        }

        // 保存済みキーがなければ通常フローへ（オンライン前提）
        do {
            try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
        } catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }

    func contentKeySession(_ s: AVContentKeySession, didProvide r: AVPersistableContentKeyRequest) {
        guard let idStr = r.identifier as? String, let u = URL(string: idStr) else {
            return r.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
        }
        let assetID = (u.host ?? "") + u.path
        guard let assetIDData = assetID.data(using: .utf8) else {
            return r.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
        }

        do {
            let appCert = try requestApplicationCertificate()

            if #available(iOS 11.2, *) {
                r.makeStreamingContentKeyRequestData(
                    forApp: appCert,
                    contentIdentifier: assetIDData,
                    options: [AVContentKeyRequestProtocolVersionsKey: [1]]
                ) { [weak self] spcData, error in
                    guard let self = self else { return }
                    if let error = error {
                        return r.processContentKeyResponseError(error)
                    }
                    guard let spc = spcData else {
                        return r.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
                    }

                    do {
                        let ckc = try self.requestContentKeyFromKeySecurityModule(
                            spcData: spc,
                            assetID: assetID
                        )
                        let pck = try r.persistableContentKey(fromKeyVendorResponse: ckc, options: nil)

                        // ★ ここで保存
                        let fileURL = self.persistableContentKeyURL(forAssetID: assetID)
                        try pck.write(to: fileURL, options: .atomic)
                        print("[DEBUG] Saved PCK at \(fileURL.path)")

                        // ★ その後 AVPlayer に応答
                        let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: pck)
                        r.processContentKeyResponse(response)

                    } catch {
                        r.processContentKeyResponseError(error)
                    }
                }
            } else {
                r.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
            }
        } catch {
            r.processContentKeyResponseError(error)
        }
    }

    func contentKeySession(_ session: AVContentKeySession,
                           shouldRetry keyRequest: AVContentKeyRequest,
                           reason retryReason: AVContentKeyRequest.RetryReason) -> Bool {
        print("[ContentKeyDelegate] shouldRetry keyRequest: reason=\(retryReason.rawValue), ID=\(String(describing: keyRequest.identifier))")
        let shouldRetry = [.timedOut, .receivedResponseWithExpiredLease, .receivedObsoleteContentKey].contains(retryReason)
        print("[ContentKeyDelegate] -> Will \(shouldRetry ? "" : "NOT ")retry key request.")
        return shouldRetry
    }

    func contentKeySession(_ session: AVContentKeySession,
                           contentKeyRequest keyRequest: AVContentKeyRequest,
                           didFailWithError err: Error) {
        print("[ContentKeyDelegate] contentKeySession didFailWithError: \(err.localizedDescription)")
        print("[ContentKeyDelegate] didFailWithError: \(err.localizedDescription)")
    }

    func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        print("[ContentKeyDelegate] handleStreamingContentKeyRequest() start.")

        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
              let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString),
              let assetIDString = contentKeyIdentifierURL.host,
              let assetIDData = assetIDString.data(using: .utf8) else {
            print("[ContentKeyDelegate] handleStreamingContentKeyRequest() -> Missing or invalid assetID.")
            return
        }

        print("[DEBUG] contentKeyIdentifierURL: \(contentKeyIdentifierURL.absoluteString)")
        print("[DEBUG] assetID: \(assetIDString)")

        let provideOnlineKey: () -> Void = { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let applicationCertificate = try strongSelf.requestApplicationCertificate()

                let completionHandler = { (spcData: Data?, error: Error?) in
                    print("[DEBUG] makeStreamingContentKeyRequestData completed. spcData size = \(spcData?.count ?? -1), error = \(String(describing: error))")
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
                        let ckcData = try strongSelf.requestContentKeyFromKeySecurityModule(spcData: spcData, assetID: assetIDString)
                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                        keyRequest.processContentKeyResponse(keyResponse)
                        print("[ContentKeyDelegate] handleStreamingContentKeyRequest -> processContentKeyResponse (CKC) success.")
                    } catch {
                        print("[ContentKeyDelegate] CKC acquisition error: \(error.localizedDescription)")
                        keyRequest.processContentKeyResponseError(error)
                    }
                }

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

        provideOnlineKey()
    }

    private func persistableContentKeyURL(forAssetID assetID: String) -> URL {
        return contentKeyDirectory.appendingPathComponent(assetID).appendingPathExtension("key")
    }
}
