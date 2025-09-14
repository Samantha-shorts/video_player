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

        guard let res = response as? HTTPURLResponse else {
            throw ProgramError.missingApplicationCertificate
        }
        if let cert = data {
            let responseText = String(data: cert, encoding: .utf8) ?? "<binary or non-UTF8 data>"
        } else {
        }
        guard res.statusCode >= 200 && res.statusCode < 300 else {
            throw ProgramError.missingApplicationCertificate
        }
        guard let cert = data else {
            throw ProgramError.missingApplicationCertificate
        }
        return cert
    }

    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String) throws -> Data {
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
            throw e
        }
        guard let res = response as? HTTPURLResponse else {
            throw ProgramError.missingApplicationCertificate
        }
        guard res.statusCode >= 200 && res.statusCode < 300 else {
            throw ProgramError.noCKCReturnedByKSM
        }
        guard let json = data else {
            throw ProgramError.noCKCReturnedByKSM
        }

        let licenseDict = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: String]
        guard let ckcBase64 = licenseDict?["ckc"] else {
            throw ProgramError.noCKCReturnedByKSM
        }
        guard let ckcData = Data(base64Encoded: ckcBase64) else {
            throw ProgramError.noCKCReturnedByKSM
        }

        return ckcData
    }

    func shouldRequestPersistableContentKey(withIdentifier identifier: String) -> Bool {
        return pendingPersistableContentKeyIdentifiers.contains(identifier)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        guard let assetID = keyRequest.identifier as? String else {
            return keyRequest.processContentKeyResponseError(ProgramError.noCKCReturnedByKSM)
        }

        let fileURL = persistableContentKeyURL(forAssetID: assetID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let pckData = try Data(contentsOf: fileURL)
                let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: pckData)
                keyRequest.processContentKeyResponse(response)
                return
            } catch {
                keyRequest.processContentKeyResponseError(error)
                return
            }
        }

        do {
            try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
        } catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
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
                return
            } catch {
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

                        let fileURL = self.persistableContentKeyURL(forAssetID: assetID)
                        try pck.write(to: fileURL, options: .atomic)

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
        let shouldRetry = [.timedOut, .receivedResponseWithExpiredLease, .receivedObsoleteContentKey].contains(retryReason)
        return shouldRetry
    }

    func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
              let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString),
              let assetIDString = contentKeyIdentifierURL.host,
              let assetIDData = assetIDString.data(using: .utf8) else {
            return
        }

        let provideOnlineKey: () -> Void = { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let applicationCertificate = try strongSelf.requestApplicationCertificate()

                let completionHandler = { (spcData: Data?, error: Error?) in
                    if let err = error {
                        keyRequest.processContentKeyResponseError(err)
                        return
                    }

                    guard let spcData = spcData else {
                        return
                    }

                    do {
                        let ckcData = try strongSelf.requestContentKeyFromKeySecurityModule(spcData: spcData, assetID: assetIDString)
                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                        keyRequest.processContentKeyResponse(keyResponse)
                    } catch {
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
                keyRequest.processContentKeyResponseError(error)
            }
        }

        provideOnlineKey()
    }

    private func persistableContentKeyURL(forAssetID assetID: String) -> URL {
        return contentKeyDirectory.appendingPathComponent(assetID).appendingPathExtension("key")
    }
}
