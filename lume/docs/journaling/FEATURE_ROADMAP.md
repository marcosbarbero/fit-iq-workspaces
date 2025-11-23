# Journaling Feature Roadmap

**Version:** 2.0.0  
**Last Updated:** 2025-01-16  
**Status:** 🚧 In Progress

---

## Overview

This document outlines the complete feature roadmap for the Lume journaling system, from critical fixes to long-term enhancements.

---

## ✅ Completed Features

### Phase 1: Core Journaling (Completed)
- [x] Basic CRUD operations (create, read, update, delete)
- [x] Entry types (Freeform, Gratitude, Reflection, Goals)
- [x] Tags and hashtag auto-extraction
- [x] Favorites
- [x] Search and filtering
- [x] Date/time selection
- [x] Word count and reading time
- [x] Offline-first architecture with sync
- [x] SwiftData persistence

### Phase 2: Mood Integration (Completed)
- [x] Mood linking functionality
- [x] Bidirectional mood-journal linking
- [x] Mood picker UI with recent moods
- [x] Linked mood indicator in entry detail
- [x] Cross-feature coordination (JournalMoodCoordinator)

### Phase 3: UX Improvements (Completed - Nov 16, 2025)
- [x] Mood link button repositioned (next to favorite star)
- [x] Improved icon contrast in mood picker
- [x] Async mood loading with loading state
- [x] Offline detection banner
- [x] Network status monitoring

---

## 🔥 Critical Priority (Week 1)

### 1. User Authentication & Session Management ⚠️ **BLOCKING**

**Status:** 🚧 In Progress  
**Priority:** P0 - Critical  
**Estimated Time:** 2 days  
**Assignee:** TBD

#### Problem Statement

Currently, the app uses hardcoded UUIDs for user identification:
- `MoodViewModel` uses `00000000-0000-0000-0000-000000000001`
- `JournalRepository` uses `00000000-0000-0000-0000-000000000000`
- This causes data mismatches and prevents proper multi-user support
- Security and privacy concerns

#### Solution Overview

Implement proper user authentication with real user IDs from the backend.

#### Implementation Plan

**Day 1: UserSession Service**
1. Create `UserSession.swift` service
2. Store current user ID in UserDefaults
3. Implement thread-safe access methods
4. Add session lifecycle management

**Day 2: Authentication Integration**
1. Update `AuthRepository` to call `/api/v1/users/me` after login/register
2. Extract and store `user_id` from response
3. Update all ViewModels to use `UserSession.shared.currentUserId`
4. Update repositories to filter by real userId
5. Add userId filtering back to `MoodRepository`

#### Technical Details

**Endpoints:**
- `POST /api/v1/auth/login` → Returns token
- `POST /api/v1/auth/register` → Returns token  
- `GET /api/v1/users/me` → Returns user profile with `user_id`

**Response Schema:**
```json
{
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "name": "John Doe",
    "email": "john@example.com",
    "date_of_birth": "1990-05-15",
    "created_at": "2025-01-16T10:00:00Z",
    "updated_at": "2025-01-16T10:00:00Z"
  }
}
```

**Files to Create:**
- `lume/lume/Core/UserSession.swift`
- `lume/lume/Services/UserProfileService.swift`

**Files to Modify:**
- `lume/lume/Data/Repositories/AuthRepository.swift`
- `lume/lume/Data/Repositories/MoodRepository.swift`
- `lume/lume/Data/Repositories/SwiftDataJournalRepository.swift`
- `lume/lume/Presentation/ViewModels/MoodViewModel.swift`
- `lume/lume/Presentation/ViewModels/JournalViewModel.swift`
- `lume/lume/DI/AppDependencies.swift`

#### Success Criteria
- [ ] UserSession service created and tested
- [ ] Login/register flow calls `/api/v1/users/me`
- [ ] Real user ID stored in UserDefaults
- [ ] All repositories use real userId
- [ ] Mood and journal entries filter by correct userId
- [ ] No hardcoded UUIDs remain
- [ ] Existing user data migrated (if needed)
- [ ] All tests pass

#### Documentation
- [ ] Update architecture docs
- [ ] Update API integration guide
- [ ] Add migration guide for existing users
- [ ] Update troubleshooting guide

---

## 🎯 High Priority (Week 2)

### 2. Journal Dashboard & Statistics

**Status:** 📋 Planned  
**Priority:** P1 - High  
**Estimated Time:** 2 days  
**Backend:** ✅ Ready - `/api/v1/journal/statistics`

#### Features
- Summary stats (total entries, words, current streak)
- Entry type distribution (pie/bar chart)
- Writing activity over time (line chart)
- Top tags with counts
- Streak tracking (current & longest)
- Time period selector (Today, 7D, 30D, 90D, 6M, 1Y)

#### Implementation
1. Create `JournalDashboardView.swift`
2. Create `JournalStatisticsService.swift`
3. Integrate `/api/v1/journal/statistics` endpoint
4. Create chart components (reuse from MoodDashboard)
5. Add dashboard button to journal list toolbar
6. Cache statistics for performance

#### UI Design
- Match MoodDashboardView style
- Use Lume color palette for charts
- Animated chart transitions
- Pull-to-refresh support
- Loading states

#### Success Criteria
- [ ] Dashboard accessible from journal list
- [ ] All time periods work correctly
- [ ] Charts render with accurate data
- [ ] Performance < 1s load time for 1000+ entries
- [ ] Backend integration working
- [ ] Offline support (cached data)

### 3. AI Writing Prompts

**Status:** 📋 Planned  
**Priority:** P1 - High  
**Estimated Time:** 1.5 days  
**Backend:** ✅ Ready - `/api/v1/journal/prompts`

#### Features
- Daily writing prompt card
- Contextual prompts (time of day, mood, etc.)
- "Use This Prompt" creates new entry
- Prompt categories (reflection, gratitude, growth, etc.)
- Privacy-first approach (no personal data sent)

#### Implementation
1. Create `JournalPromptsService.swift`
2. Create `DailyPromptCard.swift` component
3. Add prompt card to journal list (top position)
4. Implement prompt-to-entry flow
5. Cache prompts for offline use
6. Add prompt refresh action

#### Success Criteria
- [ ] Daily prompt loads from backend
- [ ] Prompt card shows in journal list
- [ ] Tapping "Use Prompt" creates entry with pre-filled title
- [ ] Works offline (cached prompts)
- [ ] Prompts rotate daily
- [ ] No personal data sent to backend

---

## 🚀 Medium Priority (Weeks 3-4)

### 4. Rich Text / Markdown Support

**Status:** 📋 Planned  
**Priority:** P2 - Medium  
**Estimated Time:** 2 days

#### Features
- Markdown editor with formatting toolbar
- Bold, italic, strikethrough
- Headers (H1, H2, H3)
- Bullet and numbered lists
- Checkboxes for task lists
- Block quotes
- Links (optional)
- Preview toggle
- Custom Lume markdown theme

#### Implementation
1. Add `MarkdownUI` package dependency
2. Create `MarkdownEditorView.swift`
3. Create formatting toolbar
4. Create custom Lume markdown theme
5. Update detail view to render markdown
6. Maintain backward compatibility with plain text

#### Technical Considerations
- Markdown stored as plain text in database
- Rendered only in UI layer
- Existing plain text entries work unchanged
- Export includes both plain and formatted versions

#### Success Criteria
- [ ] Formatting toolbar functional
- [ ] Preview mode renders correctly
- [ ] Theme matches Lume colors
- [ ] Plain text entries still work
- [ ] Existing entries display correctly
- [ ] No performance degradation

### 5. Entry Templates

**Status:** 📋 Planned  
**Priority:** P2 - Medium  
**Estimated Time:** 2 days

#### Built-in Templates
1. **Daily Gratitude** - 3 things I'm grateful for + why
2. **Weekly Review** - Wins, challenges, lessons, focus
3. **Goal Progress** - Status, obstacles, next steps
4. **Morning Pages** - Stream of consciousness
5. **Evening Reflection** - Day summary, highlights, learnings
6. **Problem Solving** - Problem, ideas, action plan
7. **Dream Journal** - Dream description, feelings, interpretation

#### Implementation
1. Create `EntryTemplate.swift` model
2. Define built-in templates
3. Create `TemplateSelectionView.swift`
4. Add template picker to journal list
5. Pre-fill editor with template structure
6. Support custom templates (optional)

#### Success Criteria
- [ ] Templates appear in selection UI
- [ ] Selecting template fills content
- [ ] Template respects entry type
- [ ] Includes relevant default tags
- [ ] User can edit freely after selection
- [ ] Templates saved for reuse

### 6. On-Device Sentiment Analysis

**Status:** 📋 Planned  
**Priority:** P2 - Medium  
**Estimated Time:** 1 day  
**Privacy:** ✅ On-device only

#### Features
- Automatic sentiment detection (positive/neutral/negative)
- Sentiment trends in dashboard
- Sentiment by entry type
- Sentiment over time chart
- Privacy-first (no data leaves device)

#### Implementation
1. Use Apple's `NaturalLanguage` framework
2. Create `SentimentAnalysisService.swift`
3. Analyze on entry save (async, non-blocking)
4. Store sentiment score in journal entry
5. Add sentiment charts to dashboard
6. Add sentiment filter to journal list

#### Technical Details
- Uses Apple's on-device ML models
- No network requests
- Runs in background queue
- Results cached in SwiftData
- User can disable feature

#### Success Criteria
- [ ] Sentiment analyzed automatically
- [ ] Results accurate (>80%)
- [ ] No performance impact
- [ ] Privacy preserved (on-device only)
- [ ] Trends visible in dashboard
- [ ] User can disable feature

---

## 📅 Lower Priority (Month 2)

### 7. Export & Sharing

**Estimated Time:** 2 days

#### Features
- Export to PDF, Markdown, plain text
- Date range selection
- Include/exclude tags, moods
- Share via system share sheet
- Email export
- Print support

### 8. Advanced Search

**Estimated Time:** 1 day

#### Features
- Full-text search across all entries
- Filter by date range
- Filter by tags (AND/OR logic)
- Filter by entry type
- Filter by mood (if linked)
- Filter by favorites
- Save search queries
- Sort options (date, relevance, length)

### 9. Accessibility Improvements

**Estimated Time:** 2 days

#### Features
- VoiceOver optimization
- Dynamic Type support
- High contrast mode
- Reduce motion support
- Keyboard navigation (iPad)
- Accessibility labels on all interactive elements

### 10. Dark Mode Support

**Estimated Time:** 1 day

#### Features
- Dark color palette (warm, not harsh)
- Automatic light/dark switching
- Consistent with iOS system theme
- Custom dark colors for charts
- Readable in all lighting conditions

### 11. iPad & Landscape Optimization

**Estimated Time:** 1 day

#### Features
- Two-column layout on iPad
- Master-detail view
- Keyboard shortcuts
- Drag & drop support
- Landscape optimized layouts

---

## 🌟 Future Enhancements (Month 3+)

### 12. Attachments
- Photos
- Voice notes
- Location tags
- Weather data

### 13. Collaborative Features
- Shared journals (optional)
- Journal groups
- Comments (optional)

### 14. Advanced AI Features
- Auto-tagging suggestions
- Writing style analysis
- Topic clustering
- Personalized insights

### 15. Backup & Sync
- iCloud sync
- Cross-device sync
- Encrypted backups
- Export/import full database

---

## Backend Endpoints Status

### ✅ Available & Ready
- `POST /api/v1/journal/entries` - Create entry
- `GET /api/v1/journal/entries` - List entries
- `GET /api/v1/journal/entries/:id` - Get single entry
- `PUT /api/v1/journal/entries/:id` - Update entry
- `DELETE /api/v1/journal/entries/:id` - Delete entry
- `GET /api/v1/journal/statistics` - Get statistics
- `GET /api/v1/journal/prompts` - Get writing prompts
- `GET /api/v1/users/me` - Get current user profile

### 📋 Needed for Future Features
- `POST /api/v1/journal/export` - Export entries
- `GET /api/v1/journal/insights` - AI insights
- `POST /api/v1/journal/attachments` - Upload attachments

---

## Testing Strategy

### Unit Tests
- Domain logic (entities, use cases)
- Repository implementations
- Service layer
- ViewModels

### Integration Tests
- Backend API integration
- SwiftData persistence
- Cross-feature coordination
- Offline sync

### UI Tests (Manual Priority)
- Entry creation flow
- Mood linking flow
- Search and filter
- Offline behavior
- Error handling

### Performance Tests
- 10,000+ entries
- Large text entries (10,000+ words)
- Rapid entry creation
- Search performance
- Dashboard load time

---

## Success Metrics

### Feature Adoption (30 days)
- 80%+ users create at least 5 entries
- 60%+ users link mood to journal
- 40%+ users use templates
- 50%+ users use tags
- 30%+ users use AI prompts

### User Satisfaction
- App Store rating: 4.5+ stars
- Positive feedback on journaling features
- Low crash rate (<0.1%)
- Fast load times (<2s)

### Technical Quality
- Test coverage: 70%+
- Zero critical bugs
- Performance: <100ms UI operations
- Memory usage: <50MB typical

---

## Risk Assessment

### Technical Risks
| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SwiftData migration issues | High | Medium | Comprehensive schema versioning |
| Backend API changes | High | Low | Versioned API, backward compatibility |
| Performance with large datasets | Medium | Medium | Pagination, lazy loading, caching |
| Markdown rendering performance | Low | Low | Efficient rendering, caching |

### UX Risks
| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Feature complexity overwhelms users | Medium | Medium | Progressive disclosure, onboarding |
| AI features feel intrusive | High | Low | Privacy-first, user control, opt-in |
| Rich text distracts from writing | Low | Medium | Simple toolbar, optional preview |

---

## Dependencies

### External Packages
- `MarkdownUI` - Markdown rendering (for feature #4)
- Apple's `NaturalLanguage` - Sentiment analysis (built-in)

### Backend Services
- Journal API endpoints (ready)
- Statistics API (ready)
- Prompts API (ready)
- User profile API (ready)

### iOS Features
- UserDefaults (session storage)
- Keychain (token storage)
- NaturalLanguage framework (sentiment)
- Charts framework (dashboard)
- System share sheet (export)

---

## Timeline Summary

```
Week 1  : User Authentication (CRITICAL)
Week 2  : Dashboard + AI Prompts
Week 3-4: Rich Text + Templates + Sentiment
Month 2 : Export, Search, Accessibility, Dark Mode, iPad
Month 3+: Attachments, Collaboration, Advanced AI
```

---

## Decision Log

### Decisions Made
1. **Privacy-First AI** - All ML runs on-device, no content sent to servers
2. **Markdown over Rich Text** - Simple, portable, future-proof
3. **Built-in Templates** - Start with 7 proven templates before custom
4. **Dashboard Reuse** - Leverage MoodDashboard patterns for consistency
5. **UserSession Pattern** - Centralized user state management

### Open Questions
1. Should we support collaborative journals?
2. How much iCloud storage should we allocate per user?
3. Should AI prompts be personalized or generic?
4. What's the max entry length (character limit)?
5. Should we support journal encryption at rest?

---

## Resources

### Documentation
- [Critical Gaps Fixed](./CRITICAL_GAPS_FIXED.md)
- [Mood Linking Fix](../fixes/MOOD_LINKING_FIX.md)
- [Backend Integration](../backend-integration/)
- [Architecture Overview](../ARCHITECTURE_OVERVIEW.md)

### Backend API
- [Swagger Documentation](../backend-integration/swagger.yaml)
- Backend Base URL: `https://fit-iq-backend.fly.dev`

### Design System
- [Lume Colors & Typography](.github/copilot-instructions.md)
- App Background: `#F8F4EC`
- Primary Accent: `#F2C9A7`
- Text Primary: `#3B332C`

---

## Contact & Ownership

**Feature Owner:** TBD  
**Engineering Lead:** TBD  
**Design Lead:** TBD  
**Product Manager:** TBD

---

**Version History:**
- v2.0.0 (2025-01-16) - Complete roadmap with auth fix priority
- v1.0.0 (2025-01-15) - Initial roadmap post-critical gaps

---

**Status:** 🚧 Active Development  
**Next Review:** 2025-01-23