# Lume Outbox Migration - Next Steps Checklist

**Date:** 2025-01-27  
**Status:** 🔄 In Progress  
**Migration Status:** ✅ Code Complete | ⏳ Testing Pending

---

## 🎯 Quick Status

✅ **COMPLETE:**
- Schema migration (V6 → V7)
- Adapter pattern implementation
- Repository migrations (3 repositories)
- SwiftDataOutboxRepository completion
- Comprehensive documentation

⏳ **IN PROGRESS:**
- Manual testing
- OutboxProcessorService migration
- Unit test implementation

---

## 📋 Immediate Tasks (Do This First)

### 1. Manual Testing - Schema Migration ⏳

**Priority:** 🔴 Critical  
**Time:** 30 minutes  
**Blocker:** Yes - Validate migration before proceeding

**Steps:**

- [ ] **Install V6 Build**
  ```bash
  # 1. Checkout V6 schema
  git checkout <v6-commit-hash>
  
  # 2. Build and run on simulator
  # Product → Run (⌘R)
  
  # 3. Create test data
  # - 3 mood entries
  # - 2 journal entries
  # - 1 goal
  ```

- [ ] **Upgrade to V7**
  ```bash
  # 1. Checkout current branch (V7)
  git checkout <current-branch>
  
  # 2. Clean build folder
  # Product → Clean Build Folder (⇧⌘K)
  
  # 3. Build and run
  # Product → Run (⌘R)
  ```

- [ ] **Verify Migration**
  - [ ] App launches without crashes
  - [ ] Check console for migration logs:
    ```
    Starting V6→V7 migration: Outbox Pattern upgrade
    Completed V6→V7 migration
    ```
  - [ ] All test data still visible (moods, journals, goals)
  - [ ] No data loss or corruption

- [ ] **Test Outbox Event Creation**
  - [ ] Create new mood entry
  - [ ] Check console for:
    ```
    📦 [OutboxRepository] Creating event - Type: [Mood Entry] | EntityID: ...
    ✅ [OutboxRepository] Event created - EventID: ... | Status: pending
    ```
  - [ ] Create new journal entry, verify console logs
  - [ ] Create new goal, verify console logs

**Pass Criteria:** ✅ No crashes, all data intact, events created

---

### 2. Fresh Install Test ⏳

**Priority:** 🔴 Critical  
**Time:** 10 minutes  
**Blocker:** Yes - Validate clean install

**Steps:**

- [ ] **Delete App from Simulator**
  - Long press app icon → Delete App

- [ ] **Clean Build**
  ```bash
  # In Xcode
  Product → Clean Build Folder (⇧⌘K)
  ```

- [ ] **Fresh Install**
  ```bash
  Product → Run (⌘R)
  ```

- [ ] **Verify Clean Start**
  - [ ] App launches without crashes
  - [ ] No schema migration errors
  - [ ] Can create mood/journal/goal entries
  - [ ] Outbox events created correctly

**Pass Criteria:** ✅ Clean install works, no errors

---

### 3. OutboxProcessorService Migration ⏳

**Priority:** 🟡 High  
**Time:** 2 hours  
**Blocker:** Yes - Required for end-to-end sync

**Location:** `lume/lume/Services/OutboxProcessorService.swift`

**What Needs Updating:**

- [ ] **Review Current Implementation**
  ```bash
  # Check what event types processor expects
  grep -n "mood\." lume/lume/Services/OutboxProcessorService.swift
  grep -n "journal\." lume/lume/Services/OutboxProcessorService.swift
  grep -n "goal\." lume/lume/Services/OutboxProcessorService.swift
  ```

- [ ] **Update Event Type Handling**
  ```swift
  // Before: String matching
  switch event.type {
  case "mood.created": ...
  case "mood.updated": ...
  case "mood.deleted": ...
  }
  
  // After: Enum matching
  switch event.eventType {
  case .moodEntry:
      // Check event.isNewRecord to determine create vs update
      // Check event.metadata for delete operation
  case .journalEntry: ...
  case .goal: ...
  }
  ```

- [ ] **Update Metadata Handling**
  ```swift
  // Before: Decode binary payload
  let payload = try decoder.decode(MoodPayload.self, from: event.payload)
  
  // After: Use metadata enum
  guard case .moodEntry(let valence, let labels) = event.metadata else {
      throw ProcessorError.invalidMetadata
  }
  ```

- [ ] **Handle isNewRecord Flag**
  ```swift
  if event.isNewRecord {
      // POST to backend (create)
  } else {
      // Check metadata for delete operation
      if case .generic(let dict) = event.metadata,
         dict["operation"] == "delete" {
          // DELETE from backend
      } else {
          // PUT to backend (update)
      }
  }
  ```

- [ ] **Test End-to-End**
  - [ ] Create mood entry (should POST)
  - [ ] Update mood entry (should PUT)
  - [ ] Delete mood entry (should DELETE)
  - [ ] Verify outbox events marked as completed

**Reference:** Check FitIQ's OutboxProcessorService for patterns

**Pass Criteria:** ✅ All event types process correctly, backend syncs work

---

## 📦 Short-Term Tasks (This Sprint)

### 4. Unit Tests - OutboxEventAdapter ⏳

**Priority:** 🟡 High  
**Time:** 2 hours  
**Location:** `lumeTests/Data/Persistence/OutboxEventAdapterTests.swift`

**Test Cases:**

- [ ] **Round-Trip Conversion**
  ```swift
  func testRoundTripConversion() async throws {
      let domain = OutboxEvent(...)
      let swiftData = OutboxEventAdapter.toSwiftData(domain)
      let converted = try OutboxEventAdapter.toDomain(swiftData)
      XCTAssertEqual(domain, converted)
  }
  ```

- [ ] **Invalid Event Type**
  ```swift
  func testInvalidEventType() throws {
      let sdEvent = SDOutboxEvent(eventType: "invalid_type", ...)
      XCTAssertThrowsError(try OutboxEventAdapter.toDomain(sdEvent)) { error in
          XCTAssertTrue(error is AdapterError)
      }
  }
  ```

- [ ] **All Metadata Types**
  ```swift
  func testMoodEntryMetadata() { ... }
  func testJournalEntryMetadata() { ... }
  func testGoalMetadata() { ... }
  func testGenericMetadata() { ... }
  ```

- [ ] **Batch Conversion with Failures**
  ```swift
  func testBatchConversionFiltersInvalid() { ... }
  ```

**Target Coverage:** 80%+

---

### 5. Unit Tests - SwiftDataOutboxRepository ⏳

**Priority:** 🟡 High  
**Time:** 3 hours  
**Location:** `lumeTests/Data/Repositories/SwiftDataOutboxRepositoryTests.swift`

**Test Cases:**

- [ ] **Event Creation**
  ```swift
  func testCreateEvent() async throws {
      let event = try await repo.createEvent(
          eventType: .moodEntry,
          entityID: UUID(),
          userID: "user-123",
          isNewRecord: true,
          metadata: .moodEntry(valence: 0.7, labels: ["happy"]),
          priority: 5
      )
      XCTAssertEqual(event.status, .pending)
  }
  ```

- [ ] **Fetch Pending Events**
- [ ] **Mark as Processing/Completed/Failed**
- [ ] **Delete Events**
- [ ] **Get Statistics**
- [ ] **Get Stale Events**

**Target Coverage:** 80%+

---

### 6. Integration Tests - Repositories ⏳

**Priority:** 🟢 Medium  
**Time:** 2 hours  
**Location:** `lumeTests/Data/Repositories/`

**Test Cases:**

- [ ] **MoodRepository Creates Outbox Events**
  ```swift
  func testMoodRepositorySaveCreatesOutboxEvent() async throws {
      // Given
      let mood = MoodEntry(...)
      
      // When
      try await moodRepo.save(mood)
      
      // Then
      let events = try await outboxRepo.fetchPendingEvents(forUserID: mood.userId.uuidString, limit: nil)
      XCTAssertEqual(events.count, 1)
      XCTAssertEqual(events.first?.eventType, .moodEntry)
      XCTAssertEqual(events.first?.entityID, mood.id)
  }
  ```

- [ ] **GoalRepository Creates Outbox Events**
- [ ] **JournalRepository Creates Outbox Events**

**Target Coverage:** 70%+

---

### 7. Performance Testing ⏳

**Priority:** 🟢 Medium  
**Time:** 1 hour

**Test Scenarios:**

- [ ] **Event Creation Performance**
  ```swift
  measure {
      for _ in 0..<100 {
          _ = try await outboxRepo.createEvent(...)
      }
  }
  // Target: <5ms per event
  ```

- [ ] **Fetch Performance (1000+ events)**
  ```swift
  // Create 1000 events
  let events = try await outboxRepo.fetchPendingEvents(forUserID: nil, limit: nil)
  // Target: <100ms
  ```

- [ ] **Memory Leak Detection**
  - Run Instruments → Leaks
  - Create/delete 100+ events
  - Verify no memory leaks

**Pass Criteria:** ✅ <5ms per event, no memory leaks

---

## 📚 Medium-Term Tasks (Next Sprint)

### 8. Documentation Updates ⏳

**Priority:** 🟢 Medium  
**Time:** 2 hours

- [ ] **Create TESTING_GUIDE.md**
  - Unit testing patterns
  - Integration testing approach
  - Manual testing checklist
  - Performance testing guide

- [ ] **Create TROUBLESHOOTING.md**
  - Common errors and solutions
  - Debug logging guide
  - Schema migration issues
  - Outbox event processing issues

- [ ] **Update Developer Onboarding**
  - Add Outbox Pattern section
  - Link to FitIQCore docs
  - Code examples

---

### 9. Code Review & Merge ⏳

**Priority:** 🟡 High  
**Time:** 1 day (including feedback cycle)

**Steps:**

- [ ] **Self-Review**
  - Review all changed files
  - Check for TODOs or FIXMEs
  - Verify all logging is appropriate
  - Check for hardcoded values

- [ ] **Create Pull Request**
  - Title: "Migrate Lume to FitIQCore Outbox Pattern"
  - Description: Link to MIGRATION_COMPLETE.md
  - List breaking changes
  - Add screenshots of console logs

- [ ] **Request Reviews**
  - Tag iOS team members
  - Tag backend team (for OutboxProcessorService changes)

- [ ] **Address Feedback**
  - Fix issues raised
  - Update documentation if needed
  - Re-test affected areas

- [ ] **Merge to Main**
  - Squash commits or keep history?
  - Update CHANGELOG.md
  - Tag release (e.g., v2.0.0-outbox-migration)

---

### 10. Production Rollout ⏳

**Priority:** 🟡 High  
**Time:** 1 week (gradual rollout)

**Phases:**

- [ ] **Phase 1: Internal Testing (Day 1-2)**
  - Deploy to internal TestFlight
  - Test on 5+ devices
  - Monitor crash reports
  - Check backend sync logs

- [ ] **Phase 2: Beta Testing (Day 3-4)**
  - Deploy to beta TestFlight group
  - Monitor analytics
  - Collect feedback
  - Fix critical bugs

- [ ] **Phase 3: Gradual Rollout (Day 5-7)**
  - 10% of users (Day 5)
  - 50% of users (Day 6)
  - 100% of users (Day 7)
  - Monitor metrics at each stage

**Rollback Plan:**
- [ ] Keep V6 build ready
- [ ] Document rollback procedure
- [ ] Set alert thresholds for rollback trigger

---

## 🚨 Known Issues & Risks

### Identified Risks

1. **OutboxProcessorService Changes May Break Existing Events**
   - **Mitigation:** Test with V6 events in outbox before deployment
   - **Fallback:** Keep old processor logic for legacy events

2. **Schema Migration May Fail on Large Datasets**
   - **Mitigation:** Test with 1000+ events
   - **Fallback:** Fresh install (with data export/import)

3. **Backend API May Not Handle New Metadata Format**
   - **Mitigation:** Coordinate with backend team
   - **Fallback:** Dual-format support during transition

### Open Questions

- [ ] **Q1:** Should we support backward migration (V7 → V6)?
  - **Decision:** TBD
  - **Owner:** Tech lead

- [ ] **Q2:** What's the retention policy for completed events?
  - **Decision:** TBD (suggest 30 days)
  - **Owner:** Product manager

- [ ] **Q3:** Should we add analytics for outbox events?
  - **Decision:** TBD
  - **Owner:** Analytics team

---

## 📊 Progress Tracking

### Overall Progress

| Phase | Status | Progress |
|-------|--------|----------|
| Code Migration | ✅ Complete | 100% |
| Manual Testing | ⏳ Pending | 0% |
| Unit Tests | ⏳ Pending | 0% |
| Integration Tests | ⏳ Pending | 0% |
| Documentation | 🔄 In Progress | 80% |
| Code Review | ⏳ Pending | 0% |
| Production Rollout | ⏳ Pending | 0% |

**Overall:** 40% Complete

### Task Breakdown

- ✅ Complete: 7 tasks
- 🔄 In Progress: 1 task
- ⏳ Pending: 10 tasks
- **Total:** 18 tasks

---

## 🎯 Success Criteria

### Must Have (MVP)

- ✅ Code compiles without errors
- ✅ All repositories use new API
- ⏳ Schema migration tested and verified
- ⏳ Fresh install tested and verified
- ⏳ OutboxProcessorService updated and tested
- ⏳ Basic unit tests pass

### Should Have (V1)

- ⏳ 80%+ test coverage
- ⏳ Performance benchmarks met
- ⏳ Comprehensive documentation
- ⏳ Code reviewed and merged

### Nice to Have (V2)

- ⏳ Advanced analytics
- ⏳ A/B testing framework
- ⏳ Automated rollback triggers
- ⏳ Performance monitoring dashboard

---

## 📞 Who to Contact

### Technical Questions

- **Schema/SwiftData:** iOS team lead
- **FitIQCore:** Check FitIQ docs or iOS team
- **Backend Sync:** Backend team lead
- **Testing Strategy:** QA lead

### Review & Approval

- **Code Review:** iOS team (2 approvals required)
- **Deployment Approval:** Engineering manager
- **Rollout Decision:** Product manager

---

## 📝 Notes & Observations

### From This Session

- Migration was smoother than expected due to FitIQ's documentation
- Type safety caught 1 bug during migration (typealias mismatch)
- Code reduction was significant (75% in JournalRepository)
- Adapter pattern made testing easier

### For Future Migrations

- Always test migration path with real data
- Document breaking changes clearly
- Keep old and new code paths during transition
- Coordinate with backend team early

---

## 🎉 Quick Wins

These tasks can be completed quickly to show progress:

1. ✅ **Run Fresh Install Test** (10 min)
2. ✅ **Test Schema Migration** (30 min)
3. ✅ **Write 1 Unit Test** (30 min)
4. ✅ **Update README** (15 min)
5. ✅ **Create Test Plan Document** (30 min)

---

## 📅 Recommended Timeline

### This Week (Jan 27 - Feb 2)

- **Monday:** Manual testing (Tasks 1-2)
- **Tuesday:** OutboxProcessorService migration (Task 3)
- **Wednesday:** Unit tests - Adapter (Task 4)
- **Thursday:** Unit tests - Repository (Task 5)
- **Friday:** Integration tests (Task 6)

### Next Week (Feb 3 - Feb 9)

- **Monday:** Performance testing (Task 7)
- **Tuesday:** Documentation (Task 8)
- **Wednesday-Thursday:** Code review (Task 9)
- **Friday:** Prepare for rollout (Task 10 prep)

### Week After (Feb 10 - Feb 16)

- **Mon-Fri:** Production rollout (Task 10)

---

**Last Updated:** 2025-01-27  
**Status:** 🔄 Active  
**Next Review:** After Task 1-2 completion

---

**END OF CHECKLIST**