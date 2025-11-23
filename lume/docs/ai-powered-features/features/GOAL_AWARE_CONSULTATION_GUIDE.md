# Goal-Aware Consultations - iOS Integration Guide

**Version:** 1.0.0  
**Date:** 2025-01-20  
**Feature:** Goal Context in AI Consultations  
**Status:** ✅ Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [What This Feature Does](#what-this-feature-does)
3. [API Changes](#api-changes)
4. [Step-by-Step Integration](#step-by-step-integration)
5. [Code Examples (Swift)](#code-examples-swift)
6. [Testing & Validation](#testing--validation)
7. [Troubleshooting](#troubleshooting)
8. [FAQ](#faq)

---

## 🎯 Overview

The Goal-Aware Consultation feature allows users to start an AI consultation **directly from a specific goal**. When they do this, the AI is fully aware of:

- The goal title (e.g., "Lose 15 pounds for summer vacation")
- The goal description and context
- Current progress, target values, and deadline
- User's stated challenges (from goal description)

The AI will **immediately acknowledge the goal** and focus the entire conversation on helping the user achieve it.

### Before vs After

**❌ Before (Generic Consultation):**
```
User: "Hi, I need help."
AI: "Hello! What can I help you with today?"
User: "I want to lose weight."
AI: "Great! Tell me more about your weight loss goal..."
```

**✅ After (Goal-Aware Consultation):**
```
User: "Hi, I need help." [Starts consultation from "Lose 15 pounds" goal]
AI: "I can see you're working on: Lose 15 pounds for summer vacation. 
     What specific challenges are you facing with portion control?"
```

---

## 🎨 What This Feature Does

### User Experience

1. **User taps on a goal** in the Goals screen
2. **User selects "Get Help from AI"** or similar action
3. **App creates consultation with goal context**
4. **AI immediately acknowledges the goal** and asks relevant questions
5. **Entire conversation stays focused** on that specific goal

### Technical Behavior

- Backend passes goal details to OpenAI in the system prompt
- AI receives full context (title, description, progress, targets)
- AI is instructed to reference the goal in its first response
- AI asks targeted questions based on goal details
- AI cannot call `get_active_goals()` function (already has the info)

---

## 🔄 API Changes

### 1. Create Consultation Endpoint (Enhanced)

**Endpoint:** `POST /api/v1/consultations`

**New Optional Fields:**

```json
{
  "persona": "wellness_specialist",
  "context_type": "goal",          // NEW: Type of context
  "context_id": "<goal_id>",        // NEW: The goal's UUID
  "initial_message": "Hi, I need help with this goal" // Optional
}
```

**Response (Enhanced):**

```json
{
  "success": true,
  "data": {
    "consultation": {
      "id": "a7af58e6-d266-4b72-aab7-6016a9021a20",
      "user_id": "15d3af32-a0f7-424c-952a-18c372476bfe",
      "persona": "wellness_specialist",
      "status": "active",
      "context_type": "goal",        // NEW: Confirms goal context
      "context_id": "bf03abfe-53eb-4abf-8d80-7b9cc4e0b171", // NEW: The goal ID
      "has_context_for_goal_suggestions": true, // NEW: AI has context
      "started_at": "2025-01-20T06:19:24Z",
      "last_message_at": "2025-01-20T06:19:24Z",
      "message_count": 0,
      "created_at": "2025-01-20T06:19:24Z",
      "updated_at": "2025-01-20T06:19:24Z"
    }
  }
}
```

### 2. List Consultations Endpoint (New)

**Endpoint:** `GET /api/v1/consultations?status=active`

**Response:**

```json
{
  "success": true,
  "data": {
    "consultations": [
      {
        "id": "a7af58e6-d266-4b72-aab7-6016a9021a20",
        "persona": "wellness_specialist",
        "status": "active",
        "context_type": "goal",
        "context_id": "bf03abfe-53eb-4abf-8d80-7b9cc4e0b171",
        "started_at": "2025-01-20T06:19:24Z",
        "message_count": 5
      }
    ],
    "total_count": 1,
    "limit": 20,
    "offset": 0
  }
}
```

### 3. WebSocket Behavior (Unchanged)

**Connection:** `wss://fit-iq-backend.fly.dev/api/v1/consultations/{id}/ws`

No changes to WebSocket protocol. Goal context is applied server-side.

---

## 📱 Step-by-Step Integration

### Step 1: Add Goal Context to Consultation Creation

When user taps "Get Help from AI" on a goal:

```swift
func createConsultationForGoal(_ goal: Goal) async throws -> Consultation {
    let endpoint = "\(baseURL)/api/v1/consultations"
    
    let requestBody: [String: Any] = [
        "persona": "wellness_specialist",
        "context_type": "goal",        // Important!
        "context_id": goal.id,          // Pass the goal ID
        "initial_message": "Hi, I need help with this goal"
    ]
    
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 201 else {
        throw ConsultationError.creationFailed
    }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let apiResponse = try decoder.decode(ConsultationResponse.self, from: data)
    
    return apiResponse.data.consultation
}
```

### Step 2: Update Consultation Model

Add new fields to your `Consultation` model:

```swift
struct Consultation: Codable, Identifiable {
    let id: String
    let userId: String
    let persona: String
    let status: String
    
    // NEW FIELDS
    let contextType: String?           // "goal", "insight", "mood", "journal", or "general"
    let contextId: String?             // The UUID of the context entity
    let hasContextForGoalSuggestions: Bool  // Whether AI has sufficient context
    
    let startedAt: Date
    let lastMessageAt: Date?
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
}
```

### Step 3: Update UI to Show Goal Context

Show visual indicator that consultation is goal-focused:

```swift
struct ConsultationHeaderView: View {
    let consultation: Consultation
    @State private var goalTitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Persona badge
            PersonaBadge(persona: consultation.persona)
            
            // Goal context badge (if applicable)
            if consultation.contextType == "goal",
               let goalTitle = goalTitle {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.blue)
                    Text("Focused on: \(goalTitle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onAppear {
            if let contextId = consultation.contextId {
                loadGoalTitle(contextId)
            }
        }
    }
    
    private func loadGoalTitle(_ goalId: String) {
        Task {
            goalTitle = try? await GoalService.shared.getGoal(goalId).title
        }
    }
}
```

### Step 4: Add "Get Help" Action to Goals

In your Goals screen, add a button to start consultation:

```swift
struct GoalDetailView: View {
    let goal: Goal
    @State private var showingConsultation = false
    @State private var consultation: Consultation?
    
    var body: some View {
        ScrollView {
            // Goal details...
            
            Button(action: startConsultation) {
                Label("Get AI Help with This Goal", systemImage: "message.badge.waveform")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(isPresented: $showingConsultation) {
            if let consultation = consultation {
                ConsultationView(consultation: consultation)
            }
        }
    }
    
    private func startConsultation() {
        Task {
            do {
                // Create consultation with goal context
                consultation = try await ConsultationService.shared
                    .createConsultationForGoal(goal)
                showingConsultation = true
            } catch {
                // Handle error
                print("Failed to create consultation: \(error)")
            }
        }
    }
}
```

### Step 5: Test the Integration

**Manual Test Flow:**

1. **Create a concrete goal:**
   - Title: "Lose 15 pounds for summer vacation"
   - Description: "I want to lose weight before my beach trip in July. I've been struggling with portion control."
   - Target: 165 lbs (current: 180 lbs)

2. **Tap "Get AI Help"** from goal detail screen

3. **Verify consultation created** with `context_type: "goal"`

4. **Connect to WebSocket** and send first message: "Hi, I need help"

5. **Expected AI response:**
   ```
   "I can see you're working on: Lose 15 pounds for summer vacation. 
    Let's make progress on that! What specific challenges are you facing 
    with portion control and getting back to regular exercise?"
   ```

6. **Success criteria:**
   - ✅ AI mentions goal title explicitly
   - ✅ AI references details from description
   - ✅ AI does NOT ask "what goal are you working on?"
   - ✅ AI asks targeted questions about the goal

---

## 💻 Code Examples (Swift)

### Complete Service Implementation

```swift
import Foundation

class ConsultationService {
    static let shared = ConsultationService()
    
    private let baseURL = "https://fit-iq-backend.fly.dev/api/v1"
    private var authToken: String { AuthManager.shared.token }
    private var apiKey: String { Config.apiKey }
    
    // MARK: - Create Consultation with Goal Context
    
    func createConsultationForGoal(
        _ goal: Goal,
        persona: Persona = .wellnessSpecialist,
        initialMessage: String? = nil
    ) async throws -> Consultation {
        let endpoint = "\(baseURL)/consultations"
        
        var requestBody: [String: Any] = [
            "persona": persona.rawValue,
            "context_type": "goal",
            "context_id": goal.id
        ]
        
        if let message = initialMessage {
            requestBody["initial_message"] = message
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConsultationError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 201:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let apiResponse = try decoder.decode(ConsultationResponse.self, from: data)
            return apiResponse.data.consultation
            
        case 429:
            throw ConsultationError.tooManyActive
            
        case 400:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ConsultationError.badRequest(errorResponse?.error.message ?? "Invalid request")
            
        case 401:
            throw ConsultationError.unauthorized
            
        default:
            throw ConsultationError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Create General Consultation (No Context)
    
    func createConsultation(
        persona: Persona = .generalWellness,
        initialMessage: String? = nil
    ) async throws -> Consultation {
        let endpoint = "\(baseURL)/consultations"
        
        var requestBody: [String: Any] = [
            "persona": persona.rawValue
        ]
        
        if let message = initialMessage {
            requestBody["initial_message"] = message
        }
        
        // ... same as above but without context_type and context_id
    }
    
    // MARK: - List User Consultations
    
    func listConsultations(status: ConsultationStatus? = nil) async throws -> [Consultation] {
        var urlComponents = URLComponents(string: "\(baseURL)/consultations")!
        
        if let status = status {
            urlComponents.queryItems = [
                URLQueryItem(name: "status", value: status.rawValue)
            ]
        }
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ConsultationError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let apiResponse = try decoder.decode(ConsultationsListResponse.self, from: data)
        
        return apiResponse.data.consultations
    }
}

// MARK: - Models

struct ConsultationResponse: Codable {
    let success: Bool
    let data: ConsultationData
    
    struct ConsultationData: Codable {
        let consultation: Consultation
    }
}

struct ConsultationsListResponse: Codable {
    let success: Bool
    let data: ConsultationsData
    
    struct ConsultationsData: Codable {
        let consultations: [Consultation]
        let totalCount: Int
        let limit: Int
        let offset: Int
    }
}

struct Consultation: Codable, Identifiable {
    let id: String
    let userId: String
    let persona: String
    let status: String
    let contextType: String?
    let contextId: String?
    let hasContextForGoalSuggestions: Bool
    let startedAt: Date
    let lastMessageAt: Date?
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
}

enum Persona: String, Codable {
    case nutritionist = "nutritionist"
    case fitnessCoach = "fitness_coach"
    case wellnessSpecialist = "wellness_specialist"
    case generalWellness = "general_wellness"
    case triage = "triage"
}

enum ConsultationStatus: String {
    case active
    case completed
    case abandoned
}

enum ConsultationError: Error, LocalizedError {
    case invalidResponse
    case tooManyActive
    case badRequest(String)
    case unauthorized
    case serverError(Int)
    case creationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .tooManyActive:
            return "You have too many active consultations. Please complete some before starting new ones."
        case .badRequest(let message):
            return message
        case .unauthorized:
            return "Authentication required"
        case .serverError(let code):
            return "Server error: \(code)"
        case .creationFailed:
            return "Failed to create consultation"
        }
    }
}

struct ErrorResponse: Codable {
    let success: Bool
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
    }
}
```

### SwiftUI View Example

```swift
import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    @StateObject private var viewModel = GoalDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal header
                GoalHeaderView(goal: goal)
                
                // Progress card
                GoalProgressCard(goal: goal)
                
                // AI Help section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Need Help?")
                        .font(.headline)
                    
                    Text("Talk to our AI wellness specialist about this specific goal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { viewModel.startGoalConsultation(goal) }) {
                        HStack {
                            Image(systemName: "message.badge.waveform")
                            Text("Get AI Help with This Goal")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isCreatingConsultation)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(goal.title)
        .sheet(isPresented: $viewModel.showingConsultation) {
            if let consultation = viewModel.activeConsultation {
                ConsultationView(consultation: consultation)
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

@MainActor
class GoalDetailViewModel: ObservableObject {
    @Published var isCreatingConsultation = false
    @Published var showingConsultation = false
    @Published var activeConsultation: Consultation?
    @Published var showingError = false
    @Published var errorMessage: String?
    
    func startGoalConsultation(_ goal: Goal) {
        isCreatingConsultation = true
        
        Task {
            do {
                let consultation = try await ConsultationService.shared
                    .createConsultationForGoal(
                        goal,
                        persona: .wellnessSpecialist,
                        initialMessage: "Hi, I need help with this goal"
                    )
                
                activeConsultation = consultation
                showingConsultation = true
                
            } catch ConsultationError.tooManyActive {
                errorMessage = "You already have active consultations. Please complete them before starting a new one."
                showingError = true
                
            } catch {
                errorMessage = "Failed to start consultation: \(error.localizedDescription)"
                showingError = true
            }
            
            isCreatingConsultation = false
        }
    }
}
```

---

## 🧪 Testing & Validation

### Automated Test Script

We've provided a Python test script that validates the entire flow:

**Location:** `fitiq-backend/test_websocket_goal.py`

**What it does:**
1. Creates a concrete test goal ("Lose 15 pounds for summer vacation")
2. Creates a consultation with goal context
3. Connects via WebSocket
4. Sends a message
5. Validates AI response mentions the goal explicitly
6. Cleans up (deletes consultation and goal)

**Run it:**
```bash
export API_KEY="your-api-key"
python3 test_websocket_goal.py
```

**Expected output:**
```
✅ TEST PASSED! Goal context feature working!
```

### Manual Testing Checklist

- [ ] **Create Goal**: Create a goal with detailed title and description
- [ ] **Start Consultation**: Tap "Get AI Help" from goal screen
- [ ] **Verify Context**: Check consultation has `context_type: "goal"` and `context_id`
- [ ] **First Message**: Send "Hi, I need help"
- [ ] **Verify AI Response**: AI should:
  - [ ] Mention goal title explicitly
  - [ ] Reference details from description
  - [ ] NOT ask "what goal are you working on?"
  - [ ] Ask targeted questions about the goal
- [ ] **Continue Conversation**: Verify AI stays focused on the goal
- [ ] **Complete Consultation**: Verify completion works normally
- [ ] **List Consultations**: Verify goal context is visible in list

### Edge Cases to Test

1. **Goal without description**: Should still work, AI acknowledges goal but has less context
2. **Goal with long description**: Should handle gracefully
3. **Multiple active consultations**: Should get 429 error with clear message
4. **Deleted goal**: Consultation still works (context is snapshotted)
5. **Network issues**: Handle WebSocket disconnects gracefully

---

## 🔧 Troubleshooting

### Issue: AI Doesn't Mention Goal

**Symptom:** AI says "Hello! What can I help you with?"

**Causes:**
1. `context_type` or `context_id` not passed in creation request
2. Goal ID is invalid
3. Backend not deployed with latest code

**Solutions:**
1. Verify request body includes both fields
2. Check goal exists: `GET /api/v1/goals/{goal_id}`
3. Check backend version (should be >= v0.35.0)

### Issue: 429 Too Many Active Consultations

**Symptom:** Cannot create new consultation

**Causes:**
- User has maximum active consultations (currently 10)

**Solutions:**
1. List active consultations: `GET /api/v1/consultations?status=active`
2. Complete or delete old consultations
3. Improve UI to show active consultations and allow completion

### Issue: Context Fields Missing in Response

**Symptom:** `context_type` or `context_id` is null

**Causes:**
1. Consultation created without context (general consultation)
2. Old API version

**Solutions:**
1. Verify you're passing `context_type` and `context_id` in creation
2. Check API response structure matches documentation

### Issue: AI Asks About Goal Despite Context

**Symptom:** AI says "What goal are you working on?"

**This should NOT happen with latest backend.** If it does:

1. Check backend logs for DEBUG messages about goal context
2. Verify goal was fetched successfully (check for errors in logs)
3. Report to backend team with consultation ID

---

## ❓ FAQ

### Q: Can a consultation have multiple goals?

**A:** No, one consultation = one goal context. If user wants help with multiple goals, they should create separate consultations.

### Q: What happens if the goal is deleted while consultation is active?

**A:** The consultation continues normally. The goal context is passed to the AI at consultation creation time, so it doesn't matter if the goal is deleted later.

### Q: Can I change the goal context after consultation is created?

**A:** No, goal context is immutable after creation. User needs to create a new consultation if they want to focus on a different goal.

### Q: What personas support goal context?

**A:** All personas support goal context, but `wellness_specialist` and `general_wellness` are recommended for goal-focused conversations.

### Q: Does goal context work with recurring goals?

**A:** Yes! Recurring goals work the same way. The AI will see the current period's targets and progress.

### Q: Can I use other context types besides "goal"?

**A:** Yes! The backend supports:
- `goal` - For goal-focused consultations (implemented and tested)
- `insight` - For insight-focused consultations (future)
- `mood` - For mood-based consultations (future)
- `journal` - For journal entry discussions (future)
- `general` - No specific context (default)

Only `goal` is fully implemented and tested currently.

### Q: How do I show which consultations are goal-focused in the UI?

**A:** Check the `context_type` field:

```swift
if consultation.contextType == "goal",
   let goalId = consultation.contextId {
    // Fetch goal title and show badge
    Text("🎯 Goal: \(goalTitle)")
}
```

### Q: What if the goal has no description?

**A:** The AI will still acknowledge the goal by title, but will have less context to work with. Encourage users to add descriptions for better AI interactions.

### Q: Does this affect existing consultations?

**A:** No, this is purely additive. Existing consultations continue to work as before. The new fields (`context_type`, `context_id`) are optional.

---

## 📞 Support

### Questions or Issues?

- **Backend issues:** Check backend logs or contact backend team
- **API questions:** Refer to `docs/swagger-consultations.yaml`
- **Feature requests:** Open an issue in the repo

### Useful Links

- **API Documentation:** `https://fit-iq-backend.fly.dev/swagger/` (if enabled)
- **Test Script:** `fitiq-backend/test_websocket_goal.py`
- **Backend Code:** `internal/application/consultation/send_message_streaming_use_case.go`

---

## ✅ Final Checklist

Before considering integration complete:

- [ ] Can create consultation with `context_type: "goal"`
- [ ] Can create consultation with `context_id: "{goal_id}"`
- [ ] Response includes new fields (`context_type`, `context_id`, `has_context_for_goal_suggestions`)
- [ ] AI mentions goal explicitly in first response
- [ ] AI references goal details from description
- [ ] UI shows goal context indicator on consultations
- [ ] Can list consultations and filter by status
- [ ] Handles 429 error gracefully (too many active consultations)
- [ ] Cleans up test data properly
- [ ] Manual testing complete with real goal
- [ ] Edge cases tested (no description, deleted goal, etc.)

---

**🎉 You're ready to ship!**

This feature is production-ready and fully tested. The backend has been validated with automated tests and manual verification. If you encounter any issues during integration, refer to the troubleshooting section or reach out to the backend team.

Good luck! 🚀
