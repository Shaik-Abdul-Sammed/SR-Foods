import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gap/gap.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';

class OwnerLoginScreen extends ConsumerStatefulWidget {
  const OwnerLoginScreen({super.key});

  @override
  ConsumerState<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends ConsumerState<OwnerLoginScreen> {
  final _mobileCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginOwner() async {
    final mobile = _mobileCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    final owner1 = dotenv.env['OWNER_MOBILE_1'];
    final owner2 = dotenv.env['OWNER_MOBILE_2'];

    if (mobile != owner1 && mobile != owner2) {
      setState(() => _error = 'Unauthorized owner mobile number');
      return;
    }

    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _storage.write(key: 'owner_name', value: 'Owner');
      await _storage.write(key: 'mobile_number', value: mobile);
      await _storage.write(key: 'app_pin', value: pin);
      
      await Future<void>.delayed(const Duration(milliseconds: 800));
      
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } catch (e) {
      setState(() => _error = 'Error during login');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2), // Emerald
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF10B981),
                    size: 48,
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                
                const Gap(24),
                
                Text(
                  'Owner Access',
                  style: AppTextStyles.displaySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fade(delay: 200.ms).slideY(begin: -0.2, end: 0),
                
                const Gap(8),
                
                Text(
                  'Enter your credentials to manage operations.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fade(delay: 300.ms),
                
                const Gap(48),
                
                _AnimatedInputField(
                  controller: _mobileCtrl,
                  label: 'Registered Mobile',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  delay: 400,
                ),
                
                const Gap(20),
                
                _AnimatedInputField(
                  controller: _pinCtrl,
                  label: 'Access PIN',
                  icon: Icons.lock_rounded,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  delay: 500,
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
                
                const Gap(48),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginOwner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
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
                            'Authorize',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ).animate().fade(delay: 700.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
              ],
            ),
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
      style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
      ),
    ).animate().fade(delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}
