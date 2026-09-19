//
//  ProfileAPIService.swift
//  MatchMate
//
//  Thin async/await wrapper around URLSession for the randomuser.me API.
//

import Foundation

/// Fetches pages of profiles from the remote API.
protocol ProfileAPIServiceProtocol {
    /// - Parameters:
    ///   - page: 1-based page index.
    ///   - results: number of profiles per page.
    func fetchProfiles(page: Int, results: Int) async throws -> [UserDTO]
}

final class ProfileAPIService: ProfileAPIServiceProtocol {
    /// Keeping the seed fixed makes the paginated results stable for review.
    private let seed = "matchmate"
    private let baseURL = "https://randomuser.me/api/"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProfiles(page: Int, results: Int) async throws -> [UserDTO] {
        guard var components = URLComponents(string: baseURL) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "results", value: String(results)),
            URLQueryItem(name: "seed", value: seed)
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.notConnected
        } catch {
            throw APIError.requestFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(RandomUserResponse.self, from: data)
            return decoded.results
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }
}
