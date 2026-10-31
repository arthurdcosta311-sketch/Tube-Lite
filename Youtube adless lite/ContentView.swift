//
//  ContentView.swift
//  Tube Lite
//

import SwiftUI

struct ContentView: View {

    @StateObject private var model = BrowserViewModel()
    @AppStorage("adBlockingEnabled") private var adBlockingEnabled = true
    @AppStorage("useDesktopLayout") private var useDesktopLayout = false
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
            }
        }
        .preferredColorScheme(.dark)
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
            chromeButton("chevron.left", enabled: model.canGoBack) {
                model.goBack()
            }
            chromeButton("house") {
                model.goHome()
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

    private func chromeButton(_ systemName: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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