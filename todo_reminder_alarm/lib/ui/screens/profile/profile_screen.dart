import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../providers.dart';
import '../../../app/deep_link_utils.dart';
import 'public_business_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _appShareLinkController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _businessCategoryController = TextEditingController();
  final _businessCityController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessGstController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _businessShareLinkController = TextEditingController();

  bool _didInitUser = false;
  bool _didInitBusiness = false;
  bool _saving = false;
  bool _uploadingUserImage = false;
  bool _uploadingBusinessLogo = false;
  String? _userPhotoUrl;
  String? _businessLogoUrl;
  String? _error;
  Country _businessCountry = Country.parse('IN');

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _appShareLinkController.dispose();
    _businessNameController.dispose();
    _businessCategoryController.dispose();
    _businessCityController.dispose();
    _businessAddressController.dispose();
    _businessGstController.dispose();
    _businessPhoneController.dispose();
    _businessDescriptionController.dispose();
    _businessShareLinkController.dispose();
    super.dispose();
  }

  void _initUser(AppUser user) {
    if (_didInitUser) return;
    _didInitUser = true;
    _nameController.text = user.name;
    _shopNameController.text = user.shopName ?? '';
    _addressController.text = user.address ?? '';
    _emailController.text = user.email;
    _phoneController.text = user.phoneNumber ?? '';
    _appShareLinkController.text = user.appShareLink ?? '';
    _userPhotoUrl = user.photoUrl;
  }

  void _initBusiness(BusinessProfile? business) {
    if (_didInitBusiness || business == null) return;
    _didInitBusiness = true;
    _businessNameController.text = business.name;
    _businessCategoryController.text = business.category;
    _businessCityController.text = business.city;
    _businessAddressController.text = business.address ?? '';
    _businessGstController.text = business.gstNumber ?? '';
    _businessPhoneController.text = business.phone ?? '';
    _businessDescriptionController.text = business.description ?? '';
    _businessShareLinkController.text = business.shareLink ?? '';
    _businessLogoUrl = business.logoUrl;
  }

  Future<void> _pickAndUploadUserImage() async {
    setState(() {
      _error = null;
      _uploadingUserImage = true;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.image,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        setState(() => _error = 'Unable to read selected image.');
        return;
      }
      final url = await ref
          .read(storageServiceProvider)
          .uploadUserProfileImage(
            userId: widget.user.id,
            fileName: file.name,
            bytes: file.bytes!,
          );
      await ref.read(firestoreServiceProvider).updateUser(widget.user.id, {
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _userPhotoUrl = url);
    } catch (err) {
      setState(() => _error = 'Profile image upload failed: $err');
    } finally {
      if (mounted) {
        setState(() => _uploadingUserImage = false);
      }
    }
  }

  Future<void> _pickAndUploadBusinessLogo(String businessId) async {
    setState(() {
      _error = null;
      _uploadingBusinessLogo = true;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.image,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        setState(() => _error = 'Unable to read selected image.');
        return;
      }
      final url = await ref
          .read(storageServiceProvider)
          .uploadBusinessLogo(
            businessId: businessId,
            fileName: file.name,
            bytes: file.bytes!,
          );
      await ref.read(firestoreServiceProvider).updateBusiness(businessId, {
        'logoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _businessLogoUrl = url);
    } catch (err) {
      setState(() => _error = 'Business logo upload failed: $err');
    } finally {
      if (mounted) {
        setState(() => _uploadingBusinessLogo = false);
      }
    }
  }

  Future<void> _copyToClipboard(String label, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _saveProfile({required String? businessId}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final firestore = ref.read(firestoreServiceProvider);
      final normalizedBusinessPhone = _normalizePhoneNumber(
        _businessPhoneController.text,
        _businessCountry,
      );
      await firestore.updateUser(widget.user.id, {
        'name': _nameController.text.trim(),
        'shopName': _shopNameController.text.trim().isEmpty
            ? null
            : _shopNameController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'photoUrl': _userPhotoUrl,
        'appShareLink': _appShareLinkController.text.trim().isEmpty
            ? null
            : _appShareLinkController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (businessId != null) {
        final businessShareLink =
            _businessShareLinkController.text.trim().isEmpty
            ? businessDeepLink(businessId)
            : _businessShareLinkController.text.trim();
        await firestore.updateBusiness(businessId, {
          'name': _businessNameController.text.trim(),
          'category': _businessCategoryController.text.trim(),
          'city': _businessCityController.text.trim(),
          'address': _businessAddressController.text.trim().isEmpty
              ? null
              : _businessAddressController.text.trim(),
          'gstNumber': _businessGstController.text.trim().isEmpty
              ? null
              : _businessGstController.text.trim().toUpperCase(),
          'description': _businessDescriptionController.text.trim().isEmpty
              ? null
              : _businessDescriptionController.text.trim(),
          'phone': _businessPhoneController.text.trim().isEmpty
              ? null
              : normalizedBusinessPhone,
          'shareLink': businessShareLink,
          'logoUrl': _businessLogoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _normalizePhoneNumber(String value, Country country) {
    final raw = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('+')) return raw;
    if (RegExp(r'^\d+$').hasMatch(raw)) return '+${country.phoneCode}$raw';
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    _initUser(widget.user);
    final isCustomer = widget.user.role == UserRole.customer;
    final businessId = widget.user.businessId;
    final businessAsync = businessId == null
        ? null
        : ref.watch(businessByIdProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'User Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: (_userPhotoUrl ?? '').isNotEmpty
                            ? NetworkImage(_userPhotoUrl!)
                            : null,
                        child: (_userPhotoUrl ?? '').isEmpty
                            ? const Icon(Icons.person, size: 36)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _uploadingUserImage
                            ? null
                            : _pickAndUploadUserImage,
                        icon: _uploadingUserImage
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: const Text('Upload Profile Picture'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter full name'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  if (isCustomer) ...[
                    TextFormField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(labelText: 'Shop Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter shop name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter address'
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email (read-only)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number (cannot be changed)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _appShareLinkController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'App Share Link',
                      hintText:
                          'https://play.google.com/store/apps/details?id=...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _appShareLinkController.text.trim().isEmpty
                          ? null
                          : () => _copyToClipboard(
                              'App share link',
                              _appShareLinkController.text,
                            ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy App Link'),
                    ),
                  ),
                  if (businessAsync != null) ...[
                    const SizedBox(height: 24),
                    businessAsync.when(
                      data: (business) {
                        _initBusiness(business);
                        if (business == null) {
                          return const Text('Business profile not found.');
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Business Details',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundImage:
                                      (_businessLogoUrl ?? '').isNotEmpty
                                      ? NetworkImage(_businessLogoUrl!)
                                      : null,
                                  child: (_businessLogoUrl ?? '').isEmpty
                                      ? const Icon(Icons.store, size: 36)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: _uploadingBusinessLogo
                                      ? null
                                      : () => _pickAndUploadBusinessLogo(
                                          business.id,
                                        ),
                                  icon: _uploadingBusinessLogo
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload),
                                  label: const Text('Upload Business Logo'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(
                                labelText: 'Business Name',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter business name'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _businessCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter business category'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _businessAddressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Business Address',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _businessCityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter city'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _businessGstController,
                              textCapitalization:
                                  TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText:
                                    'Business Unique No (GST optional)',
                                hintText: 'e.g. 27ABCDE1234F1Z5',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  width: 132,
                                  child: InkWell(
                                    onTap: () {
                                      showCountryPicker(
                                        context: context,
                                        showPhoneCode: true,
                                        onSelect: (country) {
                                          setState(
                                            () => _businessCountry = country,
                                          );
                                        },
                                      );
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Code',
                                      ),
                                      child: Text(
                                        '${_businessCountry.flagEmoji} +${_businessCountry.phoneCode}',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _businessPhoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Business Contact Number',
                                      hintText: '9876543210',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _businessDescriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Business Description',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _businessShareLinkController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Business Share Link',
                                hintText: 'https://your-business-link.com',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _businessShareLinkController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : () => _copyToClipboard(
                                        'Business share link',
                                        _businessShareLinkController.text,
                                      ),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Business Link'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PublicBusinessProfileScreen(
                                        business: BusinessProfile(
                                          id: business.id,
                                          name:
                                              _businessNameController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.name
                                              : _businessNameController.text
                                                    .trim(),
                                          category:
                                              _businessCategoryController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.category
                                              : _businessCategoryController.text
                                                    .trim(),
                                          ownerId: business.ownerId,
                                          city:
                                              _businessCityController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.city
                                              : _businessCityController.text
                                                    .trim(),
                                          address:
                                              _businessAddressController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.address
                                              : _businessAddressController.text
                                                    .trim(),
                                          gstNumber:
                                              _businessGstController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.gstNumber
                                              : _businessGstController.text
                                                    .trim()
                                                    .toUpperCase(),
                                          status: business.status,
                                          description:
                                              _businessDescriptionController
                                                  .text
                                                  .trim()
                                                  .isEmpty
                                              ? business.description
                                              : _businessDescriptionController
                                                    .text
                                                    .trim(),
                                          phone:
                                              _businessPhoneController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.phone
                                              : _businessPhoneController.text
                                                    .trim(),
                                          logoUrl:
                                              (_businessLogoUrl ?? '')
                                                  .trim()
                                                  .isEmpty
                                              ? business.logoUrl
                                              : _businessLogoUrl,
                                          shareLink:
                                              _businessShareLinkController.text
                                                  .trim()
                                                  .isEmpty
                                              ? business.shareLink
                                              : _businessShareLinkController
                                                    .text
                                                    .trim(),
                                          createdAt: business.createdAt,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.remove_red_eye_outlined),
                                label: const Text('View Public Profile'),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => Text('Error loading business: $err'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _saving ||
                              _uploadingUserImage ||
                              _uploadingBusinessLogo
                          ? null
                          : () => _saveProfile(businessId: businessId),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
