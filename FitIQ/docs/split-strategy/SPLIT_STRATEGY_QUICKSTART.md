# FitIQ Split Strategy - Quick Start Guide

**Date:** 2025-01-27  
**Status:** ✅ Ready to Implement  
**Estimated Timeline:** 3-4 months

---

## 🎯 The Decision

**Split FitIQ into two focused apps:**

### FitIQ - Fitness & Nutrition Intelligence
**Focus:** Quantitative health metrics
- 📊 Activity tracking (steps, heart rate)
- ⚖️ Body metrics (weight, BMI)
- 🍎 Nutrition tracking
- 💪 Workout management
- 😴 Sleep tracking
- 🎯 Goal management
- 🤖 AI Coach (fitness-focused)

**Users:** Gym-goers, athletes, fitness enthusiasts

---

### Lume - Wellness & Mood Intelligence
**Focus:** Qualitative mental health
- 😊 Mood tracking (iOS 18 HealthKit)
- 🧘 Wellness templates
- 🌊 Stress management
- ⏸️ Mindfulness practices
- 📝 Daily habits
- 💤 Recovery optimization

**Users:** Mindfulness seekers, wellness-focused individuals

---

## ✅ Why This Approach?

### Key Benefits

1. **👥 Clear User Experience**
   - Each app has a specific purpose
   - Simpler navigation
   - Faster, more focused
   - No feature overload

2. **📈 Better Market Position**
   - Clear App Store categories
   - Focused marketing
   - Better keyword targeting
   - Easier user acquisition

3. **🏗️ Cleaner Architecture**
   - Smaller, more maintainable codebases
   - Parallel development possible
   - Clear ownership boundaries
   - Easier to onboard developers

4. **🔗 Unified Backend**
   - Single user account
   - Centralized data
   - Cross-app insights possible
   - No backend changes needed ✅

5. **🎨 Design Freedom**
   - FitIQ: Bold, energetic, performance-focused
   - Lume: Calm, soothing, mindfulness-focused
   - Each app can have its own identity

---

## 📋 5-Phase Implementation Plan

### Phase 1: Preparation (2-3 weeks)
**Goal:** Create shared infrastructure foundation

#### Tasks
- [ ] Create `FitIQCore` Swift Package
  - [ ] Extract authentication domain
  - [ ] Extract API client foundation
  - [ ] Extract HealthKit integration framework
  - [ ] Extract SwiftData utilities
  - [ ] Extract common UI components
  - [ ] Extract error handling

- [ ] Set up workspace structure
  - [ ] Create `FitIQ.xcworkspace`
  - [ ] Configure package dependencies
  - [ ] Update build settings

- [ ] Refactor for modularity
  - [ ] Remove cross-domain dependencies
  - [ ] Ensure domain isolation
  - [ ] Update dependency injection

**Deliverables:**
- ✅ `FitIQCore` Swift Package (compiles independently)
- ✅ Workspace configuration
- ✅ Documentation

**Effort:** 4-6 person-weeks

---

### Phase 2: Update FitIQ App (1-2 weeks)
**Goal:** Maintain FitIQ with new structure

#### Tasks
- [ ] Integrate `FitIQCore` into FitIQ
  - [ ] Update imports
  - [ ] Remove duplicated code
  - [ ] Update DI configuration

- [ ] Test all features
  - [ ] Run test suite
  - [ ] Manual QA
  - [ ] Performance validation

- [ ] Add deprecation notices
  - [ ] In-app notice for mood tracking
  - [ ] "Try Lume" promotion placeholder
  - [ ] Migration guide draft

**Deliverables:**
- ✅ FitIQ using `FitIQCore` (fully functional)
- ✅ Test reports (no regressions)
- ✅ Updated documentation

**Effort:** 2-4 person-weeks

---

### Phase 3: Create Lume App (3-4 weeks)
**Goal:** Build focused wellness app

#### Tasks
- [ ] Set up Lume project
  - [ ] New Xcode project
  - [ ] Configure bundle ID (com.marcosbarbero.lume)
  - [ ] Add `FitIQCore` dependency
  - [ ] Configure HealthKit capabilities
  - [ ] Set up App Store Connect

- [ ] Implement core features
  - [ ] Mood tracking UI
  - [ ] Wellness templates
  - [ ] Daily habits
  - [ ] Mindfulness exercises
  - [ ] Wellness dashboard

- [ ] Design Lume UX
  - [ ] Calming color palette (soft blues, greens)
  - [ ] Mindfulness-focused navigation
  - [ ] Daily check-in flows
  - [ ] Smooth animations

- [ ] Migrate from FitIQ
  - [ ] Mood tracking domain
  - [ ] Wellness use cases
  - [ ] Update branding

- [ ] Testing
  - [ ] Unit tests
  - [ ] UI tests
  - [ ] Integration tests

**Deliverables:**
- ✅ Lume app (feature-complete)
- ✅ App Store assets
- ✅ Test reports
- ✅ User documentation

**Effort:** 6-8 person-weeks

---

### Phase 4: Cross-App Integration (1 week)
**Goal:** Enable seamless experience

#### Tasks
- [ ] Implement deep linking
  - [ ] FitIQ → Lume mood check-in
  - [ ] Lume → FitIQ activity view
  - [ ] URL scheme handlers

- [ ] Implement universal links
  - [ ] Configure domains
  - [ ] Handle app switches
  - [ ] Test handoff

- [ ] Cross-promotion
  - [ ] Lume promo in FitIQ
  - [ ] FitIQ promo in Lume
  - [ ] In-app suggestions

- [ ] Shared account validation
  - [ ] JWT token sharing
  - [ ] Profile sync testing
  - [ ] Backend integration

**Deliverables:**
- ✅ Deep linking working
- ✅ Integration tests passing
- ✅ Marketing materials

**Effort:** 1-2 person-weeks

---

### Phase 5: Launch & Migration (2 weeks)
**Goal:** Release Lume, migrate users

#### Tasks
- [ ] Beta testing
  - [ ] TestFlight for Lume (2 weeks)
  - [ ] Gather feedback
  - [ ] Fix critical issues

- [ ] Release Lume v1.0
  - [ ] App Store submission
  - [ ] Marketing campaign
  - [ ] Blog post

- [ ] Update FitIQ
  - [ ] Add "Try Lume" banner
  - [ ] Update wellness features (deprecation)
  - [ ] Migration guide in-app

- [ ] Monitor & iterate
  - [ ] User retention metrics
  - [ ] Adoption rate tracking
  - [ ] Feedback collection
  - [ ] Performance monitoring

- [ ] Gradual wellness removal
  - [ ] Month 1-3: Deprecation notices
  - [ ] Month 4-6: Read-only mode
  - [ ] Month 7+: Full removal

**Deliverables:**
- ✅ Lume v1.0 on App Store
- ✅ FitIQ updated with migration
- ✅ Analytics dashboards
- ✅ User feedback summary

**Effort:** 2-3 person-weeks

---

## ⏱️ Timeline & Resources

### Total Timeline
- **Calendar Time:** 9-12 weeks (3-4 months)
- **Effort:** 15-23 person-weeks
- **Team Size:** 2-3 developers
- **Parallelization:** Phases 2 & 3 can partially overlap

### Resource Allocation

| Phase | Developer 1 | Developer 2 | Developer 3 |
|-------|-------------|-------------|-------------|
| Phase 1 | Core Package | HealthKit | Network |
| Phase 2 | FitIQ Integration | Testing | Documentation |
| Phase 3 | Lume Backend | Lume UI | Lume Testing |
| Phase 4 | Deep Linking | Promotion | Integration Tests |
| Phase 5 | FitIQ Updates | Lume Launch | Monitoring |

---

## 📊 Code Distribution

### FitIQCore (Shared Package) - ~15K lines
```
FitIQCore/
├── Domain/
│   ├── Auth/
│   ├── Profile/
│   └── Common/
├── Infrastructure/
│   ├── Network/
│   ├── HealthKit/
│   └── Persistence/
└── Utilities/
```

### FitIQ App - ~45K lines
```
FitIQ/
├── FitIQCore (dependency)
├── Domain/
│   ├── Nutrition/
│   ├── Workout/
│   ├── Activity/
│   └── BodyMetrics/
├── Presentation/
│   └── UI/
└── App/
```

### Lume App - ~12K lines
```
Lume/
├── FitIQCore (dependency)
├── Domain/
│   ├── Mood/
│   ├── Wellness/
│   └── Mindfulness/
├── Presentation/
│   └── UI/
└── App/
```

**Duplication:** ~5% (~3.5K lines) - acceptable for independence

---

## 🚧 Potential Challenges & Solutions

### Challenge 1: Code Duplication
**Solution:** 
- Aggressive use of `FitIQCore` package
- Regular refactoring to extract common patterns
- Accept ~5% duplication for independence

### Challenge 2: User Confusion
**Solution:**
- Clear in-app messaging about split
- Deep linking between apps
- Unified branding (FitIQ family of apps)
- Migration guide with screenshots

### Challenge 3: Backend API Usage
**Solution:**
- No backend changes needed ✅
- Both apps use same API
- Single authentication flow
- Shared user account

### Challenge 4: Cross-App Data Correlation
**Solution:**
- Backend provides unified analytics endpoints
- Each app can show relevant cross-domain insights
- Deep link to other app for details
- Web dashboard for complete view (future)

### Challenge 5: App Store Discovery
**Solution:**
- Cross-promotion in each app
- "Also by this developer" in App Store
- Unified marketing website
- Clear messaging: "FitIQ for fitness, Lume for wellness"

---

## 🎯 Success Metrics

### Phase 1-2 Success (FitIQ Refactoring)
- ✅ No regressions in FitIQ functionality
- ✅ Build time unchanged or improved
- ✅ All tests passing
- ✅ `FitIQCore` package compiles independently

### Phase 3 Success (Lume Creation)
- ✅ Lume app feature-complete
- ✅ App Store approval obtained
- ✅ Beta testing feedback positive (>4.0/5.0)
- ✅ No critical bugs

### Phase 4 Success (Integration)
- ✅ Deep linking works in both directions
- ✅ User account shared seamlessly
- ✅ Cross-promotion visible and clickable

### Phase 5 Success (Launch & Migration)
- ✅ Lume adoption rate >20% of FitIQ users (within 3 months)
- ✅ FitIQ user retention >90%
- ✅ Combined App Store rating >4.5/5.0
- ✅ No major user complaints about split

### Long-Term Success (6+ months)
- ✅ Both apps independently viable
- ✅ Clear user segmentation visible
- ✅ Development velocity improved
- ✅ App Store rankings improved for both

---

## 📝 Immediate Next Steps

### 1. Review & Approve (This Week)
- [ ] Review `PRODUCT_ASSESSMENT.md` (full analysis)
- [ ] Review this quick start guide
- [ ] Discuss with team
- [ ] Get stakeholder buy-in

### 2. User Research (Optional - 1-2 Weeks)
- [ ] Survey existing users about preferences
- [ ] Validate demand for wellness separation
- [ ] Gather feedback on navigation complexity
- [ ] Test Lume mockups

### 3. Prototype Lume (Optional - 1 Week)
- [ ] Create Figma mockups
- [ ] Test with users
- [ ] Refine UX
- [ ] Finalize design system

### 4. Start Phase 1 (Week 2-3)
- [ ] Create `FitIQCore` package skeleton
- [ ] Extract authentication domain
- [ ] Set up workspace
- [ ] Update documentation

---

## 📚 Key Documents

1. **Full Assessment:** `PRODUCT_ASSESSMENT.md` (comprehensive analysis)
2. **This Guide:** Quick start and implementation plan
3. **Architecture:** `.github/copilot-instructions.md`
4. **API Reference:** `docs/be-api-spec/swagger.yaml`
5. **Integration:** `docs/IOS_INTEGRATION_HANDOFF.md`

---

## 🤝 Team Roles

### Technical Lead
- Architecture decisions
- Code review
- `FitIQCore` package design
- Cross-app integration

### iOS Developer 1
- FitIQ app refactoring
- FitIQ testing
- Performance optimization

### iOS Developer 2
- Lume app development
- Lume UI/UX implementation
- Lume testing

### Designer (Part-Time)
- Lume design system
- App Store assets
- Marketing materials

### QA/Testing (Part-Time)
- Test plan creation
- Manual testing
- User feedback collection

---

## 💬 Decision Time

### Ready to Proceed?

**If YES:**
1. Assign team members to roles
2. Set up project tracking (GitHub Projects or Jira)
3. Schedule kick-off meeting
4. Start Phase 1 next week

**If NO (Need More Info):**
1. Conduct user research
2. Create Lume prototype
3. Validate assumptions
4. Re-evaluate in 2-4 weeks

**If ALTERNATIVE APPROACH:**
1. Review `PRODUCT_ASSESSMENT.md` Alternative Approaches section
2. Evaluate trade-offs
3. Document decision rationale
4. Update this guide accordingly

---

## 🎉 Final Thoughts

This split represents a **strategic investment** in FitIQ's future:

- **Better user experience** for everyone
- **Clearer market positioning** for growth
- **Healthier codebase** for long-term maintenance
- **Two focused products** instead of one unfocused product

The architecture is **already modular** and **ready for this split**. The backend is **unified and requires no changes**. The timeline is **realistic and achievable**.

**This is the right move at the right time.** ✅

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Ready for Implementation  
**Next Review:** After Phase 1 Complete
