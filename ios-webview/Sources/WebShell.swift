import SwiftUI
import UIKit
import WebKit

/// 原生 App 外壳：全屏 WKWebView 加载手机端的网页应用（同一套盘面 / 括囊判定）。
/// - 没有任何浏览器 UI（地址栏、工具栏都没有）
/// - 网页更新后 App 内即时生效，不需要重新安装
/// - 网页本身带 Service Worker，首次加载后可离线使用
struct WebShell: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsInlineMediaPlayback = true
        // 告诉网页「当前跑在原生 App 壳里」：隐藏浏览器模式的安装引导条等。
        let nativeFlag = WKUserScript(
            source: "window.__QIMEN_NATIVE_APP__ = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(nativeFlag)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false

        let paper = UIColor(red: 246.0 / 255.0, green: 241.0 / 255.0, blue: 230.0 / 255.0, alpha: 1.0)
        webView.backgroundColor = paper
        webView.scrollView.backgroundColor = paper

        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }

        let urlString = (Bundle.main.object(forInfoDictionaryKey: "WebAppURL") as? String)
            ?? "https://qimen-mobile.pages.dev/"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// 只在自家域名内导航；外链交给系统 Safari 打开。
        private lazy var allowedHost: String = {
            let host = (Bundle.main.object(forInfoDictionaryKey: "WebAppHost") as? String) ?? ""
            return host.lowercased()
        }()

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let scheme = (url.scheme ?? "").lowercased()
            if scheme == "https" || scheme == "http" {
                let host = (url.host ?? "").lowercased()
                if host == allowedHost || host == "127.0.0.1" || host == "localhost" {
                    decisionHandler(.allow)
                } else {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                }
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 关掉双指缩放与橡皮筋回弹，更接近原生 App 手感
            webView.scrollView.pinchGestureRecognizer?.isEnabled = false
            webView.scrollView.bounces = false
        }
    }
}
