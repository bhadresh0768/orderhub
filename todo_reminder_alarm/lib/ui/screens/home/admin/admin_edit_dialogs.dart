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
  final name = TextEditingController(text: business?.name ?? '');
  final category = TextEditingController(text: business?.category ?? '');
  final city = TextEditingController(text: business?.city ?? '');
  final address = TextEditingController(text: business?.address ?? '');
  final phone = TextEditingController(text: business?.phone ?? '');
  final gst = TextEditingController(text: business?.gstNumber ?? '');
  final owner = TextEditingController(text: business?.ownerId ?? '');
  var status = business?.status ?? BusinessStatus.pending;
  var subscriptionActive = business?.subscriptionActive ?? false;
  DateTime? subscriptionStartDate = business?.subscriptionStartDate;
  DateTime? subscriptionEndDate = business?.subscriptionEndDate;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(business == null ? 'Add Business' : 'Edit Business'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Business Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gst,
                decoration: const InputDecoration(
                  labelText: 'Business Unique No',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: owner,
                decoration: const InputDecoration(labelText: 'Owner UID'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<BusinessStatus>(
                initialValue: status,
                items: BusinessStatus.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(_capitalize(e.name)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => status = v ?? status),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Subscription Active'),
                value: subscriptionActive,
                onChanged: (v) => setLocal(() => subscriptionActive = v),
              ),
              ListTile(
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
                    if (picked != null) {
                      setLocal(() => subscriptionStartDate = picked);
                    }
                  },
                  child: const Text('Set'),
                ),
              ),
              ListTile(
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
                        if (picked != null) {
                          setLocal(() => subscriptionEndDate = picked);
                        }
                      },
                      child: const Text('Set'),
                    ),
                    TextButton(
                      onPressed: () => setLocal(() => subscriptionEndDate = null),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final nameText = name.text.trim();
              final categoryText = category.text.trim();
              final cityText = city.text.trim();
              final ownerText = owner.text.trim();
              final addressText = address.text.trim();
              final phoneText = phone.text.trim();
              final gstText = gst.text.trim();
              final normalizedSubscriptionEndDate = subscriptionEndDate == null
                  ? null
                  : DateTime(
                      subscriptionEndDate!.year,
                      subscriptionEndDate!.month,
                      subscriptionEndDate!.day,
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
                'status': enumToString(status),
                'subscriptionActive': subscriptionActive,
                'subscriptionStartDate': subscriptionStartDate == null
                    ? null
                    : Timestamp.fromDate(subscriptionStartDate!),
                'subscriptionEndDate': subscriptionEndDate == null
                    ? null
                    : Timestamp.fromDate(
                        DateTime(
                          subscriptionEndDate!.year,
                          subscriptionEndDate!.month,
                          subscriptionEndDate!.day,
                          23,
                          59,
                          59,
                        ),
                      ),
              };
              if (business == null) {
                final id = ref
                    .read(firestoreProvider)
                    .collection('businesses')
                    .doc()
                    .id;
                await ref.read(firestoreServiceProvider).createBusiness(
                  BusinessProfile(
                    id: id,
                    name: nameText,
                    category: categoryText,
                    ownerId: ownerText,
                    city: cityText,
                    address: addressText.isEmpty ? null : addressText,
                    phone: phoneText.isEmpty ? null : phoneText,
                    gstNumber: gstText.isEmpty ? null : gstText,
                    status: status,
                    subscriptionActive: subscriptionActive,
                    subscriptionStartDate: subscriptionStartDate,
                    subscriptionEndDate: normalizedSubscriptionEndDate,
                    createdAt: DateTime.now(),
                  ),
                );
              } else {
                await ref
                    .read(firestoreServiceProvider)
                    .updateBusiness(business.id, data);
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  name.dispose();
  category.dispose();
  city.dispose();
  address.dispose();
  phone.dispose();
  gst.dispose();
  owner.dispose();
}

Future<void> showAdminUserDialog(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  final name = TextEditingController(text: user.name);
  final email = TextEditingController(text: user.email);
  final phone = TextEditingController(text: user.phoneNumber ?? '');
  final address = TextEditingController(text: user.address ?? '');
  final shop = TextEditingController(text: user.shopName ?? '');
  var role = user.role;
  var isActive = user.isActive;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: shop,
                decoration: const InputDecoration(labelText: 'Shop Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                items: UserRole.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (value) => setLocal(() => role = value ?? role),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (v) => setLocal(() => isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).updateUser(user.id, {
                'name': name.text.trim(),
                'email': email.text.trim(),
                'phoneNumber': phone.text.trim(),
                'shopName': shop.text.trim().isEmpty ? null : shop.text.trim(),
                'address': address.text.trim().isEmpty
                    ? null
                    : address.text.trim(),
                'role': enumToString(role),
                'isActive': isActive,
              });
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  name.dispose();
  email.dispose();
  phone.dispose();
  address.dispose();
  shop.dispose();
}
