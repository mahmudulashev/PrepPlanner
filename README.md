# PrepPlanner

A native macOS study planner, habit tracker and analytics dashboard for IELTS and SAT preparation.

Built with SwiftUI, SwiftData and Swift Charts. No third-party dependencies, no backend, no accounts —
all data stays on your Mac in `~/Library/Application Support/PrepPlanner/`.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later

## Build & run

Open `PrepPlanner.xcodeproj` in Xcode and press ⌘R, or from the terminal:

```bash
xcodebuild -project PrepPlanner.xcodeproj -scheme PrepPlanner -configuration Debug build
```

## Features

### Day Planner
- Hourly timeline from 06:00 to 24:00 in 15-minute steps, one day at a time
- Drag on empty space to create a block; drag a block to move it; drag its top or bottom edge to resize
- Each block has a category, title, planned start/end, note, status (Done / Partial / Skipped) and actual minutes
- Editable categories with colors, optional skill link, and a "study" flag (Rest doesn't count toward study hours)
- Day templates: save any day as a template and apply it to a date or a date range, with weekday filtering and
  Merge / Replace / Skip handling for days that already have blocks
- Header with planned vs completed study hours and countdowns to both exams

### Results
- IELTS mocks: raw Listening and Academic Reading scores (0–40) are converted to bands automatically;
  Writing and Speaking bands with optional marking criteria (TR/CC/LR/GRA, FC/LR/GRA/P)
- Overall band = average of the four bands rounded to the nearest half band (.25 rounds up to .5, .75 up to the next band)
- SAT mocks: Reading & Writing and Math (200–800) with automatic total
- Latest scores, change since the previous mock and distance to your targets

### Error Log
- Log each mistake with date, skill, error type, note and an optional link to a mock test
- Filter by skill, type, last 7 / 30 days and text search; "most frequent" chips to drill down
- Error types per skill are editable in Settings

### Analytics
- Weekly KPIs, planned vs actual hours per category (daily and weekly stacked bars) and daily completion rate
- IELTS band trends with dashed target lines; SAT total with target line and section trends
- Most frequent error types by skill and date range
- Automatic insights, e.g. "Writing time this week is 30% below plan" or "Listening improved +0.5 since last mock"

### Languages
- English and Uzbek (Latin). Switch in Settings ▸ General ▸ Language and restart the app.
- "Built-in names" renames the default categories, templates and error types to the chosen language.

### Coming next
- Habits with streaks and heatmap, notifications, menu bar item, JSON/CSV export

## Localization

Strings live in `PrepPlanner/Localizable.xcstrings`. After adding UI text, build the app and run
`python3 scripts/sync_strings.py` to add new keys to the catalog and list anything still missing an Uzbek translation.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘1 – ⌘5 | Switch section |
| ⌘N | New block at the next free slot |
| ⌘E | Log an error |
| ⌘R / ⇧⌘R | New IELTS / SAT mock |
| ⌫ | Delete selected block |
| ↑ / ↓ | Move selected block by 15 minutes |
| ⇧⌘D / ⇧⌘P / ⇧⌘K | Mark Done / Partial / Skipped |
| ⌘D | Duplicate block |
| ⌘T, ⌘[, ⌘] | Today, previous day, next day |
| ⇧⌘S / ⇧⌘T | Save day as template / apply template |
| ⌥⌘I | Show or hide the inspector |
| ⌘, | Settings (exam dates, targets, categories, templates, error types) |
