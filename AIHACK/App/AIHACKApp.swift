//
//  AIHACKApp.swift
//  AIHACK
//
//  Created by 北川達大 on 2026/08/10.
//

import SwiftUI

@main
struct AIHACKApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
                .overlay(NeonScreenBorder())
        }
    }
}
