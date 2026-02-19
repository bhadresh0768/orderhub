import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../providers.dart';

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
  Country _selectedCountry = Country.parse('IN');
  bool _usePhoneLogin = !kIsWeb;
  bool _loading = false;
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    final localeCountryCode = ui.PlatformDispatcher.instance.locale.countryCode;
    if (localeCountryCode != null && localeCountryCode.trim().isNotEmpty) {
      try {
        _selectedCountry = Country.parse(localeCountryCode.toUpperCase());
      } catch (_) {
        // Keep default country if locale code is not supported.
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _normalizePhoneNumber(String value) {
    final raw = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00') && raw.length > 2) return '+${raw.substring(2)}';
    if (RegExp(r'^\d+$').hasMatch(raw)) return '+${_selectedCountry.phoneCode}$raw';
    return value.trim();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = _normalizePhoneNumber(_phoneController.text);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        final confirmation = await ref
            .read(authServiceProvider)
            .signInWithPhoneNumberWeb(phone);
        if (!mounted) return;
        setState(() {
          _webConfirmationResult = confirmation;
          _otpSent = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP sent to $phone')));
      } else {
        await ref
            .read(authServiceProvider)
            .verifyPhoneNumber(
              phoneNumber: phone,
              forceResendingToken: _resendToken,
              codeSent: (verificationId, resendToken) {
                if (!mounted) return;
                setState(() {
                  _verificationId = verificationId;
                  _resendToken = resendToken;
                  _otpSent = true;
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('OTP sent to $phone')));
              },
              verificationCompleted: (credential) async {
                await ref
                    .read(authServiceProvider)
                    .signInWithPhoneCredential(credential);
              },
              verificationFailed: (e) {
                if (!mounted) return;
                setState(() => _error = e.message ?? e.code);
              },
              codeAutoRetrievalTimeout: (verificationId) {
                if (!mounted) return;
                setState(() => _verificationId = verificationId);
              },
            );
      }
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        final confirmation = _webConfirmationResult;
        if (confirmation == null) {
          setState(() => _error = 'Please send OTP first.');
          return;
        }
        await confirmation.confirm(_otpController.text.trim());
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) {
          setState(() => _error = 'Please send OTP first.');
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
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  if (kIsWeb)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(value: false, label: Text('Email')),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Mobile OTP'),
                        ),
                      ],
                      selected: {_usePhoneLogin},
                      onSelectionChanged: (selection) {
                        final usePhone = selection.first;
                        setState(() {
                          _usePhoneLogin = usePhone;
                          _error = null;
                          _otpSent = false;
                          _verificationId = null;
                          _webConfirmationResult = null;
                          _otpController.clear();
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  if (!_usePhoneLogin)
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        children: [
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
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your password'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _submitEmailLogin,
                              child: _loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
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
                                        setState(() => _selectedCountry = country);
                                      },
                                    );
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Code',
                                    ),
                                    child: Text(
                                      '${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}',
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
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter mobile number';
                                    }
                                    final normalized = _normalizePhoneNumber(value);
                                    if (!normalized.startsWith('+') ||
                                        normalized.length < 8) {
                                      return 'Enter valid mobile number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_otpSent) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'OTP Code',
                              ),
                              validator: (value) {
                                if (!_otpSent) return null;
                                if (value == null || value.trim().isEmpty) {
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
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading
                                  ? null
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              child: _loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                            ),
                          ),
                          if (_otpSent) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loading ? null : _sendOtp,
                              child: const Text('Resend OTP'),
                            ),
                          ],
                        ],
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
