# CogniQ Accessibility Recommendations

**Date:** July 18, 2026  
**Scope:** WCAG 2.1 compliance targets + accessibility improvements  
**Goal:** Make CogniQ usable for players with disabilities (vision, motor, cognitive, hearing)

---

## STATUS: proposal — but the quick wins are worth doing (flagged 2026-07-18)

Unlike the roadmap/social/onboarding files, most of this is low-risk and real. Verified-true premises: there are **no `Semantics` widgets / accessibility labels** in the game grids, font scaling (0.85/1.0/1.15) and dark mode **do** exist, and the font-scale + no-labels gaps are genuine. The concrete quick wins — add semantic labels to grids, verify WCAG contrast on the palette, add text labels to icon-only buttons, add focus indicators — are worth doing regardless of any roadmap. Timelines/WCAG-certification dates are estimates, not scoped commitments.

---

## Executive Summary

CogniQ currently has **moderate accessibility support** (font scaling, dark mode) but **critical gaps** (no screen reader support, no semantic labels). 

**Quick Wins (2-3 days effort):**
- Add semantic labels to game grids
- Fix text contrast issues
- Add keyboard navigation

**Medium Effort (1-2 weeks):**
- Screen reader optimization
- Motor accessibility (larger touch targets)
- Cognitive accessibility (clearer instructions)

**Timeline:** Address critical gaps by Q4 2026, full compliance by Q1 2027

---

## Current Accessibility Assessment

### What's Working ✅
- Dark mode (full implementation)
- Font scaling (0.85x, 1.0x, 1.15x)
- Color contrast generally acceptable (need WCAG verification)
- High refresh rate on Android
- Haptic feedback available

### Critical Gaps ❌
- No Semantics widgets (screen readers can't navigate games)
- No semantic labels for game elements
- Text overflow possible at 1.15x font scale
- Keyboard navigation not tested
- Game grid cells not labeled
- No alt text for visual elements
- Cognitive overload possible (no simplification mode)

### Known Issues ⚠️
- Font scale 1.15x could cause text overflow on small screens
- Color-only indicators (red = error) without text labels
- Game instructions may be unclear for new players
- No focus indicators visible (keyboard users)

---

# ACCESSIBILITY PRIORITIES

## Priority 1: Screen Reader Support (CRITICAL)

### Issue
Game grids are inaccessible to blind/low-vision players. Screen readers can't read grid cell contents, game states, or feedback.

### Solutions

#### 1.1 Add Semantics to Game Grids
```dart
// Current (inaccessible):
GridView.builder(
  itemBuilder: (ctx, idx) => GestureDetector(
    onTap: () => _selectCell(idx),
    child: Container(child: Text('1')),
  ),
)

// Recommended (accessible):
Semantics(
  customSemanticsActions: {
    CustomSemanticsAction('select'): () => _selectCell(idx),
  },
  label: 'Cell ${row}, ${col}: empty',
  enabled: true,
  child: GestureDetector(
    onTap: () => _selectCell(idx),
    child: Container(child: Text('1')),
  ),
)
```

#### 1.2 Label All Game Elements
- **Cells:** "Cell row 2, column 3: contains 5"
- **Numbers/clues:** "Clue: see 3 buildings from left"
- **Status:** "Level 15, difficulty: hard, progress: 8 of 16 cells filled"
- **Buttons:** "[Hint button]", "[Check puzzle button]"
- **Errors:** "[Error: this cell violates constraint]"

#### 1.3 Announce Game State Changes
```dart
// When cell filled:
SemanticsService.announce('Cell filled with 5');

// When level complete:
SemanticsService.announce('Level 15 complete! You solved it in 3 minutes.');

// When hint given:
SemanticsService.announce('Hint: Cell row 1 column 2 should be 4');
```

#### 1.4 Game-Specific Labels

**Sudoku:**
- Announce when row/column/region complete
- Label clue numbers as "clue: row 3 shows 2"
- Announce candidates when generating

**Colour Link:**
- Announce connection progress: "Red connected to 5 cells"
- Label path state: "uncompleted path" vs "complete path"

**Star Battle:**
- Label region numbers: "Region top-left needs 1 star"
- Announce star placement: "Star placed at row 2, column 3"

### Implementation Checklist
- [ ] Add Semantics to all game grid cells
- [ ] Label all buttons + interactive elements
- [ ] Announce game state changes (level start, puzzle complete, errors)
- [ ] Test with TalkBack (Android) and VoiceOver (iOS)
- [ ] Create screen reader testing guide
- **Estimated effort:** 2 weeks (per game)

### Success Criteria
- Screen reader announces all game elements
- Player can play entire game using only screen reader
- WCAG 2.1 Level AA for screen reader support

---

## Priority 2: Motor Accessibility

### Issue
Small touch targets difficult for players with motor disabilities (tremors, limited dexterity, arthritis).

### Solutions

#### 2.1 Increase Touch Target Sizes
```
Current: 48px cells
Recommended: 56px+ (Material Design minimum is 48dp, but 56dp better)
High-difficulty mode: 72px cells (can be toggled in settings)
```

#### 2.2 Add Accessibility-Specific Touch Settings
```
Settings → Accessibility:
  [ ] Large touch targets (56px, 72px)
  [ ] Slow animation speed (for players with slower reactions)
  [ ] Reduce animations (less motion for vestibular issues)
  [ ] Double-tap delay (longer window for confirmation)
  [ ] Haptic feedback intensity: Low / Medium / High
```

#### 2.3 Keyboard Navigation
```dart
// All games should support keyboard navigation
// Arrow keys: Move between cells
// 1-9 keys: Fill cell with number (Sudoku, Kakuro, etc.)
// Space/Enter: Confirm action
// Escape: Cancel action
// Tab: Move to next interactive element
```

**Keyboard Shortcuts:**
```
↑ ↓ ← → : Navigate grid
1-9 : Fill cell with number
0 : Clear cell
Space : Toggle cell state (Yin-Yang)
Enter : Confirm action / Next level
Escape : Cancel / Back
H : Show hint
U : Undo
R : Restart level
+ / - : Increase/decrease font size
```

#### 2.4 Motion Sensitivity Settings
```
Settings → Motion:
  [ ] Reduce animations (disable all non-critical animations)
  [ ] Reduce parallax (disable depth effects)
  [ ] Remove confetti (disable celebration animations)
  [ ] Slower transitions (300ms → 500ms)
```

### Implementation Checklist
- [ ] Implement large touch targets toggle
- [ ] Add full keyboard navigation (all games)
- [ ] Add motion sensitivity settings
- [ ] Test with adaptive controllers (if possible)
- [ ] Document keyboard shortcuts in-app
- **Estimated effort:** 2-3 weeks

### Success Criteria
- Players with motor disabilities can play without difficulty
- Keyboard navigation works for all games
- Large touch target mode reduces errors
- WCAG 2.1 Level AA for motor accessibility

---

## Priority 3: Cognitive Accessibility

### Issue
Complex game instructions, unclear feedback, overwhelming UI for players with cognitive disabilities (dyslexia, ADHD, etc.)

### Solutions

#### 3.1 Simplified Game Instructions
```
Current: Dense rules explanation
Recommended:
  1. Show rules ONE AT A TIME (not all at once)
  2. Use diagrams/visuals with text (not text-only)
  3. Progressive disclosure (basic rules first, advanced later)
  4. Highlight key instruction (bold/color)
```

#### 3.2 Clear, Unambiguous Feedback
```
Current: "Constraint violated"
Recommended: "This number breaks the rule: no same numbers in row"

Current: Red error flash (no explanation)
Recommended: "Error: Row 3 already has a 5 in column 2"
```

#### 3.3 Cognitive Load Reduction
```
Settings → Cognitive:
  [ ] Show candidates (pre-fill possible numbers)
  [ ] Show constraint highlighting (highlight what's conflicting)
  [ ] Simplified mode (fewer rules, smaller grids to start)
  [ ] Slow mode (can't accidentally tap wrong cell)
  [ ] Focus mode (dim non-relevant cells)
```

#### 3.4 Dyslexia-Friendly Options
```
Settings → Dyslexia:
  [ ] Dyslexia-friendly font (OpenDyslexic or similar)
  [ ] Increased letter spacing
  [ ] Increased line height
  [ ] Non-justified text alignment
  [ ] Colored overlays (optional tint over text)
```

### Implementation Checklist
- [ ] Rewrite all game instructions (progressive disclosure)
- [ ] Add visual diagrams to every game rule
- [ ] Implement dyslexia-friendly font option
- [ ] Add constraint highlighting feature
- [ ] Test with cognitive disabilities advocate group
- **Estimated effort:** 2-3 weeks

### Success Criteria
- Instructions clear and non-overwhelming
- Feedback specific and actionable
- Dyslexia-friendly options reduce reading errors
- WCAG 2.1 Level AA for cognitive accessibility

---

## Priority 4: Visual Accessibility

### Issue
Color contrast may not meet WCAG AA standards. Small text hard to read even with scaling.

### Solutions

#### 4.1 Verify Color Contrast
```
WCAG AA requires:
- Text to background: 4.5:1 ratio
- UI components: 3:1 ratio

Current palette verification needed:
- textPrimaryLight (#1C1A18) on bgDarkLight (#F5F4F0): ✓ High
- Accent colors on white background: Need verification
- Error colors (#D4889C) on backgrounds: Need verification
```

**Action:** Use WebAIM contrast checker on all color combinations

#### 4.2 Improve Readability
```
Settings → Vision:
  [ ] High contrast mode (maximum contrast, blacks & whites)
  [ ] Increase minimum font size (prevent below 12px)
  [ ] Larger line spacing (improve readability)
  [ ] Focus mode (highlight current cell with large border)
```

#### 4.3 Text Alternative for Icons
```
Current: [Icon] alone (no text)
Recommended: [Icon] + text label

Examples:
  🔓 Claim → "[Claim] button"
  ✅ Check → "[Check puzzle] button"
  💡 Hint → "[Hint] button"
```

### Implementation Checklist
- [ ] Test all color combinations with WebAIM
- [ ] Fix any contrast violations
- [ ] Add text labels to all icon-only elements
- [ ] Implement high contrast mode
- [ ] Add focus indicators (keyboard navigation)
- **Estimated effort:** 1 week

### Success Criteria
- All text meets 4.5:1 contrast ratio (AA)
- All UI components meet 3:1 contrast ratio (AA)
- High contrast mode available for users who need it
- WCAG 2.1 Level AA for visual accessibility

---

## Priority 5: Hearing Accessibility

### Issue
Audio feedback (haptics work, but no visual alternatives for hearing-impaired players).

### Solutions

#### 5.1 Visual Feedback for All Audio Cues
```
Current:
  - Haptic feedback: ✓ Available
  - Sound effects: Currently disabled
  - Notifications: Visual only ✓

Recommended:
  - Visual flash on level complete (instead of sound)
  - Vibration pattern for achievements (instead of sound)
  - Animation feedback for all events
  - Never rely on sound alone
```

#### 5.2 Captions (If Audio Ever Re-enabled)
```
If audio re-enabled in future:
  - Provide visual equivalents
  - Add captions/transcripts
  - Show vibration patterns visually
```

### Implementation Checklist
- [ ] Verify no audio feedback required for gameplay
- [ ] Add visual feedback for all events
- [ ] Test without sound (game should be playable)
- **Estimated effort:** < 1 day

### Success Criteria
- Game fully playable without sound
- All audio feedback has visual equivalent
- Hearing-impaired players can fully access game

---

## Accessibility Testing Checklist

### Automated Testing
- [ ] WebAIM contrast checker (all colors)
- [ ] WAVE accessibility tool (automated issues)
- [ ] Lighthouse accessibility audit (Chrome)
- [ ] axe DevTools (accessibility checker)

### Manual Testing (Required)
- [ ] TalkBack testing (Android screen reader)
- [ ] VoiceOver testing (iOS screen reader)
- [ ] Keyboard-only navigation (all games)
- [ ] Large text testing (1.15x font scale + high contrast)
- [ ] Motion sensitivity testing (animations disabled)

### User Testing (Ideal)
- [ ] Test with blind/low-vision users
- [ ] Test with motor disability users (tremors, limited dexterity)
- [ ] Test with dyslexic users
- [ ] Test with ADHD/cognitive users
- [ ] Gather feedback on improvements

---

## Accessibility Settings Page Design

```
Settings → Accessibility

VISION
  [ ] Dark mode (toggle)
  [ ] Font size: Small | Normal | Large
  [ ] High contrast mode (toggle)
  [ ] Dyslexia-friendly font (toggle)
  [ ] Focus mode (highlight current cell) (toggle)

MOTOR
  [ ] Large touch targets (toggle)
  [ ] Keyboard navigation (toggle)
  [ ] Double-tap confirmation (toggle)
  [ ] Haptic intensity: Low | Medium | High
  [ ] Slow animations (toggle)

COGNITIVE
  [ ] Show candidates (toggle)
  [ ] Constraint highlighting (toggle)
  [ ] Simplified rules mode (toggle)
  [ ] Focus mode (dim non-relevant cells) (toggle)

HEARING
  [ ] Haptic feedback (toggle)
  [ ] Visual notifications (toggle)

GENERAL
  [ ] Accessibility guide
  [ ] Keyboard shortcuts
  [ ] Report accessibility issue
```

---

## WCAG 2.1 Compliance Roadmap

### Target: WCAG 2.1 Level AA (Recommended)

| Criteria | Current | Target | Timeline |
|----------|---------|--------|----------|
| Perceivable | Partial | AA | Q4 2026 |
| Operable | Partial | AA | Q4 2026 |
| Understandable | Partial | AA | Q1 2027 |
| Robust | Partial | AA | Q1 2027 |

### WCAG Compliance by Criterion

**1. Perceivable**
- 1.3 Adaptable: Add Semantics ✓
- 1.4 Distinguishable: Fix contrast + high contrast mode ✓

**2. Operable**
- 2.1 Keyboard Accessible: Add keyboard navigation ✓
- 2.4 Navigable: Add focus indicators + semantic labels ✓

**3. Understandable**
- 3.2 Predictable: Clear game feedback ✓
- 3.3 Input Assistance: Helpful error messages ✓

**4. Robust**
- 4.1 Compatible: Screen reader compatible ✓

---

## Implementation Timeline

### Q3 2026 (Now)
- [ ] Add semantic labels (2 weeks)
- [ ] Fix critical contrast issues (3 days)

### Q4 2026
- [ ] Screen reader optimization (2 weeks)
- [ ] Keyboard navigation (2 weeks)
- [ ] Motor accessibility settings (1 week)
- [ ] Cognitive accessibility (2 weeks)
- [ ] Dyslexia-friendly options (1 week)

### Q1 2027
- [ ] Complete WCAG AA testing
- [ ] User testing with disability groups
- [ ] Final compliance certification

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| WCAG Compliance | AA level | Third-party audit |
| Screen reader usability | 90%+ playable | User testing |
| Keyboard navigation | 100% of games | Testing checklist |
| Color contrast | 100% AA | Automated tools |
| Accessibility settings adoption | 20%+ | Analytics |
| User satisfaction (disabled players) | 4/5 stars | App store reviews |

---

## Resources & References

- **WCAG 2.1:** https://www.w3.org/WAI/WCAG21/quickref/
- **Flutter Accessibility:** https://flutter.dev/docs/development/accessibility-and-localization/accessibility
- **WebAIM:** https://webaim.org/resources/
- **Inclusive Design:** https://www.microsoft.com/design/inclusive/

---

## Conclusion

Accessibility is not an afterthought — it's a core feature. Making CogniQ accessible to players with disabilities:
- **Expands audience:** 15-20% of population has disabilities
- **Improves UX for everyone:** Clear labels, high contrast, large text helps everyone
- **Legal requirement:** WCAG compliance increasingly mandated in app stores

**Next step:** Prioritize screen reader support (Q4) as foundation for broader accessibility improvements.

---

**Document prepared:** July 18, 2026  
**Compliance target:** WCAG 2.1 Level AA by Q1 2027  
**Estimated total effort:** 6-8 weeks across all priorities
