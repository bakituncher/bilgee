# Cevher Atölyesi Enhancement - Testing Scenarios

## Purpose
This document outlines testing scenarios to validate the Cevher Atölyesi upgrade and quality enhancements.

## Test Scenarios

### 1. Model Routing Verification

#### Test Case 1.1: Cevher Atölyesi Uses Correct Model
**Setup**: Generate a workshop session for any weak topic
**Expected**:
- Firebase function logs show `context: "cevher_atolyesi"`
- Model selected: `gemini-2.5-flash`
- No model override warnings

**Verification**:
```javascript
// Check Firebase Function logs
// Expected log: "Using enhanced model for Cevher Atölyesi" 
//   { context: "cevher_atolyesi", model: "gemini-2.5-flash" }
```

#### Test Case 1.2: Other Features Use Original Model
**Setup**: Generate AI insights from Coach or Strategy features
**Expected**:
- Context is NOT "cevher_atolyesi"
- Model selected: `gemini-2.0-flash-lite-001`
- Normal operation continues

### 2. Quality Guard Validation

#### Test Case 2.1: High-Quality Questions Pass
**Setup**: Generate workshop with good topic coverage
**Expected**:
- All 5 questions pass validation
- Quality scores ≥ 70/100
- No validation errors
- Questions delivered to user

**Metrics to Check**:
```dart
qualityMetrics: {
  'questionsGenerated': 5,
  'questionsAccepted': 5,
  'questionsRejected': 0,
  'averageQualityScore': '≥75.0',
  'issuesDetected': 0
}
```

#### Test Case 2.2: Low-Quality Questions Rejected
**Setup**: Simulate questions with:
- Short text (< 20 chars)
- Missing explanations
- Duplicate options
- Answer leaks

**Expected**:
- Questions fail validation
- Specific issues logged
- Retry mechanism triggered (3 attempts)
- If all fail: User sees error message

**Error Pattern**:
```
"Soru kalitesi yetersiz. Lütfen tekrar deneyin. 
Tespit edilen sorunlar: Çok kısa soru elendi, Yetersiz açıklama nedeniyle soru elendi"
```

#### Test Case 2.3: Quality Scoring Accuracy
**Setup**: Generate questions and check individual scores
**Expected Component Scores**:
- Content Quality: 0-40 points
  - Question length appropriate: 15 points
  - Explanation length adequate: 15 points
  - Formatting proper: 10 points
  
- Options Quality: 0-30 points
  - ≥4 valid options: 25 points
  - Distinct options: 5 points
  
- Pattern Detection: 0-20 points
  - No answer leaks: 10 points
  - No placeholders: 10 points
  
- Option Diversity: 0-10 points
  - ≥4 unique options: 10 points

**Minimum Pass**: 70/100

### 3. Enhanced Validation Gates

#### Test Case 3.1: Answer Leak Detection
**Setup**: Questions containing:
- "cevap:", "doğru cevap", "yanıt:"
- "şıkkı doğru", "işaretleyin"

**Expected**: Questions rejected with specific issue logged

#### Test Case 3.2: Placeholder Detection
**Setup**: Questions/options containing:
- "lorem ipsum", "placeholder", "yer tutucu"
- "[...]", "todo", "xxx"

**Expected**: Questions rejected with specific issue logged

#### Test Case 3.3: Factual Consistency Check
**Setup**: Questions with numbers that don't match in explanation
**Example**:
```
Question: "Bir sayının 5 katı 30'dur..."
Explanation: "Sayının 6 katı..." (inconsistent)
```

**Expected**: Question flagged for inconsistency

#### Test Case 3.4: Punctuation Validation
**Setup**: Questions without proper ending punctuation
**Expected**: Minor score deduction (5 points)

### 4. Quality Logging and Monitoring

#### Test Case 4.1: Success Logging
**Setup**: Complete successful workshop session
**Expected Firestore Data**:

Collection: `cevher_quality_logs`
```json
{
  "userId": "user123",
  "subject": "Matematik",
  "topic": "Türev",
  "difficulty": "normal",
  "attemptCount": 1,
  "timestamp": "2025-11-08T...",
  "modelVersion": "gemini-2.5-flash",
  "qualityMetrics": {
    "questionsGenerated": 5,
    "questionsAccepted": 5,
    "averageQualityScore": "82.3"
  },
  "validationPassed": true
}
```

Collection: `users/{userId}/cevher_stats/quality_summary`
```json
{
  "totalWorkshops": 1,
  "totalQuestionsGenerated": 5,
  "lastWorkshopDate": "2025-11-08T...",
  "avgQualityScore": "82.3"
}
```

#### Test Case 4.2: Failure Logging
**Setup**: Trigger 3 consecutive validation failures
**Expected Firestore Data**:

Collection: `cevher_validation_failures`
```json
{
  "userId": "user123",
  "subject": "Matematik",
  "topic": "Türev",
  "difficulty": "hard",
  "attemptNumber": 3,
  "timestamp": "2025-11-08T...",
  "modelVersion": "gemini-2.5-flash",
  "issues": ["Soru kalitesi yetersiz..."],
  "validationPassed": false
}
```

#### Test Case 4.3: Non-Blocking Logging
**Setup**: Simulate Firestore write failure
**Expected**:
- Workshop generation succeeds
- Error logged to console
- User experience not affected

### 5. Enhanced Prompt Effectiveness

#### Test Case 5.1: Multi-Layer Accuracy Instructions
**Setup**: Review generated questions for:
- Factual correctness
- Single correct answer
- Logical distractors
- Step-by-step explanations

**Expected**: All requirements met in high percentage (≥95%)

#### Test Case 5.2: Pedagogical Alignment
**Setup**: Verify questions match:
- Exam level difficulty
- Topic critical points
- Curriculum standards

**Expected**: Questions test genuine understanding, not trivial facts

### 6. Retry Strategy

#### Test Case 6.1: Progressive Temperature Reduction
**Setup**: Monitor AI calls during retries
**Expected Sequence**:
1. Attempt 1: Default temperature (0.7 for JSON with cap at 0.3)
2. Attempt 2: Temperature = 0.35
3. Attempt 3: Temperature = 0.25

**Rationale**: More deterministic = more consistent quality

#### Test Case 6.2: All Attempts Fail
**Setup**: Force continuous validation failures
**Expected**:
- User sees clear error message
- Failure logged to `cevher_validation_failures`
- Attempt count tracked
- User can retry manually

### 7. Backward Compatibility

#### Test Case 7.1: Other AI Features Unaffected
**Setup**: Test all AI-powered features:
- Strategy generation
- Coach insights
- Motivation messages
- Trial reviews

**Expected**:
- All features work as before
- Model: `gemini-2.0-flash-lite-001`
- No context parameter passed
- Performance unchanged

#### Test Case 7.2: Existing Workshop Data
**Setup**: Load previously saved workshops
**Expected**:
- Old workshops load correctly
- Display works as before
- No migration needed

### 8. Security and Rate Limiting

#### Test Case 8.1: Premium Check Maintained
**Setup**: Non-premium user tries to generate workshop
**Expected**: Permission denied error

#### Test Case 8.2: Rate Limits Enforced
**Setup**: Generate workshops rapidly
**Expected Limits**:
- 5 requests per minute per user
- 20 requests per minute per IP
- 10 requests per minute (premium specific)
- 100 requests per hour (premium specific)

#### Test Case 8.3: Monthly Star Quota
**Setup**: Track star usage for workshop generation
**Expected**: 1 star deducted per generation, monthly quota enforced

### 9. Performance Metrics

#### Test Case 9.1: Generation Time
**Setup**: Measure time from request to validated response
**Expected**: ≤ 45 seconds (timeout threshold)

**Note**: Gemini 2.5 Flash may be slightly slower than 2.0 Flash Lite but should provide better quality

#### Test Case 9.2: Validation Overhead
**Setup**: Measure time spent in QuizQualityGuard
**Expected**: < 200ms for 5 questions

### 10. Edge Cases

#### Test Case 10.1: Empty/Invalid Topic
**Setup**: Request workshop for non-existent topic
**Expected**: Graceful error handling

#### Test Case 10.2: Network Timeout
**Setup**: Simulate slow network
**Expected**: Timeout after 45 seconds with user-friendly message

#### Test Case 10.3: Malformed AI Response
**Setup**: AI returns invalid JSON
**Expected**: Caught by error handling, retry triggered

## Success Criteria

### Critical (Must Pass)
- ✅ Cevher Atölyesi uses Gemini 2.5 Flash
- ✅ Other features use original model
- ✅ Quality score validation works (≥70 threshold)
- ✅ All 8 validation gates enforced
- ✅ Quality logging successful (non-blocking)
- ✅ No factual errors in generated questions
- ✅ Security and rate limiting maintained

### Important (Should Pass)
- ✅ Average quality score ≥ 75
- ✅ Question rejection rate < 20%
- ✅ Generation time < 45 seconds
- ✅ User experience smooth (retries transparent)
- ✅ Logging doesn't impact performance

### Nice to Have
- ✅ Average quality score ≥ 85
- ✅ Question rejection rate < 10%
- ✅ Zero validation failures on common topics
- ✅ Comprehensive monitoring data collected

## Monitoring Dashboards (Recommended)

### Real-Time Metrics
- Workshop generation count (daily/weekly)
- Average quality score trend
- Rejection rate trend
- Failure patterns by topic/subject
- Model performance comparison

### Quality Indicators
- Questions accepted vs rejected
- Common validation failures
- Topics with high failure rates
- User satisfaction (implicit: completion rates)

### System Health
- AI call latency (p50, p95, p99)
- Error rates
- Rate limit hits
- Star quota usage

## Next Steps After Testing

1. **If All Tests Pass**: Deploy to production
2. **If Issues Found**: 
   - Adjust validation thresholds
   - Enhance prompt instructions
   - Fine-tune quality scoring
   - Re-test

3. **Post-Deployment**:
   - Monitor quality logs for 1 week
   - Gather user feedback
   - Analyze failure patterns
   - Iterate on validation rules

4. **Continuous Improvement**:
   - Review monthly quality reports
   - Update validation logic as needed
   - Adjust model configuration if necessary
   - Maintain documentation

---

**Testing Owner**: Development Team
**Review Frequency**: Weekly for first month, then monthly
**Documentation Updated**: 2025-11-08
