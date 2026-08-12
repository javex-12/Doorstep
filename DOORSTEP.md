# Doorstep — Product Specification

> **Tagline:** *"Your phone is now another folder on your computer."*

Doorstep is a LAN-only file bridge built on the LocalSend protocol. Pair a device once, designate a folder as a drop zone, and files move between your phone and computer automatically — no app-opening, no device re-discovery, no cloud.

**License:** Apache-2.0 (fork of [LocalSend](https://github.com/localsend/localsend))

---

## 1. Problem

Traditional file-sharing tools (LocalSend, AirDrop, etc.) follow the same flow every single time:

> Open app → wait for device discovery → select device → choose files → send

**Doorstep's flow:**

> Drop file into folder → done

## 2. Core Principles

Every feature and decision must satisfy these:

1. **Pair once** — a single QR scan; reconnection is automatic and permanent.
2. **Zero user interaction** for normal transfers.
3. **Never lose a file.**
4. **Never corrupt a file.**
5. **LAN first** — no internet dependency.
6. **Secure by default** — encrypted transport, authenticated devices.
7. **Scale before optimization** — the architecture must hold at thousands of files, not be patched later.

## 3. Architecture

```
              +----------------------+
              |   Watched Folder     |
              +----------+-----------+
                         |
                  Directory.watch()
                    (worker isolate)
                         |
                         v
              +----------------------+       mDNS fallback
              | Background Service   |<----- (if last-known
              | Pairing + Watcher    |        IP unreachable)
              +----------+-----------+
                         |
                   WebSocket Events
                         |
                         v
              +----------------------+
              | Flutter Mobile App   |
              | Live Folder Browser  |
              +----------+-----------+
                         |
                   HTTP Transfer
                         |
                         v
                    File Received
```

Two channels, two jobs:

| Channel | Carries |
|---|---|
| **HTTP** (LocalSend protocol) | File bytes — encrypted end-to-end |
| **WebSocket** | Metadata & live events (add/remove/rename), auth handshake |

**Auth is validated consistently across both channels** — a device authenticated over one cannot bypass the other.

## 4. What We Build On (LocalSend)

- Cross-platform apps (desktop + mobile)
- LAN discovery (mDNS / UDP broadcast)
- Encrypted HTTPS transfer with on-the-fly certificates
- A production-grade transfer engine

## 5. The Doorstep Layer

### 5.1 Persistent Pairing

- A QR code encodes: local IP, port, and a signed auth token.
- The token is stored on the phone; the laptop keeps a trusted-devices list.
- Reconnection is automatic when a device rejoins the network — **no re-scanning**.
- **IP is a fast path, not the only path.** If the last-known IP fails (DHCP renewal, network switch), Doorstep falls back to mDNS discovery keyed by **device identity**, not IP. The stored token is the proof of trust.
- **Temporal mode** (optional): a short-lived token for one-off transfers to untrusted devices.

### 5.2 Folder Watcher

- The user designates specific folders as **drop zones**.
- A background watcher (Dart `Directory.watch()`, in a **worker isolate**) emits add/remove/rename events over WebSocket.
- **Deliberately not whole-drive watching**: dedicated folders need no ignore-list, no risk of leaking system/private files, and a simpler mental model.

### 5.3 Live Folder Browser (phone side)

Built scalable from day one:

- **Lazy loading** — the phone requests a folder's contents only when the user expands it; the full tree is never shipped upfront.
- **Virtualized rendering** — `ListView.builder` keeps 20,000-item folders smooth.
- **On-demand thumbnails** — generated asynchronously in a worker isolate only when requested/visible, queued and cached; never on the UI thread.
- **Lightweight events** — watcher pushes metadata only; bytes and thumbnails travel over HTTP on demand.

### 5.4 Background Persistence

- **Laptop:** a background service (boot-start, headless) — Windows NSSM, macOS `launchd` agent, Linux `systemd` user service — running under a **standard restricted user account** (least privilege), never Local System.
- **Phone:** background listening where the OS allows. iOS constraints are handled below.

## 6. Reliability & Edge Cases

### Transfer State Machine

Every transfer is explicitly stateful and visible on both ends:

```
Pending → Transferring → Completed
   └──→ Failed → Retrying
```

A transfer interrupted mid-way is **never** presented as complete — no silent corruption, no orphaned partials. Includes an explicit `Failed: Insufficient Storage` state with a clear notification.

### Large File Safeguard

A configurable size threshold (default **500 MB**) above which auto-transfer requires explicit confirmation on the receiving device instead of pushing silently.

### Conflict Handling

- **Default:** auto-rename on collision (`report.pdf` → `report (1).pdf`) — never silently overwrite.
- Configurable to: always overwrite, or always ask (Keep both / Replace / Skip), with a **30-second prompt timeout** that falls back to auto-rename so queues never block.

### iOS Background Constraints

iOS aggressively suspends background networking. Two options, deliberately deferred until Android/desktop MVP is proven:

- **Option A:** a minimal, optional push relay that only ever sends a "wake up and check LAN" ping — **no file data passes through it**. A narrow, documented exception to LAN-only.
- **Option B:** no proactive wake; iOS transfers work while foregrounded/recently backgrounded, with a manual refresh otherwise.

Not blocking: Android/Windows/macOS have no such constraint.

### Battery & Resource Visibility

- The phone app offers a visible **Sleep Mode** toggle (temporarily disconnect background listening) with a clear indicator, so users control battery cost.
- The laptop tray icon shows rough CPU/network usage with a pause/stop control.

## 7. Terminology (Distinct in the UI)

| Term | Meaning |
|---|---|
| **Drop Zone** | A watched folder on the laptop — *source* of outgoing files (laptop → phone) |
| **Inbox** | The one folder on the laptop that receives incoming files (phone → laptop) |

These are visually separated in the UI so they're never conflated.

## 8. Build Plan

### MVP 1.0 — The Magic Moment

1. Fork LocalSend, building locally.
2. **Persistent pairing** — QR once, reconnect forever, **with mDNS fallback** (non-negotiable).
3. One default drop zone, auto-created on first launch.
4. **Auto-transfer only** with the full transfer state machine.
5. Background service running headless (NSSM on Windows, least-privilege account).

**Success criterion:** a user can install, pair once, restart both devices, drop a file, and receive it in under 5 seconds — then never open the app again for normal transfers.

### MVP 1.5 — Full Feature Set

6. Live folder browser (lazy, virtualized, on-demand thumbnails).
7. Manual transfer mode.
8. Multiple drop zones.
9. Multi-device management (per-device folders, revoke).
10. Conflict handling.
11. Bidirectional transfer + share-sheet integration.
12. UI polish pass.

## 9. Onboarding — Progressive, Not a Wall of Setup

- **Immediately:** the app auto-creates a default `Doorstep` folder on the Desktop and shows the pairing QR. Nothing to configure — scan and go.
- The background service installs silently; it is not a user-facing step.
- Everything else (more folders, modes, multi-device, Inbox config) is **deferred to Settings**, never forced upfront.

## 10. Non-Goals

- ❌ Cloud sync, Drive/Dropbox replacement
- ❌ Internet transfers (relay / WebRTC)
- ❌ User accounts or subscriptions
- ✅ **Fast, local, LAN-only file bridge — that's it**
