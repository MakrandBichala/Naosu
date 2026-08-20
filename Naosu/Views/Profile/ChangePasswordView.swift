import SwiftUI
import CryptoKit

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.naosuBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            secureFieldView(label: "Current password", placeholder: "••••••••", text: $currentPassword)
                            secureFieldView(label: "New password", placeholder: "••••••••", text: $newPassword)
                            secureFieldView(label: "Confirm new password", placeholder: "••••••••", text: $confirmPassword)
                        }
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        if !successMessage.isEmpty {
                            Text(successMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.green.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button(action: save) {
                            Text(isLoading ? "Saving..." : "Change password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.naosuAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.naosuTextSecondary)
                }
            }
        }
    }

    private func save() {
        errorMessage = ""
        successMessage = ""
        guard !currentPassword.isEmpty else { errorMessage = "Enter your current password."; return }
        guard newPassword.count >= 6 else { errorMessage = "New password must be at least 6 characters."; return }
        guard newPassword == confirmPassword else { errorMessage = "Passwords do not match."; return }

        let email = LocalAuthManager.shared.userEmail.lowercased()
        let key = "user_\(email)"
        guard let stored = UserDefaults.standard.string(forKey: key) else {
            errorMessage = "Account not found."
            return
        }
        let currentHash = hashPassword(currentPassword)
        guard stored == currentHash else { errorMessage = "Current password is incorrect."; return }

        UserDefaults.standard.set(hashPassword(newPassword), forKey: key)
        successMessage = "Password changed successfully."
        isLoading = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    @ViewBuilder
    private func secureFieldView(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.bold()).foregroundStyle(.naosuTextSecondary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.naosuSurface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.naosuBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
