//
//  ContentView.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .padding()
            #if DEBUG
            .toolbar {
                NavigationLink("動作確認") {
                    DeviceCheckView()
                }
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
}
