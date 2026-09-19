//
//  MatchMateApp.swift
//  MatchMate
//
//  Created by Furlenco on 18/09/26.
//

import SwiftUI
import SwiftData

@main
struct MatchMateApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MatchListView(viewModel: dependencies.listViewModel)
                .modelContainer(dependencies.modelContainer)
        }
    }
}
