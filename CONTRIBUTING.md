# Contributing to Doorstep

Thanks for wanting to help. This page covers everything you need: getting the
app running, the conventions the project follows, and where to start.

> **Code of conduct:** by participating you agree to the
> [Code of Conduct](CODE_OF_CONDUCT.md). Be decent; it is not hard.

---

## Ways to contribute

Not everything is code, and the non-code work matters just as much:

| You want to… | Start here |
|---|---|
| Write code | [Set up a dev environment](#set-up-a-dev-environment) |
| Fix a bug | [Good first issues](#finding-work) |
| Translate the app | [Translations](#translations) |
| Improve these docs | Open a PR — docs changes are merged quickly |
| Report a bug | [Bug report template](https://github.com/javex-12/Doorstep/issues/new?template=bug_report.yml) |
| Suggest a feature | [Feature request template](https://github.com/javex-12/Doorstep/issues/new?template=feature_request.yml) |
| Report a security issue | [SECURITY.md](SECURITY.md) — **never** a public issue |

A note on AI-generated contributions: Doorstep accepts them **only** for genuine
bug fixes, trivially small changes, or when you can demonstrate real expertise
in the relevant area. Substantive design and feature work needs to be yours.

## Set up a dev environment

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) | `3.41.9` | Pinned in [.fvmrc](.fvmrc) — use `fvm flutter` / `fvm dart` |
| [FVM](https://fvm.app) | latest | Manages the pinned Flutter version |
| [Rust](https://rustup.rs) | stable | The networking core and HTTP server |
| Android Studio / Xcode | — | Only for the platform you want to build |
| Visual Studio 2022 | C++ desktop workload | Windows builds only |

### Clone and run

```bash
git clone https://github.com/javex-12/Doorstep.git
cd Doorstep

fvm flutter --version          # picks up the pinned version
cd app

fvm flutter pub get
fvm dart run build_runner build   # dart_mappable, freezed, flutter_gen, mockito
fvm dart run slang                # i18n codegen (slang_build_runner is disabled)
fvm flutter run
```

The Rust plugin (`rust_lib_doorstep`) builds automatically through cargokit
during `flutter run` / `flutter build` — there is nothing extra to start.

### Check your work before opening a PR

This is exactly what CI runs:

```bash
cd app
fvm dart format --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test

# Rust — the --features part is mandatory: a bare check fails by design
cd ../packages/core && cargo test --features full
cd ../doorstep_isolates/rust && cargo check
```

Notes that save time:

- Formatting is **150 columns** (`page_width` in `analysis_options.yaml`).
- `fvm dart run build_runner build` sometimes rewrites `app/test/mocks.mocks.dart`
  at 80 columns — revert that file if it shows up in your diff.
- `packages/localsend_isolates`-style packages have their own `build.yaml` and
  need their own `pub get` + `build_runner` run when their models change.

## Project layout

```
app/                          Flutter app (doorstep_app)
  lib/pages/                  Screens and tabs
  lib/provider/               Refena providers — state lives here
  lib/widget/                 Reusable widgets and the Doorstep design system
  lib/gen/                    Generated — do not edit
packages/doorstep_isolates/   Dart isolates + flutter_rust_bridge bindings
  lib/src/isolate/            Parent/child isolate plumbing
  lib/src/task/               Pure helpers only — no isolate logic here
  rust/                       The Flutter plugin crate (rust_lib_doorstep)
packages/core/                doorstep_core — protocol, HTTP, crypto, WebRTC
packages/typed_isolates/      Small typed Dart isolate wrapper
server/                       WebSocket signalling server for WebRTC
cli/                          doorstep-cli — terminal client
support/scripts/              Release and packaging scripts
docs/                         Architecture and protocol documentation
```

Dependency direction is one-way: `app` → `doorstep_isolates` → (`typed_isolates`,
`rust_lib_doorstep` → `doorstep_core`). The app never depends on
`flutter_rust_bridge` or the plugin crate directly.

## Conventions

**State management** is [Refena](https://pub.dev/packages/refena_flutter), not
Riverpod. Plain state uses `NotifierProvider`; anything the isolate layer
touches uses `ReduxProvider` with dispatched action classes.

**Heavy networking never runs on the main isolate.** Child isolates translate
typed task messages into calls on `lib/src/task/`, which is pure helpers only —
isolate logic is prohibited there (see its README).

**Models** are `dart_mappable`. Mind the configured method names: `fromJson` /
`toJson` are the Map converters and `deserialize` / `serialize` are the string
ones.

**New server ↔ app interactions** extend `ServerEventV2` rather than adding side
channels. Only one upload session is active at a time; cancellation safety comes
from drop guards, not from extra flags.

**Brand** — colour changes must reach every page, not just Settings and the nav.
Use the helpers in `lib/config/doorstep_theme.dart` instead of hardcoding
colours.

**Keep it simple for the user.** If a change makes the user think about
networks, protocols or transports, it is the wrong shape. "It just works" is a
design constraint, not a slogan.

## Finding work

Look at the issue tracker for the `good-first-issue` and `help-wanted` labels:

- **`good-first-issue`** — scoped, self-contained, no deep domain knowledge needed.
- **`help-wanted`** — needs domain knowledge (native Wi-Fi, mTLS, Rust async).
- **`documentation`** — docs, diagrams, translation gaps.

Unsure where to start? Open an issue and describe what you want to work on —
nobody is expected to guess.

## Pull requests

1. Fork, then create a branch from `main`.
2. Keep the change focused — one fix or one feature per PR.
3. Run the checks listed above.
4. Write a clear description: *what* changed and *why*. Link the issue if there
   is one.
5. New behaviour needs a test where one is practical.

Reviews are conversational — expect questions, not verdicts. Changes are
requested only when they matter.

## Translations

The app speaks many languages, and translations are managed through the files in
[`app/assets/i18n`](app/assets/i18n).

1. Fork the repository.
2. Pick one:
   - **Fill missing strings** — edit `_missing_translations_<locale>.json`
   - **Fix a string** — edit `<locale>.json`
   - **Add a language** — create the new file ([locale codes](https://saimana.com/list-of-country-locale-code/))
3. Optional, to see it live:
   ```bash
   cd app && fvm dart run slang && fvm flutter run
   ```
4. Open a pull request.

**Do not translate fields whose keys start with `@`** — they are metadata for
translators and are never shown in the app.

## Release process (maintainers)

Versions live in three places that CI keeps in sync:

- `app/pubspec.yaml` — `version:`
- `support/scripts/compile_windows_exe-inno.iss` — `MyAppVersion`
- `cli/Cargo.toml` — `version`

To ship:

1. Bump the version in all three places.
2. Commit and tag: `git tag vX.Y.Z && git push origin main --tags`
3. Pushing the tag runs [Build all platforms](.github/workflows/build_all.yml):
   universal Android APK, Windows installer + portable zip, Linux AppImage,
   universal macOS zip, unsigned iOS ipa — plus a GitHub Release and an upload
   to the Blob store that the [download page](https://javex-12.github.io/Doorstep/) serves from.
4. There is no step 4. The tag is the release.

### Bumping Flutter

Pinned in four places: `.fvmrc`, `.github/workflows/ci.yml`, `app/pubspec.yaml`
and the `support/submodules/flutter` submodule.

1. `fvm use <version>`
2. Submodule:
   ```bash
   git submodule update --init
   cd support/submodules/flutter
   git fetch && git checkout <version>
   cd ../../.. && git add support/submodules/flutter
   ```
3. Update the constraint in `.github/workflows/ci.yml` and `app/pubspec.yaml`.

## Recognition

Every contributor is credited in the release notes. Translators appear in-app
under **Settings → About → Translators**.
