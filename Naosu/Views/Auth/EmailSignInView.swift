import SwiftUI

struct EmailSignInView: View {
    @State private var isSignUp = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var authManager = LocalAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.naosuBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Mode toggle
                        Picker("Mode", selection: $isSignUp) {
                            Text("Create Account").tag(true)
                            Text("Sign In").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: isSignUp) { _, _ in
                            errorMessage = ""
                        }

                        // Fields
                        VStack(spacing: 16) {
                            if isSignUp {
                                inputField(
                                    label: "Name",
                                    placeholder: "Your name",
                                    text: $name,
                                    contentType: .name
                                )
                            }

                            inputField(
                                label: "Email",
                                placeholder: "email@example.com",
                                text: $email,
                                contentType: .emailAddress,
                                keyboard: .emailAddress
                            )

                            secureField(
                                label: "Password",
                                placeholder: "••••••••",
                                text: $password,
                                contentType: isSignUp ? .newPassword : .password
                            )

                            if isSignUp {
                                secureField(
                                    label: "Confirm password",
                                    placeholder: "••••••••",
                                    text: $confirmPassword,
                                    contentType: .newPassword
                                )
                            }
                        }

                        // Error banner
                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text(errorMessage)
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.red.opacity(0.25), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Submit button
                        Button(action: submit) {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .background(Color.naosuAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isLoading)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.naosuTextSecondary)
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth { dismiss() }
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        errorMessage = ""

        // Client-side validation
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all required fields."
            return
        }
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        if isSignUp {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Please enter your name."
                return
            }
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
        }

        isLoading = true
        // Run on a Task so we don't block the main thread during hash
        Task { @MainActor in
            do {
                if isSignUp {
                    try LocalAuthManager.shared.signUp(name: name, email: email, password: password)
                } else {
                    try LocalAuthManager.shared.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Field builders

    @ViewBuilder
    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.naosuTextSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.naosuSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.naosuBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    @ViewBuilder
    private func secureField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.naosuTextSecondary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.naosuSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.naosuBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .textContentType(contentType)
        }
    }
}
