import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/providers.dart';

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _fmtDate(DateTime? date) {
  if (date == null) return '-';
  final d = date.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd-$mm-${d.year}';
}

Future<void> showAdminBusinessDialog(
  BuildContext context,
  WidgetRef ref, {
  BusinessProfile? business,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _AdminBusinessDialog(ref: ref, business: business),
  );
}

Future<void> showAdminUserDialog(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _AdminUserDialog(ref: ref, user: user),
  );
}

class _AdminBusinessDialog extends StatefulWidget {
  const _AdminBusinessDialog({required this.ref, this.business});

  final WidgetRef ref;
  final BusinessProfile? business;

  @override
  State<_AdminBusinessDialog> createState() => _AdminBusinessDialogState();
}

class _AdminBusinessDialogState extends State<_AdminBusinessDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _gstController;
  late final TextEditingController _ownerController;
  late final ValueNotifier<BusinessStatus> _status;
  late final ValueNotifier<bool> _subscriptionActive;
  late final ValueNotifier<DateTime?> _subscriptionStartDate;
  late final ValueNotifier<DateTime?> _subscriptionEndDate;

  @override
  void initState() {
    super.initState();
    final business = widget.business;
    _nameController = TextEditingController(text: business?.name ?? '');
    _categoryController = TextEditingController(text: business?.category ?? '');
    _cityController = TextEditingController(text: business?.city ?? '');
    _addressController = TextEditingController(text: business?.address ?? '');
    _phoneController = TextEditingController(text: business?.phone ?? '');
    _gstController = TextEditingController(text: business?.gstNumber ?? '');
    _ownerController = TextEditingController(text: business?.ownerId ?? '');
    _status = ValueNotifier(business?.status ?? BusinessStatus.pending);
    _subscriptionActive = ValueNotifier(business?.subscriptionActive ?? false);
    _subscriptionStartDate = ValueNotifier(business?.subscriptionStartDate);
    _subscriptionEndDate = ValueNotifier(business?.subscriptionEndDate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    _ownerController.dispose();
    _status.dispose();
    _subscriptionActive.dispose();
    _subscriptionStartDate.dispose();
    _subscriptionEndDate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final business = widget.business;
    final nameText = _nameController.text.trim();
    final categoryText = _categoryController.text.trim();
    final cityText = _cityController.text.trim();
    final ownerText = _ownerController.text.trim();
    final addressText = _addressController.text.trim();
    final phoneText = _phoneController.text.trim();
    final gstText = _gstController.text.trim();
    final normalizedSubscriptionEndDate = _subscriptionEndDate.value == null
        ? null
        : DateTime(
            _subscriptionEndDate.value!.year,
            _subscriptionEndDate.value!.month,
            _subscriptionEndDate.value!.day,
            23,
            59,
            59,
          );
    final data = {
      'name': nameText,
      'category': categoryText,
      'city': cityText,
      'address': addressText.isEmpty ? null : addressText,
      'phone': phoneText.isEmpty ? null : phoneText,
      'gstNumber': gstText.isEmpty ? null : gstText,
      'ownerId': ownerText,
      'status': enumToString(_status.value),
      'subscriptionActive': _subscriptionActive.value,
      'subscriptionStartDate': _subscriptionStartDate.value == null
          ? null
          : Timestamp.fromDate(_subscriptionStartDate.value!),
      'subscriptionEndDate': _subscriptionEndDate.value == null
          ? null
          : Timestamp.fromDate(normalizedSubscriptionEndDate!),
    };

    if (business == null) {
      final id = widget.ref
          .read(firestoreProvider)
          .collection('businesses')
          .doc()
          .id;
      await widget.ref
          .read(firestoreServiceProvider)
          .createBusiness(
            BusinessProfile(
              id: id,
              name: nameText,
              category: categoryText,
              ownerId: ownerText,
              city: cityText,
              address: addressText.isEmpty ? null : addressText,
              phone: phoneText.isEmpty ? null : phoneText,
              gstNumber: gstText.isEmpty ? null : gstText,
              status: _status.value,
              subscriptionActive: _subscriptionActive.value,
              subscriptionStartDate: _subscriptionStartDate.value,
              subscriptionEndDate: normalizedSubscriptionEndDate,
              createdAt: DateTime.now(),
            ),
          );
    } else {
      await widget.ref
          .read(firestoreServiceProvider)
          .updateBusiness(business.id, data);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.business == null ? 'Add Business' : 'Edit Business'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Business Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gstController,
              decoration: const InputDecoration(
                labelText: 'Business Unique No',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ownerController,
              decoration: const InputDecoration(labelText: 'Owner UID'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<BusinessStatus>(
              valueListenable: _status,
              builder: (context, status, _) {
                return DropdownButtonFormField<BusinessStatus>(
                  initialValue: status,
                  items: BusinessStatus.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_capitalize(e.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => _status.value = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status'),
                );
              },
            ),
            const Divider(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: _subscriptionActive,
              builder: (context, subscriptionActive, _) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subscription Active'),
                  value: subscriptionActive,
                  onChanged: (v) => _subscriptionActive.value = v,
                );
              },
            ),
            ValueListenableBuilder<DateTime?>(
              valueListenable: _subscriptionStartDate,
              builder: (context, subscriptionStartDate, _) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Subscription Start: ${_fmtDate(subscriptionStartDate)}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: subscriptionStartDate ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked != null && mounted) {
                        _subscriptionStartDate.value = picked;
                      }
                    },
                    child: const Text('Set'),
                  ),
                );
              },
            ),
            ValueListenableBuilder<DateTime?>(
              valueListenable: _subscriptionEndDate,
              builder: (context, subscriptionEndDate, _) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Subscription End: ${_fmtDate(subscriptionEndDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: subscriptionEndDate ?? now,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(now.year + 10),
                          );
                          if (picked != null && mounted) {
                            _subscriptionEndDate.value = picked;
                          }
                        },
                        child: const Text('Set'),
                      ),
                      TextButton(
                        onPressed: () => _subscriptionEndDate.value = null,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog({required this.ref, required this.user});

  final WidgetRef ref;
  final AppUser user;

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _shopController;
  late final ValueNotifier<UserRole> _role;
  late final ValueNotifier<bool> _isActive;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phoneNumber ?? '');
    _addressController = TextEditingController(text: user.address ?? '');
    _shopController = TextEditingController(text: user.shopName ?? '');
    _role = ValueNotifier(user.role);
    _isActive = ValueNotifier(user.isActive);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _shopController.dispose();
    _role.dispose();
    _isActive.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.ref.read(firestoreServiceProvider).updateUser(widget.user.id, {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'shopName': _shopController.text.trim().isEmpty
          ? null
          : _shopController.text.trim(),
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'role': enumToString(_role.value),
      'isActive': _isActive.value,
    });

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shopController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Shop Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<UserRole>(
              valueListenable: _role,
              builder: (context, role, _) {
                return DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  items: UserRole.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (value) => _role.value = value ?? role,
                  decoration: const InputDecoration(labelText: 'Role'),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isActive,
              builder: (context, isActive, _) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => _isActive.value = v,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
