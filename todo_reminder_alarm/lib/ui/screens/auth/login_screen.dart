import 'dart:async';
import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../providers.dart';

final _loginUiProvider = StateProvider.autoDispose<_LoginUiState>(
  (ref) => _LoginUiState(
    selectedCountry: Country.parse('IN'),
    usePhoneLogin: !kIsWeb,
  ),
);

class _LoginUiState {
  const _LoginUiState({
    required this.selectedCountry,
    required this.usePhoneLogin,
    this.loading = false,
    this.otpRequesting = false,
    this.otpSent = false,
    this.resendCooldownSeconds = 0,
    this.verificationId,
    this.resendToken,
    this.webConfirmationResult,
    this.error,
  });

  final Country selectedCountry;
  final bool usePhoneLogin;
  final bool loading;
  final bool otpRequesting;
  final bool otpSent;
  final int resendCooldownSeconds;
  final String? verificationId;
  final int? resendToken;
  final ConfirmationResult? webConfirmationResult;
  final String? error;

  _LoginUiState copyWith({
    Country? selectedCountry,
    bool? usePhoneLogin,
    bool? loading,
    bool? otpRequesting,
    bool? otpSent,
    int? resendCooldownSeconds,
    Object? verificationId = _loginUnset,
    Object? resendToken = _loginUnset,
    Object? webConfirmationResult = _loginUnset,
    Object? error = _loginUnset,
  }) {
    return _LoginUiState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      usePhoneLogin: usePhoneLogin ?? this.usePhoneLogin,
      loading: loading ?? this.loading,
      otpRequesting: otpRequesting ?? this.otpRequesting,
      otpSent: otpSent ?? this.otpSent,
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
      verificationId: verificationId == _loginUnset
          ? this.verificationId
          : verificationId as String?,
      resendToken: resendToken == _loginUnset
          ? this.resendToken
          : resendToken as int?,
      webConfirmationResult: webConfirmationResult == _loginUnset
          ? this.webConfirmationResult
          : webConfirmationResult as ConfirmationResult?,
      error: error == _loginUnset ? this.error : error as String?,
    );
  }
}

const _loginUnset = Object();

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  _LoginUiState get _ui => ref.read(_loginUiProvider);
  void _updateUi(_LoginUiState Function(_LoginUiState state) update) {
    final notifier = ref.read(_loginUiProvider.notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 30]) {
    _resendTimer?.cancel();
    if (!mounted) return;
    _updateUi((state) => state.copyWith(resendCooldownSeconds: seconds));
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _ui.resendCooldownSeconds;
      if (current <= 1) {
        timer.cancel();
        _updateUi((state) => state.copyWith(resendCooldownSeconds: 0));
      } else {
        _updateUi(
          (state) => state.copyWith(resendCooldownSeconds: current - 1),
        );
      }
    });
  }

  Future<void> _submitEmailLogin() async {
    if (!_emailFormKey.currentState!.validate()) return;
    _updateUi((state) => state.copyWith(loading: true, error: null));
    try {
      await ref
          .read(authServiceProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
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
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00') && raw.length > 2) return '+${raw.substring(2)}';
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return '+${_ui.selectedCountry.phoneCode}$raw';
    }
    return value.trim();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = _normalizePhoneNumber(_phoneController.text);
    _updateUi((state) => state.copyWith(otpRequesting: true, error: null));
    try {
      if (kIsWeb) {
        final confirmation = await ref
            .read(authServiceProvider)
            .signInWithPhoneNumberWeb(phone);
        if (!mounted) return;
        _updateUi(
          (state) => state.copyWith(
            webConfirmationResult: confirmation,
            otpRequesting: false,
            otpSent: true,
          ),
        );
        _startResendCooldown();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP sent to $phone')));
      } else {
        await ref
            .read(authServiceProvider)
            .verifyPhoneNumber(
              phoneNumber: phone,
              forceResendingToken: _ui.resendToken,
              codeSent: (verificationId, resendToken) {
                if (!mounted) return;
                _updateUi(
                  (state) => state.copyWith(
                    verificationId: verificationId,
                    resendToken: resendToken,
                    otpRequesting: false,
                    otpSent: true,
                  ),
                );
                _startResendCooldown();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('OTP sent to $phone')));
              },
              verificationCompleted: (credential) async {
                await ref
                    .read(authServiceProvider)
                    .signInWithPhoneCredential(credential);
                if (!mounted) return;
                _updateUi((state) => state.copyWith(otpRequesting: false));
              },
              verificationFailed: (e) {
                if (!mounted) return;
                _updateUi(
                  (state) => state.copyWith(
                    otpRequesting: false,
                    error: e.message ?? e.code,
                  ),
                );
              },
              codeAutoRetrievalTimeout: (verificationId) {
                if (!mounted) return;
                _updateUi(
                  (state) => state.copyWith(verificationId: verificationId),
                );
              },
            );
      }
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(otpRequesting: false, error: err.toString()),
      );
    } finally {
      if (mounted) {
        if (!_ui.otpSent) {
          _updateUi((state) => state.copyWith(otpRequesting: false));
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    _updateUi((state) => state.copyWith(loading: true, error: null));
    try {
      if (kIsWeb) {
        final confirmation = _ui.webConfirmationResult;
        if (confirmation == null) {
          _updateUi((state) => state.copyWith(error: 'Please send OTP first.'));
          return;
        }
        await confirmation.confirm(_otpController.text.trim());
      } else {
        final verificationId = _ui.verificationId;
        if (verificationId == null) {
          _updateUi((state) => state.copyWith(error: 'Please send OTP first.'));
          return;
        }
        await ref
            .read(authServiceProvider)
            .signInWithSmsCode(
              verificationId: verificationId,
              smsCode: _otpController.text.trim(),
            );
      }
    } catch (err) {
      _updateUi((state) => state.copyWith(error: err.toString()));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(loading: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(_loginUiProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/app_logo.png',
                        height: 108,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Welcome Back',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 16),
                              if (uiState.error != null) ...[
                                Text(
                                  uiState.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (kIsWeb)
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment<bool>(
                                      value: false,
                                      label: Text('Email'),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      label: Text('Mobile OTP'),
                                    ),
                                  ],
                                  selected: {uiState.usePhoneLogin},
                                  onSelectionChanged: (selection) {
                                    final usePhone = selection.first;
                                    _otpController.clear();
                                    _updateUi(
                                      (state) => state.copyWith(
                                        usePhoneLogin: usePhone,
                                        error: null,
                                        otpSent: false,
                                        verificationId: null,
                                        webConfirmationResult: null,
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 16),
                              if (!uiState.usePhoneLogin)
                                Form(
                                  key: _emailFormKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: const InputDecoration(
                                          labelText: 'Email',
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
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
                                            value == null || value.isEmpty
                                            ? 'Enter your password'
                                            : null,
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed: uiState.loading
                                              ? null
                                              : _submitEmailLogin,
                                          child: uiState.loading
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('Login'),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Form(
                                  key: _phoneFormKey,
                                  child: Column(
                                    children: [
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
                                                        selectedCountry:
                                                            country,
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                              child: InputDecorator(
                                                decoration:
                                                    const InputDecoration(
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
                                              controller: _phoneController,
                                              keyboardType: TextInputType.phone,
                                              decoration: const InputDecoration(
                                                labelText: 'Mobile Number',
                                                hintText: '9876543210',
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Enter mobile number';
                                                }
                                                final normalized =
                                                    _normalizePhoneNumber(
                                                      value,
                                                    );
                                                if (!normalized.startsWith(
                                                      '+',
                                                    ) ||
                                                    normalized.length < 8) {
                                                  return 'Enter valid mobile number';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (uiState.otpSent) ...[
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _otpController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'OTP Code',
                                          ),
                                          validator: (value) {
                                            if (!uiState.otpSent) return null;
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Enter OTP';
                                            }
                                            if (value.trim().length < 6) {
                                              return 'OTP must be 6 digits';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      if (uiState.otpRequesting) ...[
                                        const LinearProgressIndicator(
                                          minHeight: 3,
                                        ),
                                        const SizedBox(height: 8),
                                        const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('Sending OTP...'),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed:
                                              (uiState.loading ||
                                                  uiState.otpRequesting)
                                              ? null
                                              : (uiState.otpSent
                                                    ? _verifyOtp
                                                    : _sendOtp),
                                          child: uiState.loading
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : uiState.otpRequesting
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text(
                                                  uiState.otpSent
                                                      ? 'Verify OTP'
                                                      : 'Send OTP',
                                                ),
                                        ),
                                      ),
                                      if (uiState.otpSent) ...[
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed:
                                              (uiState.loading ||
                                                  uiState.otpRequesting ||
                                                  uiState.resendCooldownSeconds >
                                                      0)
                                              ? null
                                              : _sendOtp,
                                          child: const Text('Resend OTP'),
                                        ),
                                        if (uiState.resendCooldownSeconds > 0)
                                          Text(
                                            'Resend in ${uiState.resendCooldownSeconds}s',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
