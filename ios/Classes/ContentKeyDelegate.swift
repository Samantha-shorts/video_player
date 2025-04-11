import AVFoundation

class ContentKeyDelegate: NSObject, AVContentKeySessionDelegate {
    
    let certUrl = "https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/fps-cert"
    let licenseUrl = "https://9ab821txf9.execute-api.ap-northeast-1.amazonaws.com/license/fairplay"
    
    func requestApplicationCertificate() throws -> Data {
        let url = URL(string: certUrl)!
        var req = URLRequest(url: url)
        req.addValue("application/pkix-cert", forHTTPHeaderField: "content-type")
        req.addValue("application/pkix-cert", forHTTPHeaderField: "Accept")
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        
        let task = URLSession.shared.dataTask(with: req) { data, _, _ in
            resultData = data
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        
        guard let certData = resultData else {
            throw NSError(domain: "DRM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Certificate request failed"])
        }
        return certData
    }
    
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        do {
            let certificate = try requestApplicationCertificate()
            
            var spcData: Data!
            var spcError: Error?
            let semaphore = DispatchSemaphore(value: 0)

            keyRequest.makeStreamingContentKeyRequestData(forApp: certificate,
                                                          contentIdentifier: keyRequest.identifier as? Data,
                                                          options: nil) { data, error in
                spcData = data
                spcError = error
                semaphore.signal()
            }

            semaphore.wait()

            if let error = spcError {
                throw error
            }

            var req = URLRequest(url: URL(string: licenseUrl)!)
            req.httpMethod = "POST"
            req.httpBody = spcData
            req.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

            let ckcSemaphore = DispatchSemaphore(value: 0)
            var ckcData: Data?

            URLSession.shared.dataTask(with: req) { data, _, _ in
                ckcData = data
                ckcSemaphore.signal()
            }.resume()

            ckcSemaphore.wait()

            guard let ckc = ckcData else {
                print("Failed to get CKC")
                return
            }

            let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc)
            keyRequest.processContentKeyResponse(response)

        } catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }
}
