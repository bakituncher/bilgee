# Premium Screen Auto-Display Implementation

## Overview
This implementation adds automatic premium screen display functionality that triggers on specific user actions to encourage premium subscriptions.

## Trigger Conditions

### 1. App Launch (Every Session)
- **When**: Every time a fully onboarded user launches the app
- **Condition**: User must have completed profile, selected exam, and set availability
- **Frequency**: Once per app session
- **Skipped for**: Premium users

### 2. Test Addition (Every 2nd Addition)
- **When**: After user saves a test result
- **Condition**: Every 2nd, 4th, 6th, etc. test addition
- **Frequency**: Based on persistent counter (survives app restarts)
- **Skipped for**: Premium users

### 3. Subject Score Update (Every 2nd Update)
- **When**: As user navigates through subjects while entering test scores
- **Condition**: Every 2nd, 4th, 6th, etc. subject page visited
- **Frequency**: Per test-entry session (resets each time user enters test scores)
- **Skipped for**: Premium users

## Implementation Details

### Core Service
**File**: `lib/core/services/premium_trigger_service.dart`

- Manages counters using SharedPreferences for persistence
- Provides methods to track each action type
- Returns boolean indicating if premium screen should be shown
- Includes debug logging for tracking behavior

### Integration Points

#### 1. Main App (lib/main.dart)
- `_BilgeAiAppState._trackAppLaunchAndShowPremium()`
- Called in `initState()` via `addPostFrameCallback`
- Waits for user profile to load
- Shows premium screen 500ms after app is ready

#### 2. Test Addition (lib/features/home/widgets/add_test_step3.dart)
- `_checkAndShowPremiumScreen()` helper function
- Called after successful test save, before navigation to results
- Shows premium screen between success animation and results view

#### 3. Subject Score Entry (lib/features/home/widgets/add_test_step2.dart)
- `_Step2ScoreEntryState._onPageChanged()` listener
- Tracks page changes using Set-based deduplication
- Only triggers when page animation has settled (< 0.1 offset)
- Counts from page index 1 (second subject onwards)

### Provider Integration
**File**: `lib/data/providers/premium_provider.dart`

Added `premiumTriggerServiceProvider` for dependency injection:
```dart
final premiumTriggerServiceProvider = FutureProvider<PremiumTriggerService>((ref) async {
  return await PremiumTriggerService.init();
});
```

## Testing Guide

### Manual Testing Steps

#### Test 1: App Launch Trigger
1. Launch the app as a non-premium user
2. Complete onboarding if not done
3. **Expected**: Premium screen should appear after ~500ms
4. Close premium screen
5. Navigate around the app
6. Close and relaunch the app
7. **Expected**: Premium screen should appear again

#### Test 2: Test Addition Trigger
1. Add your first test result
2. **Expected**: No premium screen (counter = 1)
3. Add a second test result
4. **Expected**: Premium screen appears (counter = 2, 2 % 2 = 0)
5. Add a third test result
6. **Expected**: No premium screen (counter = 3)
7. Add a fourth test result
8. **Expected**: Premium screen appears (counter = 4, 4 % 2 = 0)

#### Test 3: Subject Score Update Trigger
1. Start adding a new test
2. Enter name and select section
3. Enter scores for first subject
4. Navigate to second subject (arrow or swipe)
5. **Expected**: No premium screen (counter = 1)
6. Navigate to third subject
7. **Expected**: Premium screen appears (counter = 2, 2 % 2 = 0)
8. Continue entering scores
9. Navigate to fourth subject
10. **Expected**: No premium screen (counter = 3)
11. Navigate to fifth subject
12. **Expected**: Premium screen appears (counter = 4, 4 % 2 = 0)

#### Test 4: Premium User Behavior
1. Become a premium user (purchase subscription)
2. Perform any of the above actions
3. **Expected**: Premium screen should NEVER appear

#### Test 5: Counter Persistence
1. Add a test (counter = 1)
2. Force close the app
3. Reopen the app and add another test
4. **Expected**: Premium screen appears (counter = 2)

### Debug Logging

The implementation includes debug logging (visible in debug mode):

```
[PremiumTrigger] App launch #X
[PremiumTrigger] Test addition #X, shouldShow: true/false
[PremiumTrigger] Subject score update #X, shouldShow: true/false
[AppLaunch] User is premium, skipping premium screen
[AppLaunch] Premium screen displayed
[TestAddition] Premium screen displayed
[SubjectUpdate] Premium screen displayed
```

## Counter Management

### Viewing Counters
Counters are stored in SharedPreferences with keys:
- `premium_trigger_app_launches`
- `premium_trigger_test_additions`
- `premium_trigger_subject_updates`

### Resetting Counters (Testing)
The service includes a `resetCounters()` method for testing purposes:
```dart
final service = await ref.read(premiumTriggerServiceProvider.future);
await service.resetCounters();
```

## Edge Cases Handled

1. **Context Validity**: All navigation checks `mounted` state before pushing
2. **Premium User Detection**: Premium status checked before tracking
3. **Onboarding Incomplete**: App launch trigger waits for full onboarding
4. **Page Navigation**: Set-based tracking prevents duplicate counting
5. **Animation States**: Page tracking only triggers on settled pages
6. **Concurrent Calls**: Async operations properly awaited
7. **Error Handling**: Try-catch blocks with debug logging

## Architecture Notes

### Why SharedPreferences?
- Lightweight persistence for simple counters
- No need for database complexity
- Fast synchronous/asynchronous access
- Built-in atomic operations

### Why Set-Based Tracking for Pages?
- Prevents duplicate tracking if user navigates back and forth
- Allows natural exploration without penalty
- Only counts actual progression through subjects

### Why Session-Based App Launch?
- Shows premium screen on every app open (not just first launch)
- Balances visibility with user experience
- Most impactful moment for conversion

## Future Enhancements

Potential improvements for future iterations:

1. **A/B Testing**: Test different frequencies (every 2nd vs every 3rd)
2. **Smart Timing**: Avoid showing during critical user flows
3. **Cooldown Period**: Add minimum time between displays
4. **Analytics**: Track conversion rates from different triggers
5. **Personalization**: Adjust frequency based on user engagement
6. **Context-Aware**: Show different premium features based on trigger source

## Troubleshooting

### Premium Screen Not Showing
1. Check debug logs for "[PremiumTrigger]" messages
2. Verify user is not premium: check `premiumStatusProvider`
3. Verify onboarding is complete for app launch trigger
4. Check counter values using `getCounters()` method

### Premium Screen Showing Too Often
1. Verify modulo logic in `PremiumTriggerService`
2. Check for multiple instances creating duplicate tracking
3. Verify Set-based deduplication is working in page tracking

### Navigation Issues
1. Verify GoRouter is properly configured
2. Check that `/premium` route exists in router config
3. Verify context is mounted before navigation

## Security & Privacy

- No sensitive user data is tracked
- Counters are stored locally on device
- Premium status comes from authenticated provider
- No analytics or tracking sent externally
- Complies with existing app privacy policy

## Performance Impact

- Minimal: Only tracks specific user actions
- SharedPreferences operations are fast and async
- No blocking UI operations
- Set operations are O(1) for tracking
- Counters use simple integer arithmetic

## Maintainability

- Single source of truth: `PremiumTriggerService`
- Clean separation of concerns
- Well-documented with debug logs
- Easy to adjust frequencies by changing modulo values
- Easy to disable by commenting out trigger calls
