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

### Coming next
- Results (IELTS band conversion, SAT scores) and Error Log
- Analytics dashboard with insights
- Habits with streaks and heatmap, notifications, menu bar item, JSON/CSV export

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘1 – ⌘5 | Switch section |
| ⌘N | New block at the next free slot |
| ⌫ | Delete selected block |
| ↑ / ↓ | Move selected block by 15 minutes |
| ⇧⌘D / ⇧⌘P / ⇧⌘K | Mark Done / Partial / Skipped |
| ⌘D | Duplicate block |
| ⌘T, ⌘[, ⌘] | Today, previous day, next day |
| ⇧⌘S / ⇧⌘T | Save day as template / apply template |
| ⌥⌘I | Show or hide the inspector |
| ⌘, | Settings (exam dates, targets, categories, templates) |
