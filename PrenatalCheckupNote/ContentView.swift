//
//  ContentView.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftUI

/// アプリの最初の画面。
///
/// 段階1（画面の試作）では、健診タブにあたる画面の流れだけを表示する。
/// ホーム・記録・健診の3つのタブ（要件定義 8章）は、段階3以降で作る。
struct ContentView: View {
    var body: some View {
        PrototypeRootView()
    }
}

#Preview {
    ContentView()
}
