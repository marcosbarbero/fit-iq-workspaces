# Journaling API - Implementation Proposal

**Version:** 1.0  
**Date:** 2025-01-14  
**Status:** 🎯 Proposal for Implementation

---

## Executive Summary

This document proposes a dedicated Journaling API for FitIQ Backend that goes beyond the current mood tracking notes field (500 chars) to provide a comprehensive journaling experience.

### Key Differences from Mood Tracking

| Feature | Mood Tracking | Proposed Journaling |
|---------|--------------|---------------------|
| **Primary Focus** | Emotional state (1-10 scale) | Reflection and narrative |
| **Text Length** | 500 characters (notes field) | 10,000 characters |
| **Structure** | Score + emotions + notes | Title + content + tags |
| **Rich Text** | Plain text only | Markdown support |
| **Attachments** | None | Photos, links |
| **Privacy** | Personal only | Public/private options |
| **Prompts** | None | Daily prompts, templates |
| **Search** | Basic filtering | Full-text search |
| **Use Case** | Quick mood check-in | Deep reflection, gratitude, goal tracking |

---

## Architecture

### Domain Layer

#### Entity: JournalEntry

```go
package journal

import (
    "errors"
    "time"
    "github.com/google/uuid"
)

// Domain errors
var (
    ErrInvalidJournalEntryID   = errors.New("journal entry ID cannot be empty")
    ErrInvalidUserID          = errors.New("user ID cannot be empty")
    ErrTitleTooLong           = errors.New("title cannot exceed 200 characters")
    ErrContentTooLong         = errors.New("content cannot exceed 10000 characters")
    ErrContentRequired        = errors.New("content is required")
    ErrInvalidPrivacyLevel    = errors.New("invalid privacy level")
    ErrInvalidEntryType       = errors.New("invalid entry type")
    ErrTooManyTags            = errors.New("maximum 20 tags allowed")
    ErrInvalidLoggedAt        = errors.New("logged_at cannot be in the future")
    ErrTooManyAttachments     = errors.New("maximum 10 attachments allowed")
)

// PrivacyLevel represents journal entry visibility
type PrivacyLevel string

const (
    PrivacyPrivate  PrivacyLevel = "private"   // Only user can see
    PrivacyShared   PrivacyLevel = "shared"    // Shared with specific users
    PrivacyPublic   PrivacyLevel = "public"    // Visible to all users
)

func (p PrivacyLevel) IsValid() bool {
    switch p {
    case PrivacyPrivate, PrivacyShared, PrivacyPublic:
        return true
    default:
        return false
    }
}

// EntryType represents the type of journal entry
type EntryType string

const (
    EntryTypeFreeform    EntryType = "freeform"     // General journaling
    EntryTypeGratitude   EntryType = "gratitude"    // Gratitude practice
    EntryTypeGoalReview  EntryType = "goal_review"  // Goal progress reflection
    EntryTypeWorkout     EntryType = "workout"      // Workout reflection
    EntryTypeMeal        EntryType = "meal"         // Meal/nutrition reflection
    EntryTypePrompt      EntryType = "prompt"       // Guided prompt response
)

func (e EntryType) IsValid() bool {
    switch e {
    case EntryTypeFreeform, EntryTypeGratitude, EntryTypeGoalReview,
         EntryTypeWorkout, EntryTypeMeal, EntryTypePrompt:
        return true
    default:
        return false
    }
}

// Attachment represents a file or link attached to journal entry
type Attachment struct {
    Type string `json:"type"` // photo, link
    URL  string `json:"url"`
    Name string `json:"name"`
}

// JournalEntry represents a journal entry
type JournalEntry struct {
    id            string
    userID        string
    title         string
    content       string
    contentFormat string        // plain, markdown
    entryType     EntryType
    tags          []string
    privacyLevel  PrivacyLevel
    attachments   []Attachment
    promptID      string        // If responding to a prompt
    linkedMoodID  string        // Link to mood entry
    linkedGoalID  string        // Link to goal
    loggedAt      time.Time
    isFavorite    bool
    createdAt     time.Time
    updatedAt     time.Time
}

// NewJournalEntry creates a new journal entry with validation
func NewJournalEntry(
    userID string,
    title string,
    content string,
    contentFormat string,
    entryType EntryType,
    tags []string,
    privacyLevel PrivacyLevel,
    attachments []Attachment,
    loggedAt time.Time,
) (*JournalEntry, error) {
    // Validation
    if userID == "" {
        return nil, ErrInvalidUserID
    }
    if len(title) > 200 {
        return nil, ErrTitleTooLong
    }
    if content == "" {
        return nil, ErrContentRequired
    }
    if len(content) > 10000 {
        return nil, ErrContentTooLong
    }
    if !entryType.IsValid() {
        return nil, ErrInvalidEntryType
    }
    if len(tags) > 20 {
        return nil, ErrTooManyTags
    }
    if !privacyLevel.IsValid() {
        return nil, ErrInvalidPrivacyLevel
    }
    if len(attachments) > 10 {
        return nil, ErrTooManyAttachments
    }
    if loggedAt.After(time.Now()) {
        return nil, ErrInvalidLoggedAt
    }

    now := time.Now()
    return &JournalEntry{
        id:            uuid.New().String(),
        userID:        userID,
        title:         title,
        content:       content,
        contentFormat: contentFormat,
        entryType:     entryType,
        tags:          tags,
        privacyLevel:  privacyLevel,
        attachments:   attachments,
        loggedAt:      loggedAt,
        isFavorite:    false,
        createdAt:     now,
        updatedAt:     now,
    }, nil
}

// Business logic methods
func (j *JournalEntry) UpdateContent(title, content string) error {
    if len(title) > 200 {
        return ErrTitleTooLong
    }
    if content == "" {
        return ErrContentRequired
    }
    if len(content) > 10000 {
        return ErrContentTooLong
    }
    j.title = title
    j.content = content
    j.updatedAt = time.Now()
    return nil
}

func (j *JournalEntry) ToggleFavorite() {
    j.isFavorite = !j.isFavorite
    j.updatedAt = time.Now()
}

func (j *JournalEntry) LinkToMood(moodID string) {
    j.linkedMoodID = moodID
    j.updatedAt = time.Now()
}

func (j *JournalEntry) LinkToGoal(goalID string) {
    j.linkedGoalID = goalID
    j.updatedAt = time.Now()
}

// Getters (standard pattern)
func (j *JournalEntry) ID() string              { return j.id }
func (j *JournalEntry) UserID() string          { return j.userID }
func (j *JournalEntry) Title() string           { return j.title }
func (j *JournalEntry) Content() string         { return j.content }
func (j *JournalEntry) ContentFormat() string   { return j.contentFormat }
func (j *JournalEntry) EntryType() EntryType    { return j.entryType }
func (j *JournalEntry) Tags() []string          { return j.tags }
func (j *JournalEntry) PrivacyLevel() PrivacyLevel { return j.privacyLevel }
func (j *JournalEntry) Attachments() []Attachment { return j.attachments }
func (j *JournalEntry) LoggedAt() time.Time     { return j.loggedAt }
func (j *JournalEntry) IsFavorite() bool        { return j.isFavorite }
func (j *JournalEntry) CreatedAt() time.Time    { return j.createdAt }
func (j *JournalEntry) UpdatedAt() time.Time    { return j.updatedAt }
```

---

## Database Schema

### Migration: 000XXX - Create Journal Entries Table

```sql
-- Create journal_entries table
CREATE TABLE journal_entries (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL,
    content_format TEXT NOT NULL DEFAULT 'plain' CHECK (content_format IN ('plain', 'markdown')),
    entry_type TEXT NOT NULL DEFAULT 'freeform' CHECK (entry_type IN ('freeform', 'gratitude', 'goal_review', 'workout', 'meal', 'prompt')),
    tags TEXT NOT NULL DEFAULT '[]', -- JSON array
    privacy_level TEXT NOT NULL DEFAULT 'private' CHECK (privacy_level IN ('private', 'shared', 'public')),
    attachments TEXT NOT NULL DEFAULT '[]', -- JSON array
    prompt_id TEXT,
    linked_mood_id TEXT,
    linked_goal_id TEXT,
    logged_at TIMESTAMP NOT NULL,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (linked_mood_id) REFERENCES mood_entries(id) ON DELETE SET NULL,
    FOREIGN KEY (linked_goal_id) REFERENCES goals(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX idx_journal_entries_logged_at ON journal_entries(user_id, logged_at DESC);
CREATE INDEX idx_journal_entries_entry_type ON journal_entries(user_id, entry_type);
CREATE INDEX idx_journal_entries_favorites ON journal_entries(user_id, is_favorite, logged_at DESC);

-- Full-text search index (SQLite FTS5)
CREATE VIRTUAL TABLE journal_entries_fts USING fts5(
    entry_id UNINDEXED,
    title,
    content,
    tags,
    content=journal_entries,
    content_rowid=rowid
);

-- Triggers to keep FTS index updated
CREATE TRIGGER journal_entries_ai AFTER INSERT ON journal_entries BEGIN
    INSERT INTO journal_entries_fts(entry_id, title, content, tags)
    VALUES (new.id, new.title, new.content, new.tags);
END;

CREATE TRIGGER journal_entries_au AFTER UPDATE ON journal_entries BEGIN
    UPDATE journal_entries_fts 
    SET title = new.title, content = new.content, tags = new.tags
    WHERE entry_id = new.id;
END;

CREATE TRIGGER journal_entries_ad AFTER DELETE ON journal_entries BEGIN
    DELETE FROM journal_entries_fts WHERE entry_id = old.id;
END;

-- Create journal_prompts table for guided journaling
CREATE TABLE journal_prompts (
    id TEXT PRIMARY KEY,
    category TEXT NOT NULL CHECK (category IN ('gratitude', 'reflection', 'goals', 'wellness', 'creativity')),
    prompt_text TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Insert some default prompts
INSERT INTO journal_prompts (id, category, prompt_text) VALUES
    ('prompt-001', 'gratitude', 'What are three things you''re grateful for today?'),
    ('prompt-002', 'reflection', 'What challenge did you face today and how did you handle it?'),
    ('prompt-003', 'goals', 'What progress did you make toward your goals this week?'),
    ('prompt-004', 'wellness', 'How are you taking care of your mental and physical health?'),
    ('prompt-005', 'creativity', 'Describe a moment today that sparked joy or inspiration.');
```

---

## API Endpoints

### 1. Create Journal Entry
**POST** `/api/v1/journal`

```json
{
  "title": "Great Workout Day",
  "content": "Today I pushed myself harder than ever...",
  "content_format": "markdown",
  "entry_type": "workout",
  "tags": ["fitness", "progress", "motivation"],
  "privacy_level": "private",
  "attachments": [
    {
      "type": "photo",
      "url": "https://cdn.fitiq.com/photos/12345.jpg",
      "name": "Post-workout selfie"
    }
  ],
  "linked_mood_id": "mood-uuid-123",
  "logged_at": "2024-01-15T20:00:00Z"
}
```

### 2. List Journal Entries
**GET** `/api/v1/journal`

Query Parameters:
- `from` (optional): Start date (YYYY-MM-DD)
- `to` (optional): End date (YYYY-MM-DD)
- `entry_type` (optional): Filter by type
- `tags` (optional): Comma-separated tags
- `favorites_only` (optional): Boolean
- `limit` (optional): 1-100, default 30
- `offset` (optional): Pagination offset

### 3. Search Journal Entries
**GET** `/api/v1/journal/search`

Query Parameters:
- `q` (required): Search query
- `limit` (optional): 1-100, default 30
- `offset` (optional): Pagination offset

Full-text search across title, content, and tags.

### 4. Get Journal Entry
**GET** `/api/v1/journal/{id}`

### 5. Update Journal Entry
**PUT** `/api/v1/journal/{id}`

### 6. Delete Journal Entry
**DELETE** `/api/v1/journal/{id}`

### 7. Toggle Favorite
**POST** `/api/v1/journal/{id}/favorite`

### 8. Get Journal Prompts
**GET** `/api/v1/journal/prompts`

Query Parameters:
- `category` (optional): Filter by category

### 9. Get Journal Statistics
**GET** `/api/v1/journal/statistics`

Query Parameters:
- `from` (required): Start date
- `to` (required): End date

Returns:
- Total entries
- Entries by type
- Most used tags
- Writing streak
- Average entry length
- Favorite count

---

## OpenAPI Specification

```yaml
paths:
  /api/v1/journal:
    post:
      summary: Create journal entry
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/JournalEntryRequest"
            examples:
              freeform:
                summary: Free-form journaling
                value:
                  title: "Reflections on Today"
                  content: "Today was a day of growth..."
                  content_format: "markdown"
                  entry_type: "freeform"
                  tags: ["reflection", "personal"]
                  privacy_level: "private"
                  logged_at: "2024-01-15T20:00:00Z"
              gratitude:
                summary: Gratitude entry
                value:
                  title: "Daily Gratitude"
                  content: "I'm grateful for:\n1. My health\n2. My family\n3. This beautiful day"
                  entry_type: "gratitude"
                  tags: ["gratitude"]
                  privacy_level: "private"
                  logged_at: "2024-01-15T20:00:00Z"
              workout_reflection:
                summary: Workout reflection with mood link
                value:
                  title: "PR Day!"
                  content: "Hit a new personal record on squats today..."
                  entry_type: "workout"
                  tags: ["workout", "progress"]
                  linked_mood_id: "mood-123"
                  attachments:
                    - type: "photo"
                      url: "https://cdn.fitiq.com/photos/12345.jpg"
                      name: "PR celebration"
                  privacy_level: "private"
                  logged_at: "2024-01-15T20:00:00Z"
      responses:
        "201":
          description: Journal entry created
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/JournalEntryResponse"
        "400":
          description: Bad Request
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "401":
          description: Unauthorized
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"

    get:
      summary: List journal entries
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: from
          in: query
          schema:
            type: string
            format: date
          description: Start date (YYYY-MM-DD)
        - name: to
          in: query
          schema:
            type: string
            format: date
          description: End date (YYYY-MM-DD)
        - name: entry_type
          in: query
          schema:
            type: string
            enum: [freeform, gratitude, goal_review, workout, meal, prompt]
          description: Filter by entry type
        - name: tags
          in: query
          schema:
            type: string
          description: Comma-separated tags to filter by
        - name: favorites_only
          in: query
          schema:
            type: boolean
            default: false
          description: Return only favorite entries
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 30
        - name: offset
          in: query
          schema:
            type: integer
            minimum: 0
            default: 0
      responses:
        "200":
          description: Journal entries retrieved
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/JournalEntriesListResponse"

  /api/v1/journal/search:
    get:
      summary: Full-text search journal entries
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: q
          in: query
          required: true
          schema:
            type: string
          description: Search query
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 30
        - name: offset
          in: query
          schema:
            type: integer
            minimum: 0
            default: 0
      responses:
        "200":
          description: Search results
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/JournalSearchResponse"

  /api/v1/journal/{id}:
    get:
      summary: Get journal entry by ID
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        "200":
          description: Journal entry retrieved
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/JournalEntryResponse"
        "404":
          description: Not found

    put:
      summary: Update journal entry
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/JournalEntryRequest"
      responses:
        "200":
          description: Journal entry updated
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/JournalEntryResponse"

    delete:
      summary: Delete journal entry
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        "204":
          description: Journal entry deleted

  /api/v1/journal/{id}/favorite:
    post:
      summary: Toggle favorite status
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        "200":
          description: Favorite status toggled
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        type: object
                        properties:
                          is_favorite:
                            type: boolean

  /api/v1/journal/prompts:
    get:
      summary: Get journal prompts
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: category
          in: query
          schema:
            type: string
            enum: [gratitude, reflection, goals, wellness, creativity]
      responses:
        "200":
          description: Prompts retrieved
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        type: object
                        properties:
                          prompts:
                            type: array
                            items:
                              $ref: "#/components/schemas/JournalPrompt"

  /api/v1/journal/statistics:
    get:
      summary: Get journal statistics
      tags: [Journal]
      security:
        - ApiKey: []
        - BearerAuth: []
      parameters:
        - name: from
          in: query
          required: true
          schema:
            type: string
            format: date
        - name: to
          in: query
          required: true
          schema:
            type: string
            format: date
      responses:
        "200":
          description: Statistics retrieved
          content:
            application/json:
              schema:
                allOf:
                  - $ref: "#/components/schemas/StandardResponse"
                  - type: object
                    properties:
                      data:
                        $ref: "#/components/schemas/JournalStatistics"

components:
  schemas:
    JournalEntryRequest:
      type: object
      required: [content, logged_at]
      properties:
        title:
          type: string
          maxLength: 200
          description: Entry title (optional)
        content:
          type: string
          minLength: 1
          maxLength: 10000
          description: Entry content (required)
        content_format:
          type: string
          enum: [plain, markdown]
          default: plain
          description: Content format
        entry_type:
          type: string
          enum: [freeform, gratitude, goal_review, workout, meal, prompt]
          default: freeform
          description: Entry type/category
        tags:
          type: array
          items:
            type: string
          maxItems: 20
          description: Entry tags
        privacy_level:
          type: string
          enum: [private, shared, public]
          default: private
          description: Privacy level
        attachments:
          type: array
          items:
            type: object
            properties:
              type:
                type: string
                enum: [photo, link]
              url:
                type: string
              name:
                type: string
          maxItems: 10
        prompt_id:
          type: string
          format: uuid
          description: Prompt ID if responding to a prompt
        linked_mood_id:
          type: string
          format: uuid
          description: Link to mood entry
        linked_goal_id:
          type: string
          format: uuid
          description: Link to goal
        logged_at:
          type: string
          format: date-time
          description: When entry was written

    JournalEntryResponse:
      type: object
      properties:
        id:
          type: string
          format: uuid
        user_id:
          type: string
          format: uuid
        title:
          type: string
        content:
          type: string
        content_format:
          type: string
          enum: [plain, markdown]
        entry_type:
          type: string
        tags:
          type: array
          items:
            type: string
        privacy_level:
          type: string
        attachments:
          type: array
          items:
            type: object
        prompt_id:
          type: string
          format: uuid
          nullable: true
        linked_mood_id:
          type: string
          format: uuid
          nullable: true
        linked_goal_id:
          type: string
          format: uuid
          nullable: true
        is_favorite:
          type: boolean
        logged_at:
          type: string
          format: date-time
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
      required: [id, user_id, content, entry_type, tags, privacy_level, logged_at, created_at, updated_at]

    JournalEntriesListResponse:
      type: object
      properties:
        entries:
          type: array
          items:
            $ref: "#/components/schemas/JournalEntryResponse"
        total:
          type: integer
        limit:
          type: integer
        offset:
          type: integer
        has_more:
          type: boolean
      required: [entries, total, limit, offset, has_more]

    JournalSearchResponse:
      type: object
      properties:
        results:
          type: array
          items:
            allOf:
              - $ref: "#/components/schemas/JournalEntryResponse"
              - type: object
                properties:
                  relevance_score:
                    type: number
                    description: Search relevance score
        total:
          type: integer
        limit:
          type: integer
        offset:
          type: integer
      required: [results, total, limit, offset]

    JournalPrompt:
      type: object
      properties:
        id:
          type: string
          format: uuid
        category:
          type: string
          enum: [gratitude, reflection, goals, wellness, creativity]
        prompt_text:
          type: string
      required: [id, category, prompt_text]

    JournalStatistics:
      type: object
      properties:
        period:
          type: object
          properties:
            from:
              type: string
              format: date
            to:
              type: string
              format: date
            total_days:
              type: integer
        summary:
          type: object
          properties:
            total_entries:
              type: integer
            entries_by_type:
              type: object
              additionalProperties:
                type: integer
            most_used_tags:
              type: array
              items:
                type: object
                properties:
                  tag:
                    type: string
                  count:
                    type: integer
            writing_streak:
              type: integer
              description: Current consecutive days with entries
            average_entry_length:
              type: number
              description: Average content length in characters
            favorite_count:
              type: integer
```

---

## Implementation Timeline

### Phase 1: Core Functionality (2-3 days)
- Domain entity with validation
- Database migration
- Repository layer (CRUD + search)
- Basic use cases

### Phase 2: API Layer (1-2 days)
- REST handlers
- Request/response DTOs
- OpenAPI spec update
- Integration with existing auth

### Phase 3: Advanced Features (2-3 days)
- Full-text search
- Journal prompts
- Statistics and analytics
- Linking to mood/goals

### Phase 4: Testing (1-2 days)
- Unit tests (100% coverage)
- Integration tests
- E2E tests

**Total Estimate:** 6-10 days

---

## Benefits

### For Users
1. **Deeper Reflection**: 10,000 characters vs 500
2. **Rich Content**: Markdown formatting
3. **Organization**: Tags, types, favorites
4. **Discovery**: Full-text search
5. **Guidance**: Daily prompts
6. **Privacy**: Flexible sharing options
7. **Context**: Link to mood, goals, workouts

### For Product
1. **User Engagement**: Daily journaling habit
2. **Data Insights**: Better understand user journey
3. **Retention**: Journaling drives daily app usage
4. **Differentiation**: Comprehensive wellness platform
5. **Premium Feature**: Potential paid tier for advanced features

### For AI Features
1. **Better Context**: Rich narrative data for AI coaching
2. **Pattern Recognition**: Identify trends and triggers
3. **Personalization**: Tailor recommendations to user's story
4. **Proactive Insights**: AI can suggest reflections

---

## Integration Points

### With Existing Features

1. **Mood Tracking**
   - Link journal entries to mood logs
   - "How are you feeling?" → Auto-suggest journal entry

2. **AI Consultation**
   - AI can reference journal entries for context
   - AI can suggest journal prompts
   - Function: `get_recent_journal_entries(days)`

3. **Goals**
   - Goal review journal type
   - Link progress to reflection
   - "Reflect on your progress" prompt

4. **Workouts**
   - Workout reflection journal type
   - Auto-create journal stub after workout
   - "How did that workout feel?"

5. **Nutrition**
   - Meal journal type
   - "What did you learn from today's eating?"

---

## Security Considerations

1. **Privacy Levels**
   - Private: Only user (default)
   - Shared: Explicit sharing with users/coaches
   - Public: Opt-in community sharing

2. **Data Protection**
   - Journal content is sensitive PII
   - Encryption at rest
   - Strict access controls
   - GDPR/CCPA compliant

3. **Search Privacy**
   - Full-text search limited to user's own entries
   - No cross-user search

---

## Future Enhancements

1. **Rich Editor**: WYSIWYG markdown editor
2. **Voice-to-Text**: Speak your journal entry
3. **Mood Detection**: AI-suggested mood from content
4. **Photo Uploads**: Direct image upload (not just URLs)
5. **Templates**: Pre-built journal templates
6. **Reminders**: Daily journaling reminders
7. **Sharing**: Share entries with coaches/friends
8. **Export**: PDF/email journal entries
9. **Streaks**: Journaling streak tracking
10. **AI Analysis**: AI-generated insights from journals

---

## Comparison: Journaling vs Mood Tracking

### Use Both Together

**Mood Tracking** = Quantitative wellness data
- Quick check-in (< 1 min)
- Score + emotions + brief note
- Daily trends and analytics
- Great for tracking patterns

**Journaling** = Qualitative wellness data
- Deep reflection (5-15 min)
- Narrative, context, insights
- Understanding the "why"
- Great for personal growth

**Optimal User Journey:**
1. Morning: Check mood + brief note
2. Evening: Full journal entry reflecting on day
3. Weekly: Review mood trends + journal highlights
4. Monthly: AI consultation using both data sources

---

## Success Metrics

### Engagement
- % of users who journal weekly
- Average entries per active user
- Favorite/save rate
- Search usage rate

### Quality
- Average entry length
- Markdown usage rate
- Attachment usage rate
- Tag diversity

### Integration
- % entries linked to mood
- % entries linked to goals
- % entries created from prompts
- AI consultation reference rate

---

## Conclusion

A dedicated Journaling API would:
1. ✅ Complement mood tracking (not replace)
2. ✅ Provide deep user insights
3. ✅ Drive daily engagement
4. ✅ Enhance AI capabilities
5. ✅ Differentiate FitIQ platform
6. ✅ Follow clean architecture patterns
7. ✅ Maintain consistent API design

**Recommendation:** Implement in Q1 2025 as high-value feature for user retention and AI enhancement.

---

**Status:** 🎯 Ready for Implementation  
**Priority:** High  
**Estimated Effort:** 6-10 days  
**Dependencies:** None (standalone feature)
