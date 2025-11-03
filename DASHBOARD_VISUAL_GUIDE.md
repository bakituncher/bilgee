# Dashboard Visual Design Guide

## Design System Overview

### Color Palette

#### Dark Mode
```
Scaffold Background: #0A0E1A (Deep Slate)
Card Background:     #1A1F2E (Enhanced Slate 800)
Surface Variant:     #252B3D (Mid-level Surface)
Elevated Surface:    #2D3548 (Light Surface)
Primary Text:        #F1F5F9 (Bright Text)
Secondary Text:      #A0AEC0 (Enhanced Slate 400)
Divider:            #334155 (Subtle)
```

#### Light Mode
```
Scaffold Background: #F8FAFC (Bright Slate 50)
Card Background:     #FFFFFF (Pure White)
Surface Variant:     #F1F5F9 (Slate 100)
Elevated Surface:    #E2E8F0 (Slate 200)
Primary Text:        #0F172A (Slate 900)
Secondary Text:      #475569 (Enhanced Slate 600)
Divider:            #CBD5E1 (Subtle)
```

#### Brand Colors
```
Primary:    #22D3EE (Vivid Cyan)
Secondary:  #34D399 (Emerald)
Error:      #E71D36 (Red)
Success:    #34D399 (Emerald)
Gold:       #FFB020 (Gold)
```

### Typography Scale

#### Font Weights
- Regular: 400
- Medium: 500
- SemiBold: 600
- Bold: 700
- ExtraBold: 800

#### Text Styles
```dart
// Headers
titleLarge: FontWeight.w800, letterSpacing: -0.5
titleMedium: FontWeight.w800, letterSpacing: -0.3
titleSmall: FontWeight.w700

// Body
bodyLarge: FontWeight.w400, height: 1.6
bodyMedium: FontWeight.w400, height: 1.5
bodySmall: FontWeight.w400

// Labels
labelLarge: FontWeight.w600
labelMedium: FontWeight.w700, size: 12
labelSmall: FontWeight.w400, size: 10-11
```

### Spacing System

#### Padding Scale
```
Micro:   4px
Tiny:    6px
Small:   8px
Base:    12px
Medium:  14px
Large:   16px
XLarge:  18px
XXLarge: 20px
Huge:    24px
Massive: 26px
```

#### Border Radius
```
Small:  14px
Medium: 16px
Large:  18px
XLarge: 20px
Card:   24-28px
```

### Elevation & Shadows

#### Dark Mode
```dart
Low:    elevation: 4, shadow: black.withOpacity(0.3)
Medium: elevation: 6, shadow: black.withOpacity(0.35)
High:   elevation: 8, shadow: black.withOpacity(0.4)
Max:    elevation: 10, shadow: black.withOpacity(0.45)
```

#### Light Mode
```dart
Low:    elevation: 3, shadow: black.withOpacity(0.06)
Medium: elevation: 4, shadow: black.withOpacity(0.08)
High:   elevation: 5, shadow: black.withOpacity(0.12)
Max:    elevation: 6, shadow: black.withOpacity(0.15)
```

## Widget Specifications

### HeroHeader
```
Size:         Dynamic height
Padding:      20px (all sides)
Border:       1.5px, radius: 28px
Gradient:     3 colors (dark) / 3 colors (light)
Shadow:       Medium elevation
Elements:
  - Greeting + Name (titleLarge, w800)
  - Rank Badge (primary container)
  - Progress Bar (10px height, radius: 12px)
  - Stats Row (BP, Plan %)
```

### FocusHubCard
```
Size:         Dynamic height
Padding:      20-18-20-16 (LTRB)
Border:       1.5px, radius: 28px
Gradient:     2 colors
Shadow:       Medium elevation
Elements:
  - Priority CTA (icon + title + subtitle)
  - Gradient Divider
  - Quick Actions Grid (3 buttons)
```

### MotivationQuotesCard
```
Size:         180px height
Border:       1.5px, radius: 28px
Gradient:     3 colors
Shadow:       Medium elevation
Effects:
  - Backdrop blur: 16px
  - Glow circles (2x, 130-150px)
  - Auto-scroll (5s interval)
Elements:
  - Quote icon container
  - Quote text (titleLarge)
  - Author badge
  - Pagination dots
```

### MissionCard
```
Size:         400px height (PageView item)
Padding:      26px (all sides)
Border:       1.5px, radius: 28px
Gradient:     3 colors
Shadow:       Medium elevation
Elements:
  - Icon container (16px radius)
  - Title (titleLarge, w800)
  - Subtitle (bodyLarge, h1.6)
  - CTA Button (with icon)
```

### WeeklyPlanCard
```
Size:         400px height (PageView item)
Border:       1.5px, radius: 28px
Gradient:     3 colors
Shadow:       High elevation
Effects:
  - Backdrop blur: 16px
  - Glassmorphism
Elements:
  - Header (progress ring + info)
  - Day selector tabs
  - Task list / Rest day view
```

### StatCard
```
Size:         116px minimum height
Padding:      14px (all sides)
Border:       1.5px, radius: 20px
Gradient:     2 colors
Shadow:       Low-Medium elevation
Elements:
  - Icon container (circle, bordered)
  - Value (headlineSmall, w800)
  - Label (bodySmall)
```

### DashboardOverviewCard
```
Size:         Dynamic height
Padding:      20px (all sides)
Border:       1.5px, radius: 28px
Gradient:     3 colors
Shadow:       Medium elevation
Elements:
  - Header (icon + title)
  - 2x2 Stats Grid
  - Each stat: icon, value, label, progress
```

### Quick Action Button
```
Size:         Dynamic width, 12px vertical padding
Border:       1.5px, radius: 16px
Gradient:     2 colors
Elements:
  - Icon (22px, primary color)
  - Label (labelMedium, w700)
```

## Animation Specifications

### Standard Animations
```dart
// Fade In
duration: 280-320ms
curve: Curves.easeOutCubic

// Slide
begin: Offset(0, 0.06-0.14)
duration: 280-420ms
curve: Curves.easeOutCubic

// Scale
begin: Offset(0.95-0.96, 0.95-0.96)
duration: 280-420ms
curve: Curves.easeOutCubic

// Combined Entry
effects: [FadeEffect, SlideEffect, ScaleEffect]
delay: 80ms * index (stagger)
```

### Interaction Animations
```dart
// Button Press
duration: 120-160ms
curve: Curves.easeOut

// Hover/Focus
duration: 200-250ms
curve: Curves.easeOut

// State Change
duration: 250-300ms
curve: Curves.easeInOut
```

## Gradient Patterns

### Card Backgrounds (Dark)
```dart
colors: [
  cardColor,
  primary.withOpacity(0.06-0.08),
  surfaceContainerHighest.withOpacity(0.08-0.12),
]
begin: Alignment.topLeft
end: Alignment.bottomRight
```

### Card Backgrounds (Light)
```dart
colors: [
  cardColor,
  surfaceContainerHighest.withOpacity(0.05-0.08),
  cardColor.withOpacity(0.95),
]
begin: Alignment.topLeft
end: Alignment.bottomRight
```

### Icon Containers
```dart
color: primary.withOpacity(isDark ? 0.18 : 0.12)
border: primary.withOpacity(isDark ? 0.4 : 0.5), width: 1.5
shadow: primary.withOpacity(0.2), blur: 8
```

## Accessibility Guidelines

### Contrast Ratios
- Large text (18pt+): minimum 3:1
- Normal text: minimum 4.5:1
- Icons: minimum 3:1

### Touch Targets
- Minimum: 48x48dp
- Recommended: 56x56dp
- Interactive elements: proper InkWell feedback

### Text Sizing
- Minimum body text: 14sp
- Minimum label text: 11sp
- Headers: 18-24sp

## Implementation Notes

### Performance Optimizations
1. Use RepaintBoundary for heavy widgets
2. Combine animation effects when possible
3. Use const constructors where applicable
4. Minimize rebuild scope with proper providers

### Theme Switching
- All widgets respond to theme changes
- No hardcoded colors
- Use Theme.of(context) consistently
- Test both modes thoroughly

### Responsive Design
- Use flexible layouts (Expanded, Flexible)
- FittedBox for text that might overflow
- Minimum constraints for touch targets
- Test on different screen sizes

## Testing Checklist

### Visual Testing
- [ ] All widgets display correctly in light mode
- [ ] All widgets display correctly in dark mode
- [ ] Theme transitions are smooth
- [ ] Animations run at 60fps
- [ ] No visual glitches or flickering

### Interaction Testing
- [ ] All buttons respond to taps
- [ ] Navigation works correctly
- [ ] Scroll behavior is smooth
- [ ] Touch targets are appropriate
- [ ] Hover states work (web/desktop)

### Accessibility Testing
- [ ] Text is readable in both themes
- [ ] Contrast ratios meet standards
- [ ] Screen reader compatible
- [ ] Touch targets are adequate
- [ ] Focus indicators visible

### Edge Cases
- [ ] Long text handles overflow
- [ ] Empty states display correctly
- [ ] Error states are clear
- [ ] Loading states are smooth
- [ ] Network errors handled gracefully
