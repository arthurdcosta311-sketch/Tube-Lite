//
//  ContentView.swift
//  Tube Lite
//

import SwiftUI
import UIKit

struct ContentView: View {

    @StateObject private var model = BrowserViewModel()
    @AppStorage("adBlockingEnabled") private var adBlockingEnabled = true
    @AppStorage("useDesktopLayout") private var useDesktopLayout = false
    @AppStorage("topBarLayout") private var topBarLayout = "back,forward,reload,home"
    @AppStorage("bottomBarLayout") private var bottomBarLayout = "destinations,pip"
    @AppStorage("toolbarIconSize") private var toolbarIconSizeRaw = "medium"
    @State private var blockerGeneration = 0
    @State private var showSettings = false
    @State private var iconFrames: [String: CGRect] = [:]
    @State private var draggingIcon: ToolbarIcon?
    @State private var dropTargetIcon: ToolbarIcon?
    @State private var dragTranslation: CGSize = .zero

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
        .onPreferenceChange(ToolbarIconFrameKey.self) { frames in
            iconFrames = frames
        }
        .sheet(isPresented: $model.showSearchSheet) {
            SearchSheet(model: model)
        }
        .sheet(isPresented: $model.showDestinationsSheet) {
            DestinationsSheet(model: model)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                adBlockingEnabled: $adBlockingEnabled,
                useDesktopLayout: $useDesktopLayout,
                toolbarIconSize: $toolbarIconSizeRaw,
                blockedCount: model.blockedCount
            )
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
        .animation(.spring(duration: 0.3), value: parse(topBarLayout))
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
        .animation(.spring(duration: 0.3), value: parse(bottomBarLayout))
    }

    // MARK: Movable and resizable toolbar icons

    private var iconScale: CGFloat {
        switch toolbarIconSizeRaw {
        case "small": return 0.85
        case "large": return 1.25
        default: return 1.0
        }
    }

    private func iconButton(_ icon: ToolbarIcon) -> some View {
        let size = 40 * iconScale
        let fontSize = 15 * iconScale
        return Image(systemName: icon.systemName)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(icon.isEnabled(model) ? Color.primary : Color.secondary.opacity(0.35))
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ToolbarIconFrameKey.self,
                        value: [icon.rawValue: geo.frame(in: .global)]
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(dropTargetIcon == icon ? Color.red : Color.clear, lineWidth: 2)
            )
            .scaleEffect(draggingIcon == icon ? 1.12 : 1)
            .offset(draggingIcon == icon ? dragTranslation : .zero)
            .opacity(draggingIcon != nil && draggingIcon != icon ? 0.85 : 1)
            .zIndex(draggingIcon == icon ? 2 : 0)
            .onTapGesture {
                if icon.isEnabled(model) {
                    icon.perform(model)
                }
            }
            .gesture(rearrangeGesture(for: icon))
    }

    /// Long-press to pick an icon up, then drag; releasing over another icon
    /// inserts the dragged icon before it.
    private func rearrangeGesture(for icon: ToolbarIcon) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 5))
            .onChanged { value in
                switch value {
                case .first(true):
                    if draggingIcon == nil {
                        draggingIcon = icon
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                case .second(_, let drag?):
                    dragTranslation = drag.translation
                    updateDropTarget(drag, for: icon)
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, _):
                    finishRearrange(from: icon)
                case .second(false, _):
                    cancelRearrange()
                default:
                    break
                }
            }
    }

    private func updateDropTarget(_ drag: DragGesture.Value, for source: ToolbarIcon) {
        guard let origin = iconFrames[source.rawValue]?.origin else { return }
        let point = CGPoint(x: origin.x + drag.location.x, y: origin.y + drag.location.y)

        var found: ToolbarIcon?
        for (raw, frame) in iconFrames where raw != source.rawValue {
            if let icon = ToolbarIcon(rawValue: raw), frame.contains(point) {
                found = icon
            }
        }
        if dropTargetIcon != found {
            dropTargetIcon = found
        }
    }

    private func finishRearrange(from source: ToolbarIcon) {
        let target = dropTargetIcon
        cancelRearrange()
        guard let target, target != source else { return }
        move(source, before: target)
    }

    private func cancelRearrange() {
        draggingIcon = nil
        dropTargetIcon = nil
        dragTranslation = .zero
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

private struct ToolbarIconFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
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
    @Binding var toolbarIconSize: String
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

            Picker("Icon size", selection: $toolbarIconSize) {
                Text("Small").tag("small")
                Text("Medium").tag("medium")
                Text("Large").tag("large")
            }
            .pickerStyle(.segmented)
            .tint(.red)

            Label("\(blockedCount) ads blocked so far", systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Tip: long-press an icon to pick it up, drag it over another icon and release to place it. Icons can move between the top and bottom bars.")
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
        return "Youtube adless lite \(version) (build \(build))"
    }
}

#Preview {
    ContentView()
}
