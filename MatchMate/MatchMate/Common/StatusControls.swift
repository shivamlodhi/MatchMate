//
//  StatusControls.swift
//  MatchMate
//
//  Reusable accept/decline controls shared by the card and detail screens so
//  the two never drift apart visually.
//

import SwiftUI

/// The pending state: a circular decline (✕) and accept (✓) pair.
struct PendingActions: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(.secondary)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1.5))
            }
            .accessibilityLabel("Decline")

            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Color.accentColor)
                    .overlay(Circle().stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
            }
            .accessibilityLabel("Accept")
        }
        .buttonStyle(.plain)
    }
}

/// The resolved state: a full-width "Accepted" / "Declined" banner.
struct StatusBanner: View {
    let status: MatchStatus

    private var title: String {
        switch status {
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .pending: return ""
        }
    }

    private var tint: Color {
        switch status {
        case .accepted: return Color.accentColor
        case .declined: return Color.gray
        case .pending: return .clear
        }
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint, in: RoundedRectangle(cornerRadius: 10))
    }
}
