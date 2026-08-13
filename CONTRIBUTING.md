# Contributing to Doorstep

Doorstep is an open-source project, and we welcome contributions from anyone who is interested in helping improve the app. Whether you're a developer, a translator, or a documentation writer, there are many ways to get involved.

Doorstep disallows AI generated contributions unless:

- they are bug fixes or
- very small or
- you prove your expertise in your field

## Getting Started

If you're interested in contributing code to Doorstep, you'll need to follow these steps:

## Run

After you have installed [Flutter](https://flutter.dev), then you can start this app by typing the following commands:

```shell
cd app
flutter pub get
dart run build_runner build -d
flutter run
```

## Translation

You can help in translating this app to other languages!

1. Fork this repository
2. Choose one
   - Add missing translations in existing languages: Only update `_missing_translations_<locale>.json` in [assets/i18n](https://github.com/javex-12/Doorstep/tree/main/app/assets/i18n)
   - Fix existing translations: Update `strings_<locale>.i18n.json` in [assets/i18n](https://github.com/javex-12/Doorstep/tree/main/app/assets/i18n)
   - Add new languages: Create a new file, see also: [locale codes](https://saimana.com/list-of-country-locale-code/).
3. Optional: Re-run this app
   1. Run `cd app` to enter the app directory.
   2. Make sure you have [run](#run) this app once.
   3. Update translations via `flutter pub run slang`
   4. Run the app via `flutter run`
4. Open a pull request

**_Take note:_ Fields decorated with `@` are not meant to be translated, they are not used in the app in any way, being merely informative text about the file or to give context to the translator.**

Thanks to all [translators](https://github.com/javex-12/Doorstep/tree/main/app/lib/pages/about/translators.dart)!

## Contributing Guidelines

Before you submit a pull request to Doorstep, please ensure that you have followed these guidelines:

- Code should be well-documented and formatted according to the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).
- All changes should be covered by tests.
- Commits should be well-written and descriptive, with a clear summary of the changes made and any relevant context.
- Pull requests should target the `main` branch and include a clear summary of the changes made.

## Bug Reports and Feature Requests

If you encounter a bug in Doorstep or have a feature request, please submit an issue to the [issue tracker](https://github.com/javex-12/Doorstep/issues). Please be sure to provide a clear description of the problem or feature request, along with any relevant context or steps to reproduce the issue.

## Security Issues

If you discover a security issue in Doorstep, please do not submit an issue to the public issue tracker. Instead, please open a private security advisory on the [GitHub repo](https://github.com/javex-12/Doorstep/security) so that we can address the issue as quickly and effectively as possible.

## Distribution

Doorstep is distributed directly from this repository — every release ships ready-to-run binaries for all supported platforms.

| Platform | Artifacts |
|----------|-----------|
| Windows  | EXE installer, portable ZIP (built by the release pipeline) |
| Android  | APKs for 32-bit (`armeabi-v7a`) and 64-bit (`arm64-v8a`, `x86_64`) devices |
| macOS    | DMG installer |
| Linux    | AppImage, TAR, DEB |

Maintained by [cydercoder](https://cydercoder.vercel.app) ([@javex-12](https://github.com/javex-12)).

App stores and package managers (Play Store, App Store, winget, etc.) are planned but not yet published. If you would like to help package Doorstep, please open an issue!

## Notes

Useful notes.

### Compile production APK

You will need the signing keys to generate an APK.

Either generate one or use the debug signing options:

```groovy
// File: android/app/build.gradle
buildTypes {
  release {
    signingConfig signingConfigs.debug // using debug signing
  }
}
```

### Bump Flutter

Suppose we want to update flutter to `3.41.9`:

1. Update flutter from fvm: `fvm use 3.41.9`
2. Update flutter from submodule:
   1. `git submodule update --init`
   2. `cd support/submodules/flutter`
   3. `git fetch`
   4. `git checkout 3.41.9`
   5. `cd ../../..`
   6. `git add support/submodules/flutter`
3. Update flutter constraints:
   1. In CI: `.github/workflows/ci.yml`
   2. In pubspec: `pubspec.yaml`

### Release

Make sure to set up the self-hosted runner to compile arm64 linux binaries.

To set up the runner, follow the following instructions:

Install Flutter

```bash
sudo apt install git
git clone https://github.com/flutter/flutter.git $HOME/flutter
nano $HOME/.bashrc
```

Add the following to the end of the file:

```bash
export PATH="$PATH:$HOME/flutter/bin"
```

Restart the terminal.

```bash
flutter doctor
```

Next, follow the instructions to set up the GitHub runner.

Start the "Release Draft" workflow from the "Actions" tab: https://github.com/javex-12/Doorstep/actions/workflows/release.yml

Finally, compile binaries not yet supported by the pipeline.
