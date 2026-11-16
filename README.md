# Tiny Hands

A macOS menu bar app that turns your cursor into a hand pointer that taps on every click. Built to match pokeyapp.com feature for feature.

- **Pointer on/off:** ⌃⌥P or the menu bar icon. The system cursor is hidden while the pointer is on.
- **Presentation Mode:** ⌃⌥T. Clicks only tap the pointer and never reach the app underneath. The keyboard still works. Needs Accessibility access.
- **Five tap moods:** Subtle, Polite, Lively, Loud and Unhinged. Clicking fast escalates them.
- **Four pointer styles:** Tiny Hand, Cat Paw, Middle Child and Classic Arrow. The pointer size is adjustable.
- **Knock sound:** plays as system audio, with an on/off toggle and a volume slider.
- **Custom shortcuts, launch at login, and all displays.** The pointer shows in full-screen shares and recordings.
- **Automation:** `open tinyhands://on|off|toggle|present|unpresent|settings|tap?level=1-5`

## Build and install

```bash
scripts/build-app.sh --install
```

The script signs ad-hoc by default. To sign with a Developer ID, set `SIGN_IDENTITY="Developer ID Application: …"`.
