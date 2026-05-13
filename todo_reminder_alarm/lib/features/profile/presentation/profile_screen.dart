import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../providers.dart';
import '../../../app/deep_link_utils.dart';
import '../../../utils/fiscal_year_defaults.dart';
import 'public_business_profile_screen.dart';

part 'profile_upgrade_business_dialog.dart';
part 'profile_business_details_section.dart';

final _profileUiProvider = StateProvider.autoDispose
    .family<_ProfileUiState, String>(
      (ref, _) => _ProfileUiState(businessCountry: Country.parse('IN')),
    );

class _ProfileUiState {
  const _ProfileUiState({
    required this.businessCountry,
    this.didInitUser = false,
    this.didInitBusiness = false,
    this.saving = false,
    this.uploadingUserImage = false,
    this.uploadingBusinessLogo = false,
    this.userPhotoUrl,
    this.businessLogoUrl,
    this.error,
    this.refreshTick = 0,
  });

  final bool didInitUser;
  final bool didInitBusiness;
  final bool saving;
  final bool uploadingUserImage;
  final bool uploadingBusinessLogo;
  final String? userPhotoUrl;
  final String? businessLogoUrl;
  final String? error;
  final Country businessCountry;
  final int refreshTick;

  _ProfileUiState copyWith({
    bool? didInitUser,
    bool? didInitBusiness,
    bool? saving,
    bool? uploadingUserImage,
    bool? uploadingBusinessLogo,
    Object? userPhotoUrl = _profileUnset,
    Object? businessLogoUrl = _profileUnset,
    Object? error = _profileUnset,
    Country? businessCountry,
    int? refreshTick,
  }) {
    return _ProfileUiState(
      didInitUser: didInitUser ?? this.didInitUser,
      didInitBusiness: didInitBusiness ?? this.didInitBusiness,
      saving: saving ?? this.saving,
      uploadingUserImage: uploadingUserImage ?? this.uploadingUserImage,
      uploadingBusinessLogo:
          uploadingBusinessLogo ?? this.uploadingBusinessLogo,
      userPhotoUrl: userPhotoUrl == _profileUnset
          ? this.userPhotoUrl
          : userPhotoUrl as String?,
      businessLogoUrl: businessLogoUrl == _profileUnset
          ? this.businessLogoUrl
          : businessLogoUrl as String?,
      error: error == _profileUnset ? this.error : error as String?,
      businessCountry: businessCountry ?? this.businessCountry,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}

const _profileUnset = Object();

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
  int? _selectedFiscalYearStartMonth;
  static const List<String> _taxLabelOptions = <String>[
    'GST',
    'VAT',
    'JCT',
    'TIN',
    'Tax ID',
  ];
  String _selectedTaxLabel = _taxLabelOptions.first;

  String get _activeUid =>
      ref.read(authStateProvider).value?.uid ?? widget.user.id;

  _ProfileUiState get _ui => ref.read(_profileUiProvider(_activeUid));
  void _updateUi(_ProfileUiState Function(_ProfileUiState state) update) {
    final notifier = ref.read(_profileUiProvider(_activeUid).notifier);
    notifier.state = update(notifier.state);
  }

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
    if (_ui.didInitUser) return;
    _nameController.text = user.name;
    _shopNameController.text = user.shopName ?? '';
    _addressController.text = user.address ?? '';
    _emailController.text = user.email;
    _phoneController.text = user.phoneNumber ?? '';
    _appShareLinkController.text = user.appShareLink ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateUi(
        (state) =>
            state.copyWith(didInitUser: true, userPhotoUrl: user.photoUrl),
      );
    });
  }

  void _initBusiness(BusinessProfile? business) {
    if (_ui.didInitBusiness || business == null) return;
    _businessNameController.text = business.name;
    _businessCategoryController.text = business.category;
    _businessCityController.text = business.city;
    _businessAddressController.text = business.address ?? '';
    _businessGstController.text = business.gstNumber ?? '';
    final existingTaxLabel = (business.taxLabel ?? '').trim();
    _selectedTaxLabel = _taxLabelOptions.contains(existingTaxLabel)
        ? existingTaxLabel
        : _taxLabelOptions.first;
    _businessPhoneController.text = (business.phone ?? '').trim().isNotEmpty
        ? business.phone!
        : (widget.user.phoneNumber ?? '');
    _businessDescriptionController.text = business.description ?? '';
    _businessShareLinkController.text = business.shareLink ?? '';
    _selectedFiscalYearStartMonth = business.resolvedFiscalYearStartMonth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateUi(
        (state) => state.copyWith(
          didInitBusiness: true,
          businessLogoUrl: business.logoUrl,
        ),
      );
    });
  }

  Future<void> _pickAndUploadUserImage() async {
    _updateUi((state) => state.copyWith(error: null, uploadingUserImage: true));
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.image,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        _updateUi(
          (state) => state.copyWith(error: 'Unable to read selected image.'),
        );
        return;
      }
      final url = await ref
          .read(storageServiceProvider)
          .uploadUserProfileImage(
            userId: _activeUid,
            fileName: file.name,
            bytes: file.bytes!,
          );
      await ref.read(firestoreServiceProvider).updateUser(_activeUid, {
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _updateUi((state) => state.copyWith(userPhotoUrl: url));
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(error: 'Profile image upload failed: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(uploadingUserImage: false));
      }
    }
  }

  Future<void> _pickAndUploadBusinessLogo(String businessId) async {
    _updateUi(
      (state) => state.copyWith(error: null, uploadingBusinessLogo: true),
    );
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.image,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        _updateUi(
          (state) => state.copyWith(error: 'Unable to read selected image.'),
        );
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
      _updateUi((state) => state.copyWith(businessLogoUrl: url));
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(error: 'Business logo upload failed: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(uploadingBusinessLogo: false));
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
    _updateUi((state) => state.copyWith(saving: true, error: null));
    try {
      final firestore = ref.read(firestoreServiceProvider);
      final normalizedUserPhone = _phoneController.text.trim();
      final normalizedBusinessPhone = _normalizePhoneNumber(
        _businessPhoneController.text,
        _ui.businessCountry,
      );
      await firestore.updateUser(_activeUid, {
        'name': _nameController.text.trim(),
        'phoneNumber': normalizedUserPhone.isEmpty ? null : normalizedUserPhone,
        'shopName': _shopNameController.text.trim().isEmpty
            ? null
            : _shopNameController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'photoUrl': _ui.userPhotoUrl,
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
          'ownerName': _nameController.text.trim(),
          'address': _businessAddressController.text.trim().isEmpty
              ? null
              : _businessAddressController.text.trim(),
          'gstNumber': _businessGstController.text.trim().isEmpty
              ? null
              : _businessGstController.text.trim().toUpperCase(),
          'taxLabel': _selectedTaxLabel,
          'description': _businessDescriptionController.text.trim().isEmpty
              ? null
              : _businessDescriptionController.text.trim(),
          'phone': normalizedBusinessPhone.isNotEmpty
              ? normalizedBusinessPhone
              : (normalizedUserPhone.isNotEmpty ? normalizedUserPhone : null),
          'ownerPhone': normalizedUserPhone.isNotEmpty
              ? normalizedUserPhone
              : null,
          'fiscalYearStartMonth': _selectedFiscalYearStartMonth ?? 4,
          'shareLink': businessShareLink,
          'logoUrl': _ui.businessLogoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (err) {
      _updateUi((state) => state.copyWith(error: err.toString()));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  Future<void> _requestDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure? This will submit your account deletion request for admin approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    _updateUi((state) => state.copyWith(saving: true, error: null));
    try {
      await ref.read(firestoreServiceProvider).updateUser(_activeUid, {
        'deleteRequestStatus': 'pending',
        'deleteRequestedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete request submitted (Pending)')),
      );
    } catch (err) {
      _updateUi(
        (state) =>
            state.copyWith(error: 'Failed to submit delete request: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  Future<void> _showUpgradeToBusinessOwnerDialog() async {
    final payload = await showModalBottomSheet<_UpgradeBusinessData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => _UpgradeToBusinessOwnerDialog(
        initialShopName: _shopNameController.text.trim(),
        initialAddress: _addressController.text.trim(),
        initialCountry: _ui.businessCountry,
      ),
    );

    if (payload == null || !mounted) return;
    await _upgradeCustomerToBusinessOwner(payload);
  }

  Future<void> _upgradeCustomerToBusinessOwner(
    _UpgradeBusinessData data,
  ) async {
    _updateUi((state) => state.copyWith(saving: true, error: null));
    try {
      final businessId = const Uuid().v4();
      await ref
          .read(firestoreServiceProvider)
          .upgradeCustomerToBusinessOwner(
            userId: _activeUid,
            business: BusinessProfile(
              id: businessId,
              name: data.name,
              category: data.category,
              ownerId: _activeUid,
              city: data.city,
              ownerName: widget.user.name.trim(),
              address: data.address,
              phone: (data.phone ?? '').trim().isNotEmpty
                  ? _normalizePhoneNumber(data.phone!, data.country)
                  : ((widget.user.phoneNumber ?? '').trim().isNotEmpty
                        ? widget.user.phoneNumber!.trim()
                        : null),
              ownerPhone: (widget.user.phoneNumber ?? '').trim().isNotEmpty
                  ? widget.user.phoneNumber!.trim()
                  : null,
              gstNumber: data.gstNumber,
              taxLabel: data.taxLabel,
              description: data.description,
              fiscalYearStartMonth: data.fiscalYearStartMonth,
              shareLink: businessDeepLink(businessId),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role changed to Business Owner')),
      );
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(
          error: 'Failed to switch role to business owner: $err',
        ),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
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
    final currentUid =
        ref.watch(authStateProvider).value?.uid ?? widget.user.id;
    final uiState = ref.watch(_profileUiProvider(currentUid));
    final liveUser =
        ref.watch(userProfileProvider(currentUid)).asData?.value ?? widget.user;
    _initUser(liveUser);
    final isCustomer = liveUser.role == UserRole.customer;
    final businessId = liveUser.businessId;
    final canRequestDelete =
        liveUser.role == UserRole.customer ||
        liveUser.role == UserRole.businessOwner;
    final deletePending = (liveUser.deleteRequestStatus ?? '') == 'pending';
    final businessAsync = businessId == null
        ? null
        : ref.watch(businessByIdProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (uiState.error != null) ...[
                      Text(
                        uiState.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
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
                          backgroundImage:
                              (uiState.userPhotoUrl ?? '').isNotEmpty
                              ? NetworkImage(uiState.userPhotoUrl!)
                              : null,
                          child: (uiState.userPhotoUrl ?? '').isEmpty
                              ? const Icon(Icons.person, size: 36)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: uiState.uploadingUserImage
                              ? null
                              : _pickAndUploadUserImage,
                          icon: uiState.uploadingUserImage
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
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter full name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (isCustomer) ...[
                      TextFormField(
                        controller: _shopNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Business or Shop Name',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter business or shop name'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
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
                      onChanged: (_) => _updateUi(
                        (state) =>
                            state.copyWith(refreshTick: state.refreshTick + 1),
                      ),
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
                          return _buildBusinessDetailsSection(
                            business: business,
                            uiState: uiState,
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, _) => Text('Error loading business: $err'),
                      ),
                    ],
                    if (isCustomer) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: uiState.saving
                              ? null
                              : _showUpgradeToBusinessOwnerDialog,
                          icon: const Icon(Icons.store_mall_directory_outlined),
                          label: const Text('Change Role To Business Owner'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            uiState.saving ||
                                uiState.uploadingUserImage ||
                                uiState.uploadingBusinessLogo
                            ? null
                            : () => _saveProfile(businessId: businessId),
                        child: uiState.saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Profile'),
                      ),
                    ),
                    if (canRequestDelete) ...[
                      const SizedBox(height: 12),
                      if (deletePending)
                        Text(
                          'Delete request status: Pending',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: uiState.saving || deletePending
                              ? null
                              : _requestDeleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            deletePending
                                ? 'Delete Account Requested'
                                : 'Delete Account',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
