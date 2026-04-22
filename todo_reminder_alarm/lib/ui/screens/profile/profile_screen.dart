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

class _UpgradeBusinessData {
  const _UpgradeBusinessData({
    required this.name,
    required this.category,
    required this.city,
    required this.country,
    required this.fiscalYearStartMonth,
    this.address,
    this.phone,
    this.gstNumber,
    this.description,
  });

  final String name;
  final String category;
  final String city;
  final Country country;
  final int fiscalYearStartMonth;
  final String? address;
  final String? phone;
  final String? gstNumber;
  final String? description;
}

const List<String> _monthLabels = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _UpgradeToBusinessOwnerDialog extends StatefulWidget {
  const _UpgradeToBusinessOwnerDialog({
    required this.initialShopName,
    required this.initialAddress,
    required this.initialCountry,
  });

  final String initialShopName;
  final String initialAddress;
  final Country initialCountry;

  @override
  State<_UpgradeToBusinessOwnerDialog> createState() =>
      _UpgradeToBusinessOwnerDialogState();
}

class _UpgradeToBusinessOwnerDialogState
    extends State<_UpgradeToBusinessOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  final _categoryController = TextEditingController();
  final _cityController = TextEditingController();
  late final TextEditingController _addressController;
  final _gstController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final ValueNotifier<Country> _selectedCountry;
  late final ValueNotifier<int> _fiscalYearStartMonth;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(
      text: widget.initialShopName,
    );
    _addressController = TextEditingController(text: widget.initialAddress);
    _selectedCountry = ValueNotifier<Country>(widget.initialCountry);
    _fiscalYearStartMonth = ValueNotifier<int>(
      defaultFiscalYearStartMonthForCountryCode(
        widget.initialCountry.countryCode,
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _selectedCountry.dispose();
    _fiscalYearStartMonth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Switch to Business Owner',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'After switching, your account will open Business Owner screens by default. This change applies immediately.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _businessNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter business name'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter category'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter city'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Business Address',
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
                              _selectedCountry.value = country;
                              _fiscalYearStartMonth.value =
                                  defaultFiscalYearStartMonthForCountryCode(
                                    country.countryCode,
                                  );
                            },
                          );
                        },
                        child: ValueListenableBuilder<Country>(
                          valueListenable: _selectedCountry,
                          builder: (context, selectedCountry, _) => InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Code',
                            ),
                            child: Text(
                              '${selectedCountry.flagEmoji} +${selectedCountry.phoneCode}',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
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
                  controller: _gstController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Business Unique No (GST optional)',
                    hintText: 'e.g. 27ABCDE1234F1Z5',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Business Description',
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<int>(
                  valueListenable: _fiscalYearStartMonth,
                  builder: (context, fiscalYearStartMonth, _) {
                    return DropdownButtonFormField<int>(
                      initialValue: fiscalYearStartMonth,
                      decoration: const InputDecoration(
                        labelText: 'Financial Year Start Month',
                        helperText: 'Used for future order number reset',
                      ),
                      items: List.generate(12, (index) {
                        final month = index + 1;
                        return DropdownMenuItem<int>(
                          value: month,
                          child: Text(_monthLabels[index]),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          _fiscalYearStartMonth.value = value;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(
                            _UpgradeBusinessData(
                              name: _businessNameController.text.trim(),
                              category: _categoryController.text.trim(),
                              city: _cityController.text.trim(),
                              country: _selectedCountry.value,
                              fiscalYearStartMonth: _fiscalYearStartMonth.value,
                              address: _addressController.text.trim().isEmpty
                                  ? null
                                  : _addressController.text.trim(),
                              phone: _phoneController.text.trim().isEmpty
                                  ? null
                                  : _phoneController.text.trim(),
                              gstNumber: _gstController.text.trim().isEmpty
                                  ? null
                                  : _gstController.text.trim().toUpperCase(),
                              description:
                                  _descriptionController.text.trim().isEmpty
                                  ? null
                                  : _descriptionController.text.trim(),
                            ),
                          );
                        },
                        child: const Text('Switch Role'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final currentUid = ref.watch(authStateProvider).value?.uid ?? widget.user.id;
    final uiState = ref.watch(_profileUiProvider(currentUid));
    final liveUser =
        ref.watch(userProfileProvider(currentUid)).asData?.value ??
        widget.user;
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
                                        (uiState.businessLogoUrl ?? '')
                                            .isNotEmpty
                                        ? NetworkImage(uiState.businessLogoUrl!)
                                        : null,
                                    child:
                                        (uiState.businessLogoUrl ?? '').isEmpty
                                        ? const Icon(Icons.store, size: 36)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.icon(
                                    onPressed: uiState.uploadingBusinessLogo
                                        ? null
                                        : () => _pickAndUploadBusinessLogo(
                                            business.id,
                                          ),
                                    icon: uiState.uploadingBusinessLogo
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
                                textCapitalization: TextCapitalization.words,
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
                                textCapitalization: TextCapitalization.words,
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
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Business Address',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _businessCityController,
                                textCapitalization: TextCapitalization.words,
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
                                            _updateUi(
                                              (state) => state.copyWith(
                                                businessCountry: country,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Code',
                                        ),
                                        child: Text(
                                          '${uiState.businessCountry.flagEmoji} +${uiState.businessCountry.phoneCode}',
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
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Business Description',
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int>(
                                initialValue:
                                    _selectedFiscalYearStartMonth ?? 4,
                                decoration: const InputDecoration(
                                  labelText: 'Financial Year Start Month',
                                  helperText:
                                      'Used for future order number reset',
                                ),
                                items: List.generate(12, (index) {
                                  final month = index + 1;
                                  return DropdownMenuItem<int>(
                                    value: month,
                                    child: Text(_monthLabels[index]),
                                  );
                                }),
                                onChanged: (value) {
                                  _selectedFiscalYearStartMonth = value ?? 4;
                                  _updateUi(
                                    (state) => state.copyWith(
                                      refreshTick: state.refreshTick + 1,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _businessShareLinkController,
                                onChanged: (_) => _updateUi(
                                  (state) => state.copyWith(
                                    refreshTick: state.refreshTick + 1,
                                  ),
                                ),
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
                                                : _businessCategoryController
                                                      .text
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
                                                : _businessAddressController
                                                      .text
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
                                            ownerPhone:
                                                _phoneController.text
                                                    .trim()
                                                    .isEmpty
                                                ? business.ownerPhone
                                                : _phoneController.text.trim(),
                                            fiscalYearStartMonth:
                                                _selectedFiscalYearStartMonth ??
                                                business
                                                    .resolvedFiscalYearStartMonth,
                                            logoUrl:
                                                (uiState.businessLogoUrl ?? '')
                                                    .trim()
                                                    .isEmpty
                                                ? business.logoUrl
                                                : uiState.businessLogoUrl,
                                            shareLink:
                                                _businessShareLinkController
                                                    .text
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
                                  icon: const Icon(
                                    Icons.remove_red_eye_outlined,
                                  ),
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
