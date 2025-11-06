# Cevher Atölyesi Testing Checklist

## 🎯 Critical Bug Testing

### Test 1: Correct Answer Validation
**Objective:** Verify that correct answers are properly validated

**Steps:**
1. Navigate to Cevher Atölyesi (Mineral Workshop)
2. Select a topic and start a workshop
3. Read the study material carefully
4. Start the quiz
5. For each question, select the answer you're confident is correct
6. Submit the quiz

**Expected Result:**
- ✅ Correct answers are marked with green checkmarks
- ✅ If you selected a wrong answer, the correct one is highlighted in green
- ✅ The explanation matches the correct answer marked in green
- ✅ Your score accurately reflects your correct answers

**Red Flags:**
- ❌ Correct answer marked as wrong
- ❌ Explanation contradicts the marked correct answer
- ❌ Score doesn't match your correct answers

---

## 🛡️ AI Disclaimer Testing

### Test 2: Disclaimer Visibility
**Objective:** Verify AI disclaimers appear on all relevant screens

**Steps:**
1. Navigate to Cevher Atölyesi
2. Start a new workshop session
3. Check the study view
4. Start the quiz
5. Complete the quiz and check results
6. Navigate to Saved Workshops
7. Open a saved workshop

**Expected Result:**
- ✅ Disclaimer appears at the top of study view
- ✅ Disclaimer appears at the top of quiz view
- ✅ Disclaimer appears in results view
- ✅ Disclaimer appears in saved workshop detail (both tabs)

**Disclaimer Text Should Read:**
> "AI tarafından oluşturulan içerik hata yapabilir. Lütfen dikkatli olun ve şüpheli durumlarda 'Sorunu Bildir' özelliğini kullanın."

**Red Flags:**
- ❌ Disclaimer missing from any screen
- ❌ Disclaimer text is incorrect or unclear
- ❌ Disclaimer is not visible (wrong colors/contrast)

---

## 🎨 UI/UX Testing

### Test 3: Visual Improvements
**Objective:** Verify UI enhancements work correctly

**Steps:**
1. Start a quiz in Cevher Atölyesi
2. Observe option cards before selection
3. Select an answer
4. Observe the selection animation
5. View the explanation card (if wrong answer selected)
6. Test in both light and dark themes

**Expected Result:**
- ✅ Option cards have clean borders and shadows
- ✅ Smooth scale animation when selecting an option
- ✅ Selected option has prominent border (2.0px)
- ✅ Explanation card has circular icon container
- ✅ Color contrast is good in both themes
- ✅ Layout is stable (no jumps or shifts)

**Red Flags:**
- ❌ Animation is janky or slow
- ❌ Colors are hard to see
- ❌ Layout shifts when selecting answers
- ❌ Cards overlap or have spacing issues

---

## 🔍 Debug Mode Testing

### Test 4: Debug Logging (Developer Only)
**Objective:** Verify debug logs work correctly

**Setup:**
- Run app in debug mode (not release)
- Have console/logcat visible

**Steps:**
1. Start a quiz
2. Deliberately select wrong answers
3. Submit the quiz
4. Watch console output

**Expected Result:**
- ✅ Logs appear showing incorrect answers
- ✅ Logs show user selection vs correct answer
- ✅ Format: `DEBUG: Question X - User selected: Y (...), Correct: Z (...)`
- ✅ No logs in release mode

**Example Log:**
```
DEBUG: Question 3 - User selected: 2 (Option C), Correct: 1 (Option B)
```

---

## 📝 Quality Assurance Testing

### Test 5: Question Quality
**Objective:** Verify improved question generation

**Steps:**
1. Generate 5-10 different workshop sessions
2. For each session, examine questions
3. Look for quality issues

**Expected Result:**
- ✅ All questions have 5 options (A-E)
- ✅ No placeholder options like "Seçenek A" or "Diğer Seçenek"
- ✅ All options are distinct and meaningful
- ✅ Explanations clearly explain why the correct answer is correct
- ✅ No contradictions between question and explanation

**Red Flags:**
- ❌ Questions with less than 5 options
- ❌ Placeholder text in options
- ❌ Duplicate or very similar options
- ❌ Explanation contradicts the correct answer
- ❌ Explanation is too vague or generic

---

## 🔄 Regression Testing

### Test 6: Existing Features
**Objective:** Verify existing features still work

**Steps:**
1. **Saving Workshops:**
   - Complete a quiz
   - Save the workshop
   - Navigate to Saved Workshops
   - Open the saved workshop
   - Verify content is correct

2. **Topic Selection:**
   - Try all difficulty levels
   - Test with different subjects
   - Verify suggestions work

3. **Streak Tracking:**
   - Complete workshops on consecutive days
   - Verify streak updates

4. **Mastery System:**
   - Get high scores on a topic
   - Verify mastery badge appears when earned

**Expected Result:**
- ✅ All existing features work as before
- ✅ No errors or crashes
- ✅ Data persists correctly

---

## 🌐 Cross-Platform Testing

### Test 7: Platform Consistency
**Objective:** Verify fixes work on all platforms

**Platforms to Test:**
- 📱 iOS
- 📱 Android

**Steps:**
1. Run all previous tests on each platform
2. Pay attention to:
   - Font rendering
   - Animation smoothness
   - Color accuracy
   - Touch responsiveness

**Expected Result:**
- ✅ Consistent behavior across platforms
- ✅ No platform-specific bugs
- ✅ UI looks good on different screen sizes

---

## 📊 Performance Testing

### Test 8: Performance Impact
**Objective:** Verify changes don't impact performance

**Metrics to Check:**
- Quiz loading time
- Answer selection responsiveness
- Animation frame rate
- Memory usage

**Expected Result:**
- ✅ No noticeable performance degradation
- ✅ Smooth 60fps animations
- ✅ Quick response to user interactions
- ✅ No memory leaks

---

## 🚨 Edge Case Testing

### Test 9: Edge Cases
**Objective:** Test unusual scenarios

**Scenarios:**
1. **Very Long Options:**
   - Check if long text wraps properly
   - Verify layout doesn't break

2. **Mathematical Expressions:**
   - Test questions with LaTeX/math
   - Verify rendering is correct

3. **Special Characters:**
   - Test with Turkish characters (ç, ğ, ı, ö, ş, ü)
   - Verify proper encoding

4. **Network Issues:**
   - Test with slow connection
   - Test offline (for saved workshops)

5. **Rapid Navigation:**
   - Quickly switch between screens
   - Verify no race conditions

**Expected Result:**
- ✅ Graceful handling of all edge cases
- ✅ No crashes or errors
- ✅ User-friendly error messages if needed

---

## ✅ Sign-Off Checklist

Before approving this PR, verify:

- [ ] All critical bug tests pass
- [ ] AI disclaimers visible on all screens
- [ ] UI improvements look good
- [ ] Debug logging works (developer mode)
- [ ] Question quality is improved
- [ ] No regressions in existing features
- [ ] Works on both iOS and Android
- [ ] No performance issues
- [ ] Edge cases handled properly
- [ ] Documentation is complete and clear

---

## 🐛 Bug Reporting Template

If you find issues, report with this format:

```markdown
**Issue:** [Brief description]

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Platform:** iOS / Android
**Version:** [App version]
**Screenshots:** [If applicable]

**Console Logs:** [If in debug mode]
```

---

## 📞 Contact

For questions about testing or issues found:
- Check `CEVHER_ATOLYESI_FIXES.md` for technical details
- Review the PR description for overview
- Check debug logs for detailed error information

---

**Last Updated:** 2025-11-03
**Version:** 1.1.2+13
