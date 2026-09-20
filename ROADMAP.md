# Doorstep Roadmap

Doorstep moves files between **your own** devices with no account, no cloud and no
pairing ritual: open it, see your devices, tap, done.

This document is both the public roadmap and the engineering plan. Items marked
**shipped** are already in `main`.

---

## Where Doorstep is today

| Area | State |
|---|---|
| Protocol | Rust core, protocol v2.1 over HTTP(S) with per-device mTLS |
| Transfers | Phone ↔ laptop both directions, folders, live browse, drop zones |
| Trust | Persistent (auto-reconnects) and session-only devices |
| Discovery | UDP multicast + UDP broadcast + HTTP subnet sweep, racing |
| Always-on | Android foreground service; desktop tray + autostart + single instance |
| Platforms | Android, Windows, Linux, macOS (unsigned), iOS (unsigned) |

**The remaining hard problem: the network.** Today Doorstep asks the user to be on
the same Wi-Fi. That is a real dependency — a guest network that isolates clients,
or a phone hotspot that gets switched off, breaks a transfer. Doorstep should not
care which network the user happens to be on.

---

## The Doorstep Network

The goal is simple to state and genuinely hard to build: **the user should never
have to think about networks.** "Open Doorstep, see your device, tap it."

### What "its own network" actually requires

Two devices that share no network cannot exchange IP packets. There is no way
around that — so a dedicated Doorstep link has to be *established*, and there are
only a few mechanisms that can do it:

| Mechanism | Android | Windows | Linux | macOS | iOS |
|---|---|---|---|---|---|
| Shared Wi-Fi/LAN (today) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Soft AP — this device creates the network | ✅ `startLocalOnlyHotspot` | ✅ WinRT tethering | ⚠️ hostapd/NetworkManager | ⚠️ `internetSharing` (private) | ❌ not possible |
| Join a peer's AP without user input | ✅ `WifiNetworkSpecifier` | ✅ WinRT | ⚠️ NetworkManager | ⚠️ | ⚠️ `NEHotspotConfiguration` |
| Wi-Fi Direct / P2P | ✅ `WifiP2pManager` | ⚠️ WinRT, painful | ❌ | ❌ | ❌ |
| Wi-Fi Aware / NAN | ✅ 8+ | ❌ | ❌ | ✅ 13+ | ✅ 13+ |
| Bluetooth (signaling only) | ✅ | ✅ | ✅ | ✅ | ✅ |

**Conclusion, stated honestly:** there is no single API that works on all five
platforms. Any product claiming one is either iOS-only (AirDrop/AWDL) or isn't
actually platform-independent. Doorstep wins by *negotiating* — pick the best
mechanism both ends support, and never show the user which one was chosen.

### N1 — Discovery that always works  *(highest value, lowest risk)*

This is what users actually feel as "it's slow" and "I had to type an address".

- **Race, don't queue.** Multicast, broadcast, subnet sweep and paired-device
  probing all start at the same instant; the first answer wins and results stream
  into the list as they arrive instead of after the slowest probe.
- **Bind-device rendezvous.** On app start, probe every trusted device's known
  address in parallel (plus its `/24` neighbourhood) so a laptop you have used
  before appears in well under a second.
- **Continuous listening** instead of one-shot scans: peers announce on join and
  every few seconds, so a device that wakes up simply appears.
- **Correct port negotiation.** Connect always uses the port the peer advertised.
  (Today a mismatched port is what forced manual addressing.)
- **Explicit, honest diagnostics.** When nothing is found, say *why* — no Wi-Fi,
  client isolation, or firewall — and offer the manual address as a stated
  fallback, not as the normal path.

### N2 — Bluetooth-assisted bootstrap  *(medium risk)*

When no shared network exists at all, BLE advertising can carry a tiny signed
handshake (fingerprint, IP, port, token) so the two devices can find each other
before any Wi-Fi link exists. This is the same idea AirDrop uses to bootstrap.
Bluetooth moves the *handshake*, never the files.

### N3 — Doorstep Direct  *(high risk, native code — the real "own network")*

The fallback that removes the shared-Wi-Fi requirement entirely:

1. Discovery finds nothing within a short budget.
2. If both ends support it, one side creates a private Doorstep access point
   (Android `startLocalOnlyHotspot`, Windows WinRT tethering).
3. The other side joins it **automatically** — no Settings trip, no password
   typing (`WifiNetworkSpecifier` on Android; WinRT on Windows).
4. The transfer runs exactly as it does on a normal LAN — same protocol, same
   mTLS.
5. The link is torn down when the transfer finishes.

Requires native Kotlin (Android) and a WinRT bridge (Windows), plus
`NEARBY_WIFI_DEVICES` / location permissions and careful battery accounting.
**iOS cannot create a hotspot**, so iPhone keep the LAN + Bluetooth + Wi-Fi Aware
paths; the pairing UI must never promise more than the platform can deliver.

### N4 — Always-on presence  *(the platform the ecosystem sits on)*

Once a trusted peer is persistently reachable, Doorstep stops being "a transfer
dialog" and becomes a quiet private link between your devices:

- **Clipboard sync** — copy on one, paste on the other.
- **Device presence** — "Michael is online", derived from the live link.
- **Instant notes** — send a snippet to a device without opening a file picker.
- **Shared folders** — continuous, real-time sync of a chosen folder.
- **Handoff** — start reading on the phone, continue on the laptop.
- **Nearby broadcast** — classroom/office: send to everyone on the Doorstep link.

Scope discipline: Doorstep stays **transfer · sync · share · continue**. No social
features, no profiles, no feed. Every feature above is a new way to move
something between *your own* devices, and none of them is a reason to show the
user a networking concept.

### N5 — Never explain the network

The one product rule that overrides everything else: users never see the words
*mDNS, multicast, soft AP, transport* or *Doorstep Network layer*. They see
"Looking for your devices…" and then their file arrives.

---

## Reliability before features

The rule behind the ordering above: **make Doorstep boringly reliable before
making it powerful.** If people trust the transfer, everything else gets used. If
they don't, nothing else matters.

---

## Engineering roadmap

### 1.2 — Reliability
- [ ] Discovery race + streaming results (N1)
- [ ] Paired-device rendezvous on start (N1)
- [ ] Connect uses the advertised port (N1)
- [ ] Server survives stop/start on the same port
- [ ] Network filter respects the user's choice
- [ ] Clear, specific failure messages

### 1.3 — Always-on + presence foundation
- [ ] Desktop autostart/tray hardened; Android foreground service
- [ ] Presence heartbeat over the persistent link
- [ ] One progress surface per transfer session

### 1.4 — Shared folders + clipboard
- [ ] Real-time folder sync on the persistent link
- [ ] Clipboard sync (opt-in, per device)

### 2.0 — Doorstep Direct
- [ ] Android LocalOnlyHotspot + auto-join
- [ ] Windows WinRT tethering + auto-join
- [ ] Bluetooth bootstrap (N2)
- [ ] iOS: Wi-Fi Aware + infrastructure only, documented

### Docs & community  *(runs alongside)*
- [ ] `CONTRIBUTING.md` — setup, conventions, first issue
- [ ] `docs/architecture.md`, `docs/networking.md`, `docs/discovery.md`,
      `docs/transfer-flow.md`
- [ ] Screenshots and short screen-recordings in the README
- [ ] Issue labels: `good-first-issue`, `help-wanted`, `documentation`
- [ ] Anonymous, opt-out usage analytics (install ID, active devices, transfer
      success rate, platform mix) — no personal data, documented in `PRIVACY.md`

---

## Contributing

Pick anything unchecked above. Issues labelled `good-first-issue` are scoped to be
self-contained; `help-wanted` ones need domain knowledge (native Wi-Fi, mTLS,
Rust async). See [CONTRIBUTING.md](CONTRIBUTING.md).
