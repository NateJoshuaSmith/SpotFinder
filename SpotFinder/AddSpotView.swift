//
//  AddSpotView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var spotService: SpotService
    
    let latitude: Double
    let longitude: Double
    
    @State private var spotName: String = ""
    @State private var spotComment: String = ""
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Spot Name", text: $spotName)
                            .textFieldStyle(.plain)
                    } header: {
                        Text("Spot Information")
                            .font(.headline)
                    }
                    
                    Section {
                        ZStack(alignment: .topLeading) {
                            if spotComment.isEmpty {
                                Text("Add a comment about this spot...")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $spotComment)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Description")
                            .font(.headline)
                    }
                    
                    Section {
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
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(
                            Group {
                                if spotName.isEmpty || isSaving {
                                    Color.gray.opacity(0.3)
                                } else {
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .disabled(spotName.isEmpty || isSaving)
                    }
                }
            }
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
        do {
            try await spotService.addSpot(
                name: spotName,
                latitude: latitude,
                longitude: longitude,
                comment: spotComment.isEmpty ? "No comment" : spotComment
            )
            dismiss()
        } catch {
            print("Error saving spot: \(error)")
            isSaving = false
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

