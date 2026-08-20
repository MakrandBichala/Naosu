import SwiftUI
import SwiftData
import QuickLook

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \SessionRecord.completedAt, order: .reverse) private var allRecords: [SessionRecord]
    @Query(filter: #Predicate<JourneyPlan> { $0.isCurrentWeek == true }) private var currentPlans: [JourneyPlan]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var showEditPersonal = false
    @State private var showEditGoal = false
    @State private var showEditInjury = false
    @State private var showChangePassword = false
    @State private var showEmailAuth = false
    @State private var emailAuthIsSignUp = true
    @State private var showSignOutAlert = false
    @State private var showDeleteAlert = false
    @State private var showImageViewer = false
    @State private var showPDFViewer = false
    @State private var pdfPreviewURL: URL? = nil

    var isGuest: Bool { LocalAuthManager.shared.userId.hasPrefix("guest_") }

    var displayName: String {
        if let name = profiles.first?.name, !name.isEmpty { return name }
        let n = LocalAuthManager.shared.userName
        return n.isEmpty ? "User" : n
    }

    var initials: String {
        let words = displayName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased().isEmpty ? "N" : letters.joined().uppercased()
    }

    var currentPhaseLabel: String {
        let uid = LocalAuthManager.shared.userId
        if let plan = currentPlans.first(where: { $0.userId == uid }), !plan.phase.isEmpty {
            return plan.phase
        }
        return "Getting started"
    }

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Manual title (navigation bar is hidden)
                    Text("Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.naosuTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    // Header
                    headerSection

                    // Guest upgrade banner
                    if isGuest {
                        guestBanner
                    }

                    // Personal info
                    VStack(spacing: 8) {
                        sectionHeader("PERSONAL INFO")
                        sectionCard {
                            profileRow(
                                label: "Full name",
                                value: profiles.first?.name.isEmpty == false ? profiles.first!.name : "Not set",
                                onEdit: { showEditPersonal = true }
                            )
                            if profiles.first != nil {
                                Divider().padding(.leading, 14)
                                let profile = profiles.first!
                                profileRow(
                                    label: "Age · Weight · Height",
                                    value: profile.age > 0
                                        ? "\(profile.age) yrs · \(String(format: "%.0f", profile.weight)) kg · \(String(format: "%.0f", profile.height)) cm"
                                        : "Not set",
                                    onEdit: { showEditPersonal = true }
                                )
                                Divider().padding(.leading, 14)
                                profileRow(
                                    label: "Biological sex",
                                    value: profile.sex.isEmpty ? "Not set" : profile.sex,
                                    onEdit: { showEditPersonal = true }
                                )
                            } else {
                                Divider().padding(.leading, 14)
                                profileRow(label: "Age · Weight · Height", value: "Not set", onEdit: { showEditPersonal = true })
                                Divider().padding(.leading, 14)
                                profileRow(label: "Biological sex", value: "Not set", onEdit: { showEditPersonal = true })
                            }
                        }
                    }

                    // Goal & fitness
                    VStack(spacing: 8) {
                        sectionHeader("GOAL & FITNESS")
                        sectionCard {
                            if let profile = profiles.first {
                                profileRow(
                                    label: "Goal",
                                    value: profile.goal.isEmpty ? "Not set" : profile.goal,
                                    onEdit: { showEditGoal = true }
                                )
                                Divider().padding(.leading, 14)
                                profileRow(
                                    label: "Fitness level",
                                    value: profile.fitnessLevel.isEmpty ? "Not set" : profile.fitnessLevel,
                                    onEdit: { showEditGoal = true }
                                )
                                Divider().padding(.leading, 14)
                                profileRow(
                                    label: "Location · Days/week",
                                    value: profile.trainingLocation.isEmpty ? "Not set" : "\(profile.trainingLocation) · \(profile.daysPerWeek) days",
                                    onEdit: { showEditGoal = true }
                                )
                            } else {
                                profileRow(label: "Goal", value: "Not set", onEdit: { showEditGoal = true })
                                Divider().padding(.leading, 14)
                                profileRow(label: "Fitness level", value: "Not set", onEdit: { showEditGoal = true })
                                Divider().padding(.leading, 14)
                                profileRow(label: "Location · Days/week", value: "Not set", onEdit: { showEditGoal = true })
                            }
                        }
                    }

                    // Injuries
                    VStack(spacing: 8) {
                        sectionHeader("INJURIES")
                        sectionCard {
                            if let profile = profiles.first, profile.hasInjury {
                                // Injury tags
                                HStack {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(profile.injuredAreas, id: \.self) { area in
                                                Text(area)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(Color.naosuAccent)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color.naosuAccentLight)
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(Color.naosuAccent.opacity(0.5), lineWidth: 1))
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 14)
                                    }
                                }
                                if !profile.injuryDescription.isEmpty {
                                    Divider().padding(.leading, 14)
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Description")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.naosuTextTertiary)
                                            Text(profile.injuryDescription)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.naosuTextPrimary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                }
                                if profile.injuryDocumentData != nil {
                                    Divider().padding(.leading, 14)
                                    Button {
                                        openDocument(profile.injuryDocumentData)
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.fill")
                                                .foregroundStyle(Color.naosuAccent)
                                            Text("Diagnosis document attached")
                                                .font(.caption)
                                                .foregroundStyle(.naosuTextSecondary)
                                            Spacer()
                                            Text("View")
                                                .font(.caption)
                                                .foregroundStyle(Color.naosuAccent)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                HStack {
                                    Text("No injuries reported")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.naosuTextSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                            }
                            Divider().padding(.leading, 14)
                            Button {
                                showEditInjury = true
                            } label: {
                                HStack {
                                    Text("Edit injury info")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.naosuAccent)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.naosuAccent)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                            }
                        }
                    }

                    // Account
                    VStack(spacing: 8) {
                        sectionHeader("ACCOUNT")
                        sectionCard {
                            if !isGuest {
                                // Email display
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Email")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.naosuTextTertiary)
                                        Text(LocalAuthManager.shared.userEmail.isEmpty ? "Not set" : LocalAuthManager.shared.userEmail)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.naosuTextPrimary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)

                                Divider().padding(.leading, 14)

                                // Change password
                                Button {
                                    showChangePassword = true
                                } label: {
                                    HStack {
                                        Text("Change password")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.naosuTextPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.naosuTextTertiary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                }

                                Divider().padding(.leading, 14)

                                // Sign out
                                Button {
                                    showSignOutAlert = true
                                } label: {
                                    HStack {
                                        Text("Sign out")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.red)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                }

                                Divider().padding(.leading, 14)

                                // Delete account
                                Button {
                                    showDeleteAlert = true
                                } label: {
                                    HStack {
                                        Text("Delete account")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.red)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                }
                            } else {
                                // Guest: sign out only
                                Button {
                                    showSignOutAlert = true
                                } label: {
                                    HStack {
                                        Text("Sign out")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.red)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Sign out of Naosu?", isPresented: $showSignOutAlert) {
            Button("Sign out", role: .destructive) {
                LocalAuthManager.shared.signOut()
                hasCompletedOnboarding = false
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Delete permanently", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all data.")
        }
        .sheet(isPresented: $showEditPersonal) { EditPersonalInfoView() }
        .sheet(isPresented: $showEditGoal) { EditGoalView() }
        .sheet(isPresented: $showEditInjury) { EditInjuryView() }
        .sheet(isPresented: $showChangePassword) { ChangePasswordView() }
        .sheet(isPresented: $showEmailAuth) {
            EmailSignInView()
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            let data = profiles.first?.injuryDocumentData
            let uiImage = data.flatMap { UIImage(data: $0) }
            InjuryImageViewer(image: uiImage) { showImageViewer = false }
        }
        .sheet(isPresented: $showPDFViewer, onDismiss: {
            if let url = pdfPreviewURL {
                try? FileManager.default.removeItem(at: url)
                pdfPreviewURL = nil
            }
        }) {
            if let url = pdfPreviewURL {
                QuickLookPreview(url: url)
            }
        }
    }

    // MARK: - Document viewing

    private func openDocument(_ data: Data?) {
        guard let data else { return }
        if InjuryDocumentType.isPDF(data) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("injury_\(UUID().uuidString).pdf")
            do {
                try data.write(to: tmp)
                pdfPreviewURL = tmp
                showPDFViewer = true
            } catch {
                return
            }
        } else {
            showImageViewer = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            // Avatar square
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.naosuAccentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.naosuAccent, lineWidth: 1.5)
                    )
                    .frame(width: 60, height: 60)
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.naosuAccent)
            }

            // Name + badge
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.naosuTextPrimary)

                Text(isGuest ? "Guest account" : currentPhaseLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.naosuAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.naosuAccentLight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.naosuAccent, lineWidth: 1)
                    )
            }
            Spacer()
        }
        .padding(.bottom, 16)
    }

    // MARK: - Guest Banner

    private var guestBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save your progress")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.naosuAccent)
            Text("Create a free account to save your workout history, progress, and personalized plan across devices.")
                .font(.system(size: 11))
                .foregroundStyle(.naosuTextSecondary)
                .lineSpacing(2)

            VStack(spacing: 6) {
                Button {
                    emailAuthIsSignUp = true
                    showEmailAuth = true
                } label: {
                    Text("Create account")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    emailAuthIsSignUp = false
                    showEmailAuth = true
                } label: {
                    Text("Sign in to existing account")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.naosuAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.naosuSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.naosuAccent, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.naosuAccentLight)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.naosuAccent, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Delete Account

    private func deleteAccount() {
        let uid = LocalAuthManager.shared.userId
        let records = allRecords.filter { $0.userId == uid }
        records.forEach { modelContext.delete($0) }
        profiles.forEach { modelContext.delete($0) }
        LocalAuthManager.shared.signOut()
        hasCompletedOnboarding = false
    }

    // MARK: - Helpers

    private func profileRow(label: String, value: String, onEdit: @escaping () -> Void) -> some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(.naosuTextTertiary)
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.naosuTextPrimary)
                }
                Spacer()
                Text("Edit")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.naosuAccent)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .background(Color.naosuSurface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.naosuBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(.naosuTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }
}

// MARK: - Fullscreen image viewer

private struct InjuryImageViewer: View {
    let image: UIImage?
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                Text("Unable to load image")
                    .foregroundStyle(.white)
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - QuickLook PDF preview

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
