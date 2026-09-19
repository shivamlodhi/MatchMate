//
//  MatchRepository.swift
//  MatchMate
//
//  Owns the persistence context and coordinates network + local storage.
//  This is the app's single source of truth: every read and write of a
//  profile goes through here, so the list and detail screens can never
//  disagree.
//

import Foundation
import SwiftData

/// Errors thrown by the persistence layer.
enum RepositoryError: LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Couldn't save your change. Please try again."
        case .fetchFailed:
            return "Couldn't load saved profiles."
        }
    }
}

protocol MatchRepositoryProtocol {
    /// Fetches a page from the API, merges it into local storage (preserving
    /// existing accept/decline decisions) and returns the full ordered list.
    func loadPage(_ page: Int) async throws -> [MatchProfile]

    /// Returns everything currently cached, in fetch order. Used for offline.
    func cachedProfiles() throws -> [MatchProfile]

    /// Persists a new decision for a profile.
    func setStatus(_ status: MatchStatus, for profile: MatchProfile) throws
}

@MainActor
final class MatchRepository: MatchRepositoryProtocol {
    private let api: ProfileAPIServiceProtocol
    private let context: ModelContext
    private let pageSize: Int

    init(api: ProfileAPIServiceProtocol, context: ModelContext, pageSize: Int = 10) {
        self.api = api
        self.context = context
        self.pageSize = pageSize
    }

    func loadPage(_ page: Int) async throws -> [MatchProfile] {
        let dtos = try await api.fetchProfiles(page: page, results: pageSize)
        try merge(dtos)
        return try cachedProfiles()
    }

    func cachedProfiles() throws -> [MatchProfile] {
        let descriptor = FetchDescriptor<MatchProfile>(
            sortBy: [SortDescriptor(\.sortIndex, order: .forward)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(error.localizedDescription)
        }
    }

    func setStatus(_ status: MatchStatus, for profile: MatchProfile) throws {
        profile.status = status
        do {
            try context.save()
        } catch {
            throw RepositoryError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Merge

    /// Upserts a page of DTOs. New profiles are appended after the current
    /// max `sortIndex`; existing ones are refreshed but keep their status.
    private func merge(_ dtos: [UserDTO]) throws {
        let existing = try cachedProfiles()
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1

        for dto in dtos {
            if let current = byID[dto.login.uuid] {
                dto.apply(to: current)
            } else {
                let profile = dto.makeProfile(sortIndex: nextIndex)
                context.insert(profile)
                byID[dto.login.uuid] = profile
                nextIndex += 1
            }
        }

        do {
            try context.save()
        } catch {
            throw RepositoryError.saveFailed(error.localizedDescription)
        }
    }
}
