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
    @StateObject private var commentService = CommentService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    
    // Check if current user owns this spot
    private var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return spot.createdBy == currentUserId
    }
    
    var body: some View {
        NavigationView {
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
                            
                            // Description Card
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Description", systemImage: "text.bubble.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(spot.comment)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            
                            // Created Date & Creator Card
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Added", systemImage: "calendar")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(spot.createdAt, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let username = spot.createdByUsername, !username.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                        Text("by @\(username)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            
                            // Comments Section
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Comments", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                // Add comment
                                HStack(alignment: .bottom, spacing: 8) {
                                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(10)
                                        .lineLimit(1...4)
                                    
                                    Button(action: { Task { await postComment() } }) {
                                        if isPostingComment {
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(0.9)
                                        } else {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.circle.fill")
                                                    .font(.title3)
                                                Text("Post")
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
                                    .opacity(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                                }
                                
                                // Comment list
                                ForEach(commentService.comments) { comment in
                                    CommentRowView(
                                        comment: comment,
                                        spotId: spot.id ?? "",
                                        commentService: commentService
                                    )
                                }
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
                if let spotId = spot.id {
                    commentService.listenToComments(spotId: spotId)
                }
            }
            .onDisappear {
                commentService.stopListening()
            }
        }
    }
    
    private func postComment() async {
        guard let spotId = spot.id else { return }
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isPostingComment = true
        defer { isPostingComment = false }
        
        do {
            try await commentService.addComment(spotId: spotId, text: text)
            newCommentText = ""
        } catch {
            errorMessage = "Failed to post comment: \(error.localizedDescription)"
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

// MARK: - Comment Row
private struct CommentRowView: View {
    let comment: SpotComment
    let spotId: String
    @ObservedObject var commentService: CommentService
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let username = comment.createdByUsername, !username.isEmpty {
                        Text("@\(username)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    } else {
                        Text("Anonymous")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(comment.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Like / Dislike buttons
                HStack(spacing: 12) {
                    Button(action: { Task { try? await commentService.toggleLike(spotId: spotId, comment: comment) } }) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.hasLiked(userId: currentUserId ?? "") ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .foregroundColor(comment.hasLiked(userId: currentUserId ?? "") ? .blue : .secondary)
                            Text("\(comment.likeCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { Task { try? await commentService.toggleDislike(spotId: spotId, comment: comment) } }) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.hasDisliked(userId: currentUserId ?? "") ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .foregroundColor(comment.hasDisliked(userId: currentUserId ?? "") ? .red : .secondary)
                            Text("\(comment.dislikeCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(comment.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    SpotDetailView(
        spot: SkateSpot(
            name: "Test Spot",
            latitude: 37.7749,
            longitude: -122.4194,
            comment: "This is a great spot for skateboarding!",
            createdBy: "user123",
            createdByUsername: "skater_pro"
        ),
        spotService: SpotService()
    )
}

