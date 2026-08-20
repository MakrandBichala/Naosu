import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct HealthIntakeView: View {
    // State
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    @State private var showGenerating = false

    @Query private var profiles: [UserProfile]
    @Query private var journeyPlans: [JourneyPlan]

    // Step 1 - Basic Info
    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var sex = "Male"
    @State private var selectedGoal = ""

    // Step 2 - Injuries
    @State private var hasInjury = false
    @State private var selectedInjuries: Set<String> = []
    @State private var customInjuries: [String] = []
    @State private var showCustomInjuryField = false
    @State private var customInjuryText = ""
    @State private var injuryDescription = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var documentData: Data?
    @State private var documentFileName: String?
    @State private var showDocumentPicker = false

    // Step 3 - Situation
    @State private var trainingLocation = ""
    @State private var daysPerWeek = 4
    @State private var fitnessLevel = ""
    @State private var additionalNotes = ""

    // Generation
    @State private var generationStep = 0
    @State private var errorMessage: String?
    @State private var generationComplete = false

    let presetInjuries = ["Knee", "Lower Back", "Shoulder", "Ankle", "Wrist", "Hip", "Neck", "Elbow"]

    let goals: [(id: String, title: String, subtitle: String)] = [
        ("rehab", "Recover from injury", "Rehab first, then build back"),
        ("muscle", "Build muscle & strength", "Progressive overload"),
        ("weight_loss", "Lose weight & get fit", "Cardio + strength"),
        ("general", "General fitness", "Stay active and healthy")
    ]

    let locations: [(id: String, title: String, subtitle: String)] = [
        ("gym", "Gym access", "Full equipment available"),
        ("home", "Home only", "Bodyweight & minimal equipment"),
        ("outdoors", "Outdoors", "Parks, running, bodyweight")
    ]

    var body: some View {
        if showGenerating {
            generatingScreen
        } else {
            VStack(spacing: 0) {
                stepIndicator

                TabView(selection: $currentStep) {
                    basicInfoStep.tag(0)
                    injuryStep.tag(1)
                    situationStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.naosuBackground)
            .onAppear {
                print("DEBUG profiles count: \(profiles.count)")
                print("DEBUG journeyPlans count: \(journeyPlans.count)")
                print("DEBUG userId: \(LocalAuthManager.shared.userId)")
                // If data already exists, skip intake entirely
                let hasProfile = profiles.contains { $0.userId == LocalAuthManager.shared.userId }
                let hasPlan = journeyPlans.contains { $0.userId == LocalAuthManager.shared.userId }
                if hasProfile && hasPlan {
                    hasCompletedOnboarding = true
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<3) { index in
                if index < currentStep {
                    // Completed
                    Circle()
                        .fill(Color.naosuAccent)
                        .frame(width: 10, height: 10)
                } else if index == currentStep {
                    // Active
                    ZStack {
                        Circle()
                            .stroke(Color.naosuAccent, lineWidth: 2)
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(Color.naosuAccent)
                            .frame(width: 10, height: 10)
                    }
                } else {
                    // Pending
                    Circle()
                        .fill(Color.naosuBorder)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Step 1: Basic Info

    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Tell us about yourself")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.naosuTextPrimary)

                    Text("This helps Naosu create the right plan for you.")
                        .font(.subheadline)
                        .foregroundStyle(Color.naosuTextSecondary)
                }

                themedTextField(label: "Name", text: $name, placeholder: "Your name")
                themedTextField(label: "Age", text: $age, placeholder: "e.g. 25", keyboard: .numberPad)
                themedTextField(label: "Weight (kg)", text: $weight, placeholder: "e.g. 70", keyboard: .decimalPad)
                themedTextField(label: "Height (cm)", text: $height, placeholder: "e.g. 170", keyboard: .numberPad)

                // Sex picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sex")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.naosuTextSecondary)

                    Picker("Sex", selection: $sex) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                    .pickerStyle(.segmented)
                }

                // Goal selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's your goal?")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.naosuTextSecondary)

                    ForEach(goals, id: \.id) { goal in
                        Button {
                            selectedGoal = goal.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.naosuTextPrimary)
                                    Text(goal.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.naosuTextSecondary)
                                }
                                Spacer()
                                if selectedGoal == goal.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.naosuAccent)
                                }
                            }
                            .padding(14)
                            .background(
                                selectedGoal == goal.id
                                    ? Color.naosuAccent.opacity(0.1)
                                    : Color.naosuSurface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        selectedGoal == goal.id
                                            ? Color.naosuAccent
                                            : Color.naosuBorder,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Next button
                Button {
                    withAnimation { currentStep = 1 }
                } label: {
                    Text("Next \u{2192}")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            step1Valid
                                ? Color.naosuAccent
                                : Color.naosuAccent.opacity(0.4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!step1Valid)
            }
            .padding(24)
        }
    }

    private var step1Valid: Bool {
        !name.isEmpty && !age.isEmpty && !weight.isEmpty && !height.isEmpty && !selectedGoal.isEmpty
    }

    // MARK: - Step 2: Injuries

    private var injuryStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Any injuries or limitations?")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.naosuTextPrimary)

                    Text("We'll avoid exercises that could aggravate existing conditions.")
                        .font(.subheadline)
                        .foregroundStyle(Color.naosuTextSecondary)
                        .multilineTextAlignment(.center)
                }

                // Yes / No buttons
                HStack(spacing: 12) {
                    Button {
                        hasInjury = true
                    } label: {
                        Text("Yes")
                            .fontWeight(.semibold)
                            .foregroundStyle(hasInjury ? .white : Color.naosuTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(hasInjury ? Color.naosuAccent : Color.naosuSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(hasInjury ? Color.clear : Color.naosuBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        hasInjury = false
                    } label: {
                        Text("No")
                            .fontWeight(.semibold)
                            .foregroundStyle(!hasInjury ? .white : Color.naosuTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(!hasInjury ? Color.naosuAccent : Color.naosuSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(!hasInjury ? Color.clear : Color.naosuBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if hasInjury {
                    // Affected areas
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select affected areas")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(Color.naosuTextSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(presetInjuries, id: \.self) { injury in
                                injuryTag(injury)
                            }
                            ForEach(customInjuries, id: \.self) { injury in
                                injuryTag(injury)
                            }
                        }

                        // Add custom injury
                        if showCustomInjuryField {
                            HStack(spacing: 8) {
                                TextField("e.g. Rotator cuff", text: $customInjuryText)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color.naosuSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.naosuBorder, lineWidth: 1)
                                    )

                                Button {
                                    let trimmed = customInjuryText.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        customInjuries.append(trimmed)
                                        selectedInjuries.insert(trimmed)
                                        customInjuryText = ""
                                        showCustomInjuryField = false
                                    }
                                } label: {
                                    Text("Add")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.naosuAccent)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Button {
                                showCustomInjuryField = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Add your own")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.naosuBorder)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.naosuBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Injury description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Describe your injury")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(Color.naosuTextSecondary)

                        TextField("e.g. Torn ACL 3 months ago, still in rehab...", text: $injuryDescription, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color.naosuSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.naosuBorder, lineWidth: 1)
                            )
                    }

                    // Upload section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upload medical documents (optional)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(Color.naosuTextSecondary)

                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo")
                                    Text("Photo")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.naosuTextPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.naosuSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.naosuBorder, lineWidth: 1)
                                )
                            }

                            Button {
                                showDocumentPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc")
                                    Text("Document")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.naosuTextPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.naosuSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.naosuBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let fileName = documentFileName {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(Color.naosuAccent)
                                Text(fileName)
                                    .font(.caption)
                                    .foregroundStyle(Color.naosuTextSecondary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    documentData = nil
                                    documentFileName = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.naosuTextTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color.naosuSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Skip button
                if !hasInjury {
                    Button {
                        hasInjury = false
                        withAnimation { currentStep = 2 }
                    } label: {
                        Text("I have no injuries, skip \u{2192}")
                            .font(.subheadline)
                            .foregroundStyle(Color.naosuTextTertiary)
                    }
                    .buttonStyle(.plain)
                }

                // Next button
                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("Next \u{2192}")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
        .onChange(of: selectedPhotoItem) {
            Task {
                if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self) {
                    documentData = data
                    documentFileName = "Photo attachment"
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { data, fileName in
                documentData = data
                documentFileName = fileName
            }
        }
    }

    private func injuryTag(_ injury: String) -> some View {
        let isSelected = selectedInjuries.contains(injury)
        return Button {
            if isSelected {
                selectedInjuries.remove(injury)
            } else {
                selectedInjuries.insert(injury)
            }
        } label: {
            Text(injury)
                .font(.subheadline)
                .foregroundStyle(isSelected ? Color.naosuAccent : Color.naosuTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color.naosuAccent.opacity(0.15)
                        : Color.naosuSurface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.naosuAccent : Color.naosuBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Situation

    private var situationStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Your training setup")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.naosuTextPrimary)

                    Text("Help us tailor exercises to your environment.")
                        .font(.subheadline)
                        .foregroundStyle(Color.naosuTextSecondary)
                }

                // Location cards
                VStack(alignment: .leading, spacing: 12) {
                    Text("Where will you train?")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.naosuTextSecondary)

                    ForEach(locations, id: \.id) { location in
                        Button {
                            trainingLocation = location.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(location.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.naosuTextPrimary)
                                    Text(location.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.naosuTextSecondary)
                                }
                                Spacer()
                                if trainingLocation == location.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.naosuAccent)
                                }
                            }
                            .padding(14)
                            .background(
                                trainingLocation == location.id
                                    ? Color.naosuAccent.opacity(0.1)
                                    : Color.naosuSurface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        trainingLocation == location.id
                                            ? Color.naosuAccent
                                            : Color.naosuBorder,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Days per week
                VStack(alignment: .leading, spacing: 12) {
                    Text("Days per week")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.naosuTextSecondary)

                    HStack(spacing: 10) {
                        ForEach(2...6, id: \.self) { day in
                            Button {
                                daysPerWeek = day
                            } label: {
                                Text("\(day)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(daysPerWeek == day ? .white : Color.naosuTextPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(daysPerWeek == day ? Color.naosuAccent : Color.naosuSurface)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                daysPerWeek == day ? Color.clear : Color.naosuBorder,
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Fitness level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fitness level")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.naosuTextSecondary)

                    HStack(spacing: 10) {
                        ForEach(["Beginner", "Intermediate", "Advanced"], id: \.self) { level in
                            Button {
                                fitnessLevel = level
                            } label: {
                                Text(level)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(fitnessLevel == level ? .white : Color.naosuTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(fitnessLevel == level ? Color.naosuAccent : Color.naosuSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                fitnessLevel == level ? Color.clear : Color.naosuBorder,
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Additional notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Additional notes")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.naosuTextSecondary)

                    TextField("e.g. doctor restrictions, pain levels, medications...", text: $additionalNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color.naosuSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.naosuBorder, lineWidth: 1)
                        )
                }

                // Build journey button
                Button {
                    Task {
                        await startGeneration()
                    }
                } label: {
                    Text("Build my journey \u{2192}")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            step3Valid
                                ? Color.naosuAccent
                                : Color.naosuAccent.opacity(0.4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!step3Valid)
            }
            .padding(24)
        }
    }

    private var step3Valid: Bool {
        !trainingLocation.isEmpty && !fitnessLevel.isEmpty
    }

    // MARK: - Generating Screen

    private var generatingScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.naosuAccent)

            VStack(spacing: 12) {
                Text("Building your journey")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.naosuTextPrimary)

                Text("Naosu is analysing your profile and creating a personalised plan from rehab to your goal.")
                    .font(.subheadline)
                    .foregroundStyle(Color.naosuTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Progress bar
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let progressFractions: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
                let targetWidth = generationStep < progressFractions.count
                    ? totalWidth * progressFractions[generationStep]
                    : totalWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.naosuBorder)
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.naosuAccent)
                        .frame(width: targetWidth, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: generationStep)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 40)

            // Step labels
            VStack(alignment: .leading, spacing: 16) {
                generationStepLabel(index: 0, text: "Analysing your injury & health profile")
                generationStepLabel(index: 1, text: "Mapping your recovery phases")
                generationStepLabel(index: 2, text: "Generating this week's exercises")
                generationStepLabel(index: 3, text: "Setting up your progress tracking")
            }
            .padding(.horizontal, 40)

            // Error state
            if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        Task {
                            await startGeneration()
                        }
                    } label: {
                        Text("Try again")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.naosuAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .background(Color.naosuBackground)
    }

    private func generationStepLabel(index: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: index <= generationStep ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(index <= generationStep ? Color.naosuAccent : Color.naosuBorder)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(index <= generationStep ? Color.naosuTextPrimary : Color.naosuTextTertiary)
        }
    }

    // MARK: - Generation Logic

    private func startGeneration() async {
        showGenerating = true
        errorMessage = nil
        generationStep = 0

        try? await Task.sleep(for: .seconds(0.8))
        withAnimation { generationStep = 1 }
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation { generationStep = 2 }

        let userId = AuthManager.shared.userId

        // Save UserProfile (joinedAt + progress cursors set here)
        let profile = UserProfile(
            userId: userId,
            name: name,
            age: Int(age) ?? 25,
            weight: Double(weight) ?? 70,
            height: Double(height) ?? 170,
            sex: sex,
            goal: selectedGoal,
            hasInjury: hasInjury,
            injuredAreas: Array(selectedInjuries) + customInjuries,
            injuryDescription: injuryDescription,
            injuryDocumentData: documentData,
            trainingLocation: trainingLocation,
            daysPerWeek: daysPerWeek,
            fitnessLevel: fitnessLevel,
            additionalNotes: additionalNotes,
            joinedAt: Date(),
            currentWeek: 1,
            currentDay: 1
        )
        modelContext.insert(profile)

        do {
            let response = try await APIClient.shared.generateJourney(profile: profile)

            withAnimation { generationStep = 3 }
            try? await Task.sleep(for: .seconds(0.5))

            // Persist journey roadmap structure
            let structure = JourneyStructure(
                userId: userId,
                totalWeeks: response.journeyStructure.totalWeeks,
                currentWeek: 1,
                currentDay: 1,
                phases: response.journeyStructure.phases
            )
            modelContext.insert(structure)

            // Persist Week 1 plan
            let week1 = response.week1Plan
            let plan = JourneyPlan(
                userId: userId,
                weekNumber: 1,
                phase: week1.phase,
                days: week1.days,
                isCurrentWeek: true,
                weekSummary: week1.weekSummary
            )
            modelContext.insert(plan)

            // Create DayProgress records for all 7 days of Week 1
            for day in week1.days {
                let planned = calculateTotalReps(day)
                let progress = DayProgress(
                    userId: userId,
                    weekNumber: 1,
                    dayNumber: day.dayNumber,
                    isCompleted: day.isRestDay,
                    isRestDay: day.isRestDay,
                    completionPercentage: day.isRestDay ? 1.0 : 0.0,
                    totalPlannedReps: planned,
                    totalCompletedReps: 0,
                    completedExerciseIds: (try? JSONEncoder().encode([String]())) ?? Data(),
                    sessionRecordId: nil,
                    completedAt: day.isRestDay ? Date() : nil
                )
                modelContext.insert(progress)
            }

            withAnimation { generationComplete = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Total planned reps across all exercises in a day (sets × reps).
    private func calculateTotalReps(_ day: DaySession) -> Int {
        day.sections
            .flatMap { $0.exercises }
            .reduce(0) { $0 + ($1.sets * max($1.reps, 1)) }
    }

    // MARK: - Helpers

    private func themedTextField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .bold()
                .foregroundStyle(Color.naosuTextSecondary)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.naosuSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.naosuBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (Data, String) -> Void

        init(onPick: @escaping (Data, String) -> Void) {
            self.onPick = onPick
        }

        nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            if let data = try? Data(contentsOf: url) {
                let fileName = url.lastPathComponent
                Task { @MainActor [onPick] in
                    onPick(data, fileName)
                }
            }
        }

        nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + rowHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    HealthIntakeView()
        .modelContainer(for: [
            UserProfile.self, JourneyPlan.self,
            JourneyStructure.self, DayProgress.self
        ], inMemory: true)
}
