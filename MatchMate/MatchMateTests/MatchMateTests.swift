//
//  MatchMateTests.swift
//  MatchMateTests
//
//  All suites are nested under one `.serialized` parent. SwiftData sets up
//  global schema/type registration lazily, which races when independent
//  suites create in-memory containers in parallel — serializing keeps the
//  suite deterministic under Xcode's default parallel test execution.
//

import Testing
import SwiftData
@testable import MatchMate

@Suite(.serialized)
struct MatchMateTests {

    // MARK: - MatchListViewModel

    @MainActor
    @Suite
    struct MatchListViewModelTests {

        private func makeSUT(
            connected: Bool = true
        ) -> (MatchListViewModel, MockMatchRepository, MockNetworkMonitor) {
            let repo = MockMatchRepository()
            let monitor = MockNetworkMonitor(isConnected: connected)
            let sut = MatchListViewModel(repository: repo, networkMonitor: monitor)
            return (sut, repo, monitor)
        }

        @Test func firstLoadPopulatesProfilesAndLoadsPageOne() async {
            let (sut, repo, _) = makeSUT()
            repo.allProfiles = [makeProfile(id: "1"), makeProfile(id: "2")]

            await sut.onAppear()

            #expect(sut.phase == .loaded)
            #expect(sut.profiles.count == 2)
            #expect(repo.loadedPages == [1])
        }

        @Test func onAppearLoadsOnlyOnce() async {
            let (sut, repo, _) = makeSUT()
            repo.allProfiles = [makeProfile(id: "1")]

            await sut.onAppear()
            await sut.onAppear()

            #expect(repo.loadedPages == [1])
        }

        @Test func scrollingToLastItemLoadsNextPage() async {
            let (sut, repo, _) = makeSUT()
            let page1 = [makeProfile(id: "1", sortIndex: 0), makeProfile(id: "2", sortIndex: 1)]
            let page2 = page1 + [makeProfile(id: "3", sortIndex: 2), makeProfile(id: "4", sortIndex: 3)]
            repo.loadPageHandler = { page in page == 1 ? page1 : page2 }

            await sut.onAppear()
            #expect(sut.profiles.count == 2)

            await sut.loadMoreIfNeeded(currentItem: page1[1])

            #expect(sut.profiles.count == 4)
            #expect(repo.loadedPages == [1, 2])
        }

        @Test func scrollingToNonLastItemDoesNotPaginate() async {
            let (sut, repo, _) = makeSUT()
            let page1 = [makeProfile(id: "1"), makeProfile(id: "2")]
            repo.loadPageHandler = { _ in page1 }

            await sut.onAppear()
            await sut.loadMoreIfNeeded(currentItem: page1[0]) // not the last item

            #expect(repo.loadedPages == [1])
        }

        @Test func offlineWithCacheShowsCacheAndBanner() async {
            let (sut, repo, _) = makeSUT(connected: false)
            repo.cached = [makeProfile(id: "1"), makeProfile(id: "2")]

            await sut.onAppear()

            #expect(sut.phase == .loaded)
            #expect(sut.profiles.count == 2)
            #expect(sut.banner != nil)
            #expect(repo.loadedPages.isEmpty) // never hit the network
        }

        @Test func offlineWithEmptyCacheFails() async {
            let (sut, repo, _) = makeSUT(connected: false)
            repo.cached = []

            await sut.onAppear()

            if case .failed = sut.phase {
                #expect(sut.profiles.isEmpty)
            } else {
                Issue.record("Expected failed phase, got \(sut.phase)")
            }
        }

        @Test func connectivityErrorFallsBackToCache() async {
            let (sut, repo, _) = makeSUT(connected: true)
            repo.loadPageError = APIError.requestFailed("timeout")
            repo.cached = [makeProfile(id: "1")]

            await sut.onAppear()

            #expect(sut.phase == .loaded)
            #expect(sut.profiles.count == 1)
            #expect(sut.banner != nil)
        }

        @Test func hardErrorWithNoCacheShowsFailure() async {
            let (sut, repo, _) = makeSUT(connected: true)
            repo.loadPageError = APIError.badStatus(500)

            await sut.onAppear()

            if case .failed = sut.phase {
                #expect(true)
            } else {
                Issue.record("Expected failed phase, got \(sut.phase)")
            }
        }

        @Test func acceptUpdatesStatusThroughRepository() async {
            let (sut, repo, _) = makeSUT()
            let profile = makeProfile(id: "1")
            repo.allProfiles = [profile]
            await sut.onAppear()

            sut.accept(profile)

            #expect(profile.status == .accepted)
            #expect(repo.statusUpdates.first?.status == .accepted)
        }

        @Test func declineUpdatesStatusThroughRepository() async {
            let (sut, repo, _) = makeSUT()
            let profile = makeProfile(id: "1")
            repo.allProfiles = [profile]
            await sut.onAppear()

            sut.decline(profile)

            #expect(profile.status == .declined)
            #expect(repo.statusUpdates.first?.status == .declined)
        }

        @Test func setStatusFailureSurfacesBanner() async {
            let (sut, repo, _) = makeSUT()
            let profile = makeProfile(id: "1")
            repo.allProfiles = [profile]
            repo.setStatusError = RepositoryError.saveFailed("disk full")
            await sut.onAppear()

            sut.accept(profile)

            #expect(sut.banner != nil)
        }
    }

    // MARK: - MatchDetailViewModel

    @MainActor
    @Suite
    struct MatchDetailViewModelTests {

        @Test func acceptSetsStatusAccepted() {
            let profile = makeProfile(id: "1")
            let repo = MockMatchRepository()
            let sut = MatchDetailViewModel(profile: profile, repository: repo)

            sut.accept()

            #expect(profile.status == .accepted)
            #expect(sut.status == .accepted)
            #expect(sut.errorMessage == nil)
        }

        @Test func declineSetsStatusDeclined() {
            let profile = makeProfile(id: "1")
            let repo = MockMatchRepository()
            let sut = MatchDetailViewModel(profile: profile, repository: repo)

            sut.decline()

            #expect(profile.status == .declined)
            #expect(sut.status == .declined)
        }

        @Test func saveFailureSurfacesErrorMessage() {
            let profile = makeProfile(id: "1")
            let repo = MockMatchRepository()
            repo.setStatusError = RepositoryError.saveFailed("disk full")
            let sut = MatchDetailViewModel(profile: profile, repository: repo)

            sut.accept()

            #expect(sut.errorMessage != nil)
            #expect(profile.status == .pending) // status unchanged on failure
        }
    }

    // MARK: - MatchRepository (real in-memory SwiftData store)

    @MainActor
    @Suite
    struct MatchRepositoryTests {

        @Test func loadPageInsertsAndReturnsProfilesInOrder() async throws {
            let container = try makeInMemoryContainer()
            let api = MockAPIService()
            api.pagesByNumber[1] = [makeDTO(uuid: "a"), makeDTO(uuid: "b")]
            let sut = MatchRepository(api: api, context: container.mainContext)

            let result = try await sut.loadPage(1)

            #expect(result.count == 2)
            #expect(result.map(\.id) == ["a", "b"])
        }

        @Test func secondPageAppendsAfterFirst() async throws {
            let container = try makeInMemoryContainer()
            let api = MockAPIService()
            api.pagesByNumber[1] = [makeDTO(uuid: "a"), makeDTO(uuid: "b")]
            api.pagesByNumber[2] = [makeDTO(uuid: "c"), makeDTO(uuid: "d")]
            let sut = MatchRepository(api: api, context: container.mainContext)

            _ = try await sut.loadPage(1)
            let result = try await sut.loadPage(2)

            #expect(result.map(\.id) == ["a", "b", "c", "d"])
        }

        @Test func mergePreservesExistingStatus() async throws {
            let container = try makeInMemoryContainer()
            let api = MockAPIService()
            api.pagesByNumber[1] = [makeDTO(uuid: "a")]
            let sut = MatchRepository(api: api, context: container.mainContext)

            let firstLoad = try await sut.loadPage(1)
            let profile = try #require(firstLoad.first)
            try sut.setStatus(.accepted, for: profile)

            // Re-fetch the same page: the API returns the same user again.
            let secondLoad = try await sut.loadPage(1)
            let reloaded = try #require(secondLoad.first { $0.id == "a" })

            #expect(reloaded.status == .accepted)
            #expect(secondLoad.count == 1) // no duplicate inserted
        }

        @Test func setStatusPersistsToStore() async throws {
            let container = try makeInMemoryContainer()
            let api = MockAPIService()
            api.pagesByNumber[1] = [makeDTO(uuid: "a")]
            let sut = MatchRepository(api: api, context: container.mainContext)

            let loaded = try await sut.loadPage(1)
            try sut.setStatus(.declined, for: loaded[0])

            let cached = try sut.cachedProfiles()
            #expect(cached.first?.status == .declined)
        }

        @Test func cachedProfilesReturnsEmptyWhenNothingStored() throws {
            let container = try makeInMemoryContainer()
            let api = MockAPIService()
            let sut = MatchRepository(api: api, context: container.mainContext)

            #expect(try sut.cachedProfiles().isEmpty)
        }
    }
}
