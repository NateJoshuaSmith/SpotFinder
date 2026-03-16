//
//  Login.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI

struct Login: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var showContactSupport = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 0)
                    
                    // Logo + Login Card blended into one surface
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            ZStack {
                                // Outer black outline (slightly smaller than Home)
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                                    .frame(width: 172, height: 172)
                                
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
                                    .frame(width: 162, height: 162)
                                
                                // Logo image inside the rings, slightly shrunk
                                Image("BrokenBoard")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 154, height: 154)
                                    .clipShape(Circle())
                            }
                            
                            Text("SpotFinder")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Discover and share skate spots")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        Text("Sign In")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        // Login Button
                        Button(action: {
                            Task {
                                isLoggingIn = true
                                await viewModel.login(email: email, password: password)
                                isLoggingIn = false
                            }
                        }) {
                            HStack {
                                Spacer()
                                if isLoggingIn {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.headline)
                                }
                                Text(isLoggingIn ? "Signing in..." : "Sign In")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
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
                        .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
                        
                        // Sign Up Link
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            NavigationLink("Sign Up") {
                                SignUp()
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(.top, 8)

                        // Contact Support
                        Button {
                            showContactSupport = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.caption)
                                Text("Contact Support")
                            }
                            .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showContactSupport) {
            NavigationStack {
                ContactSupportView()
            }
        }
    }
}
#Preview {
    NavigationView {
        Login()
            .environmentObject(LoginViewModel())
    }
}