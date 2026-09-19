//
//  MatchCardView.swift
//  MatchMate
//
//  A single match card. It reads `profile.status` directly from the shared
//  @Model instance, so it re-renders automatically when the status changes
//  from either this screen or the detail screen.
//

import SwiftUI

struct MatchCardView: View {
    let profile: MatchProfile
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ProfileImage(urlString: profile.pictureLarge)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .padding(.top, 16)

            VStack(spacing: 4) {
                Text(profile.fullName)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.center)
                Text(profile.shortLocation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Group {
                if profile.status == .pending {
                    PendingActions(onAccept: onAccept, onDecline: onDecline)
                } else {
                    StatusBanner(status: profile.status)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

/// Loads a remote portrait with placeholder and failure states.
struct ProfileImage: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder(systemName: "person.crop.circle.badge.exclamationmark")
            case .empty:
                ZStack {
                    Color(.tertiarySystemFill)
                    ProgressView()
                }
            @unknown default:
                placeholder(systemName: "person.crop.circle")
            }
        }
    }

    private func placeholder(systemName: String) -> some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: systemName)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }
}
