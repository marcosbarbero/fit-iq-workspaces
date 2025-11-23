# Testing Guide: Outbox Pattern Migration

**Date:** 2025-01-27  
**Status:** Active  
**Purpose:** Comprehensive testing guide for the Outbox Pattern migration in Lume iOS app

---

## Table of Contents

1. [Overview](#overview)
2. [Test Execution](#test-execution)
3. [Unit Tests](#unit-tests)
4. [Integration Tests](#integration-tests)
5. [Manual Testing](#manual-testing)
6. [Performance Testing](#performance-testing)
7. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides step-by-step instructions for testing the Outbox Pattern migration. All tests must pass before deploying to production.

### Test Pyramid

```
        /\
       /  \  Manual Tests (E2E, exploratory)
      /____\
     /      \  Integration Tests (full sync flow)
    /________\
   /          \  Unit Tests (components, mocks)
  /____________\
```

### Testing Goals

- ✅ Verify outbox events are created correctly
- ✅ Verify sync to backend works offline-to-online
- ✅ Verify error handling and retry logic
- ✅ Verify data consistency (local ↔ backend)
- ✅ Verify performance meets targets

---

## Test Execution

### Quick Start

```bash
# 1. Navigate to project
cd fit-iq/lume

# 2. Run all unit tests
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -testPlan lumeUnitTests

# 3. Run integration tests
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -testPlan lumeIntegrationTests

# 4. Generate coverage report
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  -resultBundlePath ./TestResults
```

### Coverage Targets

| Component | Target Coverage | Current |
|-----------|----------------|---------|
| OutboxProcessorService | 80%+ | TBD |
| GoalRepository | 80%+ | TBD |
| MoodRepository | 80%+ | TBD |
| JournalRepository | 80%+ | TBD |
| ChatRepository | 80%+ | TBD |

---

## Unit Tests

### 1. OutboxProcessorService Tests

**Location:** `lumeTests/Services/OutboxProcessorServiceTests.swift`

**Run specific test:**
```bash
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:lumeTests/OutboxProcessorServiceTests
```

#### Test Coverage

✅ **Mood Event Processing**
- `testProcessMoodCreated_Success_StoresBackendId`
- `testProcessMoodUpdated_WithBackendId_Success`
- `testProcessMoodUpdated_WithoutBackendId_FallsBackToCreate`
- `testProcessMoodDeleted_WithBackendId_Success`
- `testProcessMoodDeleted_WithoutBackendId_Skips`

✅ **Goal Event Processing**
- `testProcessGoalCreated_Success_StoresBackendId`
- `testProcessGoalUpdated_Success`

✅ **Error Handling**
- `testProcessOutbox_NoNetwork_SkipsProcessing`
- `testProcessOutbox_NoToken_SkipsProcessing`
- `testProcessEvent_HTTPError401_StopsProcessing`
- `testProcessEvent_HTTPError404_MarksCompleted`
- `testProcessEvent_HTTPError409_MarksCompleted`
- `testProcessEvent_GenericError_Retries`
- `testProcessEvent_MaxRetriesReached_GivesUp`

✅ **Multiple Events**
- `testProcessOutbox_MultipleEvents_ProcessesAll`

#### Expected Results

All tests should pass with:
- ✅ 0 failures
- ✅ 0 skipped
- ✅ Execution time < 5 seconds

### 2. GoalRepository Tests

**Location:** `lumeTests/Repositories/GoalRepositoryTests.swift`

**Run specific test:**
```bash
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:lumeTests/GoalRepositoryTests
```

#### Test Coverage

✅ **Create Operations**
- `testCreate_Success_CreatesLocalGoal`
- `testCreate_Success_CreatesOutboxEvent`
- `testCreate_OutboxFails_StillCreatesGoalLocally`

✅ **Update Operations**
- `testUpdate_Success_UpdatesLocalGoal`
- `testUpdate_Success_CreatesOutboxEvent`
- `testUpdate_GoalNotFound_ThrowsError`

✅ **Progress Updates**
- `testUpdateProgress_Success_UpdatesLocalGoal`
- `testUpdateProgress_Success_CreatesOutboxEvent`

✅ **Status Updates**
- `testUpdateStatus_Success_UpdatesLocalGoal`
- `testUpdateStatus_Success_CreatesOutboxEvent`

✅ **Delete Operations**
- `testDelete_Success_DeletesLocalGoal`
- `testDelete_WithBackendId_CreatesOutboxEventWithMetadata`
- `testDelete_WithoutBackendId_CreatesOutboxEventWithoutBackendId`

✅ **Fetch Operations**
- `testFetchAll_ReturnsAllGoals`
- `testFetchById_ReturnsCorrectGoal`
- `testFetchByCategory_ReturnsFilteredGoals`
- `testFetchByStatus_ReturnsFilteredGoals`

#### Expected Results

All tests should pass with:
- ✅ 0 failures
- ✅ Outbox events created for all CRUD operations
- ✅ Metadata contains correct information

### 3. Running All Unit Tests

```bash
# Run all unit tests
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  | grep -E "Test Suite|Test Case|passed|failed"
```

**Success Criteria:**
- ✅ All tests pass
- ✅ No crashes or hangs
- ✅ Total execution time < 10 seconds

---

## Integration Tests

### Test Scenarios

#### 1. Full Sync Flow (Offline → Online)

**Test:** Create goal offline, go online, verify sync

```swift
// Pseudo-code
1. Set network monitor to offline
2. Create goal via repository
3. Verify goal exists locally
4. Verify outbox event created
5. Set network monitor to online
6. Trigger outbox processing
7. Verify goal synced to backend
8. Verify backend ID stored locally
9. Verify outbox event marked as completed
```

**Expected Result:**
- ✅ Goal created locally while offline
- ✅ Outbox event created with `.pending` status
- ✅ Goal syncs when online
- ✅ Backend ID stored in local goal
- ✅ Outbox event marked `.completed`

#### 2. Update Sync Flow

**Test:** Update goal, verify sync

```swift
1. Create goal with backend ID
2. Update goal locally
3. Verify outbox event created (isNewRecord: false)
4. Trigger outbox processing
5. Verify backend updated
6. Verify outbox event completed
```

**Expected Result:**
- ✅ Update event created with correct metadata
- ✅ Backend receives update with correct ID
- ✅ Local and backend data consistent

#### 3. Delete Sync Flow

**Test:** Delete goal, verify backend deletion

```swift
1. Create goal with backend ID
2. Delete goal locally
3. Verify outbox event created with metadata["operation"] = "delete"
4. Verify metadata["backendId"] contains backend ID
5. Trigger outbox processing
6. Verify backend deletion called
7. Verify local goal deleted
```

**Expected Result:**
- ✅ Deletion event contains backendId in metadata
- ✅ Backend deletion succeeds
- ✅ Local data removed
- ✅ Outbox event completed

#### 4. Conflict Resolution

**Test:** Create goal that already exists (409 conflict)

```swift
1. Create goal locally
2. Mock backend to return 409 conflict
3. Trigger outbox processing
4. Verify event marked as completed (not failed)
5. Verify no infinite retries
```

**Expected Result:**
- ✅ Conflict detected and handled gracefully
- ✅ Event marked as completed
- ✅ No retry loop

#### 5. Retry Logic

**Test:** Transient error triggers retry

```swift
1. Create goal locally
2. Mock backend to return 500 error
3. Trigger outbox processing
4. Verify event marked as failed (not completed)
5. Verify attemptCount incremented
6. Trigger processing again
7. Verify retry with exponential backoff
```

**Expected Result:**
- ✅ Transient errors trigger retry
- ✅ Attempt count increments
- ✅ Exponential backoff applied
- ✅ Max retries respected

---

## Manual Testing

### Prerequisites

1. ✅ Lume app installed on simulator/device
2. ✅ Valid test account credentials
3. ✅ Backend API accessible
4. ✅ Charles Proxy or similar (optional, for network inspection)

### Test Environment Setup

```
1. Launch Xcode
2. Select iPhone 15 simulator
3. Product → Clean Build Folder
4. Product → Build
5. Product → Run
6. Log in with test account
```

### Manual Test Checklist

#### ✅ Test 1: Create Goal Offline → Online Sync

**Steps:**
1. Enable Airplane Mode on simulator
2. Create a new goal:
   - Title: "Manual Test Goal 1"
   - Category: Fitness
   - Target Date: 30 days from now
3. Verify goal appears in goal list
4. Check Xcode console for:
   ```
   ✅ [GoalRepository] Created outbox event for goal: <UUID>
   ```
5. Disable Airplane Mode
6. Wait 30 seconds (automatic sync interval)
7. Check console for:
   ```
   ✅ [OutboxProcessor] Successfully synced goal: <UUID>, backend ID: <ID>
   ```
8. Verify goal has backend ID in database

**Expected Result:**
- ✅ Goal created offline
- ✅ Outbox event created
- ✅ Goal syncs when online
- ✅ Backend ID stored
- ✅ No errors or crashes

**Pass/Fail:** ___________

---

#### ✅ Test 2: Update Goal Progress

**Steps:**
1. Ensure online
2. Create a goal (wait for sync)
3. Update progress to 50%
4. Check console for:
   ```
   ✅ [GoalRepository] Created outbox event for progress update: <UUID>
   ```
5. Wait for sync
6. Verify backend has updated progress

**Expected Result:**
- ✅ Progress updated locally
- ✅ Outbox event created
- ✅ Backend receives update
- ✅ Progress matches

**Pass/Fail:** ___________

---

#### ✅ Test 3: Delete Goal

**Steps:**
1. Create a goal and wait for sync
2. Note the backend ID from console
3. Delete the goal
4. Check console for:
   ```
   🗑️ [GoalRepository] Deleting goal: <UUID>
   ✅ [GoalRepository] Created outbox event for deletion
   ```
5. Wait for sync
6. Check console for:
   ```
   ✅ [OutboxProcessor] Successfully deleted backend goal: <backend-ID>
   ```
7. Verify goal removed from list

**Expected Result:**
- ✅ Goal deleted locally
- ✅ Outbox event with delete metadata
- ✅ Backend deletion succeeds
- ✅ Goal removed from UI

**Pass/Fail:** ___________

---

#### ✅ Test 4: Create Mood Entry

**Steps:**
1. Navigate to Mood Tracker
2. Log a mood entry:
   - Valence: 0.7
   - Labels: Happy, Energetic
   - Notes: "Test entry"
3. Check console for outbox event creation
4. Wait for sync
5. Verify backend ID stored

**Expected Result:**
- ✅ Mood entry created
- ✅ Outbox event created
- ✅ Syncs to backend
- ✅ Backend ID stored

**Pass/Fail:** ___________

---

#### ✅ Test 5: Multiple Rapid Changes

**Steps:**
1. Create 5 goals rapidly (< 5 seconds apart)
2. Update 3 goals immediately after creation
3. Delete 2 goals
4. Check console for all outbox events
5. Wait for sync (may take 1-2 minutes)
6. Verify all operations synced correctly

**Expected Result:**
- ✅ All events captured in outbox
- ✅ Events process sequentially
- ✅ No data loss
- ✅ No duplicate syncs
- ✅ Final state consistent

**Pass/Fail:** ___________

---

#### ✅ Test 6: App Crash During Sync

**Steps:**
1. Create a goal
2. Wait for outbox event creation
3. Immediately force quit the app (swipe up)
4. Relaunch app
5. Wait for automatic sync
6. Verify goal eventually syncs

**Expected Result:**
- ✅ Outbox event persists across app restart
- ✅ Sync resumes on relaunch
- ✅ Goal syncs successfully
- ✅ No data corruption

**Pass/Fail:** ___________

---

#### ✅ Test 7: Network Interruption

**Steps:**
1. Create a goal (online)
2. Enable Airplane Mode immediately
3. Wait 10 seconds
4. Disable Airplane Mode
5. Wait for sync to resume
6. Verify goal syncs

**Expected Result:**
- ✅ Graceful handling of network loss
- ✅ Sync resumes automatically
- ✅ No crashes or infinite loops

**Pass/Fail:** ___________

---

#### ✅ Test 8: Token Expiration

**Steps:**
1. Create a goal
2. Wait for token to expire (simulate by invalidating in keychain)
3. Trigger sync
4. Verify re-authentication prompt appears
5. Re-authenticate
6. Verify goal syncs after re-auth

**Expected Result:**
- ✅ Expired token detected
- ✅ User prompted to re-authenticate
- ✅ Sync resumes after re-auth
- ✅ No data loss

**Pass/Fail:** ___________

---

### Manual Testing Summary

| Test | Status | Notes |
|------|--------|-------|
| 1. Offline → Online Sync | ☐ Pass ☐ Fail | |
| 2. Update Goal Progress | ☐ Pass ☐ Fail | |
| 3. Delete Goal | ☐ Pass ☐ Fail | |
| 4. Create Mood Entry | ☐ Pass ☐ Fail | |
| 5. Multiple Rapid Changes | ☐ Pass ☐ Fail | |
| 6. App Crash During Sync | ☐ Pass ☐ Fail | |
| 7. Network Interruption | ☐ Pass ☐ Fail | |
| 8. Token Expiration | ☐ Pass ☐ Fail | |

**Overall Manual Testing:** ☐ Pass ☐ Fail

---

## Performance Testing

### Metrics to Measure

#### 1. Outbox Event Processing Time

**Test:** Measure time to process a single event

```swift
// Example test
func testPerformance_ProcessSingleEvent() async throws {
    let event = createTestEvent()
    
    measure {
        await sut.processEvent(event, accessToken: "test-token")
    }
}
```

**Target:** < 200ms per event

#### 2. Batch Processing Performance

**Test:** Process 50 events sequentially

**Target:** < 10 seconds total (< 200ms per event)

#### 3. Database Query Performance

**Test:** Fetch 1000 goals with filters

**Target:** < 100ms

#### 4. Metadata Serialization Performance

**Test:** Serialize/deserialize 100 outbox events

**Target:** < 50ms

### Performance Test Results

| Test | Target | Actual | Pass/Fail |
|------|--------|--------|-----------|
| Single event processing | < 200ms | ___ | ☐ |
| Batch 50 events | < 10s | ___ | ☐ |
| Fetch 1000 goals | < 100ms | ___ | ☐ |
| Metadata serialization | < 50ms | ___ | ☐ |

---

## Troubleshooting

### Common Issues

#### Issue 1: Tests Fail with "Entity Not Found"

**Cause:** SwiftData model not properly inserted or saved

**Solution:**
```swift
// Ensure you call save() after insert
modelContext.insert(entity)
try modelContext.save() // ✅ Don't forget this!
```

#### Issue 2: Outbox Events Not Processing

**Symptoms:**
- Events remain in `.pending` status
- No console logs from OutboxProcessor

**Debugging Steps:**
1. Check network monitor: `print(networkMonitor.isConnected)`
2. Check token: `print(try? await tokenStorage.getToken())`
3. Check pending events: `print(await outboxRepository.fetchPendingEvents())`
4. Manually trigger: `await outboxProcessor.processOutbox()`

#### Issue 3: Backend ID Not Stored

**Symptoms:**
- Goal syncs but `backendId` is nil

**Debugging Steps:**
1. Check console for backend response
2. Verify `moodEntry.backendId = backendId` is called
3. Verify `modelContext.save()` is called after assignment
4. Check SwiftData persistence

#### Issue 4: Duplicate Events Created

**Symptoms:**
- Multiple outbox events for same entity ID

**Debugging Steps:**
1. Check if `createEvent` is called multiple times
2. Verify repository doesn't call `save()` twice
3. Check for race conditions in concurrent code

#### Issue 5: Tests Timeout

**Symptoms:**
- Tests hang indefinitely

**Solution:**
1. Add timeout to async tests:
   ```swift
   try await withTimeout(seconds: 5) {
       await sut.processOutbox()
   }
   ```
2. Check for infinite loops in retry logic
3. Verify mock responses are configured

---

## Test Reporting

### Generate Test Report

```bash
# Run tests with coverage
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  -resultBundlePath ./TestResults.xcresult

# Generate HTML report (requires xcpretty)
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  | xcpretty --report html --output test-report.html
```

### Test Summary Template

```markdown
# Test Execution Summary

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Build:** [Build Number]
**Environment:** [Simulator/Device]

## Unit Tests
- Total: ___
- Passed: ___
- Failed: ___
- Coverage: ___%

## Integration Tests
- Total: ___
- Passed: ___
- Failed: ___

## Manual Tests
- Total: 8
- Passed: ___
- Failed: ___

## Performance Tests
- Total: 4
- Passed: ___
- Failed: ___

## Issues Found
1. [Issue description]
2. [Issue description]

## Recommendation
☐ Ready for production
☐ Requires fixes
☐ Requires further testing
```

---

## Next Steps After Testing

### If All Tests Pass ✅

1. **Code Review**
   - Submit PR with test results
   - Address review feedback
   - Merge to main

2. **TestFlight Deployment**
   - Deploy to internal TestFlight
   - Monitor crash reports
   - Collect feedback

3. **Beta Testing**
   - Deploy to beta testers
   - Monitor for 1 week
   - Track metrics

4. **Production Rollout**
   - Gradual rollout (10% → 50% → 100%)
   - Monitor error rates
   - Be ready to rollback

### If Tests Fail ❌

1. **Document Failures**
   - Screenshot errors
   - Save console logs
   - Note reproduction steps

2. **File Bug Reports**
   - Create GitHub issues
   - Tag with priority
   - Assign to team

3. **Fix and Retest**
   - Fix critical bugs
   - Re-run failed tests
   - Verify fixes work

4. **Regression Testing**
   - Re-run all tests
   - Ensure no new issues
   - Update test cases

---

## Appendix

### Useful Console Commands

```swift
// Enable verbose logging
AppMode.debugLogging = true

// Manually trigger outbox processing
await outboxProcessor.processOutbox()

// Check pending event count
print("Pending events: \(outboxProcessor.pendingEventCount)")

// Inspect outbox events
let events = try await outboxRepository.fetchPendingEvents(forUserID: nil, limit: 10)
print("Events: \(events)")

// Check network status
print("Network connected: \(networkMonitor.isConnected)")

// Check token
if let token = try? await tokenStorage.getToken() {
    print("Token expires: \(token.expiresAt)")
}
```

### Simulator Commands

```bash
# Reset simulator
xcrun simctl erase all

# Enable/disable network
xcrun simctl status_bar <DEVICE_ID> override --dataNetwork wifi

# List simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 15"
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27  
**Author:** AI Assistant  
**Status:** Active