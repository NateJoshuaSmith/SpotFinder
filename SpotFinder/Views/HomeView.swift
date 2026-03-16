//
//  HomeView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App Icon/Logo area
                VStack(spacing: 16) {
                    ZStack {
                        // Circular outline (2× bigger) with black stroke
                        Circle()
                            .stroke(Color.black, lineWidth: 4)
                            .frame(width: 192, height: 192)
                        
                        // Your logo image inside the circle, zoomed out a bit to avoid clipping
                        Image("BrokenBoard")
                            .resizable()
                            .scaledToFit()
                            // Slightly smaller than the outer circle to account for the stroke
                            .frame(width: 176, height: 176)
                            .clipShape(Circle())
                    }
                    
                    Text("Welcome to SpotFinder")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Discover and share the best skate spots")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Modern button
                NavigationLink(destination: MapScreen()) {
                    HStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.headline)
                        Text("Explore Map")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                
                NavigationLink(destination: FavoritesListView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.headline)
                        Text("My Favorites")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.pink.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .pink.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink(destination: FriendsListView()) {
                    Label("Friends", systemImage: "person.2.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Settings
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    
                    // Logout
                    Button(role: .destructive) {
                        Task {
                            await viewModel.logout()
                        }
                    } label: {
                        Label("Logout", systemImage: "arrow.right.square.fill")
                    }
                } label: {
                    avatarButtonContent
                }
            }
        }
        // Hidden NavigationLink driven by state so tapping menu item actually navigates
        .background(
            NavigationLink(
                destination: SettingsView(),
                isActive: $showSettings,
                label: { EmptyView() }
            )
            .hidden()
        )
    }
}

private extension HomeView {
    var avatarButtonContent: some View {
        Group {
            if let urlString = viewModel.avatarURL,
               let url = URL(string: urlString) {
                ZStack {
                    avatarPlaceholder
                    AsyncImage(
                        url: url,
                        transaction: Transaction(animation: .easeInOut)
                    ) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity)
                        case .empty:
                            Color.clear
                        case .failure:
                            avatarPlaceholder
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }
    
    var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.caption)
            )
    }
}

#Preview {
    NavigationView {
        HomeView()
            .environmentObject(LoginViewModel())
    }
}

