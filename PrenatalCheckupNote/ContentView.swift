//
//  ContentView.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftUI

/// アプリの最初の画面。
///
/// 要件定義 v0.4 で、v0.3 の試作（持ち越しと完了の仕組み）を外した（ADR 0005）。
/// 「次の健診」「これまでの健診」の 2 つのタブは段階 B で作る。それまでは仮の画面を出す。
struct ContentView: View {
    #if DEBUG
    @State private var isShowingDeveloperMenu = false
    #endif

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("妊婦健診ノート", systemImage: "list.bullet.clipboard")
            } description: {
                Text("画面は作り直しています。")
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingDeveloperMenu = true
                    } label: {
                        Label("開発用", systemImage: "hammer")
                    }
                }
            }
            .sheet(isPresented: $isShowingDeveloperMenu) {
                DeveloperMenuView()
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
}
