import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:uuid/uuid.dart';

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/contact_us_message.dart';
import 'package:todo_reminder_alarm/providers.dart';

final _contactUsUiProvider = StateProvider.autoDispose<_ContactUsUiState>(
  (ref) => const _ContactUsUiState(),
);

class _ContactUsUiState {
  const _ContactUsUiState({this.submitting = false});

  final bool submitting;

  _ContactUsUiState copyWith({bool? submitting}) {
    return _ContactUsUiState(
      submitting: submitting ?? this.submitting,
    );
  }
}

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  final _descriptionController = TextEditingController();

  _ContactUsUiState get _ui => ref.read(_contactUsUiProvider);
  void _updateUi(_ContactUsUiState Function(_ContactUsUiState state) update) {
    final notifier = ref.read(_contactUsUiProvider.notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _mobileController = TextEditingController();
    _prefillPhone(widget.user.phoneNumber);
  }

  void _prefillPhone(String? rawPhone) {
    final text = (rawPhone ?? '').trim();
    if (text.isEmpty) return;
    _mobileController.text = text;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ui.submitting) return;
    _updateUi((state) => state.copyWith(submitting: true));
    try {
      final message = ContactUsMessage(
        id: const Uuid().v4(),
        userId: widget.user.id,
        userRole: widget.user.role,
        name: _nameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).createContactUsMessage(message);
      if (!mounted) return;
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact request submitted')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit: $err')));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(submitting: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_contactUsUiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share your issue and our team will contact you.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: '+919876543210',
                        ),
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          if (digits.length < 6) {
                            return 'Enter valid mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Write your issue',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 5) {
                            return 'Please enter more details';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: ui.submitting ? null : _submit,
                          child: Text(
                            ui.submitting
                                ? 'Submitting...'
                                : 'Submit Contact Us',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
