# Mood API Quick Reference Card

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Base URL:** `https://fit-iq-backend.fly.dev/api/v1`

---

## 🚀 Quick Start

### Authentication
```http
X-API-Key: YOUR_API_KEY
Authorization: Bearer YOUR_JWT_TOKEN
```

### Minimal Mood Entry
```json
POST /api/v1/mood
{
  "labels": ["happy"]
}
```

### HKStateOfMind Entry
```json
POST /api/v1/mood
{
  "valence": 0.65,
  "labels": ["happy", "energetic"],
  "associations": ["exercise", "social"],
  "source": "healthkit",
  "source_id": "HK-MOOD-{UUID}"
}
```

---

## 📡 Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/mood` | Create mood entry |
| GET | `/mood` | List mood entries (paginated) |
| GET | `/mood/{id}` | Get specific entry |
| PUT | `/mood/{id}` | Update entry (manual only) |
| DELETE | `/mood/{id}` | Delete entry (manual only) |
| GET | `/mood/daily/{date}` | Daily aggregate |
| GET | `/mood/trends` | Trend analysis |
| GET | `/mood/analytics/labels` | Label frequency |
| GET | `/mood/analytics/associations` | Association impact |

---

## 📊 Data Fields

### Request Fields

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `valence` | float | No* | -1.0 to 1.0 |
| `labels` | array[string] | No* | 1-10 items, max 50 chars each |
| `associations` | array[string] | No | 0-10 items, max 50 chars each |
| `logged_at` | datetime | No | RFC3339, defaults to now |
| `source` | enum | No | `healthkit`, `manual`, `ai_analysis` |
| `source_id` | string | No** | Max 255 chars, unique |
| `notes` | string | No | Max 1000 chars |
| `mood_score` | int | No* | 1-10 (deprecated) |

\* At least one of `valence`, `labels`, or `mood_score` required  
\** Required for HealthKit to prevent duplicates

### Response Fields

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "valence": 0.6,
  "labels": ["happy"],
  "associations": ["exercise"],
  "logged_at": "2024-01-15T14:30:00Z",
  "source": "healthkit",
  "source_id": "HK-MOOD-...",
  "notes": "...",
  "created_at": "2024-01-15T14:30:05Z",
  "updated_at": null
}
```

---

## 🎯 Common Labels

**Positive:** happy, joyful, excited, content, peaceful, calm, relaxed, energetic, confident, grateful, proud, optimistic

**Neutral:** neutral, indifferent, contemplative, focused, alert

**Negative:** sad, angry, anxious, stressed, frustrated, overwhelmed, tired, irritated, lonely, worried, disappointed, bored

---

## 🔗 Common Associations

**Activities:** exercise, work, social, hobbies, travel, sleep, meditation

**Relationships:** family, friends, partner, colleagues

**Health:** health, illness, pain, medication

**Environment:** weather, home, nature, commute

**Situations:** finances, deadlines, conflict, achievement, celebration

---

## 💡 Code Examples

### iOS: Fetch HKStateOfMind
```swift
import HealthKit

let stateOfMindType = HKObjectType.categoryType(forIdentifier: .stateOfMind)!
let predicate = HKQuery.predicateForSamples(
    withStart: startDate,
    end: endDate,
    options: .strictStartDate
)

let query = HKSampleQuery(
    sampleType: stateOfMindType,
    predicate: predicate,
    limit: HKObjectQueryNoLimit,
    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
) { query, samples, error in
    guard let stateOfMindSamples = samples as? [HKStateOfMind] else { return }
    // Process samples
}

healthStore.execute(query)
```

### iOS: Convert to API Payload
```swift
extension HKStateOfMind {
    func toAPIPayload() -> [String: Any] {
        return [
            "valence": self.valence,
            "labels": self.labels.map { $0.rawValue.lowercased() },
            "associations": self.associations.map { $0.rawValue.lowercased() },
            "logged_at": ISO8601DateFormatter().string(from: self.startDate),
            "source": "healthkit",
            "source_id": "HK-MOOD-\(self.uuid.uuidString)"
        ]
    }
}
```

### iOS: Save with Use Case
```swift
let moodEntry = MoodEntry(
    id: UUID(),
    userID: currentUserID,
    valence: 0.65,
    labels: ["happy", "energetic"],
    associations: ["exercise"],
    date: Date(),
    notes: nil,
    syncStatus: .pending,
    sourceID: "HK-MOOD-\(stateOfMind.uuid)"
)

// Repository automatically triggers Outbox Pattern
try await moodRepository.save(moodEntry: moodEntry, forUserID: currentUserID)
```

---

## 🔍 Query Examples

### Get Recent Entries
```http
GET /api/v1/mood?limit=20&offset=0
```

### Filter by Date Range
```http
GET /api/v1/mood?from=2024-01-01&to=2024-01-31
```

### Filter by Label
```http
GET /api/v1/mood?label=happy
```

### Filter by Valence Range (positive moods)
```http
GET /api/v1/mood?min_valence=0.3
```

### Get Daily Aggregate
```http
GET /api/v1/mood/daily/2024-01-15?include_entries=true
```

### Get Monthly Trends
```http
GET /api/v1/mood/trends?from=2024-01-01&to=2024-01-31
```

### Top Labels (Last 30 Days)
```http
GET /api/v1/mood/analytics/labels?limit=10
```

### Association Impact Analysis
```http
GET /api/v1/mood/analytics/associations?from=2024-01-01&to=2024-01-31
```

---

## ⚠️ Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| `INVALID_VALENCE` | Valence out of range | Use -1.0 to 1.0 |
| `INVALID_LABELS` | Empty labels array | Provide at least 1 label |
| `INSUFFICIENT_DATA` | No mood data | Provide valence, labels, or mood_score |
| `DUPLICATE_SOURCE_ID` | Entry already exists | Returns existing entry (200 OK) |
| `HEALTHKIT_READ_ONLY` | Cannot modify HealthKit entry | Only manual entries can be edited |

---

## ✅ Validation Rules

- **Valence:** Must be between -1.0 and +1.0
- **Labels:** 1-10 items, each 1-50 characters
- **Associations:** 0-10 items, each 1-50 characters
- **Notes:** Maximum 1000 characters
- **Source ID:** Maximum 255 characters, must be unique per user
- **At least one required:** valence, labels, or mood_score

---

## 🔄 Valence ↔ Mood Score Conversion

### Legacy to Valence
```
valence = (mood_score - 5.5) / 4.5

Examples:
1  → -1.00 (very unpleasant)
3  → -0.56
5  → -0.11
6  →  0.11
8  →  0.56
10 →  1.00 (very pleasant)
```

### Valence to Legacy (Display)
```
mood_score = round(valence * 4.5 + 5.5)
```

---

## 🎨 UI Recommendations

### Valence Scale Display
```
-1.0 to -0.6: 😞 Very Unpleasant (Red)
-0.6 to -0.2: 😕 Unpleasant (Orange)
-0.2 to  0.2: 😐 Neutral (Yellow)
 0.2 to  0.6: 🙂 Pleasant (Light Green)
 0.6 to  1.0: 😊 Very Pleasant (Green)
```

### Label Pills
```swift
HStack {
    ForEach(labels, id: \.self) { label in
        Text(label)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)
    }
}
```

---

## 📈 Analytics Interpretation

### Trend Direction
- **Improving:** Valence increasing over time ↗️
- **Stable:** Consistent mood, low variation →
- **Declining:** Valence decreasing over time ↘️
- **Insufficient Data:** Need more entries for analysis

### Valence Impact
- **Positive:** Average valence > 0.2
- **Neutral:** Average valence between -0.2 and 0.2
- **Negative:** Average valence < -0.2

---

## 🔒 Security Notes

- All endpoints require authentication (API Key + JWT)
- Users can only access their own mood data
- HealthKit entries are immutable (read-only)
- Manual entries can be modified by owner
- Rate limit: 100 POST/hour, 500 GET/hour

---

## 📚 Resources

- **Full Specification:** [mood-api-spec.yaml](./mood-api-spec.yaml)
- **Integration Guide:** [MOOD_API_INTEGRATION_GUIDE.md](./MOOD_API_INTEGRATION_GUIDE.md)
- **HKStateOfMind Docs:** https://developer.apple.com/documentation/healthkit/hkstateofmind
- **Backend API Spec:** [swagger.yaml](../be-api-spec/swagger.yaml)

---

## 🐛 Common Issues

### Issue: Duplicate entries from HealthKit
**Solution:** Always use `source_id` with HealthKit UUID
```swift
source_id: "HK-MOOD-\(stateOfMind.uuid.uuidString)"
```

### Issue: Entries not syncing
**Solution:** Check sync status, Outbox Pattern handles retries automatically
```swift
if entry.syncStatus == .failed {
    // Outbox will retry, show UI feedback
}
```

### Issue: Cannot update HealthKit entry
**Solution:** HealthKit entries are read-only by design
```json
{
  "error": {
    "message": "Cannot modify HealthKit entries",
    "code": "HEALTHKIT_READ_ONLY"
  }
}
```

---

**Quick Reference v1.0.0** • Updated: 2025-01-27