import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:doorstep_app/config/init.dart';
import 'package:doorstep_app/config/theme.dart';
import 'package:doorstep_app/gen/strings.g.dart';
import 'package:doorstep_app/pages/home_page_controller.dart';
import 'package:doorstep_app/pages/tabs/doorstep_activity_tab.dart';
import 'package:doorstep_app/pages/tabs/doorstep_drop_zone_tab.dart';
import 'package:doorstep_app/pages/tabs/receive_tab.dart';
import 'package:doorstep_app/pages/tabs/send_tab.dart';
import 'package:doorstep_app/pages/tabs/settings_tab.dart';
import 'package:doorstep_app/provider/selection/selected_sending_files_provider.dart';
import 'package:doorstep_app/util/native/cross_file_converters.dart';
import 'package:doorstep_app/widget/responsive_builder.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  // ── Visible Doorstep tabs ────────────────────────────────────────────
  doorstep(Icons.folder_special),
  activity(Icons.history),
  settings(Icons.settings),

  // ── Hidden: used internally by receive/send provider callbacks ───────
  receive(Icons.wifi),
  send(Icons.send),
  ;

  const HomeTab(this.icon);

  final IconData icon;

  /// Only these tabs appear in the nav bar / rail
  static const List<HomeTab> visible = [doorstep, activity, settings];

  String get label {
    switch (this) {
      case HomeTab.doorstep:
        return 'Doorstep';
      case HomeTab.activity:
        return 'Activity';
      case HomeTab.settings:
        return 'Settings';
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);

    // Determine which visible-tab index is selected (for nav highlighting)
    final visibleIndex = HomeTab.visible.indexOf(vm.currentTab).clamp(0, HomeTab.visible.length - 1);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        if (event.files.length == 1 && Directory(event.files.first.path).existsSync()) {
          // user dropped a directory
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(event.files.first.path));
        } else {
          // user dropped one or more files
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: event.files,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          return Scaffold(
            body: Row(
              children: [
                if (!sizingInformation.isMobile)
                  NavigationRail(
                    selectedIndex: visibleIndex,
                    onDestinationSelected: (index) => vm.changeTab(HomeTab.visible[index]),
                    extended: sizingInformation.isDesktop,
                    backgroundColor: Theme.of(context).cardColorWithElevation,
                    leading: sizingInformation.isDesktop
                        ? const Column(
                            children: [
                              SizedBox(height: 20),
                              Text(
                                'Doorstep',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 20),
                            ],
                          )
                        : null,
                    destinations: HomeTab.visible.map((tab) {
                      return NavigationRailDestination(
                        icon: Icon(tab.icon),
                        label: Text(tab.label),
                      );
                    }).toList(),
                  ),
                Expanded(
                  child: SafeArea(
                    left: sizingInformation.isMobile,
                    child: Stack(
                      children: [
                        PageView(
                          controller: vm.controller,
                          physics: const NeverScrollableScrollPhysics(),
                          children: const [
                            DoorstepDropZoneTab(),
                            DoorstepActivityTab(),
                            SettingsTab(),
                            ReceiveTab(), // index 3 — hidden, used by receive_controller
                            SendTab(), // index 4 — hidden, used by send_provider
                          ],
                        ),
                        if (_dragAndDropIndicator)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.file_download, size: 128),
                                const SizedBox(height: 30),
                                Text(t.sendTab.placeItems, style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: sizingInformation.isMobile
                ? NavigationBar(
                    selectedIndex: visibleIndex,
                    onDestinationSelected: (index) => vm.changeTab(HomeTab.visible[index]),
                    destinations: HomeTab.visible.map((tab) {
                      return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
                    }).toList(),
                  )
                : null,
          );
        },
      ),
    );
  }
}
