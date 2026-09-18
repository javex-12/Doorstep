# Doorstep

[![CI status][ci-badge]][ci-workflow]

[ci-badge]: https://github.com/javex-12/Doorstep/actions/workflows/ci.yml/badge.svg
[ci-workflow]: https://github.com/javex-12/Doorstep/actions/workflows/ci.yml

**Your phone is another folder on your computer.**

Doorstep is a free, open-source app that shares files between your phone and your computer over your own Wi-Fi — no internet, no cloud, no accounts.

Pair once. After that, Doorstep just works: drop a file into a folder on your computer and it arrives on your phone — even with the app closed. Share from your phone and it lands on your computer just as easily.

[Download](https://github.com/javex-12/Doorstep/releases/latest) · [Download page](https://javex-12.github.io/Doorstep/) · [Product spec](DOORSTEP.md) · by [cydercoder](https://cydercoder.vercel.app)

---

## Why Doorstep

Other file-sharing apps make you do the same dance every time: open the app, wait for discovery, pick the device, pick the files, send. Doorstep throws that away:

| | Others | Doorstep |
|---|---|---|
| Pairing | Scan, re-scan, re-discover | **Once.** Devices reconnect on their own |
| Sending | Open app → wait → pick → send | Drop into a folder. Done |
| Receiving | App must be open | **Arrives with the app closed** (quiet background service) |
| Internet | Sometimes needed | **Never.** It all happens on your network |
| Privacy | Varies | End-to-end encrypted, nothing leaves your LAN |

## Features

- **Pair once** — connect to a device on your Doorstep network and choose *personal* (remembered forever, reconnects automatically) or *temporary* (this session only). No QR code hunting.
- **Drop zones** — mark folders on your computer. Anything you drop in is delivered to your phone automatically.
- **Receive with the app closed** — a quiet, battery-aware background service keeps your phone ready to receive, with a persistent notification you control.
- **Trust levels** — personal devices reconnect and can push files any time; temporary devices are forgotten when the app closes.
- **Live folder browser** — browse folders on your computer from your phone and pull files over.
- **Per-device routing** — point each drop zone at specific devices, not "everyone".
- **Encrypted** — transfers run over authenticated, encrypted connections. Only devices you approved can talk to you.

## Download

Grab the latest build from [Releases](https://github.com/javex-12/Doorstep/releases/latest) or the [download page](https://javex-12.github.io/Doorstep/):

- **Android** — APK (arm64 for most phones, armv7 for older 32-bit devices, x86_64 for emulators)
- **Windows** — installer (`.exe`) or portable `.zip`

iOS, macOS and Linux builds are planned.

> **Note for Android:** because Doorstep is distributed directly (not through an app store), Android shows a one-time "unknown apps" warning and Google Play Protect may ask for confirmation. This is normal for open-source apps installed outside the Play Store — the APK is built straight from this repository's source.

## How it works

1. Install Doorstep on both devices and connect them to the same Wi-Fi (or put your phone on your computer's hotspot).
2. Doorstep finds the other device automatically — tap **Connect** and choose how much you trust it.
3. That's it. Files now move by themselves: drop zones on the computer, the share sheet on the phone.

Under the hood, Doorstep speaks the [LocalSend protocol](https://github.com/localsend/protocol) (v2.1) over HTTPS with mandatory certificate verification, plus UDP multicast + broadcast for discovery. It is built on a fork of [LocalSend](https://github.com/localsend/localsend)'s networking core (Apache-2.0) — huge credit to the LocalSend team; see [LICENCE](LICENSE) and in-app **Settings → About → Licence notices**.

## Getting started (development)

The repo is a Flutter app on top of a Rust core:

| Path | What it is |
|---|---|
| `app/` | Flutter app (`doorstep_app`) — UI, providers, persistence, platform channels |
| `packages/doorstep_isolates/` | Dart isolate layer + Flutter-Rust-Bridge bindings (`rust_lib_doorstep`) |
| `packages/core/` | Rust crate `doorstep_core` — protocol, HTTP server/client, crypto, WebRTC |
| `packages/typed_isolates/` | Typed Dart isolate channels |
| `server/` | WebSocket signalling server for WebRTC (deployed separately) |
| `cli/` | `doorstep-cli` — terminal client on top of the core |

### Prerequisites

- Flutter `3.41.9` (pinned in `.fvmrc`; use `fvm flutter` / `fvm dart`)
- Rust toolchain (stable)
- For Windows builds: Visual Studio with C++ desktop workload

### Run

```bash
cd app
fvm flutter pub get
fvm dart run build_runner build   # dart_mappable, freezed, flutter_gen, mockito
fvm dart run slang                # i18n codegen
fvm flutter run
```

The Rust plugin builds automatically through cargokit during `flutter run` / `flutter build`.

### Checks (what CI runs)

```bash
cd app
fvm dart format --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test

cargo test --features full      # in packages/core
cargo check                      # in packages/doorstep_isolates/rust, server, cli
```

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). If you find a security issue, please follow [SECURITY.md](SECURITY.md) rather than opening a public issue.

## Licence

[Apache-2.0](LICENSE). Doorstep is a fork of [LocalSend](https://github.com/localsend/localsend) — all credit and thanks to its authors for the excellent protocol and networking core.
