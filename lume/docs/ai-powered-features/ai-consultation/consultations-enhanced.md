# 💬 Enhanced AI Consultations - iOS Integration Guide

**Feature:** Multi-persona AI chat with context awareness  
**Complexity:** High  
**Time Estimate:** 3-4 days  
**Prerequisites:** Authentication, User Profile, WebSocket library (Starscream)

---

## 📋 Overview

Enhanced AI Consultations provide real-time, context-aware conversations with specialized AI wellness coaches. The system supports multiple personas, contextual discussions linked to goals/insights/mood/journal entries, quick action prompts, and AI-generated templates during conversations.

### What You'll Build
- Multi-persona consultation system (4 personas)
- Real-time WebSocket chat interface
- Context-aware conversations (5 context types)
- Quick action prompts for easy conversation starters
- AI template creation during chat
- Message history with streaming responses
- Consultation management (list, create, archive)

### AI Personas
- **Nutritionist**: Expert in nutrition, meal planning, dietary advice
- **Fitness Coach**: Specializes in workouts, training programs, exercise technique
- **Wellness Specialist**: Focuses on holistic wellness, stress management, lifestyle
- **General Wellness**: Holistic advisor covering all aspects of health and wellness (NEW)

### Context Types
- **General**: Open-ended wellness conversations
- **Goal**: Focused on a specific user goal
- **Insight**: Discussion about an AI-generated insight
- **Mood**: Related to a mood entry or emotional state
- **Journal**: Connected to a journal entry or reflection

---

## 🔑 Key Concepts

### Architecture
```
REST API (Consultation Management)
         ↓
Create consultation → Get consultation ID
         ↓
WebSocket Connection (Real-time Chat)
         ↓
Send message → Stream AI response
         ↓
Message history persisted
```

### Communication Protocol

#### REST API (HTTPS)
- Create consultation
- List consultations
- Get consultation details
- Archive consultation
- Get quick actions

#### WebSocket (WSS)
- Real-time messaging
- Streaming AI responses
- Template creation events
- Connection management

### Message Flow
```
User sends message
    ↓
Backend validates & stores
    ↓
AI processes (OpenAI GPT-4o-mini)
    ↓
Response streams back (word-by-word)
    ↓
User sees typing effect
    ↓
Full message stored in history
```

---

## 🏗️ Swift Models

### 1. Consultation Model

```swift
import Foundation

struct Consultation: Codable, Identifiable {
    let id: String
    let userId: String
    let persona: Persona
    let contextType: ContextType
    let contextId: String?
    let title: String?
    let isActive: Bool
    let isArchived: Bool
    let messageCount: Int
    let lastMessageAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case persona
        case contextType = "context_type"
        case contextId = "context_id"
        case title
        case isActive = "is_active"
        case isArchived = "is_archived"
        case messageCount = "message_count"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum Persona: String, Codable, CaseIterable {
    case nutritionist
    case fitnessCoach = "fitness_coach"
    case wellnessSpecialist = "wellness_specialist"
    case generalWellness = "general_wellness"
    
    var displayName: String {
        switch self {
        case .nutritionist: return "Nutritionist"
        case .fitnessCoach: return "Fitness Coach"
        case .wellnessSpecialist: return "Wellness Specialist"
        case .generalWellness: return "General Wellness"
        }
    }
    
    var description: String {
        switch self {
        case .nutritionist:
            return "Expert in nutrition, meal planning, and dietary advice"
        case .fitnessCoach:
            return "Specializes in workouts, training programs, and exercise technique"
        case .wellnessSpecialist:
            return "Focuses on holistic wellness, stress management, and lifestyle"
        case .generalWellness:
            return "Holistic advisor covering all aspects of health and wellness"
        }
    }
    
    var icon: String {
        switch self {
        case .nutritionist: return "fork.knife"
        case .fitnessCoach: return "figure.run"
        case .wellnessSpecialist: return "heart.fill"
        case .generalWellness: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .nutritionist: return .green
        case .fitnessCoach: return .blue
        case .wellnessSpecialist: return .purple
        case .generalWellness: return .orange
        }
    }
}

enum ContextType: String, Codable, CaseIterable {
    case general
    case goal
    case insight
    case mood
    case journal
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .goal: return "Goal"
        case .insight: return "Insight"
        case .mood: return "Mood"
        case .journal: return "Journal"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "bubble.left.and.bubble.right"
        case .goal: return "target"
        case .insight: return "lightbulb"
        case .mood: return "face.smiling"
        case .journal: return "book"
        }
    }
}
```

### 2. Message Models

```swift
import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let consultationId: String
    let role: MessageRole
    let content: String
    let metadata: MessageMetadata?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case consultationId = "consultation_id"
        case role
        case content
        case metadata
        case createdAt = "created_at"
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct MessageMetadata: Codable {
    let templateCreated: TemplateReference?
    let functionCalled: String?
    let tokensUsed: Int?
    
    enum CodingKeys: String, CodingKey {
        case templateCreated = "template_created"
        case functionCalled = "function_called"
        case tokensUsed = "tokens_used"
    }
}

struct TemplateReference: Codable {
    let type: String // "wellness", "meal", "workout"
    let id: String
    let name: String
}
```

### 3. WebSocket Message Models

```swift
import Foundation

// Outgoing message (client → server)
struct OutgoingMessage: Codable {
    let type: String = "user_message"
    let content: String
    let metadata: [String: String]?
}

// Incoming message (server → client)
struct IncomingMessage: Codable {
    let type: String
    let content: String?
    let messageId: String?
    let error: String?
    let metadata: MessageMetadata?
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
        case messageId = "message_id"
        case error
        case metadata
    }
}

enum WebSocketMessageType: String {
    case connected
    case userMessage = "user_message"
    case assistantMessageStart = "assistant_message_start"
    case assistantMessageChunk = "assistant_message_chunk"
    case assistantMessageEnd = "assistant_message_end"
    case templateCreated = "template_created"
    case error
}
```

### 4. Quick Action Model

```swift
import Foundation

struct QuickAction: Codable, Identifiable {
    let id = UUID()
    let prompt: String
    let description: String?
    let contextType: ContextType
    let persona: Persona?
    let category: String?
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case description
        case contextType = "context_type"
        case persona
        case category
    }
}

struct QuickActionsResponse: Codable {
    let success: Bool
    let data: QuickActionsData
}

struct QuickActionsData: Codable {
    let quickActions: [QuickAction]
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case quickActions = "quick_actions"
        case count
    }
}
```

### 5. API Response Models

```swift
struct ConsultationResponse: Codable {
    let success: Bool
    let data: Consultation
}

struct ConsultationsListResponse: Codable {
    let success: Bool
    let data: ConsultationsData
}

struct ConsultationsData: Codable {
    let consultations: [Consultation]
    let pagination: Pagination
}

struct MessagesResponse: Codable {
    let success: Bool
    let data: MessagesData
}

struct MessagesData: Codable {
    let messages: [Message]
    let pagination: Pagination
}

struct CreateConsultationRequest: Codable {
    let persona: String
    let contextType: String
    let contextId: String?
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case persona
        case contextType = "context_type"
        case contextId = "context_id"
        case title
    }
}
```

---

## 🔌 API Services

### 1. ConsultationService (REST API)

```swift
import Foundation

class ConsultationService {
    private let baseURL = "https://fit-iq-backend.fly.dev/api/v1"
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Create Consultation
    
    func createConsultation(
        persona: Persona,
        contextType: ContextType,
        contextId: String? = nil,
        title: String? = nil
    ) async throws -> Consultation {
        let url = URL(string: "\(baseURL)/consultations")!
        
        let request = CreateConsultationRequest(
            persona: persona.rawValue,
            contextType: contextType.rawValue,
            contextId: contextId,
            title: title
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(ConsultationResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - List Consultations
    
    func listConsultations(
        persona: Persona? = nil,
        contextType: ContextType? = nil,
        isArchived: Bool = false,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> ConsultationsData {
        var components = URLComponents(string: "\(baseURL)/consultations")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "is_archived", value: "\(isArchived)")
        ]
        
        if let persona = persona {
            queryItems.append(URLQueryItem(name: "persona", value: persona.rawValue))
        }
        
        if let contextType = contextType {
            queryItems.append(URLQueryItem(name: "context_type", value: contextType.rawValue))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(ConsultationsListResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Get Consultation
    
    func getConsultation(id: String) async throws -> Consultation {
        let url = URL(string: "\(baseURL)/consultations/\(id)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(ConsultationResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Get Messages
    
    func getMessages(consultationId: String, page: Int = 1) async throws -> MessagesData {
        var components = URLComponents(string: "\(baseURL)/consultations/\(consultationId)/messages")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "50")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(MessagesResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Archive Consultation
    
    func archiveConsultation(id: String) async throws {
        let url = URL(string: "\(baseURL)/consultations/\(id)/archive")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Get Quick Actions
    
    func getQuickActions(
        contextType: ContextType? = nil,
        persona: Persona? = nil
    ) async throws -> [QuickAction] {
        var components = URLComponents(string: "\(baseURL)/consultations/quick-actions")!
        var queryItems: [URLQueryItem] = []
        
        if let contextType = contextType {
            queryItems.append(URLQueryItem(name: "context_type", value: contextType.rawValue))
        }
        
        if let persona = persona {
            queryItems.append(URLQueryItem(name: "persona", value: persona.rawValue))
        }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(QuickActionsResponse.self, from: data)
        
        return apiResponse.data.quickActions
    }
    
    // MARK: - Helper
    
    private func getAuthToken() -> String {
        return KeychainManager.shared.getToken() ?? ""
    }
}
```

### 2. WebSocketService (Real-time Chat)

```swift
import Foundation
import Starscream

class WebSocketService: WebSocketDelegate {
    private var socket: WebSocket?
    private let baseURL = "wss://fit-iq-backend.fly.dev/api/v1"
    
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onMessageReceived: ((IncomingMessage) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Connect
    
    func connect(consultationId: String, token: String) {
        let urlString = "\(baseURL)/consultations/\(consultationId)/ws?token=\(token)"
        guard let url = URL(string: urlString) else {
            onError?(WebSocketError.invalidURL)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    // MARK: - Disconnect
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
    }
    
    // MARK: - Send Message
    
    func sendMessage(_ content: String, metadata: [String: String]? = nil) {
        let message = OutgoingMessage(content: content, metadata: metadata)
        
        guard let jsonData = try? JSONEncoder().encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            onError?(WebSocketError.encodingFailed)
            return
        }
        
        socket?.write(string: jsonString)
    }
    
    // MARK: - WebSocketDelegate
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            onConnected?()
            
        case .disconnected(let reason, let code):
            let error = WebSocketError.disconnected(reason: reason, code: code)
            onDisconnected?(error)
            
        case .text(let string):
            handleIncomingMessage(string)
            
        case .binary(let data):
            if let string = String(data: data, encoding: .utf8) {
                handleIncomingMessage(string)
            }
            
        case .error(let error):
            onError?(error ?? WebSocketError.unknown)
            
        case .cancelled:
            onDisconnected?(nil)
            
        default:
            break
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleIncomingMessage(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let message = try decoder.decode(IncomingMessage.self, from: jsonData)
            onMessageReceived?(message)
        } catch {
            onError?(WebSocketError.decodingFailed(error))
        }
    }
}

// MARK: - WebSocket Errors

enum WebSocketError: Error, LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed(Error)
    case disconnected(reason: String, code: UInt16)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .encodingFailed:
            return "Failed to encode message"
        case .decodingFailed(let error):
            return "Failed to decode message: \(error.localizedDescription)"
        case .disconnected(let reason, _):
            return "Disconnected: \(reason)"
        case .unknown:
            return "Unknown WebSocket error"
        }
    }
}
```

---

## 🎨 SwiftUI Views

### 1. Persona Selection View

```swift
import SwiftUI

struct PersonaSelectionView: View {
    @Binding var selectedPersona: Persona?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(Persona.allCases, id: \.self) { persona in
                PersonaCard(persona: persona)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPersona = persona
                        dismiss()
                    }
            }
            .navigationTitle("Choose AI Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PersonaCard: View {
    let persona: Persona
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(persona.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: persona.icon)
                    .font(.title2)
                    .foregroundColor(persona.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(persona.displayName)
                    .font(.headline)
                
                Text(persona.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
```

### 2. Chat View (Main Interface)

```swift
import SwiftUI

struct ChatView: View {
    let consultation: Consultation
    
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var showQuickActions = false
    @FocusState private var isInputFocused: Bool
    
    init(consultation: Consultation) {
        self.consultation = consultation
        _viewModel = StateObject(wrappedValue: ChatViewModel(consultation: consultation))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesScrollView
            
            // Quick actions (if shown)
            if showQuickActions {
                quickActionsBar
            }
            
            // Input bar
            inputBar
        }
        .navigationTitle(consultation.persona.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showQuickActions.toggle()
                    } label: {
                        Label("Quick Actions", systemImage: "bolt.fill")
                    }
                    
                    Button {
                        Task {
                            await viewModel.refreshMessages()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        Task {
                            await viewModel.archiveConsultation()
                        }
                    } label: {
                        Label("Archive Chat", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.loadMessages()
            await viewModel.connectWebSocket()
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Subviews
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    // Streaming message
                    if viewModel.isStreaming, !viewModel.streamingContent.isEmpty {
                        MessageBubble(
                            content: viewModel.streamingContent,
                            role: .assistant,
                            isStreaming: true
                        )
                        .id("streaming")
                    }
                    
                    // Typing indicator
                    if viewModel.isWaitingForResponse {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isStreaming) { _ in
                scrollToBottom(proxy)
            }
        }
    }
    
    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.quickActions) { action in
                    QuickActionChip(action: action) {
                        messageText = action.prompt
                        isInputFocused = true
                        showQuickActions = false
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            Button {
                showQuickActions.toggle()
            } label: {
                Image(systemName: "bolt.fill")
                    .foregroundColor(showQuickActions ? .blue : .gray)
            }
            
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .lineLimit(1...5)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty || viewModel.isWaitingForResponse)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
```

### 3. Message Bubble

```swift
import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    init(message: Message) {
        self.message = message
        self.content = message.content
        self.role = message.role
        self.isStreaming = false
        self.metadata = message.metadata
    }
    
    init(content: String, role: MessageRole, isStreaming: Bool, metadata: MessageMetadata? = nil) {
        self.message = nil
        self.content = content
        self.role = role
        self.isStreaming = isStreaming
        self.metadata = metadata
    }
    
    private let message: Message?
    private let content: String
    private let role: MessageRole
    private let isStreaming: Bool
    private let metadata: MessageMetadata?
    
    var body: some View {
        HStack {
            if role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: role == .user ? .trailing : .leading, spacing: 8) {
                // Message content
                Text(content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                
                // Template creation indicator
                if let template = metadata?.templateCreated {
                    TemplateCreatedBanner(template: template)
                }
                
                // Timestamp
                if let message = message {
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Streaming indicator
                if isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 4, height: 4)
                                .opacity(0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isStreaming
                                )
                        }
                    }
                }
            }
            
            if role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var backgroundColor: Color {
        role == .user ? Color.blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        role == .user ? .white : .primary
    }
}

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -5 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .onAppear {
            animating = true
        }
    }
}

struct TemplateCreatedBanner: View {
    let template: TemplateReference
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: templateIcon)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(template.type.capitalized) Template Created")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(template.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                // Navigate to template
            } label: {
                Text("View")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var templateIcon: String {
        switch template.type {
        case "meal": return "fork.knife"
        case "workout": return "figure.run"
        case "wellness": return "heart.fill"
        default: return "doc.fill"
        }
    }
}
```

### 4. Quick Action Chip

```swift
import SwiftUI

struct QuickActionChip: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.prompt)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let description = action.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 180, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
```

### 5. Consultations List View

```swift
import SwiftUI

struct ConsultationsListView: View {
    @StateObject private var viewModel = ConsultationsViewModel()
    @State private var showPersonaSelection = false
    @State private var selectedPersona: Persona?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.consultations.isEmpty {
                    ProgressView()
                } else if viewModel.consultations.isEmpty {
                    emptyStateView
                } else {
                    consultationsList
                }
            }
            .navigationTitle("Consultations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPersonaSelection = true
                    } label: {
                        Label("New Chat", systemImage: "plus.bubble")
                    }
                }
            }
            .sheet(isPresented: $showPersonaSelection) {
                PersonaSelectionView(selectedPersona: $selectedPersona)
            }
            .onChange(of: selectedPersona) { persona in
                if let persona = persona {
                    Task {
                        await viewModel.createConsultation(persona: persona)
                        selectedPersona = nil
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadConsultations()
            }
        }
    }
    
    private var consultationsList: some View {
        List {
            ForEach(viewModel.consultations) { consultation in
                NavigationLink(destination: ChatView(consultation: consultation)) {
                    ConsultationRow(consultation: consultation)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.archiveConsultation(consultation)
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Consultations Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Start a conversation with an AI coach to get personalized wellness advice")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showPersonaSelection = true
            } label: {
                Label("Start Chat", systemImage: "plus.bubble")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ConsultationRow: View {
    let consultation: Consultation
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(consultation.persona.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: consultation.persona.icon)
                    .foregroundColor(consultation.persona.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(consultation.persona.displayName)
                        .font(.headline)
                    
                    if consultation.contextType != .general {
                        Image(systemName: consultation.contextType.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let title = consultation.title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("\(consultation.messageCount) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastMessage = consultation.lastMessageAt {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(lastMessage, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if consultation.isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

## 🧩 View Models

### 1. Chat ViewModel

```swift
import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var streamingContent = ""
    @Published var isStreaming = false
    @Published var isWaitingForResponse = false
    @Published var isConnected = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var quickActions: [QuickAction] = []
    
    private let consultation: Consultation
    private let restService = ConsultationService(apiKey: Config.apiKey)
    private let wsService = WebSocketService()
    
    init(consultation: Consultation) {
        self.consultation = consultation
        setupWebSocketHandlers()
    }
    
    // MARK: - Load Messages
    
    func loadMessages() async {
        do {
            let data = try await restService.getMessages(consultationId: consultation.id)
            messages = data.messages
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Load Quick Actions
    
    func loadQuickActions() async {
        do {
            quickActions = try await restService.getQuickActions(
                contextType: consultation.contextType,
                persona: consultation.persona
            )
        } catch {
            // Silently fail - not critical
            print("Failed to load quick actions: \(error)")
        }
    }
    
    // MARK: - WebSocket Connection
    
    func connectWebSocket() async {
        guard let token = KeychainManager.shared.getToken() else {
            errorMessage = "Authentication required"
            showError = true
            return
        }
        
        await loadQuickActions()
        wsService.connect(consultationId: consultation.id, token: token)
    }
    
    func disconnect() {
        wsService.disconnect()
    }
    
    // MARK: - Send Message
    
    func sendMessage(_ content: String) async {
        // Add user message immediately
        let userMessage = Message(
            id: UUID().uuidString,
            consultationId: consultation.id,
            role: .user,
            content: content,
            metadata: nil,
            createdAt: Date()
        )
        messages.append(userMessage)
        
        // Send via WebSocket
        isWaitingForResponse = true
        wsService.sendMessage(content)
    }
    
    // MARK: - WebSocket Handlers
    
    private func setupWebSocketHandlers() {
        wsService.onConnected = { [weak self] in
            self?.isConnected = true
        }
        
        wsService.onDisconnected = { [weak self] error in
            self?.isConnected = false
            if let error = error {
                self?.errorMessage = "Connection lost: \(error.localizedDescription)"
                self?.showError = true
            }
        }
        
        wsService.onMessageReceived = { [weak self] message in
            self?.handleIncomingMessage(message)
        }
        
        wsService.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
            self?.showError = true
        }
    }
    
    private func handleIncomingMessage(_ message: IncomingMessage) {
        guard let type = WebSocketMessageType(rawValue: message.type) else { return }
        
        switch type {
        case .connected:
            break
            
        case .assistantMessageStart:
            isWaitingForResponse = false
            isStreaming = true
            streamingContent = ""
            
        case .assistantMessageChunk:
            if let content = message.content {
                streamingContent += content
            }
            
        case .assistantMessageEnd:
            isStreaming = false
            
            // Add completed message
            if !streamingContent.isEmpty {
                let assistantMessage = Message(
                    id: message.messageId ?? UUID().uuidString,
                    consultationId: consultation.id,
                    role: .assistant,
                    content: streamingContent,
                    metadata: message.metadata,
                    createdAt: Date()
                )
                messages.append(assistantMessage)
                streamingContent = ""
            }
            
        case .templateCreated:
            // Template creation handled in metadata
            break
            
        case .error:
            isWaitingForResponse = false
            isStreaming = false
            errorMessage = message.error ?? "An error occurred"
            showError = true
            
        default:
            break
        }
    }
    
    // MARK: - Archive
    
    func archiveConsultation() async {
        do {
            try await restService.archiveConsultation(id: consultation.id)
        } catch {
            errorMessage = "Failed to archive consultation"
            showError = true
        }
    }
    
    // MARK: - Refresh
    
    func refreshMessages() async {
        await loadMessages()
    }
}
```

### 2. Consultations List ViewModel

```swift
import Foundation

@MainActor
class ConsultationsViewModel: ObservableObject {
    @Published var consultations: [Consultation] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let service = ConsultationService(apiKey: Config.apiKey)
    
    func loadConsultations() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let data = try await service.listConsultations()
            consultations = data.consultations
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func createConsultation(
        persona: Persona,
        contextType: ContextType = .general,
        contextId: String? = nil
    ) async {
        do {
            let consultation = try await service.createConsultation(
                persona: persona,
                contextType: contextType,
                contextId: contextId
            )
            consultations.insert(consultation, at: 0)
        } catch {
            errorMessage = "Failed to create consultation"
            showError = true
        }
    }
    
    func archiveConsultation(_ consultation: Consultation) async {
        do {
            try await service.archiveConsultation(id: consultation.id)
            consultations.removeAll { $0.id == consultation.id }
        } catch {
            errorMessage = "Failed to archive consultation"
            showError = true
        }
    }
    
    func refresh() async {
        consultations = []
        await loadConsultations()
    }
}
```

---

## 🧪 Testing Strategy

### Unit Tests

```swift
import XCTest
@testable import FitIQ

class ConsultationServiceTests: XCTestCase {
    var service: ConsultationService!
    
    override func setUp() {
        super.setUp()
        service = ConsultationService(apiKey: "test-api-key")
    }
    
    func testCreateConsultation() async throws {
        let consultation = try await service.createConsultation(
            persona: .nutritionist,
            contextType: .general
        )
        
        XCTAssertNotNil(consultation.id)
        XCTAssertEqual(consultation.persona, .nutritionist)
        XCTAssertEqual(consultation.contextType, .general)
    }
    
    func testListConsultations() async throws {
        let data = try await service.listConsultations()
        XCTAssertNotNil(data.consultations)
        XCTAssertNotNil(data.pagination)
    }
    
    func testGetQuickActions() async throws {
        let actions = try await service.getQuickActions()
        XCTAssertFalse(actions.isEmpty)
    }
}

class WebSocketServiceTests: XCTestCase {
    var wsService: WebSocketService!
    
    override func setUp() {
        super.setUp()
        wsService = WebSocketService()
    }
    
    func testConnect() {
        let expectation = XCTestExpectation(description: "WebSocket connected")
        
        wsService.onConnected = {
            expectation.fulfill()
        }
        
        wsService.connect(consultationId: "test-id", token: "test-token")
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSendMessage() {
        // Mock WebSocket connection
        wsService.sendMessage("Hello")
        // Verify message sent (requires mock)
    }
}
```

### Integration Tests

```swift
// Test complete consultation flow
func testConsultationEndToEnd() async throws {
    let service = ConsultationService(apiKey: Config.apiKey)
    
    // 1. Create consultation
    let consultation = try await service.createConsultation(
        persona: .generalWellness,
        contextType: .general
    )
    XCTAssertNotNil(consultation.id)
    
    // 2. Connect WebSocket
    let wsService = WebSocketService()
    let connected = expectation(description: "Connected")
    
    wsService.onConnected = {
        connected.fulfill()
    }
    
    wsService.connect(consultationId: consultation.id, token: "test-token")
    await fulfillment(of: [connected], timeout: 5.0)
    
    // 3. Send message
    wsService.sendMessage("Hello, I need help with my goals")
    
    // 4. Receive response (requires async wait)
    // Test response handling...
    
    // 5. Get messages
    let messages = try await service.getMessages(consultationId: consultation.id)
    XCTAssertFalse(messages.messages.isEmpty)
}
```

---

## ✅ Implementation Checklist

### Phase 1: REST API & Models (1 day)
- [ ] Create all model types (Consultation, Message, Persona, ContextType, QuickAction)
- [ ] Implement `ConsultationService` with all REST endpoints
- [ ] Test consultation creation and listing with Swagger
- [ ] Test quick actions endpoint

### Phase 2: WebSocket Setup (1 day)
- [ ] Add Starscream dependency
- [ ] Implement `WebSocketService` with delegate methods
- [ ] Test connection and disconnection
- [ ] Test message sending
- [ ] Handle all incoming message types

### Phase 3: Chat UI (1 day)
- [ ] Create persona selection view
- [ ] Create chat view with message list
- [ ] Create message bubbles (user/assistant)
- [ ] Implement typing indicator
- [ ] Add streaming message display
- [ ] Create input bar with send button
- [ ] Implement `ChatViewModel` with WebSocket integration

### Phase 4: Enhanced Features (0.5 days)
- [ ] Add quick actions bar
- [ ] Create quick action chips
- [ ] Implement template created banners
- [ ] Add consultations list view
- [ ] Implement swipe to archive
- [ ] Add empty states

### Phase 5: Testing & Polish (0.5 days)
- [ ] Write unit tests for services
- [ ] Write integration tests
- [ ] Test with real backend
- [ ] Handle reconnection logic
- [ ] Test error scenarios
- [ ] Performance optimization

---

## 🚨 Common Issues & Solutions

### Issue 1: WebSocket Connection Fails
**Cause:** Invalid token or consultation ID  
**Solution:** Verify JWT token is valid and consultation exists. Check token format in query parameter.

### Issue 2: Messages Not Streaming
**Cause:** Not handling chunk messages properly  
**Solution:** Ensure `assistantMessageChunk` handler appends to `streamingContent`.

### Issue 3: Connection Drops Frequently
**Cause:** Network instability or timeout  
**Solution:** Implement auto-reconnect logic with exponential backoff.

### Issue 4: Messages Out of Order
**Cause:** Race condition between WebSocket and REST API  
**Solution:** Use message IDs to deduplicate, prefer WebSocket for new messages.

### Issue 5: Template Creation Not Showing
**Cause:** Metadata not parsed correctly  
**Solution:** Check `metadata.templateCreated` field in assistant messages.

---

## 💡 Best Practices

### 1. Connection Management
```swift
// Auto-reconnect on disconnect
func handleDisconnection() {
    guard shouldReconnect else { return }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
        self.connectWebSocket()
        self.retryDelay = min(self.retryDelay * 2, 30) // Exponential backoff
    }
}
```

### 2. Message Deduplication
```swift
// Avoid duplicate messages
func addMessage(_ message: Message) {
    guard !messages.contains(where: { $0.id == message.id }) else { return }
    messages.append(message)
}
```

### 3. Scroll Management
```swift
// Auto-scroll to bottom smoothly
func scrollToBottom(_ proxy: ScrollViewProxy) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation {
            proxy.scrollTo(lastMessageId, anchor: .bottom)
        }
    }
}
```

### 4. Input Validation
```swift
// Validate before sending
func sendMessage() {
    let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 2000 else { return }
    
    viewModel.sendMessage(trimmed)
    messageText = ""
}
```

---

## 📊 Performance Considerations

### WebSocket
- Keep connection alive during active chat
- Disconnect when leaving chat view
- Implement heartbeat/ping mechanism

### Message History
- Load messages in pages (50 per page)
- Implement infinite scroll for history
- Cache recent conversations locally

### Streaming
- Update UI every 50-100ms during streaming
- Debounce scroll updates
- Use `LazyVStack` for message list

---

## 🔗 Integration Points

### Prerequisites
- ✅ Authentication (JWT token)
- ✅ User profile
- ✅ Starscream library for WebSocket

### Related Features
- **Goals**: Start goal-focused consultations
- **AI Insights**: Discuss insights with AI coach
- **Mood Tracking**: Mood-related conversations
- **Journal**: Reflect on journal entries with AI

### Context Integration Examples

```swift
// Start consultation about a specific goal
func startGoalConsultation(goalId: String, goalTitle: String) async {
    await viewModel.createConsultation(
        persona: .generalWellness,
        contextType: .goal,
        contextId: goalId,
        title: "Help with: \(goalTitle)"
    )
}

// Start consultation about an insight
func discussInsight(insightId: String, insightTitle: String) async {
    await viewModel.createConsultation(
        persona: .wellnessSpecialist,
        contextType: .insight,
        contextId: insightId,
        title: "Discuss: \(insightTitle)"
    )
}
```

---

## 📚 Additional Resources

- **Swagger Docs**: [swagger-consultations.yaml](../../swagger-consultations.yaml)
- **API Playground**: https://fit-iq-backend.fly.dev/swagger/index.html
- **Starscream Docs**: https://github.com/daltoniam/Starscream
- **WebSocket Protocol**: [WebSocket RFC](https://tools.ietf.org/html/rfc6455)

---

## 🎯 Next Steps

After implementing Enhanced Consultations:

1. **Cross-Feature Integration** - Link consultations with goals, insights, mood, and journal
2. **Offline Support** - Cache messages and handle offline scenarios
3. **Push Notifications** - Notify users of AI responses when app is backgrounded
4. **Voice Input** - Add speech-to-text for message input

---

**Ready to build? This is the most complex feature - take it step by step!** 🚀