//
//  RandomUserResponse.swift
//  MatchMate
//
//  Data-transfer objects that mirror the randomuser.me JSON payload.
//  These are intentionally kept separate from the persisted `MatchProfile`
//  model so the API shape and our storage schema can evolve independently.
//

import Foundation

/// Top-level response for `GET /api/?page=…&results=…&seed=matchmate`.
struct RandomUserResponse: Decodable {
    let results: [UserDTO]
    let info: Info

    struct Info: Decodable {
        let seed: String
        let results: Int
        let page: Int
    }
}

/// A single user record from the API. Only the fields the app actually
/// consumes are decoded.
struct UserDTO: Decodable {
    let gender: String
    let name: Name
    let location: Location
    let email: String
    let login: Login
    let dob: DateInfo
    let registered: DateInfo
    let phone: String
    let cell: String
    let picture: Picture
    let nat: String

    struct Name: Decodable {
        let title: String
        let first: String
        let last: String
    }

    struct Location: Decodable {
        let city: String
        let state: String
        let country: String
    }

    struct Login: Decodable {
        /// Stable identifier used as the profile's primary key everywhere.
        let uuid: String
    }

    struct DateInfo: Decodable {
        let date: String
        let age: Int
    }

    struct Picture: Decodable {
        let large: String
        let medium: String
        let thumbnail: String
    }
}
