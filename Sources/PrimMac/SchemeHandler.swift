import Foundation
import WebKit

final class SchemeHandler: NSObject, WKURLSchemeHandler {
    var root: URL
    var heldName = "open.prim"
    var held = Data()

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        do {
            let (data, mime) = try file(for: url)
            let headers = [
                "Content-Type": mime,
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*",
            ]
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func file(for url: URL) throws -> (Data, String) {
        var path = url.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.isEmpty { path = "index.html" }
        if path == "__held.prim" {
            return (held, "application/zip")
        }
        let dest = root.appendingPathComponent(path).standardizedFileURL
        guard dest.path.hasPrefix(root.standardizedFileURL.path) else {
            throw URLError(.cannotOpenFile)
        }
        let data = try Data(contentsOf: dest)
        return (data, mime(dest.pathExtension))
    }

    private func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json", "jsonl": return "application/json"
        case "md": return "text/markdown"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "woff2": return "font/woff2"
        case "wasm": return "application/wasm"
        case "prim", "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}
