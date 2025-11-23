# Lume Journaling Feature - Implementation Plan

**Date:** 2025-01-15  
**Status:** 🚀 Ready to Implement  
**Target:** Phase 1 - Core Functionality

---

## Overview

This plan outlines the step-by-step implementation of the Journaling feature for the Lume iOS app, following the existing architecture patterns and maintaining consistency with the Mood Tracking feature while keeping both features independent.

---

## Current State Analysis

### ✅ What Exists
- Basic `JournalEntry` domain entity (simple structure)
- `JournalRepositoryProtocol` port definition
- Placeholder UI in `MainTabView.swift`
- Architecture patterns from Mood Tracking to follow

### ❌ What's Missing
- Enhanced domain model with rich features
- SwiftData persistence layer
- Repository implementation
- ViewModel and use cases
- Complete UI implementation
- Dependency injection setup
- Backend integration (future)

---

## Architecture Overview

Following Lume's Hexagonal Architecture:

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  ┌────────────────────────────────┐    │
│  │ Views (SwiftUI)                │    │
│  │ - JournalListView              │    │
│  │ - JournalEntryView             │    │
│  │ - JournalSearchView            │    │
│  └────────────────────────────────┘    │
│  ┌────────────────────────────────┐    │
│  │ ViewModels                     │    │
│  │ - JournalViewModel             │    │
│  └────────────────────────────────┘    │
└─────────────────────────────────────────┘
              ↓ depends on
┌─────────────────────────────────────────┐
│           Domain Layer                  │
│  ┌────────────────────────────────┐    │
│  │ Entities                       │    │
│  │ - JournalEntry (enhanced)      │    │
│  │ - JournalTag                   │    │
│  │ - EntryType enum               │    │
│  └────────────────────────────────┘    │
│  ┌────────────────────────────────┐    │
│  │ Ports (Protocols)              │    │
│  │ - JournalRepositoryProtocol    │    │
│  └────────────────────────────────┘    │
└─────────────────────────────────────────┘
              ↓ depends on
┌─────────────────────────────────────────┐
│        Infrastructure Layer             │
│  ┌────────────────────────────────┐    │
│  │ SwiftData Models               │    │
│  │ - SDJournalEntry               │    │
│  │ - SDJournalTag                 │    │
│  └────────────────────────────────┘    │
│  ┌────────────────────────────────┐    │
│  │ Repositories                   │    │
│  │ - SwiftDataJournalRepository   │    │
│  └────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

---

## Enhanced Domain Model

### JournalEntry (Enhanced)

```swift
struct JournalEntry: Identifiable, Codable, Equatable {
    // Core fields
    let id: UUID
    let userId: UUID
    let date: Date
    
    // Content
    var title: String?
    var content: String
    
    // Metadata
    var tags: [String]
    var entryType: EntryType
    var isFavorite: Bool
    
    // Mood linking (optional)
    var linkedMoodId: UUID?
    
    // Timestamps
    let createdAt: Date
    var updatedAt: Date
    
    // Character limit: 10,000 (vs 500 for mood notes)
    static let maxContentLength = 10_000
}

enum EntryType: String, Codable, CaseIterable {
    case freeform = "freeform"
    case gratitude = "gratitude"
    case reflection = "reflection"
    case goalReview = "goal_review"
    case dailyLog = "daily_log"
}
```

### Design Decisions

1. **Title is optional** - Some entries are just stream of consciousness
2. **Tags as String array** - Simple, flexible, no pre-defined list
3. **EntryType** - Helps with organization and prompts
4. **linkedMoodId** - Optional connection to mood entries
5. **10k character limit** - Sufficient for deep reflection
6. **No markdown in v1** - Keep it simple, add later if needed

---

## Implementation Phases

### Phase 1: Core Foundation (Days 1-2)
**Goal:** Basic journaling works end-to-end

#### Step 1.1: Enhance Domain Layer
- [ ] Update `JournalEntry.swift` with enhanced model
- [ ] Create `EntryType.swift` enum
- [ ] Update `JournalRepositoryProtocol.swift` if needed
- [ ] Add computed properties (wordCount, preview, etc.)

**Files:**
- `lume/Domain/Entities/JournalEntry.swift`
- `lume/Domain/Entities/EntryType.swift`
- `lume/Domain/Ports/JournalRepositoryProtocol.swift`

#### Step 1.2: SwiftData Persistence Layer
- [ ] Create `SDJournalEntry.swift` SwiftData model
- [ ] Add relationships if needed
- [ ] Register in ModelContainer configuration

**Files:**
- `lume/Data/Persistence/SwiftData/SDJournalEntry.swift`
- Update: `lume/LumeApp.swift` (add to container)

#### Step 1.3: Repository Implementation
- [ ] Create `SwiftDataJournalRepository.swift`
- [ ] Implement all protocol methods
- [ ] Add translation between domain and SwiftData models
- [ ] Add error handling

**Files:**
- `lume/Data/Repositories/SwiftDataJournalRepository.swift`

#### Step 1.4: Dependency Injection
- [ ] Update `AppDependencies.swift`
- [ ] Add journal repository instance
- [ ] Wire up to SwiftData context

**Files:**
- Update: `lume/DI/AppDependencies.swift`

---

### Phase 2: Presentation Layer (Days 3-4)
**Goal:** Users can create, view, edit, and delete journal entries

#### Step 2.1: ViewModel
- [ ] Create `JournalViewModel.swift`
- [ ] Add state management (@Published properties)
- [ ] Implement CRUD operations
- [ ] Add error handling
- [ ] Add loading states

**Files:**
- `lume/Presentation/ViewModels/JournalViewModel.swift`

#### Step 2.2: Journal List View
- [ ] Create `JournalListView.swift`
- [ ] Show recent entries
- [ ] Add floating action button for new entry
- [ ] Add entry cards with preview
- [ ] Add pull-to-refresh
- [ ] Add empty state

**Files:**
- `lume/Presentation/Features/Journal/JournalListView.swift`

#### Step 2.3: Journal Entry View (Create/Edit)
- [ ] Create `JournalEntryView.swift`
- [ ] Title field (optional)
- [ ] TextEditor for content
- [ ] Character counter
- [ ] Date picker
- [ ] Entry type picker
- [ ] Tags input
- [ ] Favorite toggle
- [ ] Save/Cancel actions

**Files:**
- `lume/Presentation/Features/Journal/JournalEntryView.swift`

#### Step 2.4: Entry Card Component
- [ ] Create `JournalEntryCard.swift`
- [ ] Show title, preview, date
- [ ] Show tags
- [ ] Show favorite indicator
- [ ] Swipe actions (edit, delete)

**Files:**
- `lume/Presentation/Features/Journal/Components/JournalEntryCard.swift`

#### Step 2.5: Replace Placeholder
- [ ] Update `MainTabView.swift`
- [ ] Replace `JournalPlaceholderView` with `JournalListView`
- [ ] Pass dependencies

**Files:**
- Update: `lume/Presentation/MainTabView.swift`

---

### Phase 3: Enhanced Features (Days 5-6)
**Goal:** Search, filtering, and better UX

#### Step 3.1: Search Functionality
- [ ] Add search bar to list view
- [ ] Implement text search in repository
- [ ] Filter by entry type
- [ ] Filter by tags
- [ ] Filter by date range

#### Step 3.2: Tag Management
- [ ] Auto-suggest tags (from existing)
- [ ] Tag cloud/picker UI
- [ ] Filter by tag from list

#### Step 3.3: Statistics & Insights
- [ ] Total entries count
- [ ] Current streak
- [ ] Word count totals
- [ ] Favorite entries view

---

### Phase 4: Mood Integration (Days 7-8)
**Goal:** Optional linking between journal and mood entries

#### Step 4.1: Mood Linking UI
- [ ] Add mood link option in journal entry view
- [ ] Show linked mood badge
- [ ] Navigate to mood entry from journal
- [ ] Navigate to journal from mood entry

#### Step 4.2: Contextual Prompts
- [ ] Suggest linking when user logs mood then journals
- [ ] Suggest linking when user journals then logs mood
- [ ] Make it optional and dismissible
- [ ] Smart timing (don't annoy users)

---

## UI Design Specifications

### Color Palette
Following Lume's warm, calm aesthetic:

```swift
// Primary colors from LumeColors
- Background: appBackground (#F8F4EC)
- Surface: surface (#E8DFD6)
- Accent: accentPrimary (#F2C9A7)
- Text: textPrimary (#3B332C)
- Secondary: textSecondary (#6E625A)
```

### Typography
Using LumeTypography:
- Title: `titleLarge` (28pt)
- Subtitle: `titleMedium` (22pt)
- Body: `body` (17pt)
- Caption: `caption` (13pt)

### Components Style

#### Journal Entry Card
```
┌─────────────────────────────────────┐
│ 📝 Morning Reflection      ⭐       │
│ Today I woke up feeling grateful... │
│                                     │
│ #gratitude #morning                 │
│ Jan 15, 2025 · 234 words           │
└─────────────────────────────────────┘
```

- Soft corners (16pt radius)
- Subtle shadow
- Favorite star in top right
- Tags as chips
- Metadata in footer

#### Entry Editor
```
┌─────────────────────────────────────┐
│ Title (optional)                    │
│ ─────────────────────────────────── │
│                                     │
│ Start writing...                    │
│                                     │
│                                     │
│ ─────────────────────────────────── │
│ 📅 Jan 15  📁 Freeform  ⭐         │
│ #grateful #morning                  │
│                                     │
│ 234 / 10,000 characters            │
└─────────────────────────────────────┘
```

---

## Data Flow Examples

### Creating a Journal Entry

```
User Action: Tap [+] button
    ↓
JournalListView
    ↓
Show JournalEntryView (mode: .create)
    ↓
User writes content
    ↓
User taps [Save]
    ↓
JournalViewModel.saveEntry()
    ↓
Repository.create()
    ↓
SwiftData persists SDJournalEntry
    ↓
ViewModel updates @Published entries
    ↓
List refreshes automatically
    ↓
Show confirmation toast
```

### Linking to Mood Entry

```
User logs mood at 9:00 AM
    ↓
User opens Journal at 10:00 AM
    ↓
JournalViewModel detects recent mood
    ↓
Show subtle prompt: "Connect to today's mood?"
    ↓
If user taps [Yes]:
    - Pre-fill linkedMoodId
    - Show mood badge in entry
    - Entry auto-tagged with mood emotions
    ↓
User continues writing normally
```

---

## File Structure

```
lume/
├── Domain/
│   ├── Entities/
│   │   ├── JournalEntry.swift ⚠️ (enhance)
│   │   └── EntryType.swift 🆕
│   └── Ports/
│       └── JournalRepositoryProtocol.swift ✅ (exists)
│
├── Data/
│   ├── Persistence/
│   │   └── SwiftData/
│   │       └── SDJournalEntry.swift 🆕
│   └── Repositories/
│       └── SwiftDataJournalRepository.swift 🆕
│
├── Presentation/
│   ├── ViewModels/
│   │   └── JournalViewModel.swift 🆕
│   └── Features/
│       └── Journal/
│           ├── JournalListView.swift 🆕
│           ├── JournalEntryView.swift 🆕
│           └── Components/
│               ├── JournalEntryCard.swift 🆕
│               ├── TagInputField.swift 🆕
│               └── MoodLinkBadge.swift 🆕
│
├── DI/
│   └── AppDependencies.swift ⚠️ (update)
│
└── LumeApp.swift ⚠️ (update container)
```

**Legend:**
- 🆕 New file to create
- ⚠️ Existing file to modify
- ✅ Existing file, no changes needed

---

## Testing Strategy

### Unit Tests
- [ ] JournalEntry domain entity tests
- [ ] Repository implementation tests (mock ModelContext)
- [ ] ViewModel logic tests (create, update, delete)
- [ ] Search/filter logic tests

### Integration Tests
- [ ] Full flow: create → save → fetch → display
- [ ] Mood linking flow
- [ ] Search across multiple entries
- [ ] Tag filtering

### UI Tests (Manual for now)
- [ ] Create entry
- [ ] Edit entry
- [ ] Delete entry
- [ ] Search entries
- [ ] Filter by tags
- [ ] Link to mood
- [ ] Character limit enforcement

---

## Success Criteria

### Phase 1 Complete
- ✅ Users can create journal entries
- ✅ Entries persist across app restarts
- ✅ Users can view list of entries
- ✅ Users can edit existing entries
- ✅ Users can delete entries

### Phase 2 Complete
- ✅ Clean, Lume-styled UI
- ✅ Proper error handling
- ✅ Loading states
- ✅ Empty states
- ✅ Smooth animations

### Phase 3 Complete
- ✅ Search functionality works
- ✅ Tag management works
- ✅ Filtering works
- ✅ Statistics display

### Phase 4 Complete
- ✅ Optional mood linking works
- ✅ Contextual prompts show appropriately
- ✅ Navigation between features works
- ✅ No forced coupling

---

## Risk Mitigation

### Risk 1: SwiftData Model Complexity
**Mitigation:** Keep model simple initially, add complexity incrementally

### Risk 2: Search Performance
**Mitigation:** 
- Start with simple in-memory filter
- Add indexing later if needed
- Limit search results initially

### Risk 3: Mood Linking UX Confusion
**Mitigation:**
- Make linking optional and clear
- Add onboarding tips
- Allow easy unlinking
- Test with users

### Risk 4: Large Content Performance
**Mitigation:**
- Enforce 10k character limit
- Use pagination for list
- Lazy load content
- Optimize TextEditor rendering

---

## Future Enhancements (Post-MVP)

### Backend Integration
- [ ] Sync to FitIQ backend
- [ ] Use outbox pattern for reliability
- [ ] Handle conflicts (last-write-wins)
- [ ] Cloud backup

### Advanced Features
- [ ] Markdown support for formatting
- [ ] Image attachments
- [ ] Voice-to-text dictation
- [ ] Export to PDF/text
- [ ] Sharing capabilities
- [ ] Prompts library
- [ ] Templates for different entry types
- [ ] Daily reminders
- [ ] Streaks and gamification

### AI Integration
- [ ] Sentiment analysis
- [ ] Writing prompts based on mood
- [ ] Pattern recognition
- [ ] Summary generation
- [ ] Insight suggestions

---

## Dependencies & Prerequisites

### Required
- ✅ SwiftData framework (iOS 17+)
- ✅ SwiftUI (iOS 17+)
- ✅ Existing Lume architecture patterns
- ✅ LumeColors and LumeTypography
- ✅ AppDependencies pattern

### Optional
- ⏳ Backend API endpoints (Phase 5+)
- ⏳ AI/ML capabilities (Phase 6+)

---

## Timeline Estimate

### Phase 1: Foundation (2 days)
- Domain enhancement: 4 hours
- SwiftData models: 3 hours
- Repository: 4 hours
- DI setup: 1 hour

### Phase 2: UI Implementation (2 days)
- ViewModel: 4 hours
- List view: 4 hours
- Entry view: 6 hours
- Integration: 2 hours

### Phase 3: Enhanced Features (2 days)
- Search: 4 hours
- Tags: 4 hours
- Stats: 4 hours
- Polish: 4 hours

### Phase 4: Mood Integration (2 days)
- Linking logic: 4 hours
- UI components: 4 hours
- Contextual prompts: 4 hours
- Testing: 4 hours

**Total: 8 days (1-2 weeks)**

---

## Getting Started

### Step 1: Review Documentation
- [x] Read this implementation plan
- [ ] Review `JOURNALING_UX_USER_JOURNEYS.md`
- [ ] Review existing Mood Tracking implementation as reference

### Step 2: Set Up Environment
- [ ] Ensure Xcode 15+ installed
- [ ] Pull latest from main branch
- [ ] Verify existing mood tracking works

### Step 3: Start Implementation
- [ ] Begin with Phase 1, Step 1.1
- [ ] Commit frequently
- [ ] Test each component before moving forward

---

## Notes

- Follow existing code patterns from Mood Tracking
- Maintain hexagonal architecture strictly
- Keep domain layer pure (no SwiftUI, no SwiftData)
- Use async/await consistently
- Document as you go
- Test incrementally

---

**Status:** 📋 Plan Complete - Ready for Implementation  
**Next Action:** Begin Phase 1, Step 1.1 - Enhance Domain Layer