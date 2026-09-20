# Architecture

How Doorstep is put together, and why.

---

## One sentence

A Flutter app on top of a Rust networking core, wired together by typed Dart
isolates and flutter_rust_bridge, so the UI never does heavy work.

## The layers

```
┌────────────────────────────────────────────────────────────┐
│ app/  (doorstep_app)                                       │
│   UI · providers · persistence · platform channels         │
└──────────────────────────┬─────────────────────────────────┘
                           │  depends only on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ packages/doorstep_isolates/                                │
│   Typed Dart isolates + flutter_rust_bridge bindings       │
│   ├─ lib/src/isolate/   parent ↔ child plumbing            │
│   ├─ lib/src/task/      pure helpers (no isolate logic)    │
│   └─ rust/              rust_lib_doorstep (Flutter plugin) │
└──────────────┬─────────────────────────┬───────────────────┘
               │                         │
               ▼                         ▼
┌──────────────────────────┐  ┌─────────────────────────────┐
│ packages/typed_isolates/ │  │ packages/core/              │
│ typed send/recv channels │  │ doorstep_core (Rust)        │
└──────────────────────────┘  │ protocol · HTTP · crypto    │
                              │ multicast · WebRTC          │
                              └─────────────────────────────┘
```

Dependency direction is strictly one way: `app` → `doorstep_isolates` →
(`typed_isolates`, `rust_lib_doorstep` → `doorstep_core`). The app **never**
depends on `flutter_rust_bridge` or the plugin crate directly.

## State management

[Refena](https://pub.dev/packages/refena_flutter), not Riverpod.

- Plain state → `NotifierProvider`.
- Anything the isolate layer touches → `ReduxProvider` plus dispatched action
  classes, because those actions are the only supported way to talk to children.

Providers live in `app/lib/provider/`. Bootstrap is `app/lib/config/init.dart`
(`preInit`): logging, `RustLib.init()`, persistence, the isolate container,
tray/window — it returns the `RefenaContainer` that `main.dart` mounts.

## Isolates

The heavy networking never runs on the main isolate.

- `parent/parent_isolate_provider.dart` holds one `IsolateConnector` per child
  (HTTP scan discovery, multicast discovery, HTTP upload, HTTP server) plus a
  `SyncState` mirrored into every child.
- `parent/actions.dart` and `parent/actions_sync.dart` are the **only**
  supported way for the app to talk to the children.
- `child/*_isolate.dart` are the child entry points; they translate typed task
  messages into calls on `lib/src/task/`.

State children need (alias, port, protocol, whether the server runs, whether
web send is on) is pushed via `IsolateSyncServerStateAction`. Children read
`syncState` at start, so **sync before starting the server**.

`lib/src/task/` contains pure helpers only — isolate logic is prohibited there.

## The Rust HTTP server

`packages/core/src/http/server/` implements protocol v2 plus the web-send
download flow and an internal `show` endpoint used to foreground an already
running instance.

Integration is **channel based**, not call based:

```
start_with_port(ServerConfigV2 { pin, event_tx, web_send })
        │
        ▼  emits ServerEventV2
   Register · PrepareUpload (decision_tx oneshot)
   FileUpload (byte stream + result_tx) · PrepareDownload
   SessionEnd · PrepareUploadAborted · CancelReceived
```

Rules that keep it correct:

- Only **one upload session is active at a time**.
- Cancellation safety comes from drop guards (`PendingSessionGuard`,
  `UploadGuard`, `PendingWebSessionGuard`), not from extra flags.
- There is deliberately no `auto_accept` in core — the app auto-accepts by
  answering `decision_tx` immediately.
- New server → app interactions **extend `ServerEventV2`** rather than adding
  side channels.

The FRB layer (`packages/doorstep_isolates/rust/src/api/server.rs`) exposes
`start_server` plus an opaque `RsHttpServer` whose `listen` merges the v2, web
send and internal channels into one `RsServerEvent` stream. Responder oneshots
stay on the Rust side. On the Dart side `child/server_isolate.dart` turns those
into `HttpServerEvent`s, which `server_provider.dart` routes to
`ReceiveController` / `SendController` — event handlers, not route handlers.

Save targets are decided in Dart and written by Rust: a plain path, or an
Android SAF file descriptor obtained through the
`com.doorstep.app/doorstep` method channel. Gallery saves go through a cache
file first.

Server event `ip`s are `PeerIp` (IP + IPv6 scope): a link-local peer renders as
`fe80::1%3`, which the HTTP client accepts back as a host, so event ips stay
dialable.

## Multicast discovery (Rust)

`packages/core/src/multicast/` (feature `multicast`, independent of `http`)
implements UDP discovery for protocol v2.1 — v1 messages are not parsed.

- `multicast::start` takes a `MulticastConfig { group, group_v6, port,
  interface_filter, device, event_tx }` and emits `MulticastEvent::Discovered`.
- The returned `MulticastHandle` offers `announce` (the burst) and
  `wait_stopped`.
- UDP is **announce only**: answers go back over HTTP as a unicast register
  request, not as more UDP.
- One socket is bound per interface IPv4 address (`SO_REUSEPORT`/`SO_REUSEADDR`
  + `IP_MULTICAST_IF`), because a single socket only sends on one interface.
- Multicast loopback stays on so two instances on one host can see each other;
  own messages are dropped by fingerprint.
- IPv6 is a Doorstep extension (group `ff12::fd3a:e420`), enabled by setting
  `group_v6`: one `IPV6_V6ONLY` socket per interface, joined by interface index.
- `Discovered` carries the source's scope ID, which link-local IPv6 sources
  need for the HTTP answer.

## Crate features

`packages/core` gates almost everything behind Cargo features (`crypto`, `http`,
`multicast`, `webrtc`, `webrtc-signaling`, `full`) and `default = []`.

**Always build and test with `--features full`.** A bare `cargo check` fails
because modules are declared unconditionally while their dependencies are
optional — that is pre-existing and expected, not a regression.

## There is no Cargo workspace

`packages/core`, `packages/doorstep_isolates/rust`, `server` and `cli` are
independent crates that must be checked and built individually.
