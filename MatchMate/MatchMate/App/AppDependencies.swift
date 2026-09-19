//
//  AppDependencies.swift
//  MatchMate
//
//  Composition root. Wires the concrete API service, SwiftData store,
//  repository and network monitor together, and hands the list view model
//  its dependencies. This is the one place that knows about concrete types.
//

import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let listViewModel: MatchListViewModel

    init() {
        do {
            modelContainer = try ModelContainer(for: MatchProfile.self)
        } catch {
            // A failure here means the on-disk store is unusable; there's no
            // meaningful recovery, so we surface it loudly during development.
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        let api = ProfileAPIService()
        let repository = MatchRepository(api: api, context: modelContainer.mainContext)
        let monitor = NetworkMonitor()

        listViewModel = MatchListViewModel(repository: repository, networkMonitor: monitor)
    }
}
