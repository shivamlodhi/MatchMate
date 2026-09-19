//
//  MatchListView.swift
//  MatchMate
//
//  The main screen: a scrollable list of match cards with real pagination,
//  an offline banner, and loading / error / empty states.
//

import SwiftUI

struct MatchListView: View {
    @State private var viewModel: MatchListViewModel

    init(viewModel: MatchListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Profile Matches")
                .navigationDestination(for: MatchProfile.self) { profile in
                    MatchDetailView(viewModel: viewModel.makeDetailViewModel(for: profile))
                }
        }
        .task {
            await viewModel.onAppear()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView("Finding matches…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.loadFirstPage() }
            }

        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        ScrollView {
            if let banner = viewModel.banner {
                OfflineBanner(message: banner)
            }

            LazyVStack(spacing: 16) {
                ForEach(viewModel.profiles) { profile in
                    NavigationLink(value: profile) {
                        MatchCardView(
                            profile: profile,
                            onAccept: { viewModel.accept(profile) },
                            onDecline: { viewModel.decline(profile) }
                        )
                    }
                    .buttonStyle(.plain)
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: profile)
                    }
                }

                if viewModel.isLoadingNextPage {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// Small inline banner shown above the list when serving cached data offline.
struct OfflineBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(message)
                .font(.footnote)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Full-screen error with a retry affordance.
struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
