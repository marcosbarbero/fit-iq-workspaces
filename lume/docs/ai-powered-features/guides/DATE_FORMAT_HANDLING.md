# Date Format Handling in FitIQ API

**Last Updated:** January 28, 2025  
**API Version:** 0.22.1+  
**Status:** ✅ Production Ready

---

## 📋 Overview

The FitIQ API now supports **flexible date format parsing** for all `date_of_birth` fields. This means you can send dates in multiple formats, and the backend will handle them correctly.

### ✅ Supported Formats

The API accepts the following date formats:

1. **Date-only (YYYY-MM-DD)** - **RECOMMENDED** ⭐
   ```
   "1983-07-20"
   ```

2. **RFC3339 with Z (UTC)**
   ```
   "1983-07-20T00:00:00Z"
   ```

3. **RFC3339 with timezone offset**
   ```
   "1983-07-20T10:30:00-05:00"
   ```

4. **RFC3339 with milliseconds**
   ```
   "1983-07-20T15:04:05.123Z"
   ```

5. **RFC3339 with milliseconds and timezone**
   ```
   "1983-07-20T15:04:05.123-03:00"
   ```

6. **RFC3339 with nanoseconds**
   ```
   "1983-07-20T15:04:05.123456789Z"
   ```

---

## 🎯 Why This Matters

### **Problem**
Go's standard `time.Time` type expects RFC3339 format by default when parsing JSON, which can be confusing for API consumers who naturally want to send simple date strings like `"1983-07-20"` for date-of-birth fields.

### **Solution**
We implemented a custom `FlexibleDate` type that accepts multiple date formats, making the API more developer-friendly while maintaining type safety and validation.

---

## 🔧 Swift Integration Examples

### Example 1: Using Date-only Format (Recommended)

```swift
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    
    let dateOfBirth: String  // Send as "YYYY-MM-DD"
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case name
        
        case dateOfBirth = "date_of_birth"
    }
}

// Usage
let request = RegisterRequest(
    email: "marcos@example.com",
    password: "SecurePass123",
    name: "Marcos Barbero",
    
    dateOfBirth: "1983-07-20"  // ✅ Simple and clean
)
```

### Example 2: Using Swift Date with ISO8601

```swift
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    
    let dateOfBirth: Date
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case name
        
        case dateOfBirth = "date_of_birth"
    }
}

// Configure your JSON encoder
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601  // Sends as RFC3339

// Usage
let dateOfBirth = DateComponents(
    calendar: .current,
    year: 1983,
    month: 7,
    day: 20
).date!

let request = RegisterRequest(
    email: "marcos@example.com",
    password: "SecurePass123",
    name: "Marcos Barbero",
    
    dateOfBirth: dateOfBirth  // ✅ Will be encoded as RFC3339
)
```

### Example 3: Custom Date Formatter (Most Control)

```swift
extension DateFormatter {
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    
    let dateOfBirth: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case name
        
        case dateOfBirth = "date_of_birth"
    }
    
    init(email: String, password: String, firstName: String, lastName: String, dateOfBirth: Date) {
        self.email = email
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = DateFormatter.dateOnly.string(from: dateOfBirth)
    }
}
```

---

## 📍 Affected Endpoints

### 1. **User Registration** (Required Field)
- **Endpoint:** `POST /api/v1/auth/register`
- **Field:** `date_of_birth` (required)
- **Validation:** Must be 13+ years old (COPPA compliance)

```bash
# Example cURL
curl -X POST https://fit-iq-backend.fly.dev/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{
    "email": "marcos@example.com",
    "password": "SecurePass123",
    "name": "Marcos Barbero",
    "date_of_birth": "1983-07-20"
  }'
```

### 2. **Update Physical Profile** (Optional Field)
- **Endpoint:** `PUT /api/v1/profiles/physical`
- **Field:** `date_of_birth` (optional)
- **Validation:** Must be 13+ years old if provided

```bash
# Example cURL
curl -X PUT https://fit-iq-backend.fly.dev/api/v1/profiles/physical \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "biological_sex": "male",
    "height_cm": 180.5,
    "date_of_birth": "1983-07-20"
  }'
```

---

## 🚨 Error Handling

### Invalid Date Format Error

If you send an invalid date format, you'll receive:

```json
{
  "success": false,
  "error": {
    "message": "invalid date format: expected YYYY-MM-DD or RFC3339, got \"07/20/1983\"",
    "code": "VALIDATION_FAILED"
  }
}
```

**HTTP Status:** `400 Bad Request`

### COPPA Compliance Error

If the user is under 13 years old:

```json
{
  "success": false,
  "error": {
    "message": "User must be at least 13 years old (COPPA compliance). Age: 10 years",
    "code": "VALIDATION_FAILED"
  }
}
```

**HTTP Status:** `400 Bad Request`

### Future Date Error

If the date is in the future:

```json
{
  "success": false,
  "error": {
    "message": "Date of birth cannot be in the future",
    "code": "VALIDATION_FAILED"
  }
}
```

**HTTP Status:** `400 Bad Request`

---

## ✅ Best Practices for iOS

### 1. **Use Date-only Format When Possible**
```swift
// ✅ GOOD - Simple and clean
"date_of_birth": "1983-07-20"

// ⚠️ WORKS BUT UNNECESSARY - Adds complexity
"date_of_birth": "1983-07-20T00:00:00Z"
```

### 2. **Handle Timezones Carefully**
When using Swift's `Date` type, be aware that dates are stored with time information. For birth dates, you typically want to ignore time:

```swift
// ✅ GOOD - Use date components
let dateOfBirth = DateComponents(
    calendar: .current,
    year: 1983,
    month: 7,
    day: 20
).date!

// ❌ BAD - Could have timezone issues
let dateOfBirth = Date() // Current timestamp
```

### 3. **Validate Before Sending**
```swift
func isValidAge(birthDate: Date) -> Bool {
    let calendar = Calendar.current
    let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
    return (ageComponents.year ?? 0) >= 13
}

// Use before making API call
if !isValidAge(birthDate: userBirthDate) {
    // Show error to user
    return
}
```

### 4. **Store Dates Appropriately in SwiftData**
```swift
@Model
class SDUserProfile {
    var id: UUID
    var fullName: String
    var dateOfBirth: Date?  // Optional - use Date type
    
    // When sending to API, convert to string
    func toAPIRequest() -> UpdateProfileRequest {
        return UpdateProfileRequest(
            fullName: fullName,
            dateOfBirth: dateOfBirth.map { 
                DateFormatter.dateOnly.string(from: $0) 
            }
        )
    }
}
```

---

## 🧪 Testing Examples

### Unit Test: Date Format Conversion

```swift
import XCTest

class DateFormattingTests: XCTestCase {
    
    func testDateOnlyFormat() {
        let dateString = "1983-07-20"
        let request = RegisterRequest(
            email: "test@example.com",
            password: "pass123",
            firstName: "Test",
            lastName: "User",
            dateOfBirth: dateString
        )
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"date_of_birth\":\"1983-07-20\""))
    }
    
    func testAgeValidation() {
        // Test user under 13 (should fail COPPA)
        let tenYearsAgo = Calendar.current.date(
            byAdding: .year, 
            value: -10, 
            to: Date()
        )!
        
        XCTAssertFalse(isValidAge(birthDate: tenYearsAgo))
        
        // Test user over 13 (should pass)
        let twentyYearsAgo = Calendar.current.date(
            byAdding: .year,
            value: -20,
            to: Date()
        )!
        
        XCTAssertTrue(isValidAge(birthDate: twentyYearsAgo))
    }
}
```

---

## 📝 Response Format

The API always returns dates in **RFC3339 format** for consistency:

```json
{
  "success": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "marcos@example.com",
    "name": "Marcos Barbero",
    "created_at": "2025-01-28T10:30:00Z",
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc..."
  }
}
```

When fetching profile information:

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Marcos Barbero",
    "bio": null,
    "preferred_unit_system": "metric",
    "language_code": "en",
    "biological_sex": "male",
    "height_cm": 180.5,
    "date_of_birth": "1983-07-20T00:00:00Z"  // ← Always RFC3339 in response
  }
}
```

**Note:** Even if you send `"1983-07-20"`, the API returns `"1983-07-20T00:00:00Z"`.

---

## 🔍 Debugging Tips

### 1. **Check Your JSON Payload**
Before sending, log your JSON:
```swift
if let jsonData = try? encoder.encode(request),
   let jsonString = String(data: jsonData, encoding: .utf8) {
    print("JSON Payload: \(jsonString)")
}
```

### 2. **Verify Date Format**
Use a simple regex check:
```swift
func isValidDateFormat(_ dateString: String) -> Bool {
    let pattern = "^\\d{4}-\\d{2}-\\d{2}$"
    return dateString.range(of: pattern, options: .regularExpression) != nil
}
```

### 3. **Test with cURL First**
Before implementing in your app, test with cURL to isolate issues:
```bash
curl -v -X POST https://fit-iq-backend.fly.dev/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-key" \
  -d '{"email":"test@example.com","password":"pass","first_name":"Test","last_name":"User","date_of_birth":"1983-07-20"}'
```

---

## 🎓 Technical Details

### Backend Implementation

The backend uses a custom `FlexibleDate` type that:

1. **Accepts multiple formats during unmarshalling** (JSON → Go)
2. **Always outputs RFC3339 format during marshalling** (Go → JSON)
3. **Maintains timezone information** when provided
4. **Defaults to UTC** for date-only formats

### Source Code Reference

- **Type Definition:** `internal/shared/flexible_date.go`
- **Tests:** `internal/shared/flexible_date_test.go`
- **Usage:** `internal/application/user/register_user.go`

### Format Parsing Order

The backend tries formats in this order:
1. `2006-01-02` (Date only)
2. RFC3339 standard
3. RFC3339 with milliseconds
4. RFC3339 with milliseconds and timezone
5. RFC3339 with nanoseconds

**First match wins** - this ensures optimal performance.

---

## 📚 Related Documentation

- **Authentication Guide:** `getting-started/01-setup.md`
- **API Reference:** `_archive/API_REFERENCE.md`
- **Error Handling:** `guides/ERROR_HANDLING.md` (if exists)
- **Swagger/OpenAPI:** `../../swagger.yaml`

---

## ✅ Summary

| Aspect | Recommendation |
|--------|----------------|
| **Format to Send** | `"YYYY-MM-DD"` (date-only) |
| **Format Received** | `"YYYY-MM-DDTHH:MM:SSZ"` (RFC3339) |
| **Swift Type** | `String` (simplest) or `Date` (with encoder config) |
| **Validation** | Age ≥ 13 years (COPPA), not in future |
| **Affected Endpoints** | Registration (required), Profile update (optional) |
| **Error Handling** | 400 with descriptive error message |

---

## 🆘 Troubleshooting

### "Invalid request payload" Error

**Symptom:** Getting 400 error with `"Invalid request payload"` message.

**Causes & Solutions:**

1. **Wrong date format** → Use `"YYYY-MM-DD"` or RFC3339
2. **Missing required fields** → Include all: email, password, first_name, last_name, date_of_birth
3. **Invalid JSON** → Check for syntax errors (trailing commas, quotes)
4. **Wrong Content-Type** → Must be `application/json`

### Date Parsing Issues in Swift

**Symptom:** Dates not encoding/decoding correctly.

**Solution:** Use a custom date formatter:
```swift
extension JSONDecoder {
    static var fitIQ: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var fitIQ: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let dateString = formatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        }
        return encoder
    }
}
```

---

**Last Updated:** January 28, 2025  
**Questions?** Check the main integration guide or Swagger documentation.