import Foundation

struct FileTransferService: Sendable {
    let client: HTTPClient

    func upload(data: Data, fileName: String, mimeType: String) async throws -> String {
        if DemoMode.isEnabled {
            let folder = try Self.localMaterialFolder()
            let safeName = "\(UUID().uuidString)-\(fileName.replacingOccurrences(of: "/", with: "-"))"
            let url = folder.appendingPathComponent(safeName)
            try data.write(to: url, options: .atomic)
            return "local-materials/\(safeName)"
        }
        let intent: APIUploadIntent = try await client.send(.json(method: .post, path: "storage/upload-intents", body: UploadIntent(fileName: fileName, mimeType: mimeType, sizeBytes: data.count)))
        guard let url = URL(string: intent.uploadUrl) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.cannotWriteToFile) }
        return intent.objectKey
    }

    func downloadURL(objectKey: String) async throws -> URL {
        if DemoMode.isEnabled {
            guard objectKey.hasPrefix("local-materials/") else { throw CocoaError(.fileNoSuchFile) }
            return try Self.localMaterialFolder().appendingPathComponent(String(objectKey.dropFirst("local-materials/".count)))
        }
        let payload: APIDownloadURL = try await client.send(HTTPRequest(method: .get, path: "storage/download-url", query: [.init(name: "objectKey", value: objectKey)]))
        guard let url = URL(string: payload.url) else { throw URLError(.badURL) }
        return url
    }

    private static func localMaterialFolder() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ClassTrace/LocalMaterials", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

private struct UploadIntent: Encodable { let fileName: String; let mimeType: String; let sizeBytes: Int }
