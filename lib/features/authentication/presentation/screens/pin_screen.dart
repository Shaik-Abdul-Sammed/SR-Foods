import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final _pinController = TextEditingController();
  bool _isError = false;



  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinCompleted(String pin) async {
    const storage = FlutterSecureStorage();
    final storedPin = await storage.read(key: 'app_pin');

    // Handle case where no PIN is stored yet — redirect to registration
    if (storedPin == null || storedPin.isEmpty) {
      if (mounted) context.go(AppRoutes.registration);
      return;
    }

    if (pin == storedPin) {
      HapticFeedback.lightImpact();
      final mobile = await storage.read(key: 'mobile_number');
      if (mounted) {
        if (mobile == '9440067933' || mobile == '9010150809') {
          context.go(AppRoutes.dashboard);
        } else {
          context.go(AppRoutes.products);
        }
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _isError = true);
      _shakeController.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _pinController.clear();
      setState(() => _isError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: AppTextStyles.headlineSmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
      color: AppColors.primaryContainer,
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: AppColors.primary,
      border: Border.all(color: AppColors.primary),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.error, width: 2),
      color: AppColors.errorLight,
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Logo
              Hero(
                tag: 'app_logo',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/dad.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConfig.appName,
                style: AppTextStyles.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your PIN to continue',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 48),
              // PIN Input in a glass card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _shakeAnimation.value *
                                  (_shakeController.value < 0.5 ? 1 : -1),
                              0,
                            ),
                            child: child,
                          );
                        },
                        child: Pinput(
                          controller: _pinController,
                          length: 4,
                          obscureText: true,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: _isError
                              ? errorPinTheme
                              : submittedPinTheme.copyWith(
                                  textStyle: AppTextStyles.headlineSmall
                                      .copyWith(color: Colors.white),
                                ),
                          onCompleted: _onPinCompleted,
                          hapticFeedbackType:
                              HapticFeedbackType.lightImpact,
                        ),
                      ),
                      if (_isError) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Incorrect PIN. Please try again.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Reset Registration?'),
                              content: const Text('This will clear your PIN and require you to register again. Do you want to proceed?'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            const storage = FlutterSecureStorage();
                            await storage.deleteAll();
                            if (!context.mounted) return;
                            context.go(AppRoutes.registration);
                          }
                        },
                        child: Text(
                          'Forgot PIN? Reset Registration',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Text(
                '${AppConfig.appName} • ${AppConfig.appVersion}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
