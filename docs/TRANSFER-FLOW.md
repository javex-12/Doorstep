# Transfer flow

What happens between "tap send" and "file saved".

---

## The short version

```
sender                                receiver
  │ select files, pick device             │
  │ POST /prepare-upload ────────────────►│  Rust server emits PrepareUpload
  │                                       │  app asks the user (or auto-accepts)
  │ ◄─────────────────────────────────────│  decision via decision_tx
  │ send the accepted files ─────────────►│  FileUpload: byte stream + result_tx
  │ ◄─────────────────────────────────────│  per-file result
  │              SessionEnd               │
```

## 1. Selection

Files can enter the flow from anywhere — the picker, a share sheet, drag and
drop, the Windows "Send with Doorstep" context menu, or a note typed in the app.
They all become the same `CrossFile` shape.

A note is just a tiny `text/plain` file, which is why notes and clipboard sync
ride the exact same path as everything else and work on every platform.

## 2. Device selection

Quick-send is the default surface:

- **Exactly one trusted device online** → it is sent straight away.
- **Several** → a picker, already filtered to what is reachable.
- **None** → a clear "nothing is reachable right now" with the manual connect
  fallback.

"Reachable" means the device has been seen on the network recently — via
multicast, an HTTP register, or a direct probe. A send is never fired into the
void.

## 3. The request

The sender calls `prepare-upload` on the receiver, pinned to that device's
certificate fingerprint. **Pinning means the request is not sent at all if
someone else answers on that address** — a different device cannot inherit the
session by taking the IP.

The Rust server is the authority on the single-session invariant: a new request
means the previous session is over, so the app closes it before showing the new
one.

## 4. Accept or decline

The receiver decides:

- **From a trusted device**, with auto-accept on and sleep mode off → accepted
  silently. That is the Doorstep promise.
- **From anyone else** → the user is asked.

Only one upload session is active at a time, and the decision is delivered back
through a oneshot channel (`decision_tx`) — not a side channel.

Drop-zone auto-transfer is deliberately not enabled just because a device asked
to connect. Trusting a device that asked for a connection is a separate decision
from trusting one you connected to yourself.

## 5. The transfer

Accepted files stream over the same TLS connection, with per-file progress
reported back to the UI.

- Cancellation safety comes from drop guards (`PendingSessionGuard`,
  `UploadGuard`, `PendingWebSessionGuard`), so a cancelled session cannot leave
  the server wedged.
- If a receiver cancels, the sender is told and marks the session cancelled.
- If a sender aborts while the receiver is still deciding, the pending request
  is cleaned up automatically.
- A receiver with nothing selected closes the session as finished, not as an
  error.

## 6. Saving

Save targets are decided in Dart and written by Rust:

- a plain path, or
- an Android SAF file descriptor obtained through the
  `com.doorstep.app/doorstep` method channel, or
- through a cache file first for gallery saves.

The destination is shown on the progress screen and can be opened from there.
Per-file bars cover every file — waiting, in flight and finished — so progress
is readable per file rather than only as one aggregate.

## 7. Progress surfaces

There is exactly **one** progress surface per transfer session at a time.

Normally that is the slim bottom banner. Once the user opens the detailed
screen, that screen becomes the surface and the banner steps aside, so the two
never stack. This single rule is what fixed the "loading screen keeps showing
up" problem.

## 8. After

- Finished files land in the Activity history with their destination.
- Notes are recorded as messages, not as mystery `.txt` entries.
- A failed file can be retried on its own without resending the rest.
- Sessions end cleanly, and the port is free for the next one.
