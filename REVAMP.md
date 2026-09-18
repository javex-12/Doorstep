# Doorstep — Full Revamp Plan

> Research + findings + phased plan. **No code has been changed yet.**
> Author: cydercoder · Repo: `javex-12/Doorstep`

---

## 0. What you asked for (translated into requirements)

| # | Ask | Requirement |
|---|-----|-------------|
| R1 | No LocalSend anywhere — UI, logo, README, installer, settings | Full de-LocalSend sweep |
| R2 | Remove "scan to pair" | Delete QR from the primary flow |
| R3 | Doorstep should *find* nearby Doorstep networks and connect | Discovery-first pairing |
| R4 | Ask "permanent or temporary?" on connect | Trust dialog (already exists — needs to be reachable from discovery) |
| R5 | Laptop boots → Doorstep is on automatically | Desktop autostart + tray, on by default |
| R6 | Tap send → arrives even if the phone app was never opened | Android always-on listener + notification |
| R7 | Receiving device gets a notification to connect/trust | Incoming-request notification path |
| R8 | Port problem | Robust port handling |
| R9 | Settings page is still LocalSend | Rebuild settings natively |
| R10 | Simple, clean UI for Home / History / Settings | UI revamp |
| R11 | Loading screen shows once, not per file, not annoying | Progress/notification revamp |
| R12 | Refresh discovery button (or auto) in settings | Live discovery status + manual refresh |
| R13 | Theme must apply everywhere | Theme work |
| R14 | Where received files go must be clear | Smart destination + "where did it go?" |
| R15 | Must feel different because it's effortless — no reconnecting | The "always paired" experience |

---

## 1. Findings — what the code actually looks like today

### 1.1 Still LocalSend (concrete)

| Location | What's there |
|---|---|
| `app/pubspec.yaml:3` | `homepage: https://localsend.org/` |
| `app/lib/pages/tabs/settings_tab.dart` | **The settings page is the upstream LocalSend layout**: `_SettingsEntry` = label-left / control-right rows, `_SettingsSection` cards, section titles straight from `t.settingsTab.*` (`Receive`, `Send`, `Network`, `Other`), and the "Advanced settings" checkbox at the bottom. Two Doorstep toggles were bolted on top. This is exactly what you're seeing. |
| `app/lib/pages/home_page.dart` (~L128) | Desktop rail leading widget is a plain `Text('Doorstep')` with a hardcoded indigo `0xFF6366F1` — not the logo, not the brand palette. |
| `app/lib/main.dart` | Comment links to `github.com/localsend/localsend/issues/1568`. |
| `nearby_devices_provider.dart`, `doorstep_logo.dart`, `doorstep_pairing_helper.dart`, `doorstep_settings_provider.dart`, `doorstep_browse_provider.dart`, `doorstep_browse_page.dart` | Comments describing things "as LocalSend". |
| `README.md` | Still the upstream structure: screenshots, dependency hierarchy, upstream troubleshooting, and **17 translated copies** under `support/readme/`. |
| `app/assets/CHANGELOG.md` | Upstream changelog history. |
| Internal package names | `doorstep_isolates`, `rust_lib_doorstep` — structural, see Open Question Q4. |
| Icons | Need to verify all Android mipmaps / Windows `.ico` / installer icon are the Doorstep mark (some were regenerated earlier — must re-verify). |

**Good news:** `t.appName` is already `"Doorstep"`, the Android package is `com.doorstep.app`, the Windows binary is `doorstep.exe`, and `assets/i18n/*` has **zero** LocalSend strings. So this is a finishing sweep, not a rewrite.

### 1.2 Pairing / discovery

- `pages/doorstep_pair_scan_page.dart` (509 lines) — the camera QR scanner.
- `pages/tabs/doorstep_drop_zone_tab.dart` `_showPairingModal` — laptop shows a QR (`pretty_qr_code`).
- **Already exists and works:** `_DiscoveredDeviceCard` + `pairWithDiscoveredDevice()` → "Connect & Trust" from network discovery, and the trust dialog (`_askTrustLevel` → *My personal device* / *Temporary — this session only*) already matches R4 exactly.
- So R2/R3/R4 are mostly **re-wiring**, not new networking: make discovery the only entry point and delete the QR UI.

### 1.3 Always-on / notifications

- `flutter_foreground_task: 9.2.2` **is already a dependency** (`packages/doorstep_isolates/pubspec.yaml`), the Android manifest already declares the foreground service + a quick-settings tile, and `TransferNotification` (`packages/doorstep_isolates/lib/util/transfer_notification.dart`) already posts progress notifications.
- `util/native/autostart_helper.dart` already implements launch-at-login for **Windows (registry) / macOS (launch agent) / Linux (.desktop)** — but it's **opt-in and default off**.
- **Missing:** no `RECEIVE_BOOT_COMPLETED` / boot receiver on Android, no "Doorstep is on" persistent service independent of a transfer, and no *incoming connection request* notification when the app is closed.

### 1.4 Port

- `provider/doorstep_browse_provider.dart:22` → `doorstepBrowsePort(p) => p + 1`, bound on `InternetAddress.anyIPv4` as **plain HTTP**.
  - Breaks at port 65535 (overflow) → exception on bind.
  - If `p+1` is taken, the browse server silently fails and the phone hangs on "Loading forever".
  - It's a second, unauthenticated-looking socket that the peer has to *guess* from `port + 1`.
- `defaultPort = 53317` is the well-known LocalSend port. Changing it breaks protocol interop with any real LocalSend device on the network (which the transfer layer still speaks).

### 1.5 Loading / progress

- `widget/doorstep_loading_screen.dart` (235) + `widget/doorstep_quick_send_overlay.dart` (294) + `DoorstepTransferOverlay`, stacked over the whole app in `main.dart`'s `MaterialApp.builder`.
- `pages/progress_page.dart` — the upstream progress page still exists as a separate route.
- Three overlapping progress surfaces = the "shows up multiple times / frustrating" complaint.

### 1.6 Destination

- `settings.destination` + `quickSave` / `quickSaveFromFavorites` exist, with notices. There's no clear, simple answer to "where did my file go?" on the receiving side.

---

## 2. The target experience (R5 + R6 + R15)

**Laptop**
1. Install Doorstep once. It registers itself to start at login and minimise to tray — **on by default**.
2. From then on, Doorstep is simply *on*. Tray icon shows state. The transfer server is always listening.
3. The Doorstep tab shows devices that are actually reachable right now, refreshing on its own.

**Phone**
1. Install, grant notifications, and turn on **Doorstep always-on** (one switch, with an honest battery note).
2. From then on Android shows a quiet, permanent *"Doorstep is on — ready to receive"* notification. Behind it, a foreground service keeps the listener + receiver alive.
3. It auto-starts after reboot.

**Sending**
- Laptop: drop a file into a drop zone (or hit Send) → if only one trusted device is online it just goes; if several, a small picker. No re-pairing, no re-discovery, no app-opening.
- Phone: share sheet → Send to Doorstep → goes to your trusted laptop.

**Receiving on a phone that was never opened**
- The transfer arrives. Android posts a **doorstep notification** ("3 files from Laptop") that opens straight into the transfer, and *auto-accepts* when the sender is a trusted device (that's the existing `autoAcceptFromPaired` promise).

**Connecting a new device (no QR)**
- Both apps show the other under **"Nearby on the Doorstep network"**.
- Tap → *"Connect to Laptop?"* → **My personal device (reconnects automatically)** or **Temporary (this session only)**.
- The other side gets a notification: *"Phone wants to connect"* → Accept / Decline.
- Both sides store the pairing. Done forever.

**Honest limits I will not paper over**
- Android will not let any app run invisibly forever. A foreground service with a visible notification is the *only* compliant way to get "transfers arrive with the app closed", and the user must grant notification permission. I'll design the UX around that rather than pretend otherwise.
- Many routers block UDP multicast. Discovery will work on most home networks, but not all — so I want a **hidden fallback** (see Q1).

---

## 3. Architecture changes

### 3.1 Discovery-first pairing (R2–R4)
- **Delete** `doorstep_pair_scan_page.dart` and the QR panel in `_showPairingModal`; drop `mobile_scanner` and `pretty_qr_code` from the primary flow (keep the packages until confirmed unused, then remove).
- New **Connect** flow: `NearbyDeviceCard → ConnectSheet(trust level) → pairWithDiscoveredDevice()` (already exists) → confirm on both sides.
- Bind discovery to the **Doorstep tab and Settings**, both live-updating, with a manual refresh and a "last scanned Xs ago" line.
- Keep a hidden *Troubleshoot / Connect manually* entry (Q1).

### 3.2 Always-on network (R5, R6, R7, R12)
- **Desktop:** enable `enableAutoStart(startHidden: true)` by default on first run; ensure `minimizeToTray` + server started on launch; single-instance guard so opening it again just focuses the tray app.
- **Android:** promote the existing `flutter_foreground_task` from "transfer progress only" to a persistent **Doorstep service**:
  - `START_STICKY`, low-importance ongoing notification ("Doorstep is on").
  - Receives `RECEIVE_BOOT_COMPLETED` → start after reboot (`android/app/src/main/AndroidManifest.xml` + a boot receiver).
  - Holds the HTTP receiver + multicast listener alive so transfers land with the UI closed.
  - Explicit user switch + battery-optimisation exemption prompt.
- **New `ServerEventV2`-driven notification path:** when a non-trusted device connects, post *"X wants to connect"* with Accept/Decline actions instead of the current silent drop.

### 3.3 Port robustness (R8)
- Replace `port + 1` with a **discovered port**: the laptop advertises its browse endpoint as part of the pairing/register handshake (the handshake carrier in `doorstep_pairing_helper.dart` already smuggles fields through `deviceModel` — extend it).
- Keep `port + 1` as a *fallback only*, and add:
  - Guard against `> 65535`.
  - If the browse port is busy, scan upward for a free port and advertise *that*.
  - Clear error surfacing instead of a silent failure (today's "loading forever").
- Keep `defaultPort = 53317` for protocol interop; make custom ports safe.

### 3.4 One progress surface (R11)
- Keep **one** in-app surface (`DoorstepTransferOverlay`) and **one** notification channel.
- Show it **once per session**, not per file — a single queued transfer list.
- Delete/redirect `progress_page.dart`.
- Loading screen: only on cold start, auto-dismisses (no per-file replays).

### 3.5 Destination clarity (R14)
- Smart default per platform (Android → `Downloads/Doorstep`; Windows → `Downloads\Doorstep`; macOS/Linux → `~/Downloads/Doorstep`).
- One-tap **"Open folder"** from the notification and from History.
- A one-line plain-language explanation in Settings and on first receive.

---

## 4. UI revamp (R9, R10, R13)

### 4.0 Research (sources)

Design direction is grounded in these, not invented:

1. **Google — *Expressive Design: Google's UX Research*** (design.google/library/expressive-material-design-google-research)
   - The five fundamentals are **color, shape, size, motion, containment**.
   - In eye-tracking tests across 10 apps, expressive layouts let users spot key UI elements **up to 4× faster**, and the age gap in visual search time nearly **disappears for 45+ users**. Bigger tap targets and high-contrast containment are the drivers.
   - Hard warning that applies directly to us: *"When basic interaction paradigms are broken, expressive design can lead to poor usability."* Removing familiar labels/lists made things worse. So: expressive container styling, **conventional structure**.
2. **Android Developers — *Settings* design guide** (developer.android.com/design/ui/mobile/guides/patterns/settings)
   - Build settings from **Material lists: primary label + optional supporting text + icon + selection control on the right**.
   - *"Provide an overview"* — show the most important settings **and their current values** on one screen.
   - *"Containment — group settings in smaller relevant groups. Use visual or intrinsic containment and headings between groups instead of individual items."*
   - **Avoid putting app version / licensing info in settings.** (Doorstep currently puts a logo, version, tagline and a changelog button there — that goes.)
   - Frequent actions don't belong in settings; avoid jargon; labels start with the most important word.
   - 15+ settings → group into subscreens.
3. **Empty-state guidance** (mockplus.com/blog/post/empty-state-ui-design)
   - Every empty state needs four things: **visual, title, explanation, and exactly one CTA**.
   - Five kinds to handle: first-use, no-results, no-data, action-needed, error. Doorstep has all five today and currently renders three of them as a bare sentence on a card.

### 4.1 Design tokens

| Token | Dark | Light |
|---|---|---|
| `bg` | `#0B0D11` | `#F4F6F8` |
| `surface` | `#15181E` | `#FFFFFF` |
| `surfaceAlt` | `#1B1F27` | `#EDF1F6` |
| `border` | `#22262E` | `#E2E8F0` |
| `primary` | `#7CB7FF` | `#0F60FF` |
| `accent` | `#98E6D9` | `#006874` |
| `success` | `#86EFAC` | `#15803D` |
| `warning` | `#FDE047` | `#A16207` |
| `danger` | `#FCA5A5` | `#B91C1C` |
| `text` | `#F1F5F9` | `#1A1D20` |
| `textMuted` | `#8A939E` | `#64748B` |

Shape scale: cards `24`, sheets/dialogs `28`, pills/buttons `StadiumBorder`, chips `12`, icon badges `14`.
Type scale: display `32/w800`, title `20/w700`, body `14.5/1.45`, caption `12.5`, mono for IP:port.
Spacing: `4 / 8 / 12 / 16 / 24 / 32`. Screen gutter `20` mobile, `24` desktop.
Motion: 180ms for state changes, 320ms for entrances, `Curves.easeOutCubic`; respect the existing `enableAnimations` switch (and OS reduce-motion).

### 4.2 Layout rules (from the Android settings guide)

- **Settings rows are lists, not form grids.** Left: icon + label + optional supporting line. Right: the control. The existing `_SettingsEntry` (label left, fixed 150px control right, no icon, no supporting text) is the single biggest "this looks like LocalSend" tell and it goes.
- **Containment**: one card per group, heading above the card, never a divider per row.
- **Overview with values**: the Settings root shows current state inline (`On`, `Downloads/Doorstep`, `4 devices`) so it's readable without entering each row.
- **Version/licensing leaves Settings** → moves to an About screen reached from Settings → About.

### 4.3 Screen specs

**Home — "Doorstep"**
1. `DoorstepHeader`: greeting + one-line state.
2. **Status card** — the hero. Device name, Wi-Fi name, IP:port, and a real state chip (`Ready to receive` / `Not reachable` / `Sleep mode`) with a colour dot that reflects truth, not decoration.
3. **Nearby on the Doorstep network** — the discovery list. Live, auto-refreshing, each row = avatar/icon + alias + device type + `Connect` button, plus a `Searching…` empty state with a manual refresh and `last checked Ns ago`.
4. **Your devices** — trusted devices: online/offline dot, last seen, and a `Send` action. Empty state = one CTA explaining how to connect.
5. **Drop zones** (desktop) / **Send files** (phone) — primary action, full-width, high-contrast (the M3 "send button above the keyboard" lesson).

**History**
- Day-grouped timeline. Row: file icon, name, direction (sent/received), size, status chip. Tap → detail sheet with `Open file` / `Open folder` / `Send again`.
- Empty state: visual + "Nothing transferred yet" + one CTA.

**Settings**
1. **Doorstep** — Always on (with supporting text + battery honesty), Auto-accept from trusted devices, Sleep mode, Discover devices (refresh + last-checked).
2. **Your devices** — count, then the list; revoke asks for confirmation.
3. **Where files go** — destination path + `Open folder`.
4. **Appearance** — theme, colour, animations.
5. **Advanced** (collapsed) — port, multicast group, network interfaces, encryption, device type/model, plus **Connect manually** (the Q1 fallback) and the discovery diagnostics.
6. **About** — separate screen: logo, version, credits, changelog, licences.

**Remaining pages to de-LocalSend:** `about_page`, `progress_page`, `receive_options_page`, `send_page`, `selected_files_page`, `web_send_page`, `receive_history_page`, `network_interfaces_page`, `troubleshoot_page`, `changelog_page`, `language_page`, `apk_picker_page`, `receive_page`, and the `list_tile/*` widgets.

Keep the existing Doorstep palette (`#0B0D11` / `#7CB7FF` / `#98E6D9`) but rebuild the three tabs as **Doorstep-native**, not upstream-shaped.

**Home** — a status-first dashboard
- Device card: name, live connection state, *"Ready to receive"*, and a prominent state chip.
- **Nearby on the Doorstep network** — auto-refreshing list, tap to connect (replaces the QR button).
- **Your devices** — trusted devices with online/offline and last-seen.
- **Drop zones** (desktop) / **Sending** (phone) — primary action.

**History**
- Clean timeline grouped by day; per-item status, size, direction; tap → details + *Open file* / *Open folder*.
- Fix the per-file animation replay (`doorstepArrivalProvider` already hints this was patched).

**Settings** — grouped tiles, switches on the right, no label-left/control-right grid
1. **Doorstep** — Always on, Auto-accept from trusted, Sleep mode, Nearby discovery (with refresh).
2. **Your devices** — trusted-device list with revoke (confirm dialog).
3. **Where files go** — destination + Open folder.
4. **Look & feel** — theme, colour, animations.
5. **Advanced** (collapsed) — the genuinely technical upstream knobs (port, multicast, interfaces, encryption, device type/model).

Theme: fix the "colour only applies to settings + nav" bug by making `DoorstepTheme` helpers read from the resolved `ColorScheme` everywhere, and audit every page for hardcoded hex.

---

## 5. De-LocalSend sweep (R1)

1. `app/pubspec.yaml` homepage → repo/portfolio.
2. Rebuild `settings_tab.dart` (above) — removes the strongest LocalSend signal.
3. Desktop rail: use `DoorstepLogo`, brand colours.
4. Purge LocalSend from code comments; keep `LICENSE` + a `NOTICE`/credits page (Apache-2.0 *requires* attribution — it just shouldn't be in the product UI).
5. Rewrite `README.md` as Doorstep's own; delete/replace `support/readme/*` translated upstream readmes (or regenerate short Doorstep ones).
6. Replace `app/assets/CHANGELOG.md` with the Doorstep changelog.
7. Re-verify every icon: Android mipmaps (legacy/adaptive/monochrome/quick-tile), Windows `.ico`, Inno Setup installer icon + publisher/splash.
8. Rebrand the Inno Setup script (`support/scripts/compile_windows_exe-inno.iss`) — publisher, URLs, icon, AppId.
9. Website: already Doorstep-branded, but re-check for LocalSend.
10. `brew`/macOS/Linux packaging + `fastlane` metadata: verify names, descriptions, icons.

---

## 6. Phased delivery

Phases are ordered so each one is independently testable on your laptop + itel A50C.

### Phase 1 — De-LocalSend + Settings rebuild *(UI, low risk)*
- Settings page rebuilt natively (sections above) with a working discovery refresh.
- Desktop rail logo/brand fix. `pubspec.yaml` homepage.
- Comments purged; theme helpers fixed so colour applies everywhere.
- README / CHANGELOG / installer / icons rewritten.
- **Verify:** `flutter analyze`, app runs on Windows, screenshots.

### Phase 2 — Discovery-first pairing, QR removed
- Remove the scan page + QR panel; build the Connect sheet + confirm-on-both-sides.
- Wire the trust dialog into discovery (reuse what exists).
- Add the hidden manual fallback (per Q1).
- **Verify:** pair phone ↔ laptop with no QR, on your phone.

### Phase 3 — Always-on
- Desktop: autostart at login by default, tray, single instance.
- Android: persistent Doorstep service, boot receiver, notification permission flow, battery-exemption prompt.
- Incoming-connection notification with Accept/Decline.
- **Verify:** reboot the laptop and the phone, then send without opening the app.

### Phase 4 — Port fix + transfer reliability
- Discovered browse port, busy-port fallback, 65535 guard, clear failures.
- **Verify:** browse a large folder from the phone with no "loading forever".

### Phase 5 — Progress/loading revamp + History polish + destination clarity
- One progress surface per session, one notification channel, `progress_page.dart` retired.
- History redesign. Smart destinations + "Open folder".
- **Verify:** transfer many files; confirm exactly one progress UI and one notification.

### Phase 6 — Packaging + release
- Rebuild APKs (arm64/armv7/x86_64) + Windows installer/portable, re-upload the release, refresh the site.

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| Removing QR leaves some networks unpairable (multicast blocked) | Keep a hidden manual/troubleshoot fallback (Q1) |
| Android kills the background listener anyway | Foreground service + boot receiver + battery exemption prompt; honest UI copy |
| Battery drain on the itel A50C | Sleep mode preserved; low-importance notification; configurable |
| Always-on could break the existing v1.0.0 flow | Phased, each phase independently verified on-device |
| Renaming internal packages is a large mechanical change | Deferred / optional (Q4) |

---

## 8. Decisions (confirmed)

| Q | Decision |
|---|---|
| **Q1 — QR removal** | **Remove QR from the primary flow, and make discovery significantly more robust — plus keep a hidden fallback** for networks that block multicast. |
| **Q2 — Always-on defaults** | **On by default, with honest notices.** Laptop enables launch-at-login + minimise-to-tray on first run; phone asks once for notification permission, then keeps a quiet "Doorstep is on" notification. |
| **Q3 — Scope/order** | **All phases back-to-back.** |
| **Q4 — Internal package names** | **Rename everything**, including `doorstep_isolates` → `doorstep_isolates`, `rust_lib_doorstep` → `rust_lib_doorstep`, and the Rust core crate `localsend` → `doorstep_core`. |

### Revised discovery scope (because of Q1)

Making discovery "significantly more robust" is now a first-class requirement, not a nice-to-have:

1. Keep the UDP multicast path, but add these on top:
   - **UDP broadcast fallback** per interface (works where multicast is filtered but broadcast is not).
   - **Subnet sweep** — after discovery, probe `x.y.z.0/24` on `DEFAULT_PORT` for the Doorstep handshake (fast, concurrent, bounded).
   - **Rendezvous over the paired list** — already partly there via `StartFavoriteScan`; extend it to also retry stored last-known IPs.
   - **Continuous background refresh** while the app is open, with visible "last refreshed" state.
2. Every discovery source feeds one list, de-duplicated by fingerprint, with a per-source badge so failures are diagnosable in Troubleshoot.
3. Hidden fallback (Q1): a **Connect manually** entry inside Settings → Advanced for the rare network where nothing is discoverable.

### Execution order

1. Internal rename (mechanical, verifiable — do it while global find/replace is cheap)
2. De-LocalSend sweep + Settings rebuild + brand/theme fixes
3. Discovery: robustness + discovery-first pairing + QR removal + manual fallback
4. Port fix
5. Always-on (desktop + Android)
6. Progress/history/destination
7. Packaging + release
