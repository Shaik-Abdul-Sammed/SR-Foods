import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gap/gap.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';

class CustomerLoginScreen extends ConsumerStatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  ConsumerState<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends ConsumerState<CustomerLoginScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerCustomer() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    if (mobile.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != confirmPin) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _storage.write(key: 'owner_name', value: name);
      await _storage.write(key: 'mobile_number', value: mobile);
      await _storage.write(key: 'app_pin', value: pin);
      
      // Simulate network delay for animation effect
      await Future<void>.delayed(const Duration(milliseconds: 800));
      
      if (mounted) {
        context.go(AppRoutes.customerHome);
      }
    } catch (e) {
      setState(() => _error = 'Error saving registration data');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Setup',
                style: AppTextStyles.displaySmall.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ).animate().fade(delay: 100.ms).slideX(begin: -0.1, end: 0),
              
              const Gap(8),
              
              Text(
                'Create your profile to start ordering.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ).animate().fade(delay: 200.ms).slideX(begin: -0.1, end: 0),
              
              const Gap(40),
              
              _AnimatedInputField(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
                delay: 300,
              ),
              const Gap(20),
              
              _AnimatedInputField(
                controller: _mobileCtrl,
                label: 'Mobile Number',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                delay: 400,
              ),
              const Gap(20),
              
              _AnimatedInputField(
                controller: _pinCtrl,
                label: 'Create 4-digit PIN',
                icon: Icons.lock_outline_rounded,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                delay: 500,
              ),
              const Gap(20),
              
              _AnimatedInputField(
                controller: _confirmPinCtrl,
                label: 'Confirm PIN',
                icon: Icons.lock_rounded,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                delay: 600,
              ),
              
              if (_error != null) ...[
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade().slideY(begin: -0.1, end: 0),
              ],
              
              const Gap(40),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Get Started',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ).animate().fade(delay: 700.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLength;
  final int delay;

  const _AnimatedInputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLength,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    ).animate().fade(delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}
