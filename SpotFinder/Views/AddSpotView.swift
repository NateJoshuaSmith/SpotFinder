//
//  AddSpotView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import PhotosUI

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var spotService: SpotService
    
    let latitude: Double
    let longitude: Double
    
    @State private var spotName: String = ""
    @State private var spotComment: String = ""
    @State private var isSaving: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Spot photo (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Spot Photo")
                            .font(.headline)
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Group {
                                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 160)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 160)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.system(size: 36))
                                                    .foregroundColor(.secondary)
                                                Text("Add a photo of the spot")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        )
                                }
                            }
                            .cornerRadius(12)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                } else {
                                    selectedImageData = nil
                                }
                            }
                        }
                    }
                    
                    // Spot Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Spot Information")
                            .font(.headline)
                        TextField("Spot Name", text: $spotName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Description - TextField expands as you type, outer ScrollView handles all scrolling (no gesture conflict)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        TextField("Add a comment about this spot...", text: $spotComment, axis: .vertical)
                            .lineLimit(5...30)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Save Button
                    Button(action: {
                        Task {
                            await saveSpot()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                            }
                            Text(isSaving ? "Saving..." : "Save Spot")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    spotName.isEmpty || isSaving
                                        ? LinearGradient(
                                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                )
                        )
                    }
                    .disabled(spotName.isEmpty || isSaving)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func saveSpot() async {
        guard !spotName.isEmpty else { return }
        
        isSaving = true
        defer { isSaving = false }
        do {
            var imageURL: String?
            if let data = selectedImageData, !data.isEmpty {
                imageURL = try await spotService.uploadSpotImage(data: data)
            }
            try await spotService.addSpot(
                name: spotName,
                latitude: latitude,
                longitude: longitude,
                comment: spotComment.isEmpty ? "No comment" : spotComment,
                imageURL: imageURL
            )
            dismiss()
        } catch {
            print("Error saving spot: \(error)")
        }
    }
}

#Preview {
    AddSpotView(
        spotService: SpotService(),
        latitude: 37.7749,
        longitude: -122.4194
    )
}

