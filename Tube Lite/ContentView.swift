//
//  ContentView.swift
//  Tube Lite
//

import SwiftUI

struct ContentView: View {

    @StateObject private var model = BrowserViewModel()
    @AppStorage("adBlockingEnabled") private var adBlockingEnabled = true
    @AppStorage("useDesktopLayout") private var useDesktopLayout = false
    @AppStorage("topBarLayout") private var topBarLayout = "back,forward,reload,home"
    @AppStorage("bottomBarLayout") private var bottomBarLayout = "destinations,pip"
    @State private var blockerGeneration = 0
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09)
                .ignoresSafeArea()

            BrowserWebView(model: model, adBlockingEnabled: adBlockingEnabled, useDesktopAgent: useDesktopLayout)
                .id(blockerGeneration)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                topBar

                if model.isLoading {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .tint(.red)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                }

                Spacer()

                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showSearchSheet) {
            SearchSheet(model: model)
        }
        .sheet(isPresented: $model.showDestinationsSheet) {
            DestinationsSheet(model: model)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(adBlockingEnabled: $adBlockingEnabled, useDesktopLayout: $useDesktopLayout, blockedCount: model.blockedCount)
        }
        .onChange(of: adBlockingEnabled) { _, _ in
            blockerGeneration += 1
        }
        .onChange(of: useDesktopLayout) { _, _ in
            blockerGeneration += 1
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            ForEach(parse(topBarLayout), id: \.self) { raw in
                if let icon = ToolbarIcon(rawValue: raw) {
                    iconButton(icon)
                }
            }

            Spacer(minLength: 8)

            shieldBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var shieldBadge: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: adBlockingEnabled ? "checkmark.shield.fill" : "shield.slash")
                if model.blockedCount > 0 {
                    Text("\(model.blockedCount)")
                        .monospacedDigit()
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(adBlockingEnabled ? Color.green : Color.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            ForEach(parse(bottomBarLayout), id: \.self) { raw in
                if let icon = ToolbarIcon(rawValue: raw) {
                    iconButton(icon)
                }
            }

            Button {
                model.showSearchSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Search YouTube")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            iconButton(.pip)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: Draggable toolbar icons

    private func iconButton(_ icon: ToolbarIcon) -> some View {
        Button {
            if icon.isEnabled(model) {
                icon.perform(model)
            }
        } label: {
            Image(systemName: icon.systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(icon.isEnabled(model) ? Color.primary : Color.secondary.opacity(0.35))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .draggable(icon.rawValue)
        .dropDestination(for: String.self) { payload, _ in
            guard let movedRaw = payload.first, let moved = ToolbarIcon(rawValue: movedRaw) else {
                return false
            }
            move(moved, before: icon)
            return true
        }
    }

    /// Moves an icon so it lands just before the target, keeping every icon
    /// present exactly once and persisting both bars' order.
    private func move(_ moved: ToolbarIcon, before target: ToolbarIcon) {
        guard moved != target else { return }

        var top = parse(topBarLayout)
        var bottom = parse(bottomBarLayout)

        if let idx = top.firstIndex(of: moved.rawValue) {
            top.remove(at: idx)
        } else if let idx = bottom.firstIndex(of: moved.rawValue) {
            bottom.remove(at: idx)
        } else {
            return
        }

        if let idx = top.firstIndex(of: target.rawValue) {
            top.insert(moved.rawValue, at: idx)
            topBarLayout = top.joined(separator: ",")
        } else if let idx = bottom.firstIndex(of: target.rawValue) {
            bottom.insert(moved.rawValue, at: idx)
            bottomBarLayout = bottom.joined(separator: ",")
        }
    }

    private func parse(_ layout: String) -> [String] {
        var result: [String] = []
        for raw in layout.split(separator: ",").map(String.init)
        where ToolbarIcon(rawValue: raw) != nil && !result.contains(raw) {
            result.append(raw)
        }
        for icon in ToolbarIcon.allCases where !result.contains(icon.rawValue) {
            result.append(icon.rawValue)
        }
        return result
    }
}

private enum ToolbarIcon: String, CaseIterable {
    case back, forward, reload, home
    case destinations
    case pip

    var systemName: String {
        switch self {
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .reload: return "arrow.clockwise"
        case .home: return "house"
        case .destinations: return "square.grid.2x2"
        case .pip: return "pip"
        }
    }

    func isEnabled(_ model: BrowserViewModel) -> Bool {
        switch self {
        case .back: return model.canGoBack
        case .forward: return model.canGoForward
        default: return true
        }
    }

    func perform(_ model: BrowserViewModel) {
        switch self {
        case .back: model.goBack()
        case .forward: model.goForward()
        case .reload: model.reload()
        case .home: model.goHome()
        case .destinations: model.showDestinationsSheet = true
        case .pip: model.enterPictureInPicture()
        }
    }
}

private struct SearchSheet: View {

    @ObservedObject var model: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search YouTube or paste a link", text: $query)
                    .focused($fieldFocused)
                    .submitLabel(.go)
                    .onSubmit(submit)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.quaternary, in: Capsule())

            Text("Paste a youtube.com or youtu.be link to open it directly.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.height(230)])
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.search(query)
        dismiss()
    }
}

// MARK: - Destinations

private struct DestinationsSheet: View {

    struct Destination {
        let name: String
        let icon: String
        let url: URL
    }

    @ObservedObject var model: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    private let destinations: [Destination] = [
        .init(name: "Home", icon: "house", url: URL(string: "https://www.youtube.com/")!),
        .init(name: "Shorts", icon: "bolt.fill", url: URL(string: "https://www.youtube.com/shorts")!),
        .init(name: "Subscriptions", icon: "person.2", url: URL(string: "https://www.youtube.com/feed/subscriptions")!),
        .init(name: "Trending", icon: "flame", url: URL(string: "https://www.youtube.com/feed/trending")!),
        .init(name: "History", icon: "clock.arrow.circlepath", url: URL(string: "https://www.youtube.com/feed/history")!),
        .init(name: "Watch later", icon: "bookmark", url: URL(string: "https://www.youtube.com/playlist?list=WL")!),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(destinations, id: \.name) { destination in
                        Button {
                            model.load(destination.url)
                            dismiss()
                        } label: {
                            Label(destination.name, systemImage: destination.icon)
                                .foregroundStyle(.primary)
                        }
                    }
                } footer: {
                    Text("These open in the built-in browser, with ad blocking applied.")
                }
            }
            .navigationTitle("Go to")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Settings

private struct SettingsSheet: View {

    @Binding var adBlockingEnabled: Bool
    @Binding var useDesktopLayout: Bool
    let blockedCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Ad blocking")
                .font(.title2.bold())

            Toggle(isOn: $adBlockingEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block YouTube ads")
                    Text("WebKit content rules plus an auto-skip script. Applied after the page reloads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.red)
            .onChange(of: adBlockingEnabled) { _, _ in
                dismiss()
            }

            Toggle(isOn: $useDesktopLayout) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Desktop layout")
                    Text("Serves the desktop YouTube site. The mobile layout usually works and plays better on a phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.red)
            .onChange(of: useDesktopLayout) { _, _ in
                dismiss()
            }

            Label("\(blockedCount) ads blocked so far", systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Tip: long-press any toolbar icon and drag it onto another to reorder the buttons.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Ad blocking is best-effort: YouTube changes constantly, so a few ads may still slip through.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(versionLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.medium])
    }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Tube Lite \(version) (build \(build))"
    }
}

#Preview {
    ContentView()
}
