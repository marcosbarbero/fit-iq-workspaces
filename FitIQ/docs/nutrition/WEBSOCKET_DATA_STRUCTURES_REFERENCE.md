# 🔌 WebSocket Data Structures Reference

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Applies To:** FitIQ iOS App + Backend v0.30.0+

---

## 📋 Overview

This document provides a quick reference for the WebSocket notification data structures used in the FitIQ meal logging system. Use this when implementing or debugging WebSocket integration.

---

## 🎯 WebSocket Message Envelope

All WebSocket messages follow this structure:

```json
{
  "type": "message_type",
  "data": { /* payload varies by type */ },
  "timestamp": "2024-01-15T12:30:05Z"
}
```

### Message Types

| Type | Direction | Description |
|------|-----------|-------------|
| `connected` | Server → Client | Connection established |
| `meal_log.completed` | Server → Client | Meal processing succeeded |
| `meal_log.failed` | Server → Client | Meal processing failed |
| `message` | Client → Server | User sends message |
| `ping` | Client → Server | Keep-alive ping |
| `pong` | Server → Client | Keep-alive response |
| `error` | Server → Client | Error notification |

---

## ✅ Success: `meal_log.completed`

### Complete JSON Payload

```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "01234567-89ab-cdef-0123-456789abcdef",
    "user_id": "user-uuid-here",
    "raw_input": "2 scrambled eggs with cheese and whole wheat toast",
    "meal_type": "breakfast",
    "status": "completed",
    "total_calories": 450,
    "total_protein_g": 28.5,
    "total_carbs_g": 32.0,
    "total_fat_g": 18.5,
    "total_fiber_g": 4.2,
    "total_sugar_g": 2.1,
    "logged_at": "2024-01-15T08:30:00Z",
    "processing_started_at": "2024-01-15T08:30:02Z",
    "processing_completed_at": "2024-01-15T08:30:05Z",
    "created_at": "2024-01-15T08:30:00Z",
    "updated_at": "2024-01-15T08:30:05Z",
    "items": [
      {
        "id": "item-uuid-1",
        "meal_log_id": "01234567-89ab-cdef-0123-456789abcdef",
        "food_id": null,
        "user_food_id": null,
        "food_name": "Scrambled Eggs",
        "quantity": 2.0,
        "unit": "large eggs",
        "calories": 200,
        "protein_g": 14.0,
        "carbs_g": 2.0,
        "fat_g": 14.0,
        "fiber_g": 0.0,
        "sugar_g": 2.0,
        "confidence_score": 0.95,
        "parsing_notes": null,
        "order_index": 0,
        "created_at": "2024-01-15T08:30:05Z"
      },
      {
        "id": "item-uuid-2",
        "meal_log_id": "01234567-89ab-cdef-0123-456789abcdef",
        "food_id": null,
        "user_food_id": null,
        "food_name": "Cheddar Cheese",
        "quantity": 30.0,
        "unit": "g",
        "calories": 120,
        "protein_g": 7.0,
        "carbs_g": 1.0,
        "fat_g": 10.0,
        "fiber_g": 0.0,
        "sugar_g": 0.1,
        "confidence_score": 0.92,
        "parsing_notes": null,
        "order_index": 1,
        "created_at": "2024-01-15T08:30:05Z"
      },
      {
        "id": "item-uuid-3",
        "meal_log_id": "01234567-89ab-cdef-0123-456789abcdef",
        "food_id": null,
        "user_food_id": null,
        "food_name": "Whole Wheat Toast",
        "quantity": 2.0,
        "unit": "slices",
        "calories": 130,
        "protein_g": 7.5,
        "carbs_g": 29.0,
        "fat_g": 1.5,
        "fiber_g": 4.2,
        "sugar_g": 0.0,
        "confidence_score": 0.98,
        "parsing_notes": null,
        "order_index": 2,
        "created_at": "2024-01-15T08:30:05Z"
      }
    ]
  },
  "timestamp": "2024-01-15T08:30:05Z"
}
```

### Swift Codable Model

```swift
struct MealLogCompletedData: Codable {
    let id: String
    let userId: String
    let rawInput: String?
    let mealType: String
    let status: String
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let totalFiberG: Double?      // ✨ NEW
    let totalSugarG: Double?      // ✨ NEW
    let loggedAt: Date
    let processingStartedAt: Date?
    let processingCompletedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let items: [MealLogItem]
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rawInput = "raw_input"
        case mealType = "meal_type"
        case status
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"      // ✨ NEW
        case totalSugarG = "total_sugar_g"      // ✨ NEW
        case loggedAt = "logged_at"
        case processingStartedAt = "processing_started_at"
        case processingCompletedAt = "processing_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
    }
}

struct MealLogItem: Codable {
    let id: String
    let mealLogId: String
    let foodId: String?
    let userFoodId: String?
    let foodName: String
    let quantity: Double
    let unit: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?          // ✨ NEW (optional)
    let sugarG: Double?          // ✨ NEW (optional)
    let confidenceScore: Double?
    let parsingNotes: String?
    let orderIndex: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case mealLogId = "meal_log_id"
        case foodId = "food_id"
        case userFoodId = "user_food_id"
        case foodName = "food_name"
        case quantity
        case unit
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"        // ✨ NEW
        case sugarG = "sugar_g"        // ✨ NEW
        case confidenceScore = "confidence_score"
        case parsingNotes = "parsing_notes"
        case orderIndex = "order_index"
        case createdAt = "created_at"
    }
}
```

---

## ❌ Failure: `meal_log.failed`

### Complete JSON Payload

```json
{
  "type": "meal_log.failed",
  "data": {
    "id": "01234567-89ab-cdef-0123-456789abcdef",
    "user_id": "user-uuid-here",
    "raw_input": "xyz123 invalid food",
    "meal_type": "lunch",
    "status": "failed",
    "error_message": "Unable to parse food items from input",
    "logged_at": "2024-01-15T12:30:00Z",
    "created_at": "2024-01-15T12:30:00Z",
    "updated_at": "2024-01-15T12:30:05Z"
  },
  "timestamp": "2024-01-15T12:30:05Z"
}
```

### Swift Codable Model

```swift
struct MealLogFailedData: Codable {
    let id: String
    let userId: String
    let rawInput: String?
    let mealType: String
    let status: String
    let errorMessage: String?
    let loggedAt: Date
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rawInput = "raw_input"
        case mealType = "meal_type"
        case status
        case errorMessage = "error_message"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

---

## 🔗 Connection Messages

### Connected

```json
{
  "type": "connected",
  "data": {
    "consultation_id": "consultation-uuid",
    "timestamp": "2024-01-15T12:30:00Z"
  },
  "timestamp": "2024-01-15T12:30:00Z"
}
```

### Pong (Keep-Alive Response)

```json
{
  "type": "pong",
  "data": null,
  "timestamp": "2024-01-15T12:30:00Z"
}
```

### Error

```json
{
  "type": "error",
  "data": {
    "error": "Authentication failed",
    "code": "AUTH_ERROR"
  },
  "timestamp": "2024-01-15T12:30:00Z"
}
```

---

## 📊 Field Reference Table

### Meal Log Level

| Field | Type | Nullable | Description | Example |
|-------|------|----------|-------------|---------|
| `id` | String (UUID) | No | Meal log unique ID | `"01234567-89ab-cdef..."` |
| `user_id` | String (UUID) | No | User who created the log | `"user-uuid-here"` |
| `raw_input` | String | Yes | Original natural language input | `"2 eggs"` |
| `meal_type` | String | No | Type of meal | `"breakfast"`, `"lunch"`, `"dinner"`, `"snack"` |
| `status` | String | No | Processing status | `"completed"`, `"failed"` |
| `total_calories` | Integer | Yes | Sum of all item calories | `450` |
| `total_protein_g` | Double | Yes | Sum of all item protein (g) | `28.5` |
| `total_carbs_g` | Double | Yes | Sum of all item carbs (g) | `32.0` |
| `total_fat_g` | Double | Yes | Sum of all item fat (g) | `18.5` |
| `total_fiber_g` | Double | Yes | Sum of all item fiber (g) ✨ | `4.2` |
| `total_sugar_g` | Double | Yes | Sum of all item sugar (g) ✨ | `2.1` |
| `logged_at` | ISO8601 | No | When meal was consumed | `"2024-01-15T08:30:00Z"` |
| `processing_started_at` | ISO8601 | Yes | When AI processing started | `"2024-01-15T08:30:02Z"` |
| `processing_completed_at` | ISO8601 | Yes | When AI processing completed | `"2024-01-15T08:30:05Z"` |
| `created_at` | ISO8601 | No | When log was created | `"2024-01-15T08:30:00Z"` |
| `updated_at` | ISO8601 | No | When log was last updated | `"2024-01-15T08:30:05Z"` |
| `items` | Array | No | Food items (can be empty) | `[...]` |

### Item Level

| Field | Type | Nullable | Description | Example |
|-------|------|----------|-------------|---------|
| `id` | String (UUID) | No | Item unique ID | `"item-uuid-1"` |
| `meal_log_id` | String (UUID) | No | Parent meal log ID | `"01234567-89ab..."` |
| `food_id` | String (UUID) | Yes | Reference to global foods DB | `null` or `"food-uuid"` |
| `user_food_id` | String (UUID) | Yes | Reference to user's custom foods | `null` or `"user-food-uuid"` |
| `food_name` | String | No | Name of the food | `"Scrambled Eggs"` |
| `quantity` | Double | No | Amount consumed ✨ | `2.0` |
| `unit` | String | No | Unit of measurement ✨ | `"large eggs"`, `"g"`, `"cups"` |
| `calories` | Integer | No | Calories in kcal | `200` |
| `protein_g` | Double | No | Protein in grams | `14.0` |
| `carbs_g` | Double | No | Carbohydrates in grams | `2.0` |
| `fat_g` | Double | No | Fat in grams | `14.0` |
| `fiber_g` | Double | Yes | Fiber in grams ✨ | `0.0` or `null` |
| `sugar_g` | Double | Yes | Sugar in grams ✨ | `2.0` or `null` |
| `confidence_score` | Double | Yes | AI confidence (0.0-1.0) | `0.95` |
| `parsing_notes` | String | Yes | Notes from AI parsing | `null` |
| `order_index` | Integer | No | Display order (0-based) ✨ | `0`, `1`, `2` |
| `created_at` | ISO8601 | No | When item was created | `"2024-01-15T08:30:05Z"` |

**✨ = New or changed field in v1.0.0**

---

## 🎨 Meal Type Values

| Value | Display Name |
|-------|--------------|
| `breakfast` | Breakfast |
| `lunch` | Lunch |
| `dinner` | Dinner |
| `snack` | Snack |

---

## 🎯 Status Values

| Value | Description | Final State |
|-------|-------------|-------------|
| `pending` | Waiting to process | No |
| `processing` | AI processing in progress | No |
| `completed` | Successfully processed | Yes |
| `failed` | Processing failed | Yes |

---

## 📏 Confidence Score Interpretation

| Score | Interpretation | Action |
|-------|----------------|--------|
| `0.0 - 0.5` | Low confidence | Show warning, suggest manual review |
| `0.5 - 0.8` | Medium confidence | Display normally |
| `0.8 - 1.0` | High confidence | Display with confidence indicator |

---

## 🔧 Date Handling

All dates are in **ISO 8601 format** with UTC timezone:

```
2024-01-15T12:30:05Z
```

### Swift Decoding

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

let message = try decoder.decode(WebSocketMessage.self, from: data)
```

### Swift Encoding

```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601

let data = try encoder.encode(message)
```

---

## 🔍 Field Nullability Rules

### Always Present (Non-Nullable)
- `id`, `user_id`, `meal_type`, `status`, `logged_at`, `created_at`, `updated_at`
- Item: `id`, `meal_log_id`, `food_name`, `quantity`, `unit`, `calories`, `protein_g`, `carbs_g`, `fat_g`, `order_index`, `created_at`

### Optional (Nullable)
- `raw_input` (if manually created without text input)
- `processing_started_at`, `processing_completed_at` (only for AI-processed meals)
- `total_calories`, `total_protein_g`, etc. (only after processing completes)
- `error_message` (only if failed)
- Item: `food_id`, `user_food_id`, `fiber_g`, `sugar_g`, `confidence_score`, `parsing_notes`

---

## ⚠️ Common Gotchas

### 1. Optional Fiber/Sugar
Not all foods have fiber/sugar data. Always handle `null`:

```swift
if let fiber = item.fiberG {
    print("Fiber: \(fiber)g")
} else {
    print("Fiber: N/A")
}
```

### 2. Quantity Changed from String to Double
**Before:** `"quantity": "2 large eggs"`  
**After:** `"quantity": 2.0, "unit": "large eggs"`

### 3. Items Array Can Be Empty
A meal log can exist without items (if processing failed or pending):

```swift
if mealLog.items.isEmpty {
    // Show "No items yet" state
}
```

### 4. Confidence Score Only for AI-Parsed Items
Manually entered items may have `confidence_score: null`.

### 5. Order Index Matters
Always sort items by `order_index` before displaying:

```swift
let sortedItems = mealLog.items.sorted { $0.orderIndex < $1.orderIndex }
```

---

## 🧪 Test Data Examples

### Minimal Meal (1 item, no optionals)

```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "meal-123",
    "user_id": "user-456",
    "raw_input": "apple",
    "meal_type": "snack",
    "status": "completed",
    "total_calories": 95,
    "total_protein_g": 0.5,
    "total_carbs_g": 25.0,
    "total_fat_g": 0.3,
    "total_fiber_g": null,
    "total_sugar_g": null,
    "logged_at": "2024-01-15T10:00:00Z",
    "processing_completed_at": "2024-01-15T10:00:03Z",
    "created_at": "2024-01-15T10:00:00Z",
    "updated_at": "2024-01-15T10:00:03Z",
    "items": [
      {
        "id": "item-1",
        "meal_log_id": "meal-123",
        "food_name": "Apple",
        "quantity": 1.0,
        "unit": "medium",
        "calories": 95,
        "protein_g": 0.5,
        "carbs_g": 25.0,
        "fat_g": 0.3,
        "fiber_g": null,
        "sugar_g": null,
        "confidence_score": 0.99,
        "parsing_notes": null,
        "order_index": 0,
        "created_at": "2024-01-15T10:00:03Z"
      }
    ]
  },
  "timestamp": "2024-01-15T10:00:03Z"
}
```

### Complex Meal (3 items, all optionals)

```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "meal-789",
    "user_id": "user-456",
    "raw_input": "chicken breast with rice and broccoli",
    "meal_type": "lunch",
    "status": "completed",
    "total_calories": 520,
    "total_protein_g": 52.0,
    "total_carbs_g": 55.0,
    "total_fat_g": 8.5,
    "total_fiber_g": 6.2,
    "total_sugar_g": 1.8,
    "logged_at": "2024-01-15T12:30:00Z",
    "processing_completed_at": "2024-01-15T12:30:05Z",
    "created_at": "2024-01-15T12:30:00Z",
    "updated_at": "2024-01-15T12:30:05Z",
    "items": [
      {
        "id": "item-1",
        "food_name": "Grilled Chicken Breast",
        "quantity": 200.0,
        "unit": "g",
        "calories": 330,
        "protein_g": 62.0,
        "carbs_g": 0.0,
        "fat_g": 7.2,
        "fiber_g": 0.0,
        "sugar_g": 0.0,
        "confidence_score": 0.95,
        "order_index": 0
      },
      {
        "id": "item-2",
        "food_name": "Brown Rice",
        "quantity": 150.0,
        "unit": "g",
        "calories": 165,
        "protein_g": 3.8,
        "carbs_g": 35.0,
        "fat_g": 1.3,
        "fiber_g": 1.8,
        "sugar_g": 0.3,
        "confidence_score": 0.98,
        "order_index": 1
      },
      {
        "id": "item-3",
        "food_name": "Steamed Broccoli",
        "quantity": 100.0,
        "unit": "g",
        "calories": 35,
        "protein_g": 2.8,
        "carbs_g": 7.0,
        "fat_g": 0.4,
        "fiber_g": 2.6,
        "sugar_g": 1.7,
        "confidence_score": 0.92,
        "order_index": 2
      }
    ]
  }
}
```

---

## 📖 Related Documentation

- **Integration Guide:** `MEAL_LOG_INTEGRATION.md`
- **Implementation Status:** `IOS_WEBSOCKET_IMPLEMENTATION_STATUS.md`
- **Enhancement Report:** `WEBSOCKET_NOTIFICATION_ENHANCEMENT.md`
- **API Spec:** `../be-api-spec/swagger.yaml` (lines 2904-3208)

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Maintained By:** FitIQ Engineering Team