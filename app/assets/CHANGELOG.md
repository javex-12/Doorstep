# Changelog

All notable changes to Doorstep are documented here.

## v1.0.0 — Initial release

Doorstep is a LAN-only file bridge: connect your phone to your laptop once, then
files move between them automatically over your own Wi-Fi — no cloud, no
accounts, no internet required.

### What's new

- **Connect once, stay connected** — nearby devices are found automatically and
  can be trusted with one tap. A trusted device reconnects by itself, so you
  never pair, scan, or re-discover again.
- **Trust levels** — when you connect, choose *My personal device* (remembered,
  reconnects automatically) or *Just this once* (this session only, never
  remembered).
- **No QR codes** — Doorstep finds devices on the network by itself. There is
  nothing to scan.
- **Always on** — the laptop starts with your computer and waits in the tray;
  on Android a quiet "Doorstep is on" notification keeps the listener running so
  a trusted device can send you files without you opening the app.
- **Drop zones** — drop a file into a watched folder on your laptop and it
  arrives on your phone automatically. Route each drop zone to specific trusted
  devices instead of everyone.
- **Live folder browser** — browse and pull files from your laptop on your
  phone, with lazy directory loading so large folders never hang.
- **Encrypted, direct transfers** — TLS with per-device certificates and
  mandatory client-certificate verification. Nothing leaves your network.
- **One progress surface** — a single compact banner for a whole transfer, never
  one screen per file.
- **Files land somewhere obvious** — received files go to a `Doorstep` folder
  inside your Downloads, with an "Open folder" action everywhere.
- **Theme-aware UI** — the chosen color scheme applies to every page.

### Platforms

Android (32-bit & 64-bit), Windows, macOS, Linux, iOS.
