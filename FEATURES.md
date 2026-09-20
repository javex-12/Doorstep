# Doorstep — what exists today, what's coming, and the platform truth

Short version: **the core transfer product works on every platform.** The
ecosystem features from the ideas list are mostly *not* built yet, and one of
them — the network layer — has a hard iOS limit that no amount of code can
remove. This file exists so nobody (including future-you) confuses a roadmap
item with a shipped feature.

## What is actually shipped

| Feature | State |
|---|---|
| Phone ↔ laptop transfers, both directions | ✅ shipped |
| Live folder browse from the phone | ✅ shipped |
| Drop zones (watched folders, auto-transfer) | ✅ shipped |
| Trusted devices, persistent + session-only | ✅ shipped |
| Connect request: accept / decline | ✅ shipped |
| Send a note (plain text transfer) | ✅ shipped |
| Clipboard sync (opt-in, per device) | ✅ shipped |
| Activity history, per-file progress, per-file retry | ✅ shipped |
| Android always-on listener (foreground service) | ✅ phones |
| Desktop autostart + tray, single instance | ✅ desktops |
| Discovery: multicast + broadcast + subnet sweep | ✅ shipped |
| Windows "Send with Doorstep" right-click | ✅ shipped |
| Per-file progress bars, backup/restore to file | ✅ shipped |

## The ecosystem features — status

| Feature | State | What it really needs |
|---|---|---|
| **Device Handoff** — start on phone, continue on laptop | ⬜ not built | A shared workspace over the persistent link; needs a document/handoff format first |
| **Shared Folders, real-time sync** | ⬜ not built | A sync engine (change detection, conflict handling) — the single biggest item here |
| **Nearby Broadcasting** — classroom use case | ⬜ not built | 1→N send + an audience UI; the transfer protocol is one-to-one today |
| **Local Messaging** — private LAN chat | ⬜ not built | A small chat protocol over the persistent link |
| **Multi-device Workspace** | ⬜ all of the above | Everything above, composed |

None of these are hidden behind flags pretending to work — they're simply not
in the app yet, and the roadmap (`ROADMAP.md`) sequences them by risk.

## Platform support — the truth table

| | Android | Windows | Linux | macOS | iOS |
|---|---|---|---|---|---|
| Install | ✅ APK | ✅ installer / zip | ✅ AppImage | ✅ zip | ⚠️ unsigned ipa |
| Transfer | ✅ | ✅ | ✅ | ✅ | ✅ |
| Always-on | ✅ | ✅ | ✅ | ✅ | ⚠️ limited |
| **Its-own-network (soft AP)** | ✅ possible | ✅ possible | ⚠️ privileged | ⚠️ partial | ❌ **impossible** |

**iOS is the one real exception, and it is Apple's rule, not Doorstep's.** iOS
cannot create a hotspot, cannot join a peer's network without a confirmation
dialog the user must confirm manually, and cannot run a persistent listener in
the background the way Android's foreground service can. Every cross-platform
product ships this way — AirDrop only does what it does because Apple owns both
ends.

### The fallbacks that DO exist on iOS

iOS can't do everything, but it is not locked out:

- **Same Wi-Fi transfers**: fully works, exactly like everywhere else.
- **Wi-Fi Aware (NAN)** on iPhone 13+ / iOS 16+ gives true peer-to-peer Wi-Fi
  without any network at all — needs native Swift, on the roadmap.
- **Bluetooth bootstrap**: the only "nearby" radio every platform shares. It
  carries the *handshake* (identity, address, trust request) while Wi-Fi moves
  the bytes. On the roadmap.
- **Auto Backup + manual backup file**: settings and trusted devices survive a
  reinstall.

So the honest answer to "will every OS work": **transfers work everywhere,
including iPhone; the soft-AP "own network" mode can never work on iPhone, and
there BLE + Wi-Fi Aware are the honest fallbacks.**

## Analytics

No telemetry today. When it arrives it will be anonymous and opt-out-able
(install ID, active devices, transfer success rate, platform mix), documented in
`PRIVACY.md` — see the roadmap.
