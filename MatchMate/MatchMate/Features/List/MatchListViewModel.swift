//
//  MatchListViewModel.swift
//  MatchMate
//
//  Drives the match list: pagination, loading/error state, offline fallback,
//  and accept/decline. The view stays thin and just renders this state.
//

import Foundation

@MainActor
@Observable
final class MatchListViewModel {

    /// High-level state for the initial load, so the view can switch between
    /// a spinner, the list, and a full-screen error/empty state.
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var profiles: [MatchProfile] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingNextPage = false
    /// Non-fatal message (e.g. "you're offline") shown as a banner while
    /// cached content is still visible.
    private(set) var banner: String?

    private let repository: MatchRepositoryProtocol
    private let networkMonitor: NetworkMonitoring

    private var currentPage = 0
    private var canLoadMore = true

    var isOffline: Bool { !networkMonitor.isConnected }

    init(repository: MatchRepositoryProtocol, networkMonitor: NetworkMonitoring) {
        self.repository = repository
        self.networkMonitor = networkMonitor
    }

    /// Called when the list first appears. Loads page 1 once.
    func onAppear() async {
        guard case .idle = phase else { return }
        await loadFirstPage()
    }

    func loadFirstPage() async {
        phase = .loading
        banner = nil
        currentPage = 0
        canLoadMore = true
        await loadNextPage()
        // If the very first network load failed but we have no cache either,
        // `loadNextPage` will have set `.failed`. Otherwise show the list.
        if case .loading = phase {
            phase = .loaded
        }
    }

    /// Loads the next page when the user nears the bottom of the list.
    func loadMoreIfNeeded(currentItem: MatchProfile) async {
        guard let last = profiles.last, last.id == currentItem.id else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard canLoadMore, !isLoadingNextPage else { return }

        // Offline: serve whatever is cached and stop paginating remotely.
        guard networkMonitor.isConnected else {
            await serveCache(offline: true)
            return
        }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let nextPage = currentPage + 1
        do {
            let all = try await repository.loadPage(nextPage)
            profiles = all
            currentPage = nextPage
            banner = nil
            if phase != .loaded { phase = .loaded }
            // randomuser always returns a full page for our seed; if it ever
            // returns fewer, we've reached the end.
            canLoadMore = true
        } catch let error as APIError where error.isConnectivity {
            await serveCache(offline: true, fallbackError: error)
        } catch {
            await handle(error)
        }
    }

    /// Falls back to cached profiles. Used both when offline and when a
    /// network request fails for connectivity reasons.
    private func serveCache(offline: Bool, fallbackError: Error? = nil) async {
        do {
            let cached = try repository.cachedProfiles()
            profiles = cached
            canLoadMore = false
            if cached.isEmpty {
                let message = fallbackError?.localizedDescription
                    ?? APIError.notConnected.localizedDescription
                phase = .failed(message)
            } else {
                phase = .loaded
                banner = offline ? APIError.notConnected.localizedDescription : nil
            }
        } catch {
            await handle(error)
        }
    }

    private func handle(_ error: Error) async {
        let message = (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        if profiles.isEmpty {
            phase = .failed(message)
        } else {
            banner = message
        }
    }

    // MARK: - Actions

    func accept(_ profile: MatchProfile) {
        updateStatus(.accepted, for: profile)
    }

    func decline(_ profile: MatchProfile) {
        updateStatus(.declined, for: profile)
    }

    private func updateStatus(_ status: MatchStatus, for profile: MatchProfile) {
        do {
            try repository.setStatus(status, for: profile)
        } catch {
            banner = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: - Navigation

    /// Builds a detail view model for a profile, sharing the same repository so
    /// both screens read and write one source of truth.
    func makeDetailViewModel(for profile: MatchProfile) -> MatchDetailViewModel {
        MatchDetailViewModel(profile: profile, repository: repository)
    }
}
