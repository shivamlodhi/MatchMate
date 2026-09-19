//
//  TestSupport.swift
//  MatchMateTests
//
//  Mocks and factories shared across the test suites.
//

import Foundation
import SwiftData
@testable import MatchMate

// MARK: - Factories

func makeProfile(
    id: String,
    first: String = "Test",
    last: String = "User",
    status: MatchStatus = .pending,
    sortIndex: Int = 0
) -> MatchProfile {
    MatchProfile(
        id: id,
        firstName: first,
        lastName: last,
        age: 30,
        gender: "female",
        city: "City",
        state: "State",
        country: "Country",
        nationality: "US",
        email: "\(first)@example.com",
        phone: "123",
        cell: "456",
        pictureLarge: "https://example.com/large.jpg",
        pictureMedium: "https://example.com/medium.jpg",
        registeredDate: .init(timeIntervalSince1970: 0),
        status: status,
        sortIndex: sortIndex
    )
}

func makeDTO(uuid: String, first: String = "Test", last: String = "User") -> UserDTO {
    UserDTO(
        gender: "female",
        name: .init(title: "Ms", first: first, last: last),
        location: .init(city: "City", state: "State", country: "Country"),
        email: "\(first)@example.com",
        login: .init(uuid: uuid),
        dob: .init(date: "1990-01-01T00:00:00.000Z", age: 30),
        registered: .init(date: "2015-01-19T08:46:16.565Z", age: 11),
        phone: "123",
        cell: "456",
        picture: .init(
            large: "https://example.com/large.jpg",
            medium: "https://example.com/medium.jpg",
            thumbnail: "https://example.com/thumb.jpg"
        ),
        nat: "US"
    )
}

/// Creates a fresh in-memory SwiftData container. Tests must keep the returned
/// container alive for their duration — if it deallocates, its `mainContext`
/// dangles and crashes on use.
@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: MatchProfile.self, configurations: config)
}

// MARK: - Mocks

final class MockNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool
    init(isConnected: Bool = true) { self.isConnected = isConnected }
}

final class MockAPIService: ProfileAPIServiceProtocol {
    var pagesByNumber: [Int: [UserDTO]] = [:]
    var error: Error?
    private(set) var requestedPages: [Int] = []

    func fetchProfiles(page: Int, results: Int) async throws -> [UserDTO] {
        requestedPages.append(page)
        if let error { throw error }
        return pagesByNumber[page] ?? []
    }
}

final class MockMatchRepository: MatchRepositoryProtocol {
    var loadPageHandler: ((Int) async throws -> [MatchProfile])?
    var loadPageError: Error?
    var allProfiles: [MatchProfile] = []
    var cached: [MatchProfile] = []
    var setStatusError: Error?

    private(set) var loadedPages: [Int] = []
    private(set) var statusUpdates: [(id: String, status: MatchStatus)] = []

    func loadPage(_ page: Int) async throws -> [MatchProfile] {
        loadedPages.append(page)
        if let handler = loadPageHandler { return try await handler(page) }
        if let loadPageError { throw loadPageError }
        return allProfiles
    }

    func cachedProfiles() throws -> [MatchProfile] {
        cached
    }

    func setStatus(_ status: MatchStatus, for profile: MatchProfile) throws {
        if let setStatusError { throw setStatusError }
        profile.status = status
        statusUpdates.append((profile.id, status))
    }
}
