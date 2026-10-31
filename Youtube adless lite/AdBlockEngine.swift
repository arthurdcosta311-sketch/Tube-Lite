//
//  AdBlockEngine.swift
//  Tube Lite
//
//  Keeps YouTube free of ads inside the built-in browser using WebKit
//  content blocking rules, a DOM cleanup script and request filtering.
//

import Foundation
import WebKit

enum AdBlockEngine {

    static let ruleListIdentifier = "TubeLiteAdBlockRules"

    // Desktop YouTube serves a layout whose ad markup the rules below know
    // how to hide, and it skips the "Open in app" interstitials.
    static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    // URL fragments (regular expressions matched against the full request
    // URL) that belong to ad delivery or ad tracking.
    private static let networkFilters: [String] = [
        "doubleclick\\.net",
        "googlesyndication\\.com",
        "googleadservices\\.com",
        "adservice\\.google\\.",
        "2mdn\\.net",
        "youtube\\.com/api/stats/(ads|atr|adevents)",
        "youtube\\.com/pagead/",
        "youtube\\.com/ptracking",
        "/get_midroll_info",
        "[?&]adformat=",
        "//ad\\.",
    ]

    // Ad slots YouTube renders into the page; hidden with CSS both through
    // WebKit content rules and the injected style sheet below.
    private static let cssSelectors: [String] = [
        "ytd-ad-slot-renderer",
        "ytd-display-ad-renderer",
        "ytd-promoted-sparkles-web-renderer",
        "ytd-promoted-sparkles-text-search-renderer",
        "ytd-in-feed-promo-renderer",
        "#masthead-ad",
        "ytd-rich-item-renderer:has(ytd-ad-slot-renderer)",
        "ytd-rich-section-renderer:has(ytd-statement-banner-renderer)",
        ".ytp-ad-module",
        ".ytp-ad-overlay-container",
        "ytm-companion-slot",
        "ytm-promoted-video-renderer",
    ]

    private static let urlRegexes: [NSRegularExpression] = networkFilters.compactMap {
        try? NSRegularExpression(pattern: $0)
    }

    /// Synchronous check used by the navigation delegate as a second line of
    /// defence alongside the WebKit content rules, so blocked requests can be
    /// counted for the badge in the toolbar.
    static func isAdURL(_ url: URL) -> Bool {
        let absolute = url.absoluteString
        let range = NSRange(absolute.startIndex..., in: absolute)
        return urlRegexes.contains { $0.firstMatch(in: absolute, options: [], range: range) != nil }
    }

    /// Compiles the rule list ahead of the first load so it is usually ready
    /// (and disk-cached by WebKit) by the time the browser is created.
    static func warmUp() {
        compile { _ in }
    }

    static func install(in configuration: WKWebViewConfiguration) {
        if let cached = cachedRuleList {
            configuration.userContentController.add(cached)
            return
        }
        compile { list in
            guard let list else { return }
            DispatchQueue.main.async {
                configuration.userContentController.add(list)
            }
        }
    }

    private static var cachedRuleList: WKContentRuleList?

    private static func compile(completion: @escaping (WKContentRuleList?) -> Void) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: ruleListIdentifier,
            encodedContentRuleList: makeRulesJSON()
        ) { list, _ in
            cachedRuleList = list
            completion(list)
        }
    }

    private static func makeRulesJSON() -> String {
        var rules: [[String: Any]] = []

        for filter in networkFilters {
            rules.append([
                "action": ["type": "block"],
                "trigger": ["url-filter": filter, "url-filter-is-case-sensitive": true],
            ])
        }

        for selector in cssSelectors {
            rules.append([
                "action": ["type": "css-display-none", "selector": selector],
                "trigger": ["url-filter": ".*"],
            ])
        }

        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// Document-start script that hides ad markup in every frame and clicks
    /// the "Skip" button the moment it becomes clickable.
    static func userScript() -> WKUserScript {
        let selectorsJSON: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: cssSelectors),
                  let json = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return json
        }()

        let source = """
        (function () {
          if (window.__tubeLiteAdBlock) { return; }
          window.__tubeLiteAdBlock = true;

          // Stop YouTube's player from reacting to presentation-mode
          // changes, which is how it forces videos back inline and blocks
          // picture-in-picture in the built-in browser.
          document.addEventListener('webkitpresentationmodechanged', function (event) {
            event.stopPropagation();
            event.preventDefault();
            event.cancelBubble = true;
          }, true);

          var hideSelectors = \(selectorsJSON);

          var style = document.createElement('style');
          style.setAttribute('data-tube-lite', 'ad-block');
          style.textContent = hideSelectors.map(function (selector) {
            return selector + ' { display: none !important; visibility: hidden !important; }';
          }).join(' ');
          if (document.head) {
            document.head.appendChild(style);
          } else {
            document.addEventListener('DOMContentLoaded', function () {
              document.head.appendChild(style);
            });
          }

          function sweep() {
            var skipButtons = document.querySelectorAll('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-ad-skip-button-container button, .ytp-skip-button-container button');
            for (var i = 0; i < skipButtons.length; i++) {
              var button = skipButtons[i];
              if (button.offsetParent !== null) {
                button.click();
              }
            }
          }

          var lastSweep = 0;
          var observer = new MutationObserver(function () {
            var now = Date.now();
            if (now - lastSweep < 200) { return; }
            lastSweep = now;
            sweep();
          });

          function start() {
            sweep();
            observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
            window.setInterval(sweep, 1500);
          }

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', start);
          } else {
            start();
          }
        })();
        """

        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}
