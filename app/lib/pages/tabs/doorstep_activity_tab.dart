import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/receive_history_entry.dart';
import 'package:doorstep_app/model/state/doorstep_transfer_state.dart';
import 'package:doorstep_app/provider/doorstep_arrival_provider.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/receive_history_provider.dart';
import 'package:doorstep_app/util/native/open_file.dart';
import 'package:doorstep_app/util/native/open_folder.dart';
import 'package:doorstep_app/util/ui/snackbar.dart';
import 'package:doorstep_app/widget/door_entry_animation.dart';
import 'package:doorstep_app/widget/doorstep_empty_state.dart';
import 'package:doorstep_app/widget/doorstep_header.dart';
import 'package:doorstep_app/widget/doorstep_section.dart';
import 'package:doorstep_app/widget/doorstep_status_chip.dart';
import 'package:doorstep_app/widget/file_thumbnail.dart';
import 'package:doorstep_isolates/util/file_size_helper.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Doorstep activity.
///
/// A day-grouped timeline of everything that moved, plus whatever is moving
/// right now. Empty states always explain what will appear here and offer the
/// one action that changes that.
class DoorstepActivityTab extends StatefulWidget {
  const DoorstepActivityTab({super.key});

  @override
  State<DoorstepActivityTab> createState() => _DoorstepActivityTabState();
}

class _DoorstepActivityTabState extends State<DoorstepActivityTab> with Refena {
  ReceiveHistoryEntry? _arrival;

  void _trackArrival(List<ReceiveHistoryEntry> received) {
    if (received.isEmpty) return;
    final head = received.first;
    final lastAnimated = ref.read(doorstepArrivalProvider);
    if (head.id == lastAnimated) return;

    ref.notifier(doorstepArrivalProvider).markAnimated(head.id);
    final age = DateTime.now().difference(head.timestamp);
    if (age.inSeconds < 60 || _arrival != null) {
      _arrival = head;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfers = context.watch(doorstepTransferProvider);
    final received = context.watch(receiveHistoryProvider);
    _trackArrival(received);

    // Day-grouped, newest first. The provider already returns newest first, so
    // a single ordered pass keeps the groups in order.
    final grouped = <String, List<ReceiveHistoryEntry>>{};
    for (final entry in received) {
      grouped.putIfAbsent(_dayLabel(entry.timestamp), () => []).add(entry);
    }

    return Scaffold(
      backgroundColor: DoorstepTheme.backgroundOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DoorstepHeader(
                title: 'Activity',
                subtitle: received.isEmpty
                    ? 'Files you send and receive will show up here.'
                    : '${received.length} transfer${received.length == 1 ? '' : 's'} so far',
                trailing: received.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear history',
                        icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                        onPressed: () => _confirmClear(context),
                      ),
              ),
              const SizedBox(height: 20),

              if (_arrival != null) ...[
                DoorEntryAnimation(
                  key: ValueKey(_arrival!.id),
                  entry: _arrival!,
                  onDone: () => setState(() => _arrival = null),
                ),
                const SizedBox(height: 18),
              ],

              // ── In flight ────────────────────────────────────────────────
              if (transfers.isNotEmpty)
                DoorstepSection(
                  title: 'Happening now',
                  subtitle: '${transfers.length} transfer${transfers.length == 1 ? '' : 's'} in progress',
                  children: transfers.map((item) => _InFlightRow(item: item)).toList(),
                ),

              // ── History ──────────────────────────────────────────────────
              if (received.isEmpty)
                DoorstepSection(
                  title: 'History',
                  children: [
                    DoorstepEmptyState(
                      inline: true,
                      kind: DoorstepEmptyKind.noData,
                      icon: Icons.inbox_rounded,
                      title: 'Nothing here yet',
                      message: transfers.isEmpty
                          ? 'Connect a device and send a file — or add a drop zone on your computer — and it will appear here.'
                          : 'Your finished transfers will be listed here.',
                    ),
                  ],
                )
              else
                ...grouped.entries.map(
                  (group) => DoorstepSection(
                    title: group.key,
                    subtitle: '${group.value.length} item${group.value.length == 1 ? '' : 's'}',
                    children: group.value.map((entry) => _HistoryRow(entry: entry)).toList(),
                  ),
                ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  static String _dayLabel(DateTime timestamp) {
    final now = DateTime.now();
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear transfer history?'),
        content: const Text('This only clears the list. Your files stay exactly where they are.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.ref.redux(receiveHistoryProvider).dispatchAsync(RemoveAllHistoryEntriesAction());
    if (context.mounted) context.showSnackBar('History cleared.');
  }
}

// ── In-flight transfer row ────────────────────────────────────────────────────

class _InFlightRow extends StatelessWidget {
  final DoorstepTransferState item;

  const _InFlightRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final progress = item.progress;
    final transferring = status == DoorstepTransferStatus.transferring;

    final (label, tone) = switch (status) {
      DoorstepTransferStatus.completed => ('Done', DoorstepStatusTone.positive),
      DoorstepTransferStatus.transferring => ('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%', DoorstepStatusTone.neutral),
      DoorstepTransferStatus.failed => ('Failed', DoorstepStatusTone.negative),
      DoorstepTransferStatus.pending => ('Waiting', DoorstepStatusTone.warning),
      DoorstepTransferStatus.retrying => ('Retrying', DoorstepStatusTone.warning),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.sourceDevice} → ${item.targetDevice}',
                      style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DoorstepStatusChip(label: label, tone: tone),
            ],
          ),
          if (transferring) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: DoorstepTheme.borderOf(context),
                color: DoorstepTheme.primaryOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── History row ───────────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final ReceiveHistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isSent = entry.senderAlias.startsWith('Sent to');
    final path = entry.path;

    return InkWell(
      onTap: path == null ? null : () => openFile(context, entry.fileType, path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 38,
                height: 38,
                child: FilePathThumbnail(path: path, fileType: entry.fileType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.fileSize.asReadableFileSize} · ${isSent ? 'Sent' : 'Received'} · ${entry.timestampString}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (path != null)
              IconButton(
                tooltip: 'Show in folder',
                onPressed: () {
                  final separator = path.contains('\\') ? '\\' : '/';
                  final folder = path.substring(0, path.lastIndexOf(separator));
                  openFolder(folderPath: folder, fileName: entry.fileName); // ignore: discarded_futures
                },
                icon: Icon(Icons.folder_open_rounded, size: 19, color: DoorstepTheme.textMutedOf(context)),
              ),
          ],
        ),
      ),
    );
  }
}
