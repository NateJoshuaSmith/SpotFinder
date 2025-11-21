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
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("SpotFinder")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding()
            Text("Sign in")
                .fontWeight(.bold)
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Text("Password")
                .fontWeight(.bold)
            TextField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button("Login") {
                Task {
                    await viewModel.login(email: email, password: password)
                }
            }
            .padding()
            NavigationLink("Go to Map") {
                MapScreen()
            }
        }
    }
}

#Preview {
    Login()
}
