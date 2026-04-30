import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../providers.dart';
import '../../../utils/fiscal_year_defaults.dart';
import 'login_screen.dart';

final _signUpUiProvider = StateProvider.autoDispose<_SignUpUiState>(
  (ref) => _SignUpUiState(selectedCountry: Country.parse('IN')),
);

class _SignUpUiState {
  const _SignUpUiState({
    required this.selectedCountry,
    this.role = UserRole.businessOwner,
    this.loading = false,
    this.error,
    this.profileOnlyMode = false,
    this.fiscalYearStartMonth,
  });

  final Country selectedCountry;
  final UserRole role;
  final bool loading;
  final String? error;
  final bool profileOnlyMode;
  final int? fiscalYearStartMonth;

  _SignUpUiState copyWith({
    Country? selectedCountry,
    UserRole? role,
    bool? loading,
    Object? error = _signUpUnset,
    bool? profileOnlyMode,
    int? fiscalYearStartMonth,
    bool clearFiscalYearStartMonth = false,
  }) {
    return _SignUpUiState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      role: role ?? this.role,
      loading: loading ?? this.loading,
      error: error == _signUpUnset ? this.error : error as String?,
      profileOnlyMode: profileOnlyMode ?? this.profileOnlyMode,
      fiscalYearStartMonth: clearFiscalYearStartMonth
          ? null
          : (fiscalYearStartMonth ?? this.fiscalYearStartMonth),
    );
  }
}

const _signUpUnset = Object();

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  static const routeName = '/signup';

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  static const List<String> _monthLabels = <String>[
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

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessCategoryController = TextEditingController();
  final _businessCityController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessGstController = TextEditingController();
  _SignUpUiState get _ui => ref.read(_signUpUiProvider);
  void _updateUi(_SignUpUiState Function(_SignUpUiState state) update) {
    final notifier = ref.read(_signUpUiProvider.notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    final existingUser = ref.read(firebaseAuthProvider).currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final localeCountryCode =
          ui.PlatformDispatcher.instance.locale.countryCode;
      if (localeCountryCode != null && localeCountryCode.trim().isNotEmpty) {
        try {
          _updateUi(
            (state) => state.copyWith(
              selectedCountry: Country.parse(localeCountryCode.toUpperCase()),
            ),
          );
        } catch (_) {
          // Keep default country if locale code is not supported.
        }
      }
    });
    if (existingUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateUi((state) => state.copyWith(profileOnlyMode: true));
      });
      _nameController.text = existingUser.displayName ?? '';
      _emailController.text = existingUser.email ?? '';
      _mobileController.text = existingUser.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _businessCategoryController.dispose();
    _businessCityController.dispose();
    _businessAddressController.dispose();
    _businessGstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _updateUi((state) => state.copyWith(loading: true, error: null));
    try {
      final auth = ref.read(authServiceProvider);
      final firestore = ref.read(firestoreServiceProvider);
      final existingUser = ref.read(firebaseAuthProvider).currentUser;
      final roleToSave = _ui.role == UserRole.admin
          ? UserRole.customer
          : _ui.role;
      final isCustomer = roleToSave == UserRole.customer;
      UserCredential? credential;
      String uid;
      final email = _emailController.text.trim();
      final normalizedPhone = _normalizePhoneNumber(_mobileController.text);
      String? phoneNumber = normalizedPhone.isEmpty ? null : normalizedPhone;

      if (existingUser == null) {
        credential = await auth.signUp(
          email: email,
          password: _passwordController.text.trim(),
        );
        uid = credential.user!.uid;
        phoneNumber = phoneNumber ?? credential.user!.phoneNumber;
      } else {
        uid = existingUser.uid;
        phoneNumber = existingUser.phoneNumber;
      }

      String? businessId;
      if (roleToSave == UserRole.businessOwner) {
        businessId = const Uuid().v4();
        final business = BusinessProfile(
          id: businessId,
          name: _businessNameController.text.trim(),
          category: _businessCategoryController.text.trim(),
          ownerId: uid,
          city: _businessCityController.text.trim(),
          ownerName: _nameController.text.trim(),
          address: _businessAddressController.text.trim(),
          fiscalYearStartMonth:
              _ui.fiscalYearStartMonth ??
              defaultFiscalYearStartMonthForCountryCode(
                _ui.selectedCountry.countryCode,
              ),
          phone: (phoneNumber ?? '').trim().isEmpty
              ? null
              : phoneNumber!.trim(),
          ownerPhone: (phoneNumber ?? '').trim().isEmpty
              ? null
              : phoneNumber!.trim(),
          gstNumber: _businessGstController.text.trim().isEmpty
              ? null
              : _businessGstController.text.trim().toUpperCase(),
        );
        await firestore.createBusiness(business);
      }

      final userProfile = AppUser(
        id: uid,
        email: email,
        phoneNumber: phoneNumber,
        name: _nameController.text.trim(),
        shopName: isCustomer ? _shopNameController.text.trim() : null,
        address: isCustomer ? _addressController.text.trim() : null,
        role: roleToSave,
        businessId: businessId,
      );
      await firestore.createUserProfile(userProfile);

      if (existingUser == null) {
        await auth.signOut();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingUser == null
                ? 'Account created successfully. Please login.'
                : 'Profile created successfully.',
          ),
        ),
      );
      if (existingUser == null) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
      }
    } catch (err) {
      _updateUi((state) => state.copyWith(error: err.toString()));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(loading: false));
      }
    }
  }

  String _normalizePhoneNumber(String value) {
    final raw = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('+')) return raw;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return '+${_ui.selectedCountry.phoneCode}$raw';
    }
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(_signUpUiProvider);
    final allowedRoles = UserRole.values
        .where((role) => role != UserRole.admin && role != UserRole.deliveryBoy)
        .toList();
    final selectedRole = allowedRoles.contains(uiState.role)
        ? uiState.role
        : UserRole.businessOwner;
    final isBusiness = selectedRole == UserRole.businessOwner;
    final isCustomer = selectedRole == UserRole.customer;
    final defaultFiscalMonth = defaultFiscalYearStartMonthForCountryCode(
      uiState.selectedCountry.countryCode,
    );
    final selectedFiscalMonth =
        uiState.fiscalYearStartMonth ?? defaultFiscalMonth;
    final existingUser = ref.watch(firebaseAuthProvider).currentUser;
    final profileOnlyMode = uiState.profileOnlyMode || existingUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Join OrderHub',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        if (uiState.error != null) ...[
                          Text(
                            uiState.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your name'
                              : null,
                        ),
                        if (profileOnlyMode) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'You are signed in with mobile OTP. Complete your profile to continue.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if ((existingUser?.phoneNumber ?? '').isNotEmpty)
                            TextFormField(
                              initialValue: existingUser?.phoneNumber,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            readOnly: (existingUser?.email ?? '').isNotEmpty,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final email = value.trim();
                              final isValid = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email);
                              return isValid ? null : 'Enter valid email';
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
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
                                            selectedCountry: country,
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
                                      '${uiState.selectedCountry.flagEmoji} +${uiState.selectedCountry.phoneCode}',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Mobile Number (optional)',
                                    hintText: '9876543210',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your email'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            obscureText: true,
                            validator: (value) =>
                                value != null && value.length < 6
                                ? 'Password must be 6+ chars'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<UserRole>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Account Type',
                          ),
                          items: allowedRoles
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(_roleLabel(role)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _updateUi(
                                (state) => state.copyWith(
                                  role: value,
                                  clearFiscalYearStartMonth:
                                      value != UserRole.businessOwner,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'If you have a valid business registration ID, register as Business.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCustomer) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _shopNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Business or Shop Name',
                            ),
                            validator: (value) =>
                                isCustomer &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Enter business or shop name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                            ),
                            validator: (value) =>
                                isCustomer &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Enter address'
                                : null,
                          ),
                        ],
                        if (isBusiness) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _businessNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Business Name',
                            ),
                            validator: (value) =>
                                isBusiness && (value == null || value.isEmpty)
                                ? 'Enter business name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _businessCategoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            validator: (value) =>
                                isBusiness && (value == null || value.isEmpty)
                                ? 'Enter category'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _businessAddressController,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Business Address',
                            ),
                            validator: (value) =>
                                isBusiness &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Enter business address'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _businessCityController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'City',
                            ),
                            validator: (value) =>
                                isBusiness && (value == null || value.isEmpty)
                                ? 'Enter city'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _businessGstController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Business Unique No (GST optional)',
                              hintText: 'e.g. 27ABCDE1234F1Z5',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey<int>(selectedFiscalMonth),
                            initialValue: selectedFiscalMonth,
                            decoration: const InputDecoration(
                              labelText: 'Financial Year Start Month',
                            ),
                            items: List.generate(12, (index) {
                              final month = index + 1;
                              return DropdownMenuItem<int>(
                                value: month,
                                child: Text(_monthLabels[index]),
                              );
                            }),
                            onChanged: (value) {
                              if (value == null) return;
                              _updateUi(
                                (state) => state.copyWith(
                                  fiscalYearStartMonth: value,
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: uiState.loading ? null : _submit,
                            child: uiState.loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed(LoginScreen.routeName);
                          },
                          child: const Text('Already have an account? Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.businessOwner:
        return 'Business';
      case UserRole.admin:
        return 'Admin';
      case UserRole.deliveryBoy:
        return 'Delivery Boy';
    }
  }
}
