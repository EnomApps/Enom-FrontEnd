import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: _emailController.text.trim(),
              isFromRegistration: true,
            ),
          ),
        );
      } else {
        AppTheme.showSnackBar(context, result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('network_error'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      extendBodyBehindAppBar: true,
      appBar: AppTheme.appBar(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const EnomScreenBackground(gradientVariant: 2, particleCount: 15),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Header
                    Text(
                      'CREATE ACCOUNT',
                      style: AppTheme.subheading(context, size: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join ENOM',
                      style: AppTheme.heading(context, size: 36),
                    ),
                    const SizedBox(height: 20),
                    AppTheme.goldDivider(context),
                    const SizedBox(height: 28),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      style: AppTheme.body(context),
                      decoration: AppTheme.inputDecoration(
                        context,
                        hint: l10n.translate('enter_name'),
                        prefixIcon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.translate('enter_name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTheme.body(context),
                      decoration: AppTheme.inputDecoration(
                        context,
                        hint: l10n.translate('enter_email'),
                        prefixIcon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.translate('enter_email');
                        }
                        final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return l10n.translate('invalid_email');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: AppTheme.body(context),
                      decoration: AppTheme.inputDecoration(
                        context,
                        hint: l10n.translate('enter_password'),
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.text2(context),
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.translate('enter_password');
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Create Account button
                    AppTheme.goldCTAButton(
                      label: l10n.translate('signup'),
                      onPressed: _isLoading ? null : _handleSignup,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 24),

                    // Or divider
                    AppTheme.orDivider(context, l10n.translate('or_continue_with')),
                    const SizedBox(height: 24),

                    // Social buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppTheme.socialButton(
                          context,
                          icon: Text(
                            'G',
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.goldColor(context),
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        AppTheme.socialButton(
                          context,
                          icon: Icon(
                            Icons.apple,
                            color: AppTheme.text2(context),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Login link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.translate('have_account'),
                            style: GoogleFonts.jost(
                              color: AppTheme.text2(context),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              ' ${l10n.translate('login')}',
                              style: GoogleFonts.jost(
                                color: AppTheme.goldColor(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
