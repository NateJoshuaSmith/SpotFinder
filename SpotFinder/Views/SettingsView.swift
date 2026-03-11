//
//  SettingsView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var userEmail: String = ""
    @State private var showContactSupport = false
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.headline)
                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            } header: {
                Text("Account")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("App Name", systemImage: "app.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("SpotFinder")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
                    .font(.headline)
            }
            
            Section("Help & Support") {
                Button(action: {
                    showContactSupport = true
                }) {
                    Label("Contact Support", systemImage: "envelope.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            Section {
                Button(action: {
                    Task {
                        await viewModel.logout()
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.right.square.fill")
                        Text("Logout")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContactSupport) {
            NavigationStack {
                ContactSupportView()
            }
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                userEmail = user.email ?? "No email"
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(LoginViewModel())
    }
}

