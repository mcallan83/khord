# Khord review — 1.16.1

Reviewed all runtime Swift sources, icon generation, build scripts, tests, and documentation. The fixed shortcuts, menu layout, activation timing, window dimensions, and login-item behavior are retained. No configuration support or dependencies were added.

## Correctness fixes

- Buffered S/D could be discarded when a key consumed by a previous activation repeated or released. Buffer handling is now explicit, and every intervening key event flushes pending text in order. Regressions cover old window-key repeats, modifier releases, and mapped-arrow releases.
- Chord timing depended on when a run-loop timer fired. Original event timestamps now independently enforce the 60 ms boundary.
- Deferred keyboard actions or tap-disable handling could outlive the tap that scheduled them. A generation check prevents an old request affecting a newly enabled tap.
- Event-tap run-loop source creation is checked before use.
- Accessibility frame decoding checks both CF/AX value types and finite, positive dimensions before converting or using them.
- Restore moves a window back onto an available display if its original monitor has disappeared; intentional spanning/partially offscreen frames are preserved.
- Queued AX work is canceled on pause/sleep/quit. Window cycling clears its retained snapshot on cancellation and verifies current window ownership before focusing a cached window.

## Performance and cleanup

- Status-icon drawing is deferred/coalesced out of the keyboard callback.
- Removed obsolete rebinding/configuration indirection and unused Fn-rebinding paths. Physical Fn/Globe still passes through normally.
- Shared typed Accessibility access and cancellation logic replace duplicated implementations.
- Window-cycle advancement is constant-time after sorting; repeated linear searches were removed.
- Window cycling avoids extra geometry reads before each focus, reads focused-window data only for the focused app, requests titles only for ambiguous matches, and stops scanning an app once all its on-screen windows are matched.
- Intermediate animation frames use two AX writes instead of three and skip the redundant initial frame. The final frame retains the compatibility retry after movement.
- Display frames/usable areas are captured from the same screen snapshot. Full-screen and animation deadlines use monotonic time.
- Icon PNGs are rendered once per pixel size and reused across exports. Build-time asset generation is skipped when sources/assets are unchanged. PNG checksums remained identical.
- Builds compile/sign/verify in a temporary app bundle before publishing; a compiler failure cannot overwrite the previous working app.
- Removed hidden NSMenuItem objects that were only storing diagnostic strings.

## Validation

- 8 named test groups, 806 passing assertions; source/line and group names are included on failure.
- Separate failed-build test passes and verifies executable preservation plus staging cleanup.
- App and test compilation treat warnings as errors. App signature verification, plist validation, and shell syntax checks pass.
- Tests use pure event/geometry models and synthetic AX values; they do not post global keyboard events, change Accessibility permission, register login items, or alter user preferences.

## Remaining integration limits

Live window focusing, full-screen animations, and login/reboot behavior need checking on the target Mac. Some applications do not expose window identifiers; geometry/title matching remains a fallback and can be ambiguous for identical hidden windows on other Spaces. These are platform/app compatibility limits, not covered by unit tests. The release remains ad-hoc signed, so replacing it with a newly built version can require macOS permission approval again.

## 1.17 — cursor-display focus

Comma/period focus cycling is now restricted to the display under the mouse cursor on each press. Crossing displays rebuilds the stable cycle; spanning windows are assigned by largest overlap. The eligible window rules and ordering are otherwise unchanged. Tests now pass 8 groups / 824 assertions, including coordinate conversion, monitor filtering, and single-window entry.

## 1.17.1 — Zoom placement compatibility

Zoom bypasses intermediate animation writes, waits for two matching observations, and retries the same target at most twice. Missing focused-window references fall back only to the main window. Limited placements report AX error plus requested/actual frames. No accessibility mode settings are changed. All 9 groups / 836 checks pass; release build/signature and failed-build preservation pass. Live Zoom testing remains required; this addresses potential timing issues rather than a confirmed live reproduction.

## 1.17.2 — delete to line start

S+D+F+Backspace sends exact Command+Backspace; plain layer Backspace retains Option+Backspace. Tests cover repeats, release after F/chord release, and additional A/Space modifiers. All 9 groups / 854 checks pass.

## 1.17.3 — missing window references

User diagnostics showed Accessibility recognized, an active event tap, and no focused window reference. Replaced the Zoom-only fallback with focused-window retry → focused-control window → main-window resolution for the captured app. No arbitrary window enumeration or accessibility mode changes. Added app/command/source and readable AX lookup error context, and eliminated silent frame/display lookup exits. Generalized bounded frame settlement to failed/delayed placements in all apps. New tests cover priority, transient lookup failure, unavailable references and cancellation; 10 groups / 871 checks pass. Native build/signature and failed-build preservation pass. The user’s live Chrome failure has not been reproduced locally.

## 1.17.4 — adaptive placement for every app

Removed Zoom bundle-ID detection from WindowManager. A failed or unsettled placement enables direct placement on that window’s existing bounded session record; the existing generic settlement path retries the same target. Window lookup recovery is unchanged. This retains normal animations for other windows and makes the compatibility behavior independent of app identity. No live Zoom verification.

## 1.17.5 — uniform tab shortcuts

Removed Ghostty detection, activation observer, per-event app flag and special Control+Tab mappings. I/O now use Command+Option+Left/Right for every app. Removed obsolete special-case tests and unused virtual Control support; physical Control detection remains intact. All 10 groups / 859 checks pass; native build/signature verified.

## 1.17.6 — focus across monitors

Removed cursor-display scope and its filtering/cache invalidation. Comma/period use one stable eligible-window list across all displays, preserving position order and wraparound. Replaced obsolete scope tests with cross-monitor ordering/wraparound checks. All 10 groups / 843 checks pass; native build and signature verify. Live multi-monitor focusing remains unverified.
