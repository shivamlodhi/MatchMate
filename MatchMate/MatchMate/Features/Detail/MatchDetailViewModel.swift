//
//  MatchDetailViewModel.swift
//  MatchMate
//
//  Backs the profile detail screen. It operates on the same `MatchProfile`
//  instance the list holds, so a decision here is immediately visible on the
//  card when the user navigates back — no refresh required.
//

import Foundation

@MainActor
@Observable
final class MatchDetailViewModel {
    let profile: MatchProfile
    private(set) var errorMessage: String?

    private let repository: MatchRepositoryProtocol

    init(profile: MatchProfile, repository: MatchRepositoryProtocol) {
        self.profile = profile
        self.repository = repository
    }

    var status: MatchStatus { profile.status }

    func accept() {
        updateStatus(.accepted)
    }

    func decline() {
        updateStatus(.declined)
    }

    private func updateStatus(_ status: MatchStatus) {
        do {
            try repository.setStatus(status, for: profile)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
