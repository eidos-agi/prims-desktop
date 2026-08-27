import AppKit
import SwiftUI
import WebKit
import PrimMacCore

final class PrimToolWebView: WKWebView {
    func pageFolio(_ dir: Int) {
        let js = """
        (function(){
          var rail = document.querySelector('body.bare .app-rail');
          var n = rail;
          var used = 'rail';
          if (!n || n.scrollHeight <= n.clientHeight + 2) {
            n = document.scrollingElement;
            used = 'doc';
          }
          if (!n) return { ok: false, used: used };
          var before = n.scrollTop;
          var page = Math.max(80, (n.clientHeight || window.innerHeight) * 0.92);
          n.scrollBy(0, page * \(dir));
          return {
            ok: true, used: used, dir: \(dir),
            tag: n.tagName || '', cls: String(n.className || ''),
            before: before, after: n.scrollTop,
            sh: n.scrollHeight, ch: n.clientHeight
          };
        })()
        """
        evaluateJavaScript(js) { result, error in
            var payload: [String: Any] = [
                "at": ISO8601DateFormatter().string(from: Date()),
            ]
            if let error {
                payload["error"] = error.localizedDescription
            }
            if let result {
                payload["result"] = result
            }
            guard JSONSerialization.isValidJSONObject(payload),
                  let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
                  let text = String(data: data, encoding: .utf8) else { return }
            let url = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("repos-eidos-agi/prim-mac/.learn/proofs/pagefolio.json")
            try? text.write(to: url, atomically: true, encoding: .utf8)
            print("pageFolio \(text)")
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 121: pageFolio(1)
        case 116: pageFolio(-1)
        default: super.keyDown(with: event)
        }
    }
}

struct ToolWebView: NSViewRepresentable {
    let kind: String
    let tool: String
    let packName: String
    let pack: Data
    let root: URL
    let token: Int
    var onExport: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(kind: kind, tool: tool, packName: packName, pack: pack, token: token, onExport: onExport)
    }

    func makeNSView(context: Context) -> PrimToolWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.scheme, forURLScheme: "prim-tool")
        config.userContentController.add(context.coordinator, name: "prim")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let web = PrimToolWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsMagnification = false
        web.allowsBackForwardNavigationGestures = false
        context.coordinator.scheme.root = root
        context.coordinator.scheme.heldName = packName
        context.coordinator.scheme.held = pack
        context.coordinator.web = web
        context.coordinator.installKeys(web)
        context.coordinator.load()
        return web
    }

    func updateNSView(_ web: PrimToolWebView, context: Context) {
        context.coordinator.onExport = onExport
        context.coordinator.scheme.heldName = packName
        context.coordinator.scheme.held = pack
        context.coordinator.packName = packName
        context.coordinator.pack = pack
        if context.coordinator.token != token || context.coordinator.kind != kind || context.coordinator.tool != tool {
            context.coordinator.token = token
            context.coordinator.kind = kind
            context.coordinator.tool = tool
            context.coordinator.ready = false
            context.coordinator.load()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var kind: String
        var tool: String
        var packName: String
        var pack: Data
        var token: Int
        var onExport: (Data) -> Void
        let scheme = SchemeHandler(root: Paths.toolsRoot())
        weak var web: WKWebView?
        var ready = false
        var keyMonitor: Any?

        init(kind: String, tool: String, packName: String, pack: Data, token: Int, onExport: @escaping (Data) -> Void) {
            self.kind = kind
            self.tool = tool
            self.packName = packName
            self.pack = pack
            self.token = token
            self.onExport = onExport
        }

        deinit {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }

        func installKeys(_ web: PrimToolWebView) {
            if keyMonitor != nil { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak web] event in
                guard let web, event.window === web.window else { return event }
                switch event.keyCode {
                case 121:
                    web.pageFolio(1)
                    return nil
                case 116:
                    web.pageFolio(-1)
                    return nil
                default:
                    return event
                }
            }
        }

        func load() {
            var parts = URLComponents()
            parts.scheme = "prim-tool"
            parts.host = "app"
            parts.path = "/index.html"
            parts.queryItems = [
                URLQueryItem(name: "bare", value: "1"),
                URLQueryItem(name: "fast", value: "1"),
                URLQueryItem(name: "kind", value: kind),
                URLQueryItem(name: "tool", value: tool.isEmpty ? kind : tool),
            ]
            if let chapter = UserDefaults.standard.string(forKey: "gotoChapter"), !chapter.isEmpty {
                parts.queryItems?.append(URLQueryItem(name: "chapter", value: chapter))
            }
            if let url = parts.url {
                web?.load(URLRequest(url: url))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let hook = """
            window.addEventListener('message', function(e) {
              if (!e.data || !window.webkit || !window.webkit.messageHandlers.prim) return;
              if (e.data.type === 'prim-bare-ready') {
                window.webkit.messageHandlers.prim.postMessage({ type: 'prim-bare-ready', kind: e.data.kind || '' });
              }
              if (e.data.type === 'prim-export' && e.data.b64) {
                window.webkit.messageHandlers.prim.postMessage({ type: 'prim-export', b64: e.data.b64, kind: e.data.kind || '' });
              }
            });
            """
            webView.evaluateJavaScript(hook, completionHandler: nil)
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(webView)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = message.body as? [String: Any]
            let type = body?["type"] as? String
            if type == "prim-bare-ready" {
                ready = true
                sendPack()
            }
            if type == "prim-export", let b64 = body?["b64"] as? String, let data = Data(base64Encoded: b64) {
                onExport(data)
            }
        }

        func sendPack() {
            guard let web, !pack.isEmpty else { return }
            scheme.held = pack
            scheme.heldName = packName
            let name = packName.replacingOccurrences(of: "'", with: "")
            let chapter = (UserDefaults.standard.string(forKey: "gotoChapter") ?? "")
                .filter { $0.isLetter || $0.isNumber }
            if !chapter.isEmpty {
                UserDefaults.standard.removeObject(forKey: "gotoChapter")
            }
            let jump = chapter.isEmpty ? "" : """
            setTimeout(function(){
              if (window.primGoto) window.primGoto('\(chapter)');
            }, 900);
            """
            let js = """
            fetch('prim-tool://app/__held.prim').then(function(r){ return r.arrayBuffer(); }).then(function(bytes){
              window.postMessage({ type: 'prim-drop', name: '\(name)', bytes: bytes }, '*');
            }).then(function(){ \(jump) });
            """
            web.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
