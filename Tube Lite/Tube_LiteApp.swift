//
//  Tube_LiteApp.swift
//  Tube Lite
//

import SwiftUI
import WebKit

@main
struct Tube_LiteApp: App {

    init() {
        AdBlockEngine.warmUp()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        BackgroundAudioKeeper.shared.activate()
                    case .active:
                        BackgroundAudioKeeper.shared.deactivate()
                    default:
                        break
                    }
                }
        }
    }
}
