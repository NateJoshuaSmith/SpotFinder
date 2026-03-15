//
//  FavoritesListView.swift
//  SpotFinder
//
//  List of the current user's favorited spots.
//

import SwiftUI
import FirebaseAuth

struct FavoritesListView: View {
    @StateObject private var spotService = SpotService()
    @StateObject private var userService = UserService()
    @State private var favoriteSpots: [SkateSpot] = []
    @State private var isLoading = true
    @State private var selectedSpot: SkateSpot?
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }
    
    var body: some View {
        Group {
            if !isLoggedIn {
                ContentUnavailableView(
                    "Sign in to see favorites",
                    systemImage: "heart.slash",
                    description: Text("Log in to save spots to your favorites list.")
                )
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading favorites...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favoriteSpots.isEmpty {
                ContentUnavailableView(
                    "No favorites yet",
                    systemImage: "heart",
                    description: Text("Tap the heart on a spot to add it here.")
                )
            } else {
                List {
                    ForEach(favoriteSpots) { spot in
                        Button(action: { selectedSpot = spot }) {
                            HStack(spacing: 12) {
                                if let urlString = spot.imageURL ?? spot.imageURLs?.first,
                                   let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            Rectangle()
                                                .fill(Color(.systemGray5))
                                        }
                                    }
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.secondary)
                                        )
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(spot.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let username = spot.createdByUsername, !username.isEmpty {
                                        Text("by @\(username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFavorites()
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot, spotService: spotService)
                .onDisappear {
                    Task { await loadFavorites() }
                }
        }
    }
    
    private func loadFavorites() async {
        guard isLoggedIn else {
            isLoading = false
            return
        }
        isLoading = true
        await userService.loadFavorites()
        let ids = userService.favoriteSpotIds
        let spots = await spotService.fetchSpots(ids: ids)
        await MainActor.run {
            favoriteSpots = spots
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesListView()
    }
}
