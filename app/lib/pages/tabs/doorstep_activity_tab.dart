import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/receive_history_entry.dart';
import 'package:doorstep_app/model/state/doorstep_transfer_state.dart';
import 'package:doorstep_app/provider/doorstep_arrival_provider.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/receive_history_provider.dart';
import 'package:doorstep_app/util/native/open_file.dart';
import 'package:doorstep_app/widget/door_entry_animation.dart';
import 'package:doorstep_app/widget/doorstep_card.dart';
import 'package:doorstep_app/widget/doorstep_header.dart';
import 'package:doorstep_app/widget/file_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

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

    return Scaffold(
      backgroundColor: DoorstepTheme.backgroundOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DoorstepHeader(
                title: 'Activity',
                subtitle: 'Files that walked in the door, and transfers in flight.',
              ),
              const SizedBox(height: 24),

              if (_arrival != null) ...[
                DoorEntryAnimation(
                  key: ValueKey(_arrival!.id),
                  entry: _arrival!,
                  onDone: () => setState(() => _arrival = null),
                ),
                const SizedBox(height: 16),
              ],

              // ── Transfer History (Sent & Received) ─────────────────────
              const _SectionLabel(label: 'TRANSFER HISTORY'),
              const SizedBox(height: 12),
              if (received.isEmpty)
                DoorstepCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 40, color: DoorstepTheme.textMutedOf(context)),
                          const SizedBox(height: 12),
                          Text(
                            'No transfer history yet',
                            style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Files sent and received on this device will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...received
                    .take(12)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReceivedFileCard(entry: entry),
                      ),
                    ),

              const SizedBox(height: 28),

              // ── Transfers in flight ──────────────────────────────────────
              const _SectionLabel(label: 'TRANSFERS IN FLIGHT'),
              const SizedBox(height: 12),
              if (transfers.isEmpty)
                DoorstepCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horizontal_circle_outlined, size: 40, color: DoorstepTheme.textMutedOf(context)),
                          const SizedBox(height: 12),
                          Text(
                            'No active transfers',
                            style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Files dropped into watched folders will appear here automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...transfers.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DoorstepCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _getStatusIcon(item.status),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.sourceDevice} → ${item.targetDevice}',
                                      style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _getStatusBadge(item.status),
                            ],
                          ),
                          if (item.status == DoorstepTransferStatus.transferring) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                value: item.progress,
                                minHeight: 6,
                                backgroundColor: DoorstepTheme.borderOf(context),
                                color: DoorstepTheme.primaryOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(DoorstepTransferStatus status) {
    switch (status) {
      case DoorstepTransferStatus.completed:
        return const Icon(Icons.check_circle_rounded, color: DoorstepTheme.success, size: 24);
      case DoorstepTransferStatus.transferring:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: DoorstepTheme.primaryOf(context)),
        );
      case DoorstepTransferStatus.failed:
        return const Icon(Icons.error_rounded, color: DoorstepTheme.danger, size: 24);
      case DoorstepTransferStatus.pending:
      case DoorstepTransferStatus.retrying:
        return const Icon(Icons.schedule_rounded, color: DoorstepTheme.warning, size: 24);
    }
  }

  Widget _getStatusBadge(DoorstepTransferStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case DoorstepTransferStatus.completed:
        bg = DoorstepTheme.success.withValues(alpha: 0.15);
        text = DoorstepTheme.success;
        label = 'Completed';
        break;
      case DoorstepTransferStatus.transferring:
        bg = DoorstepTheme.primaryOf(context).withValues(alpha: 0.15);
        text = DoorstepTheme.primaryOf(context);
        label = 'Transferring';
        break;
      case DoorstepTransferStatus.failed:
        bg = DoorstepTheme.danger.withValues(alpha: 0.15);
        text = DoorstepTheme.danger;
        label = 'Failed';
        break;
      case DoorstepTransferStatus.pending:
        bg = DoorstepTheme.warning.withValues(alpha: 0.15);
        text = DoorstepTheme.warning;
        label = 'Pending';
        break;
      case DoorstepTransferStatus.retrying:
        bg = DoorstepTheme.warning.withValues(alpha: 0.15);
        text = DoorstepTheme.warning;
        label = 'Retrying';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: DoorstepTheme.textMutedOf(context),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── One transfer file entry ──────────────────────────────────────────────────

class _ReceivedFileCard extends StatelessWidget {
  final ReceiveHistoryEntry entry;
  const _ReceivedFileCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isSent = entry.senderAlias.startsWith('Sent to');

    return DoorstepCard(
      onTap: entry.path != null ? () => openFile(context, entry.fileType, entry.path!) : null,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FilePathThumbnail(path: entry.path, fileType: entry.fileType),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSent
                            ? DoorstepTheme.primaryOf(context).withValues(alpha: 0.12)
                            : DoorstepTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSent ? 'SENT' : 'RECEIVED',
                        style: TextStyle(
                          color: isSent ? DoorstepTheme.primaryOf(context) : const Color(0xFF16A34A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.fileSize.asReadableFileSize}  ·  ${entry.senderAlias}  ·  ${entry.timestampString}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.path != null)
            Icon(Icons.open_in_new_rounded, color: DoorstepTheme.textMutedOf(context).withValues(alpha: 0.6), size: 18),
        ],
      ),
    );
  }
}
