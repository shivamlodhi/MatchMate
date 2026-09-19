//
//  MatchDetailView.swift
//  MatchMate
//
//  Full profile screen. Accept/Decline here update the shared model, so the
//  detail UI changes immediately and the list card reflects it on back-nav.
//

import SwiftUI

struct MatchDetailView: View {
    @State private var viewModel: MatchDetailViewModel

    init(viewModel: MatchDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var profile: MatchProfile { viewModel.profile }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if profile.status == .pending {
                    PendingActions(
                        onAccept: { viewModel.accept() },
                        onDecline: { viewModel.decline() }
                    )
                    .padding(.vertical, 4)
                } else {
                    StatusBanner(status: profile.status)
                        .padding(.horizontal, 24)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                details
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(profile.firstName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ProfileImage(urlString: profile.pictureLarge)
                .frame(width: 160, height: 160)
                .clipShape(Circle())

            Text(profile.fullName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(profile.shortLocation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "envelope", title: "Email", value: profile.email)
            Divider().padding(.leading, 52)
            DetailRow(icon: "phone", title: "Phone", value: profile.phone)
            Divider().padding(.leading, 52)
            DetailRow(icon: "iphone", title: "Cell", value: profile.cell)
            Divider().padding(.leading, 52)
            DetailRow(icon: "flag", title: "Nationality", value: profile.nationality)
            Divider().padding(.leading, 52)
            DetailRow(icon: "mappin.and.ellipse", title: "Location",
                      value: "\(profile.city), \(profile.state), \(profile.country)")
            Divider().padding(.leading, 52)
            DetailRow(icon: "calendar", title: "Member since",
                      value: profile.registeredDate.formatted(date: .abbreviated, time: .omitted))
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(16)
    }
}
