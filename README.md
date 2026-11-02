# Khord — S+D navigation layer

Hold physical **S+D**, pressing the second key within **60 ms** of the first. Keep both held while using this final layout:

| Keys within S+D mode | Action |
| --- | --- |
| H / J / K / L | Left / Down / Up / Right |
| Hold A | Option (Alt) |
| Hold F | Command |
| Hold Space | Shift |
| A + J / K | Page Down / Page Up |
| I / O | Previous / next tab |
| U / P | First / last tab |
| A + H / L | Previous / next word |
| B / N | Back / forward in browsers and Finder |
| R | Reopen the last closed tab |
| Backspace | Delete the previous word |
| F + Backspace | Delete to the start of the line (Command+Backspace) |
| Comma / period | Focus previous / next window |

The modifiers combine: Space+H selects left; A+Space+L selects the next word; F+C sends Command+C. Press A/F/Space **after activating S+D**, then press the action key. They act as modifiers only inside the layer. Releasing either S or D exits the layer and releases its virtual modifiers immediately; their remaining physical repeats/releases are consumed until released.

I/O sends Command+Option+Left/Right in every app; U/P sends Command+1/Command+9. These are Chrome-compatible shortcuts, and work in other apps with the same bindings. Apps with different tab shortcuts may behave differently. I/O/U/P use their exact shortcuts regardless of extra modifiers. B/N sends Command+[/], and R sends Command+Shift+T once per press. These new letter shortcuts apply without extra modifiers, preserving combinations such as F+B (Command+B) and F+C (Command+C). Backspace sends exact Option+Delete; F+Backspace sends exact Command+Delete to delete to the start of the line. Both can repeat. A+J/K sends Page Down/Up without Option, retaining additional Shift/Command modifiers. Word movement is Option+Left/Right and follows the target app's conventions. 

The linked-key menu-bar icon turns **green while S+D is active**. It returns to normal when either activation key is released. The menu shows **Disable** when enabled and **Enable** when paused.

## Window management

These use **physical Enter/arrow/bracket keys while S+D is held**. H/J/K/L retain navigation, and I/O retain tab switching.

| Key within S+D mode | Focused-window action |
| --- | --- |
| C | Center at a comfortable reading size |
| Enter | Toggle macOS full screen on / off |
| Up arrow | Exit full screen if necessary, then maximize |
| Down arrow | Exit full screen if necessary, then restore prior size/position |
| Left arrow | Left 50% → left 30% → left 70% → repeat, full usable height |
| Right arrow | Right 50% → right 70% → right 30% → repeat, full usable height |
| [ | Move to the display to the left |
| ] | Move to the display to the right |

Release and press again to cycle sizes; holding a window-control key does not repeatedly trigger actions. Resizing, restoring, and display moves first leave native full screen when needed. Maximize/tiling use the screen's visible area, respecting the menu bar and Dock. Restore uses the frame before Khord's first layout change for that window; subsequent Khord layouts retain that frame. A manual move/resize establishes a fresh baseline on the next command. Restore history is kept only for this running session, up to 64 windows. If a window starts in native full screen, macOS's restored frame becomes the baseline after leaving full screen.

C centers the window at 1,100 logical pixels wide, capped at the full usable screen width, and a fixed 90% of usable height. It exits full screen first, uses the existing quick animation, and supports Down-arrow restore.

Display directions follow horizontal screen arrangement in macOS settings, without wrapping at the outermost display. The nearest screen in that direction is chosen; purely vertically aligned screens are not left/right neighbors. Moves preserve proportional size and position and fit within the target display's usable area. Full screen uses a separate macOS Space; maximize stays on the desktop.

Maximize, restore, tiling, and display moves use a subtle **100 ms ease-out animation** with no bounce. Slow apps skip intermediate frames and still receive the exact final frame. Animations are disabled when macOS Reduce Motion is enabled. Native full-screen transitions keep macOS’s own animation and timing.

Window actions run on a separate serial queue so a slow app or full-screen animation cannot block keyboard interception. Full-screen exit waits for a stable window frame, with a six-second transition deadline. Pause/quit cancels queued work; a command already sent to macOS cannot be undone by cancellation. Show Diagnostics reports the latest window action. Restore falls back onto the current screen if the original monitor is disconnected. Apps may impose minimum sizes, disallow full screen, or not expose standard Accessibility windows; exact layouts are not guaranteed for those apps. No additional permission beyond the app's existing Accessibility access is requested.

Khord uses fixed keys and settings. It does not read or create configuration files. The activation window is 60 ms, custom window animations are 100 ms, and the reading layout uses up to 1,100 logical pixels of width and 90% of usable height.

## Cycle window focus

Hold **S+D** and tap **comma** for the previous window or **period** for the next. These are the keys marked `<` and `>`; Shift is not required. Each tap advances one window without moving or resizing it. Eligible windows across all monitors participate, regardless of cursor location. The list is ordered left to right across the desktop, then top to bottom; overlapping windows remain separate entries. It wraps in both directions, so repeated taps reach every eligible window.

The list is captured on the first cycle command and remains stable while that S+D activation is held. Closed, minimized, or newly hidden windows are skipped. Release S or D and activate again to rebuild the list, including newly opened windows. Hidden apps, other Spaces, desktop elements, and floating utility panels are excluded. Only standard windows/dialogs exposed through the app's Accessibility interface can be focused.

Enumeration and focus operations run off the keyboard callback with per-app timeouts. Khord uses Core Graphics on-screen window metadata and Accessibility window controls; it does not request Screen Recording or capture images. Some apps omit window identifiers, so matching falls back to bounds and titles where available. Apps with unusual Accessibility windows, identical hidden-window geometry, or restricted focus behavior may need testing. The latest result appears in Show Diagnostics.

## Build and run

Requires macOS 13+ and Apple's Command Line Tools. No third-party runtime, driver, or packages. Install Apple's tools if needed:

```sh
xcode-select --install
```

From this folder:

```sh
./test.sh
./build.sh
mkdir -p "$HOME/Applications"
ditto build/Khord.app "$HOME/Applications/Khord.app"
open "$HOME/Applications/Khord.app"
```

The build targets your Mac's architecture and creates an ad-hoc signed app. Quit the previous Chordwell/SuperDuper/Khord copy **before replacing it**. Run only one copy. There is no Dock icon or main window; look for the linked-key icon in the menu bar.

## Permissions

1. Open System Settings → Privacy & Security → Accessibility (called Device Control and Data Access on some newer versions).
2. Add/enable the exact Khord.app copy you are running. Copy it to its final location before granting access.
3. The app retries automatically after approval. If needed, release all layer keys and choose **Disable**, then **Enable**. If needed, quit and reopen.

The linked-key icon means the keyboard event tap was created; the icon with **!** means inactive (hover over the icon or use Show Diagnostics for details); the icon with **⏸** means paused. **Show Diagnostics** reports the running app's path and permission/event tap status.

If the switch is on but the icon still shows !, quit and reopen the same app. If that fails, remove only Khord's old permission entry, add the exact app shown in Diagnostics, enable it, and reopen. An existing entry may refer to another copy or an older ad-hoc signed build. Rebuilding may require approval again. The internal bundle identifier is retained from the original SuperDuper app for continuity.

The app uses an active `.defaultTap` session event filter, so Accessibility is the relevant permission. It does not separately request Input Monitoring or Automation, require root, or require disabling SIP. Use the app bundle rather than running its executable from Terminal, where permission attribution can differ. Use **Launch At Login** in the menu to enable automatic startup after validating the app. A checkmark immediately to the right of the label means macOS reports it enabled. Click again to turn it off. If approval is required, Khord offers to open General → Login Items. This setting is managed by macOS; Khord does not register itself automatically at startup. Install the app in a stable location before enabling it.

## Typing and event handling

Ordinary S or D is buffered for up to 60 ms, or replayed earlier when another event arrives. Quick overlapping S+D within that window is consumed as activation even if you intended to type both letters. Type sequentially, releasing the first before the second, for literal `sd`/`ds`. Slower overlapping pairs pass through. Holding S or D alone repeats normally after the initial buffer. The timing and bindings are fixed in source. Original event timestamps enforce the 60 ms limit even when the run-loop timer is delayed.

Mappings use physical US ANSI positions; they do not follow translated letters on other layouts. Outside the layer, typing and modified shortcuts pass through normally.

The app uses a main-run-loop `.cgSessionEventTap`; visual updates and window actions are deferred out of the keyboard callback. Buffered text is replayed before every intervening key event, including consumed repeats and releases. It copies/replays buffered events in order, tags generated events against recursion, emits fresh keyboard events for mappings, and forwards repeat state. Virtual modifiers emit flags-changed events and are cleared on layer exit, pause, sleep, or quit. Physical Shift/Option/Command remain independent. Mapped keys retain their output key identity until release, even if activation ends first; virtual modifier flags on repeats reflect which layer modifiers remain held. Keys already held before activation retain their original identity.

On event tap interruption the app stops instead of guessing missed state. Release all keys, then choose Disable followed by Enable. Sleep stops it; wake restarts listening and lets any already-held keys finish normally. Password fields, Secure Keyboard Entry, login/FileVault screens, games, and remote desktops may block or bypass event taps; delivery/recovery in protected input contexts is not guaranteed.

No keystroke logging, text storage, network access, or background service. Buffered events exist briefly in memory.

## Startup key handling

Accessibility permission and keyboard startup state are separate. Startup no longer waits for all layer keys to appear released in global session state. Khord creates the event tap immediately; keys already held at startup pass their repeats and release through normally, and a new non-repeat press clears any stale held-key snapshot. A stale key state cannot keep the app permanently inactive. Diagnostics lists the hardware-held startup snapshot and keys still awaiting release or a fresh press.

## Validation

The app builds on Apple Silicon with Swift 6.4 in Swift 5 language mode, with compiler warnings treated as errors. `./test.sh` runs **10 named test groups with 843 assertions** covering typing/buffering, activation timing, navigation, modifier combinations, shortcuts, startup recovery, geometry, animation, stable cycling, AX type validation, and concurrent cancellation. Failures identify the group, source file, and line. `./Tests/build-failure.sh` verifies that a failed build preserves the previous app and cleans up staging files.

The build stages and verifies the signed app before replacing the previous build. Icon rendering is cached by size and regenerated only when drawing sources change or required assets are missing. The rendered PNGs were verified unchanged by checksum during cleanup. The build preserves the previous app as `build/Khord.previous.app` (one backup).

Automated tests do not verify live WindowServer/Accessibility delivery, full-screen animations, app-specific focus behavior, or login registration. Those require the manual checks below on the target Mac.

After granting permission, verify in TextEdit, Chrome, and your other apps:

1. Check B/N in browser history and Finder, R after closing a tab, Backspace in a text editor, and C on both a small and large display. Confirm F+C still copies.
2. Type normally, including separate S/D presses; check Command+S and ordinary Space/A/F.
3. Activate S+D; test H/J/K/L and green icon feedback.
4. Hold A and use H/L for words, J/K for pages.
5. Hold Space and navigate to select; combine A+Space for word selection.
6. Hold F and press C to copy a selection.
7. In a multi-tab Chrome window, test I/O and U/P.
8. Test physical Left/Right twice each for the width cycles; Up to maximize and Down to restore. Press Enter twice to enter and leave native full screen, then test Up/Down leaving it. Check the quick resize transitions and Reduce Motion behavior. With two displays, test [ / ] in both directions.
9. Release S/D before A/F/Space and the action key; check no modifier remains stuck. Test repeats, pause, and sleep/wake with keys released.


## References

- [Apple event tap creation](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [Apple active filters versus passive listeners](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions)
- [Apple macOS security and keyboard permissions](https://developer.apple.com/videos/play/wwdc2019/701/)
- [Chrome keyboard shortcuts](https://support.google.com/chrome/answer/157179?hl=en-GB)

- [Apple screen visible area](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe)
- [Apple Accessibility window position attribute](https://developer.apple.com/documentation/applicationservices/kaxpositionattribute)

- [Apple Reduce Motion preference](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)

## Icon assets

Assets/Khord-AppIcon.png is the 1024px app icon, Assets/Khord.icns is the macOS icon bundle, and Assets/MenuBar.png plus MenuBar@2x.png are transparent monochrome menu-bar exports. The runtime menu symbol is drawn as a native template image for light/dark mode, with a green non-template active variant. Assets/Khord-Icons-Preview.png shows both designs. Editable drawing source is in Sources/IconDrawing.swift; build.sh regenerates assets when needed using the native Swift generator in Assets/GenerateIcons.swift.

All menu rows use standard AppKit menu items with the state column hidden; Launch At Login adds its checkmark immediately after the label. The app builds and its signature verifies; actual login registration and a login/reboot cycle were not performed during this build.

For window cycling, open at least three windows (including two from the same app), overlap a pair, and check comma/period reach each one and wrap. Check both displays, close/minimize a candidate during a cycle, and verify ordinary punctuation still types outside S+D. Live app focusing and Space filtering have not been verified during this build.

Cross-monitor focus tests cover horizontal and vertical window positions, stable ordering, and wraparound. Live multi-monitor focusing still requires testing on the target Mac.

Window placement compatibility (1.17.4): All apps use the same adaptive placement path. If a window refuses a write or its frame does not immediately reach the target, Khord verifies and retries that same target, then uses direct placement without intermediate animation for that window for the rest of the session. This replaces the Zoom-only exception. Other windows retain their animation. Apps can still enforce minimum sizes or refuse operations. Live Zoom meeting behavior has not been verified.

Window lookup recovery (1.17.3): A missing focused-window reference gets one retry after 50 ms, followed by the focused control’s window and the same app’s main window. Khord never picks an arbitrary window from the app’s window list. Diagnostics identify the app, command, selected reference, and lookup error details if all references fail. Delayed/refused layout writes in any app now use bounded settling/retries; successful immediate updates retain their existing animation. The reported Chrome failure was a missing focused-window reference; live verification of the failing Chrome window is still needed.
