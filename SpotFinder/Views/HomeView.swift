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
    @State private var cardOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background image behind the white sheet
            Image("HomeBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Dark overlay so the illustration stays visible but doesn't compete with the card
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Square stylized card: vertically centered and draggable up/down
                VStack(spacing: 24) {
                    // App Icon/Logo area
                    VStack(spacing: 16) {
                        Image("SpotfinderLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 126)
                            .padding(.top, -92)
                        
                        ZStack {
                            // Outer black outline
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                                .frame(width: 192, height: 192)
                            
                            // Inner purple/blue ring just inside the black outline
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 5
                                )
                                .frame(width: 180, height: 180)
                            
                            // Your logo image inside the circle, zoomed out a bit to avoid clipping
                            Image("GrassRamp")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 172, height: 172)
                                .clipShape(Circle())
                        }
                        .padding(.top, -24)
                        
                        Text("Welcome to Spotfinder")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Discover and share skate spots")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Explore Map button
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black, lineWidth: 3)
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    // Community button
                    NavigationLink(destination: FriendsListView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.headline)
                            Text("Community")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange.opacity(0.9), .red.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black, lineWidth: 3)
                        )
                        .cornerRadius(16)
                        .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    // Favorites button
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black, lineWidth: 3)
                        )
                        .cornerRadius(16)
                        .shadow(color: .pink.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 112)
                .padding(.bottom, 96)
                .frame(maxWidth: 355)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    Color.white.opacity(0.90)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.purple.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.black, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
                )
                // Shift card left (more trailing padding) and up slightly
                .padding(.leading, 18)
                .padding(.trailing, 30)
                .padding(.top, -44)
                .offset(y: cardOffset + dragTranslation)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Live drag offset, limited so it doesn't go too far
                            dragTranslation = value.translation.height
                        }
                        .onEnded { value in
                            // Add a bit of "settling" motion, lightly clamped
                            let proposed = cardOffset + value.translation.height * 0.4
                            cardOffset = max(-40, min(40, proposed))
                            dragTranslation = 0
                        }
                )
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink(destination: FriendsListView()) {
                    Label("Friends", systemImage: "person.2.fill")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(Color(.systemGray5))
                                Capsule().strokeBorder(Color.black, lineWidth: 3)
                            }
                        )
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Home")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.systemGray5)))
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
        .frame(width: 32, height: 32)
        .background(
            Circle().fill(Color(.systemGray5))
        )
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

