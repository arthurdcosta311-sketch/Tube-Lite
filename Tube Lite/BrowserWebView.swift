//
//  BrowserWebView.swift
//  Tube Lite
//

import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {

    @ObservedObject var model: BrowserViewModel
    var adBlockingEnabled: Bool
    var useDesktopAgent: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.websiteDataStore = .default()

        if adBlockingEnabled {
            AdBlockEngine.install(in: configuration)
            configuration.userContentController.addUserScript(AdBlockEngine.userScript())
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // The mobile layout is the default; desktop is opt-in from settings.
        if useDesktopAgent {
            webView.customUserAgent = AdBlockEngine.desktopUserAgent
        }
        webView.backgroundColor = .black

        context.coordinator.attach(webView, model: model, adBlockingEnabled: adBlockingEnabled)
        model.webView = webView

        webView.load(URLRequest(url: model.currentURL ?? model.homeURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
        uiView.stopLoading()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {

        private var adBlockingEnabled = true
        private(set) weak var model: BrowserViewModel?
        private var observations: [NSKeyValueObservation] = []

        func attach(_ webView: WKWebView, model: BrowserViewModel, adBlockingEnabled: Bool) {
            self.model = model
            self.adBlockingEnabled = adBlockingEnabled

            observations = [
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
                    self?.notify { $0.progress = web.estimatedProgress }
                },
                webView.observe(\.url, options: [.new]) { [weak self] web, _ in
                    self?.notify { $0.currentURL = web.url }
                },
                webView.observe(\.title, options: [.new]) { [weak self] web, _ in
                    self?.notify { $0.pageTitle = web.title ?? "" }
                },
                webView.observe(\.isLoading, options: [.new]) { [weak self] web, _ in
                    self?.notify { $0.isLoading = web.isLoading }
                },
                webView.observe(\.canGoBack, options: [.new]) { [weak self] web, _ in
                    self?.notify { $0.canGoBack = web.canGoBack }
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak self] web, _ in
                    self?.notify { $0.canGoForward = web.canGoForward }
                },
            ]
        }

        func detach() {
            observations.removeAll()
            model = nil
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if adBlockingEnabled, AdBlockEngine.isAdURL(url) {
                notify { $0.registerBlockedAd() }
                decisionHandler(.cancel)
                return
            }

            // Keep taps inside the browser; never hand off to other apps.
            if navigationAction.navigationType == .linkActivated,
               let scheme = url.scheme?.lowercased(),
               scheme != "http", scheme != "https" {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            notify { $0.currentURL = webView.url }
        }

        // MARK: State syncing

        private func notify(_ change: @escaping (BrowserViewModel) -> Void) {
            guard let model else { return }
            change(model)
        }
    }
}
