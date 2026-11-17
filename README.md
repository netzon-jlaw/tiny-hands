# Tiny Hands

A macOS menu bar app that turns your cursor into a hand pointer that taps on every click. Built to match pokeyapp.com feature for feature.

- **Pointer on/off:** ⌃⌥P or the menu bar icon. The system cursor is hidden while the pointer is on.
- **Presentation Mode:** ⌃⌥T. Clicks only tap the pointer and never reach the app underneath. The keyboard still works. Needs Accessibility access.
- **Five tap moods:** Subtle, Polite, Lively, Loud and Unhinged. Clicking fast escalates them.
- **Four pointer styles:** Classic, Tiny Hand, High Five and Cat Paw. The pointer size is adjustable. (Middle Child, Peace Sign, Thumbs Up and Rock On are archived in `Resources/Pointers/archive`.)
- **Stick:** Solid (default) or Expandable, in white (default), a preset colour or any custom colour.
- **Rubber-hose tap effects:** ink dashes, pow stars, flung stars, teardrops, dust puffs and dizzy spirals, drawn on twos.
- **Weight:** flick the pointer sideways and the hand rolls that way while the rod trails behind, then springs back and settles. Slow, careful pointing stays still.
- **Knock sound:** plays as system audio, with an on/off toggle and a volume slider.
- **Custom shortcuts, launch at login, and all displays.** The pointer shows in full-screen shares and recordings.
- **Automation:** `open tinyhands://on|off|toggle|present|unpresent|settings|tap?level=1-5`

## Build and install

```bash
scripts/build-app.sh --install
```

The script signs ad-hoc by default. To sign with a Developer ID, set `SIGN_IDENTITY="Developer ID Application: …"`.
