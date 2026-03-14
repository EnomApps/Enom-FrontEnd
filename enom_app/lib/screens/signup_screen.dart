import 'package:flutter/material.dart';
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
        // Navigate to OTP verification
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
      appBar: AppTheme.appBar(context),
      body: Stack(
        children: [
          const GradientBackground(variant: 2),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Logo centered
                    Center(
                      child: AppTheme.logo(context, size: 70),
                    ),
                    const SizedBox(height: 24),
                    // Subtitle label
                    Text(
                      'CREATE ACCOUNT',
                      style: AppTheme.label(context),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      l10n.translate('create_account'),
                      style: AppTheme.heading(context, size: 22),
                    ),
                    const SizedBox(height: 32),
                    // Full Name
                    Text(
                      l10n.translate('full_name'),
                      style: AppTheme.body(context),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 20),
                    // Email
                    Text(
                      l10n.translate('email'),
                      style: AppTheme.body(context),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 20),
                    // Password
                    Text(
                      l10n.translate('password'),
                      style: AppTheme.body(context),
                    ),
                    const SizedBox(height: 8),
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
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
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
                    const SizedBox(height: 32),
                    // Signup button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: AppTheme.primaryButton(context),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppTheme.toggleBg(context),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                l10n.translate('signup'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Gold divider
                    Center(child: AppTheme.goldDivider(context)),
                    const SizedBox(height: 24),
                    // Login link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.translate('have_account'),
                            style: AppTheme.body(context).copyWith(
                              color: AppTheme.text2(context),
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
                              l10n.translate('login'),
                              style: AppTheme.body(context, weight: FontWeight.bold).copyWith(
                                color: AppTheme.goldColor(context),
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
