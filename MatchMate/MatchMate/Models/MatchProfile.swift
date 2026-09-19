//
//  MatchProfile.swift
//  MatchMate
//
//  The single source of truth for a match. Persisted with SwiftData and
//  shared by reference between the list and detail screens, so a status
//  change made anywhere is reflected everywhere without a manual refresh.
//

import Foundation
import SwiftData

/// The decision a user has made about a profile.
enum MatchStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
}

@Model
final class MatchProfile {
    /// `login.uuid` from the API — stable across pages and relaunches.
    @Attribute(.unique) var id: String

    var firstName: String
    var lastName: String
    var age: Int
    var gender: String

    var city: String
    var state: String
    var country: String
    var nationality: String

    var email: String
    var phone: String
    var cell: String

    var pictureLarge: String
    var pictureMedium: String

    var registeredDate: Date

    /// Backing storage for `status`. SwiftData persists primitives more
    /// reliably than enums across schema changes, so we store the raw value.
    var statusRaw: String

    /// Preserves the order in which profiles were fetched so the list looks
    /// identical after an app relaunch.
    var sortIndex: Int

    var status: MatchStatus {
        get { MatchStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var fullName: String { "\(firstName) \(lastName)" }

    /// "56, Oudega, Drenthe" — the subtitle shown on cards.
    var shortLocation: String { "\(age), \(city), \(state)" }

    init(
        id: String,
        firstName: String,
        lastName: String,
        age: Int,
        gender: String,
        city: String,
        state: String,
        country: String,
        nationality: String,
        email: String,
        phone: String,
        cell: String,
        pictureLarge: String,
        pictureMedium: String,
        registeredDate: Date,
        status: MatchStatus = .pending,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.gender = gender
        self.city = city
        self.state = state
        self.country = country
        self.nationality = nationality
        self.email = email
        self.phone = phone
        self.cell = cell
        self.pictureLarge = pictureLarge
        self.pictureMedium = pictureMedium
        self.registeredDate = registeredDate
        self.statusRaw = status.rawValue
        self.sortIndex = sortIndex
    }
}
