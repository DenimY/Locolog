import Foundation

// MARK: - AI Provider

enum AIProvider: String, CaseIterable {
    case claude  = "Claude"
    case openAI  = "OpenAI"
    case gemini  = "Gemini"

    var keyStorageKey: String {
        switch self {
        case .claude: return "claudeAPIKey"
        case .openAI: return "openAIAPIKey"
        case .gemini: return "geminiAPIKey"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "sparkles"
        case .openAI: return "circle.hexagongrid"
        case .gemini: return "diamond"
        }
    }
}

// MARK: - AI Command

enum AICommand: String, CaseIterable, Identifiable {
    case summarize      = "요약"
    case improve        = "내용 개선"
    case translateEN    = "영어 번역"
    case suggestTags    = "태그 제안"
    case continueWrite  = "계속 쓰기"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .summarize:     return "text.quote"
        case .improve:       return "wand.and.stars"
        case .translateEN:   return "globe"
        case .suggestTags:   return "tag"
        case .continueWrite: return "pencil.and.scribble"
        }
    }

    func systemPrompt() -> String {
        switch self {
        case .summarize:
            return "주어진 메모를 3-5문장으로 핵심만 간결하게 요약해 주세요. 원문과 같은 언어로 작성하세요."
        case .improve:
            return "주어진 메모의 내용을 더 명확하고 자연스럽게 다듬어 주세요. 의미를 바꾸지 않고, 표현을 개선하세요. 원문과 같은 언어를 유지하세요."
        case .translateEN:
            return "주어진 메모를 영어로 번역해 주세요. 마크다운 형식을 유지하세요."
        case .suggestTags:
            return "주어진 메모의 내용을 분석하여 관련 태그를 5개 이내로 제안해 주세요. #태그명 형식으로, 줄바꿈 없이 공백으로 구분하여 태그만 나열하세요."
        case .continueWrite:
            return "주어진 메모를 이어서 자연스럽게 작성해 주세요. 원문의 스타일과 톤을 유지하면서 내용을 확장하세요. 이어지는 내용만 출력하세요."
        }
    }
}

// MARK: - AI Error

enum AIError: LocalizedError {
    case noAPIKey(AIProvider)
    case noActiveProvider
    case networkError(Error)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "\(provider.rawValue) API 키가 설정되지 않았습니다. 설정 > AI 설정에서 입력해 주세요."
        case .noActiveProvider:
            return "사용 가능한 AI 제공자가 없습니다. 설정 > AI 설정에서 API 키를 입력해 주세요."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .invalidResponse:
            return "AI 응답을 처리할 수 없습니다."
        case .apiError(let message):
            return "AI 오류: \(message)"
        }
    }
}

// MARK: - AI Manager

@MainActor
final class AIManager: ObservableObject {
    static let shared = AIManager()

    @Published private(set) var isLoading = false

    private init() {}

    // MARK: - Active Provider (Claude → OpenAI → Gemini 우선순위)

    var activeProvider: AIProvider? {
        for provider in AIProvider.allCases {
            let key = UserDefaults.standard.string(forKey: provider.keyStorageKey) ?? ""
            if !key.trimmingCharacters(in: .whitespaces).isEmpty {
                return provider
            }
        }
        return nil
    }

    func apiKey(for provider: AIProvider) -> String {
        UserDefaults.standard.string(forKey: provider.keyStorageKey) ?? ""
    }

    // MARK: - Execute Command

    func execute(command: AICommand, noteContent: String) async throws -> String {
        guard let provider = activeProvider else {
            throw AIError.noActiveProvider
        }
        let key = apiKey(for: provider)
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AIError.noAPIKey(provider)
        }

        isLoading = true
        defer { isLoading = false }

        switch provider {
        case .claude:
            return try await callClaude(command: command, content: noteContent, apiKey: key)
        case .openAI:
            return try await callOpenAI(command: command, content: noteContent, apiKey: key)
        case .gemini:
            return try await callGemini(command: command, content: noteContent, apiKey: key)
        }
    }

    // MARK: - Claude API

    private func callClaude(command: AICommand, content: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 1024,
            "system": command.systemPrompt(),
            "messages": [
                ["role": "user", "content": content]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        struct ClaudeResponse: Decodable {
            struct ContentBlock: Decodable { let text: String }
            let content: [ContentBlock]
        }
        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first?.text else { throw AIError.invalidResponse }
        return text
    }

    // MARK: - OpenAI API

    private func callOpenAI(command: AICommand, content: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": command.systemPrompt()],
                ["role": "user", "content": content]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else { throw AIError.invalidResponse }
        return text
    }

    // MARK: - Gemini API

    private func callGemini(command: AICommand, content: String, apiKey: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let combinedText = "\(command.systemPrompt())\n\n---\n\n\(content)"
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": combinedText]]]
            ],
            "generationConfig": ["maxOutputTokens": 1024]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text else { throw AIError.invalidResponse }
        return text
    }

    // MARK: - HTTP Validation

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
                ?? "HTTP \(http.statusCode)"
            throw AIError.apiError(message)
        }
    }
}
