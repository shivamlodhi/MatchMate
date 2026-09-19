//
//  UserDTO+Mapping.swift
//  MatchMate
//
//  Translates the network DTO into a persisted `MatchProfile`.
//

import Foundation

extension UserDTO {
    /// Parses the API's ISO-8601 timestamps, which include fractional seconds.
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Builds a fresh `MatchProfile` from this DTO.
    ///
    /// - Parameter sortIndex: position used to keep list ordering stable.
    /// - Note: status always starts as `.pending`; callers that update an
    ///   existing profile must preserve the stored status themselves.
    func makeProfile(sortIndex: Int) -> MatchProfile {
        MatchProfile(
            id: login.uuid,
            firstName: name.first,
            lastName: name.last,
            age: dob.age,
            gender: gender,
            city: location.city,
            state: location.state,
            country: location.country,
            nationality: nat,
            email: email,
            phone: phone,
            cell: cell,
            pictureLarge: picture.large,
            pictureMedium: picture.medium,
            registeredDate: UserDTO.iso8601.date(from: registered.date) ?? .distantPast,
            status: .pending,
            sortIndex: sortIndex
        )
    }

    /// Copies the latest API values onto an existing profile **without**
    /// touching the user's accept/decline decision.
    func apply(to profile: MatchProfile) {
        profile.firstName = name.first
        profile.lastName = name.last
        profile.age = dob.age
        profile.gender = gender
        profile.city = location.city
        profile.state = location.state
        profile.country = location.country
        profile.nationality = nat
        profile.email = email
        profile.phone = phone
        profile.cell = cell
        profile.pictureLarge = picture.large
        profile.pictureMedium = picture.medium
        profile.registeredDate = UserDTO.iso8601.date(from: registered.date) ?? profile.registeredDate
        // statusRaw and sortIndex are deliberately left untouched.
    }
}
