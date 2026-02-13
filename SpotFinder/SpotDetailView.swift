//
//  SpotDetailView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseAuth

struct SpotDetailView: View {
    let spot: SkateSpot
    @ObservedObject var spotService: SpotService
    @Environment(\.dismiss) var dismiss
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var isLoading = true
    
    // Check if current user owns this spot
    private var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return spot.createdBy == currentUserId
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading spot details...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Spot Name Card
                            VStack(alignment: .leading, spacing: 8) {
                                Text(spot.name)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Comments Card
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Description", systemImage: "text.bubble.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(spot.comment)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            
                            // Created Date Card
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Added", systemImage: "calendar")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(spot.createdAt, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            
                            // Delete Button (only show if user owns the spot)
                            if isOwner {
                                Button(action: {
                                    showDeleteAlert = true
                                }) {
                                    HStack {
                                        Spacer()
                                        if isDeleting {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "trash.fill")
                                        }
                                        Text(isDeleting ? "Deleting..." : "Delete Spot")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.red)
                                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                                    )
                                }
                                .disabled(isDeleting)
                                .padding(.horizontal)
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Spot Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Spot?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSpot()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(spot.name)\"? This action cannot be undone.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                // Simulate a brief loading time for better UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isLoading = false
                }
            }
        }
    }
    
    private func deleteSpot() async {
        isDeleting = true
        
        do {
            try await spotService.deleteSpot(spot)
            dismiss()  // Close view after successful deletion
        } catch {
            errorMessage = "Failed to delete spot: \(error.localizedDescription)"
            isDeleting = false
        }
    }
}

#Preview {
    SpotDetailView(
        spot: SkateSpot(
            name: "Test Spot",
            latitude: 37.7749,
            longitude: -122.4194,
            comment: "This is a great spot for skateboarding!",
            createdBy: "user123"
        ),
        spotService: SpotService()
    )
}

