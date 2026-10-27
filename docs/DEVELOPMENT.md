# Development

Requires macOS 14 Sonoma or later and Xcode 16 or later.

```bash
xcodebuild -project PrepPlanner.xcodeproj -scheme PrepPlanner -configuration Debug build
```

## Tests

The scoring rules (IELTS raw-score conversion, band rounding, SAT section scores), streaks, analytics
and backups are covered by unit tests, since a wrong band is not visible in the UI:

```bash
xcodebuild test -project PrepPlanner.xcodeproj -scheme PrepPlanner -destination 'platform=macOS'
```

## Structure

`Models/` holds the SwiftData models plus the scoring, analytics, insight and backup logic; `Views/` is
split by screen; `Support/` has theming, shared components, formatting, reminders and the menu bar tracker.

## Localization

Strings live in `PrepPlanner/Localizable.xcstrings`. After adding UI text, build and run
`python3 scripts/sync_strings.py` to add new keys and list anything still untranslated.

## App icon

Edit `scripts/make_icon.swift`, then:

```bash
swiftc -O -o /tmp/icongen scripts/make_icon.swift && /tmp/icongen PrepPlanner/Assets.xcassets/AppIcon.appiconset
```

## Disk image

`scripts/make_dmg.sh path/to/PrepPlanner.app out.dmg` builds the styled installer window; its
background comes from `scripts/make_dmg_background.swift`.

## Your data

Everything lives in one SwiftData store at `~/Library/Application Support/PrepPlanner/PrepPlanner.store`.
Nothing is uploaded anywhere. **File ▸ Export Backup** writes a JSON copy; importing saves a safety copy of
the current data first.

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
| ⌘E | Log an error |
| ⌘R / ⇧⌘R | New IELTS / SAT mock |
| ⌥⌘N | New habit |
| ⌥⌘I | Show or hide the inspector |
| ⇧⌘E | Export backup |
| ⌘, | Settings |
