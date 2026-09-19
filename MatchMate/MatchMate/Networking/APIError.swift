//
//  APIError.swift
//  MatchMate
//

import Foundation

/// Errors surfaced by the networking layer, mapped to user-friendly copy.
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case notConnected
    case requestFailed(String)
    case badStatus(Int)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Something went wrong building the request."
        case .notConnected:
            return "You appear to be offline. Showing saved profiles."
        case .requestFailed:
            return "Couldn't reach the server. Please try again."
        case .badStatus(let code):
            return "The server responded with an error (\(code))."
        case .decodingFailed:
            return "We received an unexpected response from the server."
        }
    }

    /// True when the failure is purely a connectivity problem, so callers can
    /// fall back to cached data instead of showing a hard error.
    var isConnectivity: Bool {
        switch self {
        case .notConnected, .requestFailed:
            return true
        default:
            return false
        }
    }
}
