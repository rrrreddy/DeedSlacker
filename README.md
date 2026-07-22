# DeedSlacker

A single fluid, gesture-driven app that folds four familiar ideas into one
design language and one iCloud sync layer:

| Module | Inspired by | What it does |
|---|---|---|
| World Clock | Overlap | Compare hours across cities with a draggable time-shift slider |
| Actions | Actions | Fast task capture with a quick-add bar and swipe-to-complete |
| Flow | Flow | Trigger → action automations |
| Timepage | Timepage | Day-strip calendar with colored events |

All four live in one SwiftUI app, switchable via a spring-animated pill
switcher (iPhone/iPad) or sidebar (Mac), and share:

- **Design system** (`Sources/DesignSystem`) — spring animation curves,
  color tokens per module, a reusable `FluidCard` surface.
- **Data + sync** (`Sources/Models`, `Sources/Sync`) — SwiftData `@Model`
  types backed by a single private CloudKit database, so data written on
  iPhone appears on iPad and Mac automatically.

## Requirements

- macOS with **Xcode 15.4+** (needed for iOS 17 / macOS 14 SDKs — this
  project was scaffolded in a Linux container with no Xcode, so it has
  **not yet been compiled**; do that first on your Mac).
- An Apple Developer account with iCloud/CloudKit capability enabled, so
  the `iCloud.com.deedslacker.app` container can be created.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to turn `project.yml`
  into an `.xcodeproj` (`brew install xcodegen`). The `.xcodeproj` itself
  isn't checked in — generate it locally so project settings stay in a
  diffable, mergeable YAML file instead of an opaque pbxproj.

## First-time setup (on your Mac)

```bash
brew install xcodegen
cd DeedSlacker
xcodegen generate
open DeedSlacker.xcodeproj
```

Then in Xcode:

1. Select the `DeedSlacker` target → **Signing & Capabilities** → set your
   Team. Xcode will auto-provision the bundle ID `com.deedslacker.app`.
2. Under **Signing & Capabilities**, confirm the **iCloud** capability is
   present with **CloudKit** checked and the container
   `iCloud.com.deedslacker.app` selected (create it if it doesn't exist yet
   in the list — Xcode can provision it automatically the first time you
   build with a paid Developer account).
3. Build & run on the iOS Simulator, then on a real device signed into
   iCloud, then on Mac (My Mac target) signed into the *same* iCloud
   account, to confirm data written on one shows up on the other.

## Project layout

```
Sources/
  App/            App entry point, root tab/sidebar switcher, entitlements
  DesignSystem/   Shared fluid animation curves, colors, card surface
  Models/         SwiftData @Model types (one file per module)
  Sync/           CloudKit-backed ModelContainer factory
  Features/
    WorldClock/   Overlap-style time comparison
    Actions/      Task manager
    Flow/         Automations
    Timepage/     Calendar
Tests/            Unit tests for model defaults/behavior
```

## Sync design notes

- One shared `ModelContainer` (`CloudSyncContainer.makeModelContainer()`)
  configured with `cloudKitDatabase: .private(...)` — all four modules'
  models sync through the same private CloudKit database automatically;
  there's no manual upload/download code to write.
- Every `@Model` property has an inline default value (e.g.
  `var isCompleted: Bool = false`), which SwiftData's CloudKit mirroring
  requires — non-optional properties without a default will crash at
  container creation.
- Conflict resolution is CloudKit's default last-writer-wins per record;
  this is fine for personal single-user sync across your own devices.

## What's stubbed vs. real

This scaffold is a working first pass, not a finished product:

- All four modules have real SwiftData persistence, working CRUD UI, and
  the shared fluid design language.
- Flow's "actions" (send notification, toggle setting, open URL) are
  defined as data but don't yet **execute** — wiring them to
  `UNUserNotificationCenter`, Shortcuts, or URL handling is the next step.
- World Clock's slider shifts the displayed time but doesn't yet persist
  a "meeting time" you're solving for.
- No app icon, launch screen art, or onboarding flow yet.

## Next steps to discuss

1. Which module should get real depth first (recommend Actions or
   Timepage since those have the clearest CRUD flows).
2. Whether Flow's actions should integrate with the Shortcuts app instead
   of reimplementing automation execution from scratch.
3. Widget/Live Activity support for World Clock and Actions.
