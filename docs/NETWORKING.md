# Networking

What Doorstep puts on the wire, and what each platform can actually do.

---

## The transport

Doorstep speaks the [LocalSend protocol](https://github.com/localsend/protocol)
**v2.1** over HTTP(S). v1 endpoints are not served.

| Concern | Choice |
|---|---|
| Transport | HTTP/1.1 over TLS |
| Certificates | Generated per device, on the fly |
| Client certificates | **Mandatory** |
| Peer identity | Uppercase-hex SHA-256 of the client certificate DER |
| Discovery | UDP multicast + UDP broadcast (see [Discovery](DISCOVERY.md)) |
| Registration | Unicast HTTP register, announce-only over UDP |

## Trust and identity

- Every device generates its own certificate at first run.
- TLS uses those per-device certificates with **mandatory client certificates**.
- A peer's identity is the SHA-256 of its certificate — that is the
  *fingerprint* you see in the UI.
- `Register` is **not emitted** when a payload's claimed fingerprint disagrees
  with the certificate that was actually presented. The payload fallback only
  exists for encryption-off mode.
- Prefer `event.certFingerprint ?? event.info.fingerprint` when reading identity.

On top of that sits the Doorstep trust layer:

- A **connection request** must prove it was addressed to *you* (your token or
  your fingerprint) — otherwise it is dropped.
- Proving addressing is not authorisation: a new device still waits for the
  user to accept or decline.
- On acceptance the two devices exchange their long-lived tokens, so each can
  authenticate the other later without re-pairing.

See [TRANSFER-FLOW.md](TRANSFER-FLOW.md) for the request lifecycle.

## Ports

| Port | Purpose |
|---|---|
| Main server port (default `53317`) | Transfers, registration, web send |
| Browse ports `+1 … +8` | The laptop-side live folder browser |

The browser takes the first free port above the main port and the phone probes
the same range, so a busy `port + 1` neither breaks browsing nor hangs it. A
main port above `65535` clamps instead of throwing on bind.

Both the receive PIN and the web-send PIN are fixed at server start, so
changing either restarts the server.

The server binds both listeners with `SO_REUSEADDR`. That is what makes
stop → start work without the user picking a new port: without it the operating
system refuses the re-bind while the old connections are still in `TIME_WAIT`,
which Windows does by default for listening TCP sockets.

## Platform reality

There is no single operating-system API that makes "its own network" work
everywhere. This table is the honest picture, and the UI never promises more
than a platform can deliver.

| | Android | Windows | Linux | macOS | iOS |
|---|---|---|---|---|---|
| Shared Wi-Fi/LAN (today) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Soft AP — create the network | ✅ `startLocalOnlyHotspot` | ✅ WinRT tethering | ⚠️ privileged | ⚠️ private API | ❌ |
| Join a peer's AP without user input | ✅ `WifiNetworkSpecifier` | ✅ WinRT | ⚠️ NetworkManager | ⚠️ | ⚠️ `NEHotspotConfiguration` |
| Wi-Fi Direct / P2P | ✅ | ⚠️ painful | ❌ | ❌ | ❌ |
| Wi-Fi Aware / NAN | ✅ 8+ | ❌ | ❌ | ✅ 13+ | ✅ 13+ |
| Bluetooth (signalling) | ✅ | ✅ | ✅ | ✅ | ✅ |

**iOS is the hard limit, and it is Apple's rule.** iOS cannot create a hotspot
and cannot join a peer's network without a user confirmation dialog. It also
cannot run a persistent background listener the way Android's foreground service
does.

### The fallbacks that do exist on iOS

- Shared Wi-Fi transfers work exactly like everywhere else.
- **Wi-Fi Aware (NAN)** on iPhone 13+ / iOS 16+ gives true peer-to-peer Wi-Fi
  with no network at all (native Swift, on the roadmap).
- **Bluetooth bootstrap** is the only "nearby" radio every platform shares; it
  carries the handshake while Wi-Fi moves the bytes (on the roadmap).
- Auto Backup and the manual backup file mean a reinstall restores settings and
  trusted devices.

## Web send

The server can also serve a browser download page (web send), with assets
embedded from `packages/core/assets/web/`. It is guarded by its own PIN and is
fixed at server start.

## The signalling server

`server/` is an Axum WebSocket signalling server (`/v1/ws`) used for WebRTC
relaying. It is deployed separately — see `server/Dockerfile` — and is not part
of any transfer path that stays on the LAN.
