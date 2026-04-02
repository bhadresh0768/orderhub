import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import '../../../models/support_ticket.dart';

final _supportTicketUiProvider = StateProvider.autoDispose
    .family<_SupportTicketUiState, String>(
      (ref, _) => const _SupportTicketUiState(),
    );

class _SupportTicketUiState {
  const _SupportTicketUiState({
    this.issueType = SupportIssueType.other,
    this.priority = SupportPriority.medium,
    this.attachments = const [],
    this.submitting = false,
    this.uploading = false,
    this.error,
  });

  final SupportIssueType issueType;
  final SupportPriority priority;
  final List<OrderAttachment> attachments;
  final bool submitting;
  final bool uploading;
  final String? error;

  _SupportTicketUiState copyWith({
    SupportIssueType? issueType,
    SupportPriority? priority,
    List<OrderAttachment>? attachments,
    bool? submitting,
    bool? uploading,
    Object? error = _supportUnset,
  }) {
    return _SupportTicketUiState(
      issueType: issueType ?? this.issueType,
      priority: priority ?? this.priority,
      attachments: attachments ?? this.attachments,
      submitting: submitting ?? this.submitting,
      uploading: uploading ?? this.uploading,
      error: error == _supportUnset ? this.error : error as String?,
    );
  }
}

const _supportUnset = Object();

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdController = TextEditingController();
  final _descriptionController = TextEditingController();

  String get _uiKey => widget.user.id;
  _SupportTicketUiState get _ui => ref.read(_supportTicketUiProvider(_uiKey));

  void _updateUi(_SupportTicketUiState Function(_SupportTicketUiState) update) {
    final notifier = ref.read(_supportTicketUiProvider(_uiKey).notifier);
    notifier.state = update(notifier.state);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    _updateUi((state) => state.copyWith(uploading: true, error: null));
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
        type: FileType.image,
      );
      if (picked == null || picked.files.isEmpty) return;
      final ticketId = const Uuid().v4();
      final uploaded = <OrderAttachment>[];
      for (final file in picked.files) {
        if (file.bytes == null) continue;
        final attachment = await ref
            .read(storageServiceProvider)
            .uploadSupportTicketAttachment(
              userId: widget.user.id,
              ticketId: ticketId,
              fileName: file.name,
              bytes: file.bytes!,
            );
        uploaded.add(attachment);
      }
      _updateUi((state) {
        return state.copyWith(attachments: [...state.attachments, ...uploaded]);
      });
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(error: 'Attachment upload failed: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(uploading: false));
      }
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ui.submitting) return;
    _updateUi((state) => state.copyWith(submitting: true, error: null));
    try {
      final ticket = SupportTicket(
        id: const Uuid().v4(),
        userId: widget.user.id,
        userName: widget.user.name.isEmpty ? 'Unknown' : widget.user.name,
        userRole: widget.user.role,
        issueType: _ui.issueType,
        priority: _ui.priority,
        status: SupportTicketStatus.open,
        description: _descriptionController.text.trim(),
        orderId: _orderIdController.text.trim().isEmpty
            ? null
            : _orderIdController.text.trim(),
        attachments: _ui.attachments,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).createSupportTicket(ticket);
      _orderIdController.clear();
      _descriptionController.clear();
      _updateUi(
        (state) => state.copyWith(
          attachments: const [],
          issueType: SupportIssueType.other,
          priority: SupportPriority.medium,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Support ticket submitted')));
    } catch (err) {
      _updateUi((state) => state.copyWith(error: 'Submit failed: $err'));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(submitting: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_supportTicketUiProvider(_uiKey));
    final ticketsAsync = ref.watch(
      supportTicketsForUserProvider(widget.user.id),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Ticket',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<SupportIssueType>(
                        initialValue: ui.issueType,
                        decoration: const InputDecoration(
                          labelText: 'Issue Type',
                        ),
                        items: SupportIssueType.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_capitalize(e.name)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateUi(
                            (state) => state.copyWith(issueType: value),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<SupportPriority>(
                        initialValue: ui.priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: SupportPriority.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_capitalize(e.name)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateUi((state) => state.copyWith(priority: value));
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _orderIdController,
                        decoration: const InputDecoration(
                          labelText: 'Order ID / Order Number (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe the issue clearly',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ui.attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final attachment = entry.value;
                          return Chip(
                            label: Text(
                              attachment.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => _updateUi((state) {
                              final updated = List<OrderAttachment>.from(
                                state.attachments,
                              );
                              updated.removeAt(index);
                              return state.copyWith(attachments: updated);
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: ui.uploading ? null : _pickAttachments,
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              ui.uploading ? 'Uploading...' : 'Add Attachment',
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (ui.attachments.isNotEmpty)
                            Text('Files: ${ui.attachments.length}'),
                        ],
                      ),
                      if (ui.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          ui.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: ui.submitting ? null : _submitTicket,
                          child: Text(
                            ui.submitting ? 'Submitting...' : 'Submit Ticket',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('My Tickets', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ticketsAsync.when(
              data: (tickets) {
                if (tickets.isEmpty) {
                  return const Text('No support tickets yet.');
                }
                return Column(
                  children: tickets.map((ticket) {
                    final created =
                        ticket.createdAt
                            ?.toLocal()
                            .toString()
                            .split('.')
                            .first ??
                        '-';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          '${_capitalize(ticket.issueType.name)} • ${_capitalize(ticket.status.name)}',
                        ),
                        subtitle: Text(
                          'Priority: ${_capitalize(ticket.priority.name)}'
                          '${ticket.orderId == null ? '' : ' | Order: ${ticket.orderId}'}\n'
                          '$created\n'
                          '${ticket.description}'
                          '${(ticket.adminNote ?? '').trim().isEmpty ? '' : '\nAdmin Note: ${ticket.adminNote!.trim()}'}',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
              error: (err, _) => Text('Error loading tickets: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
