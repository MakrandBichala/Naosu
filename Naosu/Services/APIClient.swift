import Foundation

actor APIClient {
    static let shared = APIClient()

    private static let baseURL = "https://naosu-backend-production.up.railway.app"
    private var authToken: String = "dev-bypass"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - Journey Generation

    func generateJourney(profile: UserProfile) async throws -> FullJourneyAPIResponse {
        let requestBody = GenerateJourneyRequest(
            name: profile.name,
            age: profile.age,
            weight: profile.weight,
            height: profile.height,
            sex: profile.sex,
            goal: profile.goal,
            hasInjury: profile.hasInjury,
            injuredAreas: profile.injuredAreas,
            injuryDescription: profile.injuryDescription,
            trainingLocation: profile.trainingLocation,
            daysPerWeek: profile.daysPerWeek,
            fitnessLevel: profile.fitnessLevel,
            additionalNotes: profile.additionalNotes
        )

        let data = try await postRaw(path: "/generate-journey", body: requestBody)
        let rawString = String(data: data, encoding: .utf8) ?? ""
        print("[Naosu] RAW /generate-journey:\n\(rawString)")

        let cleanedData = extractJSON(rawString).data(using: .utf8) ?? data

        do {
            let lenient = try JSONDecoder().decode(LenientJourneyAPIResponse.self, from: cleanedData)

            guard let week1Plan = lenient.week1Plan else {
                throw APIError.serverError(
                    statusCode: 502,
                    message: "Week 1 plan was missing from the AI response. Please try again."
                )
            }

            let structure = lenient.journeyStructure ?? JourneyStructureResponse(
                totalWeeks: 12,
                phases: [JourneyPhase(
                    id: "phase1", name: "Phase 1: Foundation",
                    startWeek: 1, endWeek: 12,
                    goal: "Build toward your goal",
                    weeklyFocus: Array(repeating: "Progressive training", count: 12),
                    isCompleted: false, isCurrent: true
                )]
            )

            return FullJourneyAPIResponse(journeyStructure: structure, week1Plan: week1Plan)

        } catch let decodeError {
            print("[Naosu] Decode error: \(decodeError)")
            throw APIError.serverError(
                statusCode: 502,
                message: "Failed to decode journey response: \(decodeError.localizedDescription)"
            )
        }
    }

    func generateNextWeek(
        weekNumber: Int,
        currentPhase: String,
        phaseGoal: String,
        weeklyFocus: String,
        avgFormScore: Double,
        totalReps: Int,
        sessionsCompleted: Int,
        daysPerWeek: Int,
        notes: String
    ) async throws -> JourneyWeekPlan {
        let request = GenerateNextWeekRequest(
            weekNumber: weekNumber,
            currentPhase: currentPhase,
            phaseGoal: phaseGoal,
            weeklyFocus: weeklyFocus,
            avgFormScore: avgFormScore,
            totalReps: totalReps,
            sessionsCompleted: sessionsCompleted,
            daysPerWeek: daysPerWeek,
            notes: notes
        )

        let data = try await postRaw(path: "/generate-next-week", body: request)
        let rawString = String(data: data, encoding: .utf8) ?? ""
        print("[Naosu] RAW /generate-next-week:\n\(rawString)")

        let cleanedData = extractJSON(rawString).data(using: .utf8) ?? data

        do {
            return try JSONDecoder().decode(JourneyWeekPlan.self, from: cleanedData)
        } catch let decodeError {
            print("[Naosu] Decode error: \(decodeError)")
            throw APIError.serverError(
                statusCode: 502,
                message: "Failed to decode week plan: \(decodeError.localizedDescription)"
            )
        }
    }

    // MARK: - Session Logging

    func logSession(request: SessionLogRequest) async throws {
        let _: [String: String] = try await postJSON(path: "/log-session", body: request)
    }

    // MARK: - Progress

    func fetchProgress(userId: String) async throws -> ProgressResponse {
        let url = URL(string: "\(APIClient.baseURL)/progress/\(userId)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw APIError.serverError(statusCode: statusCode, message: body)
        }
        return try JSONDecoder().decode(ProgressResponse.self, from: data)
    }

    // MARK: - JSON Extraction (strips markdown code fences if present)

    private func extractJSON(_ text: String) -> String {
        var s = text
        if s.contains("```json") {
            s = s.components(separatedBy: "```json").dropFirst().joined()
            s = s.components(separatedBy: "```").first ?? s
        } else if s.contains("```") {
            let parts = s.components(separatedBy: "```")
            if parts.count >= 2 { s = parts[1] }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Raw POST Helper (returns Data for custom decoding)

    private func postRaw<T: Encodable>(path: String, body: T) async throws -> Data {
        let url = URL(string: "\(APIClient.baseURL)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let msg  = String(data: data, encoding: .utf8) ?? "No body"
            throw APIError.serverError(statusCode: code, message: msg)
        }
        return data
    }

    // MARK: - Generic POST Helper

    private func postJSON<T: Encodable, R: Decodable>(path: String, body: T) async throws -> R {
        let url = URL(string: "\(APIClient.baseURL)\(path)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw APIError.serverError(statusCode: statusCode, message: body)
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
}

enum APIError: LocalizedError {
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

// Used internally by generateJourney to decode the AI response leniently.
// Both fields are optional so a partial response doesn't fail the entire decode.
private struct LenientJourneyAPIResponse: Decodable {
    var journeyStructure: JourneyStructureResponse?
    var week1Plan: JourneyWeekPlan?
}
