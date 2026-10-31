//
//  BrowserViewModel.swift
//  Tube Lite
//

import Foundation
import WebKit

final class BrowserViewModel: ObservableObject {

    private static let blockedAdCountKey = "blockedAdCount"

    weak var webView: WKWebView?
    let homeURL = URL(string: "https://www.youtube.com/")!

    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var pageTitle = "YouTube"
    @Published var currentURL: URL?
    @Published var blockedCount: Int

    init() {
        blockedCount = UserDefaults.standard.integer(forKey: Self.blockedAdCountKey)
    }

    var displayTitle: String {
        pageTitle.isEmpty ? "YouTube" : pageTitle
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        if let url = webView?.url {
            webView?.load(URLRequest(url: url))
        } else {
            webView?.reload()
        }
    }

    func goHome() {
        load(homeURL)
    }

    /// Enters picture-in-picture for the page's video through WebKit's
    /// webkitSetPresentationMode API, re-asserting it for a few seconds in
    /// case YouTube's player forces the video back inline.
    func enterPictureInPicture() {
        let script = """
        (function () {
          var videos = document.querySelectorAll('video');
          var video = null;
          for (var i = 0; i < videos.length; i++) {
            if (!video || videos[i].readyState > video.readyState) { video = videos[i]; }
          }
          if (!video) { return 'no-video'; }
          video.disablePictureInPicture = false;
          video.removeAttribute('disablepictureinpicture');
          if (!video.webkitSetPresentationMode) { return 'unsupported'; }

          if (video.webkitPresentationMode === 'picture-in-picture') {
            video.webkitSetPresentationMode('inline');
            return 'inline';
          }

          video.webkitSetPresentationMode('picture-in-picture');
          if (video.paused && video.play) { video.play().catch(function () {}); }

          var tries = 0;
          (function reenter() {
            if (video.webkitPresentationMode !== 'picture-in-picture' && tries++ < 20) {
              video.webkitSetPresentationMode('picture-in-picture');
              if (video.paused) { video.play().catch(function () {}); }
              setTimeout(reenter, 500);
            }
          })();

          return 'ok';
        })();
        """
        webView?.evaluateJavaScript(script)
    }

    func load(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func registerBlockedAd() {
        blockedCount += 1
        UserDefaults.standard.set(blockedCount, forKey: Self.blockedAdCountKey)
    }
}
