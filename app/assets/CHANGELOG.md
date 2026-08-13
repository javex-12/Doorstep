# Changelog

All notable changes to Doorstep are documented here.

## v1.0.0 — Initial release

Doorstep is a LAN-only file bridge: pair your phone with your laptop once,
designate a folder as a drop zone, and files move between them automatically —
no cloud, no accounts, no internet required.

### What's new

- **QR pairing** — scan the laptop's QR code once. Reconnects automatically
  across restarts and IP changes.
- **Trust levels** — when pairing, choose *Personal device* (remembered,
  reconnects automatically) or *Temporary* (this session only, never
  remembered, never reconnects).
- **Drop zones** — drop files into a watched folder on your laptop and they
  arrive on your phone automatically.
- **Per-drop-zone routing** — choose which trusted devices each drop zone
  sends to, instead of broadcasting to everyone.
- **Phone-side live browser** — browse and pull files from your laptop over
  the LAN.
- **End-to-end encryption** — TLS with per-device certificates and mandatory
  client-certificate verification.
- **Slick transfer overlay** — one clean loading screen per transfer batch,
  with live progress — never one per file.
- **Theme-aware UI** — the chosen color scheme applies to every page.
- **Rebrand** — the LocalSend fork is now Doorstep, with its own identity
  (package `com.doorstep.app`, new logo, new icon set).

### Platforms

Android (32-bit & 64-bit), Windows, macOS, Linux, iOS.
