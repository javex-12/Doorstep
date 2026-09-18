import 'dart:io';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/gen/strings.g.dart';
import 'package:doorstep_app/model/persistence/color_mode.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/pages/about/about_page.dart';
import 'package:doorstep_app/pages/debug/discovery_debug_page.dart';
import 'package:doorstep_app/pages/language_page.dart';
import 'package:doorstep_app/pages/settings/network_interfaces_page.dart';
import 'package:doorstep_app/pages/tabs/settings_tab_controller.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_settings_provider.dart';
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/provider/network/server/server_provider.dart';
import 'package:doorstep_app/provider/settings_provider.dart';
import 'package:doorstep_app/util/alias_generator.dart';
import 'package:doorstep_app/util/device_type_ext.dart';
import 'package:doorstep_app/util/native/macos_channel.dart';
import 'package:doorstep_app/util/native/open_folder.dart';
import 'package:doorstep_app/util/native/pick_directory_path.dart';
import 'package:doorstep_app/util/native/platform_check.dart';
import 'package:doorstep_app/util/ui/snackbar.dart';
import 'package:doorstep_app/widget/custom_dropdown_button.dart';
import 'package:doorstep_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:doorstep_app/widget/dialogs/pin_dialog.dart';
import 'package:doorstep_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:doorstep_app/widget/dialogs/quick_save_notice.dart';
import 'package:doorstep_app/widget/dialogs/text_field_tv.dart';
import 'package:doorstep_app/widget/dialogs/text_field_with_actions.dart';
import 'package:doorstep_app/widget/doorstep_empty_state.dart';
import 'package:doorstep_app/widget/doorstep_list_tile.dart';
import 'package:doorstep_app/widget/doorstep_section.dart';
import 'package:doorstep_app/widget/doorstep_status_chip.dart';
import 'package:doorstep_app/widget/labeled_checkbox.dart';
import 'package:doorstep_app/widget/responsive_list_view.dart';
import 'package:doorstep_isolates/constants.dart';
import 'package:doorstep_isolates/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// Doorstep settings.
///
/// Layout follows the Android settings guidance: a Material **list** per group,
/// with an icon, a primary label, supporting text carrying the current state,
/// and the control on the right. Groups are contained in a single card with a
/// heading above it — never one container per row.
///
/// App version, credits and the changelog deliberately live on the About
/// screen, not here.
class SettingsTab extends StatelessWidget {
  const SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => settingsTabControllerProvider,
      builder: (context, vm) {
        final ref = context.ref;
        final doorstep = ref.watch(doorstepSettingsProvider);
        final pairedDevices = ref.watch(doorstepPairingProvider);
        final nearbyCount = ref.watch(nearbyDevicesProvider).allDevices.length;
        final isMobile = checkPlatform([TargetPlatform.android, TargetPlatform.iOS]);

        return ResponsiveListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          children: [
            const _SettingsHeading(),

            // ── Doorstep ────────────────────────────────────────────────────
            DoorstepSection(
              title: 'Doorstep',
              subtitle: 'How Doorstep behaves on this device',
              children: [
                if (isMobile)
                  DoorstepListTile(
                    icon: Icons.podcasts_rounded,
                    title: 'Stay on in the background',
                    subtitle: doorstep.backgroundService
                        ? 'Ready to receive even when Doorstep is closed\nUses a little more battery'
                        : 'Only receiving while the app is open',
                    trailing: Switch(
                      value: doorstep.backgroundService,
                      onChanged: (b) async {
                        await ref.notifier(doorstepSettingsProvider).setBackgroundService(b);
                      },
                    ),
                    onTap: () async {
                      await ref.notifier(doorstepSettingsProvider).setBackgroundService(!doorstep.backgroundService);
                    },
                  ),
                DoorstepListTile(
                  icon: Icons.bolt_rounded,
                  title: 'Auto-accept from trusted devices',
                  subtitle: doorstep.autoAcceptFromPaired ? 'Files arrive without a prompt' : 'You confirm every incoming transfer',
                  trailing: Switch(
                    value: doorstep.autoAcceptFromPaired,
                    onChanged: (b) async {
                      await ref.notifier(doorstepSettingsProvider).setAutoAcceptFromPaired(b);
                    },
                  ),
                  onTap: () async {
                    await ref.notifier(doorstepSettingsProvider).setAutoAcceptFromPaired(!doorstep.autoAcceptFromPaired);
                  },
                ),
                if (isMobile)
                  DoorstepListTile(
                    icon: Icons.battery_saver_rounded,
                    title: 'Sleep mode',
                    subtitle: doorstep.sleepMode ? 'Announcements paused to save battery' : 'Doorstep stays discoverable',
                    trailing: Switch(
                      value: doorstep.sleepMode,
                      onChanged: (b) async {
                        await ref.notifier(doorstepSettingsProvider).setSleepMode(b);
                      },
                    ),
                    onTap: () async {
                      await ref.notifier(doorstepSettingsProvider).setSleepMode(!doorstep.sleepMode);
                    },
                  ),
                DoorstepListTile(
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Discover devices',
                  subtitle: nearbyCount == 0 ? 'No devices found nearby yet' : '$nearbyCount device${nearbyCount == 1 ? '' : 's'} found nearby',
                  trailing: IconButton(
                    tooltip: 'Search again',
                    onPressed: () {
                      ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
                      context.showSnackBar('Searching the Doorstep network…');
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                  onTap: () {
                    ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
                    context.showSnackBar('Searching the Doorstep network…');
                  },
                ),
              ],
            ),

            // ── Your devices ────────────────────────────────────────────────
            DoorstepSection(
              title: 'Your devices',
              subtitle: pairedDevices.isEmpty
                  ? 'Nothing connected yet'
                  : '${pairedDevices.length} connected · ${pairedDevices.where((d) => d.trustLevel == DeviceTrustLevel.temporary).length} temporary',
              action: TextButton.icon(
                onPressed: () => context.showSnackBar('Open the Doorstep tab to connect a device nearby.'),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              children: pairedDevices.isEmpty
                  ? [
                      const DoorstepEmptyState(
                        inline: true,
                        kind: DoorstepEmptyKind.firstUse,
                        icon: Icons.devices_rounded,
                        title: 'No devices connected',
                        message:
                            'Make sure both devices are on the same Wi-Fi (or your phone is on the laptop\'s hotspot), then connect from the Doorstep tab.',
                      ),
                    ]
                  : pairedDevices
                        .map(
                          (device) => _PairedDeviceRow(
                            device: device,
                            onRevoke: () => _confirmRevoke(context, ref, device),
                          ),
                        )
                        .toList(),
            ),

            // ── Where files go ──────────────────────────────────────────────
            DoorstepSection(
              title: 'Where files go',
              subtitle: vm.settings.destination ?? _defaultDestinationLabel(),
              children: [
                if (checkPlatformWithFileSystem())
                  DoorstepListTile(
                    icon: Icons.folder_rounded,
                    title: 'Save received files to',
                    subtitle: vm.settings.destination ?? _defaultDestinationLabel(),
                    trailing: const DoorstepChevron(),
                    onTap: () async {
                      if (vm.settings.destination != null) {
                        await ref.notifier(settingsProvider).setDestination(null);
                        if (defaultTargetPlatform == TargetPlatform.macOS) {
                          await removeExistingDestinationAccess();
                        }
                        return;
                      }

                      final directory = await pickDirectoryPath();
                      if (directory != null) {
                        if (defaultTargetPlatform == TargetPlatform.macOS) {
                          await persistDestinationFolderAccess(directory);
                        }
                        await ref.notifier(settingsProvider).setDestination(directory);
                      }
                    },
                  ),
                if (vm.settings.destination != null)
                  DoorstepListTile(
                    icon: Icons.open_in_new_rounded,
                    title: 'Open destination folder',
                    onTap: () async {
                      await openFolder(folderPath: vm.settings.destination!);
                    },
                  ),
                if (checkPlatformWithGallery())
                  DoorstepListTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Also save images to gallery',
                    subtitle: vm.settings.saveToGallery ? 'On' : 'Off',
                    trailing: Switch(
                      value: vm.settings.saveToGallery,
                      onChanged: (b) async {
                        await ref.notifier(settingsProvider).setSaveToGallery(b);
                      },
                    ),
                    onTap: () async {
                      await ref.notifier(settingsProvider).setSaveToGallery(!vm.settings.saveToGallery);
                    },
                  ),
                DoorstepListTile(
                  icon: Icons.auto_mode_rounded,
                  title: 'Quick save',
                  subtitle: vm.settings.quickSave ? 'Keeping files in the last used folder' : 'Asking where to save each time',
                  trailing: Switch(
                    value: vm.settings.quickSave,
                    onChanged: (b) async {
                      final old = vm.settings.quickSave;
                      await ref.notifier(settingsProvider).setQuickSave(b);
                      if (!old && b && context.mounted) {
                        await QuickSaveNotice.open(context);
                      }
                    },
                  ),
                  onTap: () async {
                    final old = vm.settings.quickSave;
                    await ref.notifier(settingsProvider).setQuickSave(!old);
                    if (!old && context.mounted) {
                      await QuickSaveNotice.open(context);
                    }
                  },
                ),
                DoorstepListTile(
                  icon: Icons.star_rounded,
                  title: 'Quick save from your devices',
                  subtitle: vm.settings.quickSaveFromFavorites ? 'On' : 'Off',
                  trailing: Switch(
                    value: vm.settings.quickSaveFromFavorites,
                    onChanged: (b) async {
                      final old = vm.settings.quickSaveFromFavorites;
                      await ref.notifier(settingsProvider).setQuickSaveFromFavorites(b);
                      if (!old && b && context.mounted) {
                        await QuickSaveFromFavoritesNotice.open(context);
                      }
                    },
                  ),
                  onTap: () async {
                    final old = vm.settings.quickSaveFromFavorites;
                    await ref.notifier(settingsProvider).setQuickSaveFromFavorites(!old);
                    if (!old && context.mounted) {
                      await QuickSaveFromFavoritesNotice.open(context);
                    }
                  },
                ),
                DoorstepListTile(
                  icon: Icons.checklist_rounded,
                  title: 'Finish transfers automatically',
                  subtitle: vm.settings.autoFinish ? 'On' : 'Off',
                  trailing: Switch(
                    value: vm.settings.autoFinish,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setAutoFinish(b);
                    },
                  ),
                  onTap: () async {
                    await ref.notifier(settingsProvider).setAutoFinish(!vm.settings.autoFinish);
                  },
                ),
                DoorstepListTile(
                  icon: Icons.history_rounded,
                  title: 'Keep a transfer history',
                  subtitle: vm.settings.saveToHistory ? 'On' : 'Off',
                  trailing: Switch(
                    value: vm.settings.saveToHistory,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setSaveToHistory(b);
                    },
                  ),
                  onTap: () async {
                    await ref.notifier(settingsProvider).setSaveToHistory(!vm.settings.saveToHistory);
                  },
                ),
              ],
            ),

            // ── Security ────────────────────────────────────────────────────
            DoorstepSection(
              title: 'Security',
              children: [
                DoorstepListTile(
                  icon: Icons.password_rounded,
                  title: 'Require a PIN to send to this device',
                  subtitle: vm.settings.receivePin != null ? 'A PIN is set' : 'Off — trusted devices connect freely',
                  trailing: Switch(
                    value: vm.settings.receivePin != null,
                    onChanged: (b) async {
                      final currentPIN = vm.settings.receivePin;
                      if (currentPIN != null) {
                        await ref.notifier(settingsProvider).setReceivePin(null);
                      } else {
                        final String? newPin = await showDialog<String>(
                          context: context,
                          builder: (_) => const PinDialog(
                            obscureText: false,
                            generateRandom: false,
                          ),
                        );

                        if (newPin != null && newPin.isNotEmpty) {
                          await ref.notifier(settingsProvider).setReceivePin(newPin);
                        }
                      }

                      // The pin is enforced by the Rust server, so it needs a restart.
                      if (ref.read(serverProvider) != null) {
                        await ref.notifier(serverProvider).restartServerFromSettings();
                      }
                    },
                  ),
                  onTap: () async {
                    final currentPIN = vm.settings.receivePin;
                    if (currentPIN != null) {
                      await ref.notifier(settingsProvider).setReceivePin(null);
                    } else {
                      final String? newPin = await showDialog<String>(
                        context: context,
                        builder: (_) => const PinDialog(
                          obscureText: false,
                          generateRandom: false,
                        ),
                      );
                      if (newPin != null && newPin.isNotEmpty) {
                        await ref.notifier(settingsProvider).setReceivePin(newPin);
                      }
                    }
                    if (ref.read(serverProvider) != null) {
                      await ref.notifier(serverProvider).restartServerFromSettings();
                    }
                  },
                ),
                if (vm.advanced)
                  DoorstepListTile(
                    icon: Icons.lock_rounded,
                    title: 'Encrypt transfers (HTTPS)',
                    subtitle: vm.settings.https ? 'On — recommended' : 'Off — traffic is unencrypted',
                    trailing: Switch(
                      value: vm.settings.https,
                      onChanged: (b) async {
                        final old = vm.settings.https;
                        await ref.notifier(settingsProvider).setHttps(b);
                        if (old && !b && context.mounted) {
                          await EncryptionDisabledNotice.open(context);
                        }
                      },
                    ),
                    onTap: () async {
                      final old = vm.settings.https;
                      await ref.notifier(settingsProvider).setHttps(!old);
                      if (old && context.mounted) {
                        await EncryptionDisabledNotice.open(context);
                      }
                    },
                  ),
              ],
            ),

            // ── Appearance ──────────────────────────────────────────────────
            DoorstepSection(
              title: 'Appearance',
              children: [
                DoorstepListTile(
                  icon: Icons.brightness_6_rounded,
                  title: 'Brightness',
                  trailing: CustomDropdownButton<ThemeMode>(
                    value: vm.settings.theme,
                    items: vm.themeModes.map((theme) {
                      return DropdownMenuItem(
                        value: theme,
                        alignment: Alignment.center,
                        child: Text(theme.humanName),
                      );
                    }).toList(),
                    onChanged: (theme) => vm.onChangeTheme(context, theme),
                  ),
                ),
                DoorstepListTile(
                  icon: Icons.palette_rounded,
                  title: 'Colour',
                  trailing: CustomDropdownButton<ColorMode>(
                    value: vm.settings.colorMode,
                    items: vm.colorModes.map((colorMode) {
                      return DropdownMenuItem(
                        value: colorMode,
                        alignment: Alignment.center,
                        child: Text(colorMode.humanName),
                      );
                    }).toList(),
                    onChanged: vm.onChangeColorMode,
                  ),
                ),
                DoorstepListTile(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  trailing: DoorstepTrailingText(vm.settings.locale?.humanName ?? t.settingsTab.general.languageOptions.system),
                  onTap: () => vm.onTapLanguage(context),
                ),
                DoorstepListTile(
                  icon: Icons.animation_rounded,
                  title: 'Animations',
                  subtitle: vm.settings.enableAnimations ? 'On' : 'Off',
                  trailing: Switch(
                    value: vm.settings.enableAnimations,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setEnableAnimations(b);
                    },
                  ),
                  onTap: () async {
                    await ref.notifier(settingsProvider).setEnableAnimations(!vm.settings.enableAnimations);
                  },
                ),
              ],
            ),

            // ── Windows / desktop ───────────────────────────────────────────
            if (checkPlatformIsDesktop())
              DoorstepSection(
                title: 'On this computer',
                subtitle: 'Keep Doorstep ready without opening it',
                children: [
                  DoorstepListTile(
                    icon: Icons.power_settings_new_rounded,
                    title: 'Open Doorstep at login',
                    subtitle: vm.autoStart ? 'On — Doorstep is always ready' : 'Off — start it yourself',
                    trailing: Switch(value: vm.autoStart, onChanged: (_) => vm.onToggleAutoStart(context)),
                    onTap: () => vm.onToggleAutoStart(context),
                  ),
                  if (vm.autoStart)
                    DoorstepListTile(
                      icon: Icons.visibility_off_rounded,
                      title: 'Start minimised',
                      subtitle: vm.autoStartLaunchHidden ? 'On — starts in the tray' : 'Off — window opens on login',
                      trailing: Switch(value: vm.autoStartLaunchHidden, onChanged: (_) => vm.onToggleAutoStartLaunchHidden(context)),
                      onTap: () => vm.onToggleAutoStartLaunchHidden(context),
                    ),
                  if (checkPlatformHasTray())
                    DoorstepListTile(
                      icon: Icons.minimize_rounded,
                      title: 'Keep running when the window closes',
                      subtitle: vm.settings.minimizeToTray ? 'On — stays in the tray' : 'Off — closing quits Doorstep',
                      trailing: Switch(
                        value: vm.settings.minimizeToTray,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setMinimizeToTray(b);
                        },
                      ),
                      onTap: () async {
                        await ref.notifier(settingsProvider).setMinimizeToTray(!vm.settings.minimizeToTray);
                      },
                    ),
                  if (vm.advanced && checkPlatformIsNotWaylandDesktop())
                    DoorstepListTile(
                      icon: Icons.window_rounded,
                      title: 'Remember window position',
                      trailing: Switch(
                        value: vm.settings.saveWindowPlacement,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setSaveWindowPlacement(b);
                        },
                      ),
                      onTap: () async {
                        await ref.notifier(settingsProvider).setSaveWindowPlacement(!vm.settings.saveWindowPlacement);
                      },
                    ),
                  if (vm.advanced && checkPlatform([TargetPlatform.windows]))
                    DoorstepListTile(
                      icon: Icons.menu_open_rounded,
                      title: 'Show “Send with Doorstep” in the right-click menu',
                      trailing: Switch(value: vm.showInContextMenu, onChanged: (_) => vm.onToggleShowInContextMenu(context)),
                      onTap: () => vm.onToggleShowInContextMenu(context),
                    ),
                ],
              ),

            // ── Advanced ────────────────────────────────────────────────────
            if (vm.advanced)
              DoorstepSection(
                title: 'Advanced',
                subtitle: 'Protocol details — change only if you know why',
                children: [
                  DoorstepListTile(
                    icon: Icons.dns_rounded,
                    title: t.settingsTab.network.server,
                    subtitle: vm.serverState == null ? t.general.offline : 'Running on port ${vm.serverState!.port}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: vm.serverState == null ? t.general.start : t.general.restart,
                          onPressed: vm.serverState == null ? () => vm.onTapStartServer(context) : () => vm.onTapRestartServer(context),
                          icon: Icon(vm.serverState == null ? Icons.play_arrow_rounded : Icons.refresh_rounded, size: 20),
                        ),
                        IconButton(
                          tooltip: t.general.stop,
                          onPressed: vm.serverState == null ? null : vm.onTapStopServer,
                          icon: const Icon(Icons.stop_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  DoorstepListTile(
                    icon: Icons.badge_rounded,
                    title: t.settingsTab.network.alias,
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: TextFieldWithActions(
                        name: t.settingsTab.network.alias,
                        controller: vm.aliasController,
                        onChanged: (s) async {
                          await ref.notifier(settingsProvider).setAlias(s);
                        },
                        actions: [
                          Tooltip(
                            message: t.settingsTab.network.generateRandomAlias,
                            child: IconButton(
                              onPressed: () async {
                                final newAlias = generateRandomAlias();
                                vm.aliasController.text = newAlias;
                                await ref.notifier(settingsProvider).setAlias(newAlias);
                              },
                              icon: const Icon(Icons.casino, size: 20),
                            ),
                          ),
                          Tooltip(
                            message: t.settingsTab.network.useSystemName,
                            child: IconButton(
                              onPressed: () async {
                                final String newAlias;
                                if (Platform.isMacOS) {
                                  final result = await Process.run('scutil', ['--get', 'ComputerName']);
                                  newAlias = result.stdout.toString().trim();
                                } else {
                                  newAlias = Platform.localHostname;
                                }
                                vm.aliasController.text = newAlias;
                                await ref.notifier(settingsProvider).setAlias(newAlias);
                              },
                              icon: const Icon(Icons.desktop_windows_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DoorstepListTile(
                    icon: Icons.numbers_rounded,
                    title: t.settingsTab.network.port,
                    subtitle: vm.settings.port != defaultPort
                        ? t.settingsTab.network.portWarning(defaultPort: defaultPort)
                        : 'Default ($defaultPort)',
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: TextFieldTv(
                        name: t.settingsTab.network.port,
                        controller: vm.portController,
                        onChanged: (s) async {
                          final port = int.tryParse(s);
                          if (port != null) {
                            await ref.notifier(settingsProvider).setPort(port);
                          }
                        },
                      ),
                    ),
                  ),
                  DoorstepListTile(
                    icon: Icons.timer_outlined,
                    title: t.settingsTab.network.discoveryTimeout,
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: TextFieldTv(
                        name: t.settingsTab.network.discoveryTimeout,
                        controller: vm.timeoutController,
                        onChanged: (s) async {
                          final timeout = int.tryParse(s);
                          if (timeout != null) {
                            await ref.notifier(settingsProvider).setDiscoveryTimeout(timeout);
                          }
                        },
                      ),
                    ),
                  ),
                  DoorstepListTile(
                    icon: Icons.hub_rounded,
                    title: t.settingsTab.network.multicastGroup,
                    subtitle: vm.settings.multicastGroup != defaultMulticastGroup
                        ? t.settingsTab.network.multicastGroupWarning(defaultMulticast: defaultMulticastGroup)
                        : null,
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: TextFieldTv(
                        name: t.settingsTab.network.multicastGroup,
                        controller: vm.multicastController,
                        onChanged: (s) async {
                          await ref.notifier(settingsProvider).setMulticastGroup(s);
                        },
                      ),
                    ),
                  ),
                  DoorstepListTile(
                    icon: Icons.lan_rounded,
                    title: t.settingsTab.network.network,
                    trailing: DoorstepTrailingText(
                      switch (vm.settings.networkWhitelist != null || vm.settings.networkBlacklist != null) {
                        true => t.settingsTab.network.networkOptions.filtered,
                        false => t.settingsTab.network.networkOptions.all,
                      },
                    ),
                    onTap: () async {
                      await context.push(() => const NetworkInterfacesPage());
                    },
                  ),
                  if (vm.advanced)
                    DoorstepListTile(
                      icon: Icons.devices_other_rounded,
                      title: t.settingsTab.network.deviceType,
                      trailing: CustomDropdownButton<DeviceType>(
                        value: vm.deviceInfo.deviceType,
                        items: DeviceType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            alignment: Alignment.center,
                            child: Icon(type.icon),
                          );
                        }).toList(),
                        onChanged: (type) async {
                          await ref.notifier(settingsProvider).setDeviceType(type);
                        },
                      ),
                    ),
                  DoorstepListTile(
                    icon: Icons.memory_rounded,
                    title: t.settingsTab.network.deviceModel,
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: TextFieldTv(
                        name: t.settingsTab.network.deviceModel,
                        controller: vm.deviceModelController,
                        onChanged: (s) async {
                          await ref.notifier(settingsProvider).setDeviceModel(s);
                        },
                      ),
                    ),
                  ),
                  if (vm.advanced)
                    DoorstepListTile(
                      icon: Icons.share_rounded,
                      title: t.settingsTab.send.shareViaLinkAutoAccept,
                      subtitle: vm.settings.shareViaLinkAutoAccept ? 'On' : 'Off',
                      trailing: Switch(
                        value: vm.settings.shareViaLinkAutoAccept,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(b);
                        },
                      ),
                      onTap: () async {
                        await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(!vm.settings.shareViaLinkAutoAccept);
                      },
                    ),
                  DoorstepListTile(
                    icon: Icons.troubleshoot_rounded,
                    title: 'Discovery troubleshooter',
                    subtitle: 'See which networks and protocols answered',
                    trailing: const DoorstepChevron(),
                    onTap: () async {
                      await context.push(() => const DiscoveryDebugPage());
                    },
                  ),
                ],
              ),

            // ── About ───────────────────────────────────────────────────────
            DoorstepSection(
              title: 'About',
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                DoorstepListTile(
                  icon: Icons.info_outline_rounded,
                  title: t.aboutPage.title,
                  subtitle: 'Version, credits, licences and the changelog',
                  trailing: const DoorstepChevron(),
                  onTap: () async {
                    await context.push(() => const AboutPage());
                  },
                ),
              ],
            ),

            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LabeledCheckbox(
                  label: t.settingsTab.advancedSettings,
                  value: vm.advanced,
                  labelFirst: true,
                  onChanged: (b) async {
                    vm.onTapAdvanced(b == true);
                    await ref.notifier(settingsProvider).setAdvancedSettingsEnabled(b == true);
                  },
                ),
                const SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  String _defaultDestinationLabel() {
    if (checkPlatform([TargetPlatform.android, TargetPlatform.iOS])) {
      return 'Downloads/Doorstep';
    }
    return 'Downloads/Doorstep';
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 2, bottom: 22),
      child: Text(
        'Settings',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1),
      ),
    );
  }
}

/// A connected device row with its trust level and a revoke action.
class _PairedDeviceRow extends StatelessWidget {
  final PairedDevice device;
  final VoidCallback onRevoke;

  const _PairedDeviceRow({required this.device, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final isTemporary = device.trustLevel == DeviceTrustLevel.temporary;
    return DoorstepListTile(
      icon: isTemporary ? Icons.timer_rounded : Icons.verified_user_rounded,
      iconColor: isTemporary ? null : null,
      title: device.alias,
      subtitle: isTemporary ? 'Temporary · forgotten when Doorstep closes' : 'Your device · reconnects automatically',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DoorstepStatusChip(
            label: isTemporary ? 'Session' : 'Trusted',
            tone: isTemporary ? DoorstepStatusTone.warning : DoorstepStatusTone.positive,
            icon: isTemporary ? Icons.timer_rounded : Icons.lock_rounded,
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: Icon(Icons.more_vert_rounded, size: 20, color: DoorstepTheme.textMutedOf(context)),
            onSelected: (value) {
              if (value == 'revoke') onRevoke();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'revoke',
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Disconnect'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Revoking a trusted device is destructive (drops it from every drop zone), so
/// it always asks first.
Future<void> _confirmRevoke(BuildContext context, Ref ref, PairedDevice device) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Disconnect this device?'),
      content: Text(
        '“${device.alias}” will forget this device, and any drop zone pointed at it will stop sending there.\n\nYou can connect again any time from the Doorstep tab.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Disconnect'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  await ref.notifier(doorstepPairingProvider).revokeDevice(device.id);
  if (context.mounted) {
    context.showSnackBar('${device.alias} disconnected.');
  }
}

extension on ThemeMode {
  String get humanName {
    switch (this) {
      case ThemeMode.system:
        return t.settingsTab.general.brightnessOptions.system;
      case ThemeMode.light:
        return t.settingsTab.general.brightnessOptions.light;
      case ThemeMode.dark:
        return t.settingsTab.general.brightnessOptions.dark;
    }
  }
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.doorstep => t.appName,
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
    };
  }
}
