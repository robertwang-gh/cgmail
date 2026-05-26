import SwiftUI
import WebKit

struct HTMLBodyView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: -apple-system, sans-serif; font-size: 14px;
                 color: #1a1a1a; margin: 16px; line-height: 1.6; }
          a { color: #1a73e8; }
          img { max-width: 100%; height: auto; }
          pre { white-space: pre-wrap; }
          @media (prefers-color-scheme: dark) {
            body { color: #e8eaed; background: #202124; }
            a { color: #8ab4f8; }
          }
        </style>
        </head><body>\(html)</body></html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}
