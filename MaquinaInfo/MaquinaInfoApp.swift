//
//  MaquinaInfoApp.swift
//  MaquinaInfo
//
//  Created by Roberto Antonio Berrospe Machin on 6/1/26.
//

import SwiftUI

@main
struct MaquinaInfoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowAboutPanel"), object: nil)
                }) {
                    Text(LanguageManager.shared.translate("AboutTitle"))
                }
                .keyboardShortcut("i", modifiers: [.command])
            }
        }
    }
}
