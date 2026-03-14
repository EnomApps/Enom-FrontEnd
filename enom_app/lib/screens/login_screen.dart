import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else if (result.statusCode == 403) {
        // Email not verified — go to OTP screen
        AppTheme.showSnackBar(context, result.message, isError: true);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: _emailController.text.trim(),
              isFromRegistration: false,
            ),
          ),
        );
      } else {
        AppTheme.showSnackBar(context, result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppTheme.showSnackBar(context, l10n.translate('network_error'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppTheme.appBar(context),
      body: Stack(
        children: [
          const GradientBackground(variant: 3),
          const StarField(starCount: 8),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Logo centered
                    Center(
                      child: AppTheme.logo(context, size: 80),
                    ),
                    const SizedBox(height: 32),
                    // Title
                    Text(
                      l10n.translate('login'),
                      style: AppTheme.heading(context, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.translate('welcome_back'),
                      style: AppTheme.subheading(context, size: 16),
                    ),
                    const SizedBox(height: 16),
                    Center(child: AppTheme.goldDivider(context)),
                    const SizedBox(height: 32),
                    // Email field
                    _buildLabel(l10n.translate('email')),
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
                    const SizedBox(height: 24),
                    // Password field
                    _buildLabel(l10n.translate('password')),
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
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          l10n.translate('forgot_password'),
                          style: AppTheme.body(context, size: 14).copyWith(
                            color: AppTheme.goldColor(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
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
                                l10n.translate('login'),
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.cardBorder(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.translate('or_continue_with'),
                            style: AppTheme.body(context, size: 12).copyWith(
                              color: AppTheme.text2(context),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.cardBorder(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Social login buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton(Icons.g_mobiledata, 'G'),
                        const SizedBox(width: 16),
                        _socialButton(Icons.apple, ''),
                        const SizedBox(width: 16),
                        _socialButton(Icons.facebook, ''),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Sign up link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.translate('no_account'),
                            style: AppTheme.body(context, size: 14).copyWith(
                              color: AppTheme.text2(context),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: Text(
                              l10n.translate('signup'),
                              style: AppTheme.body(context, size: 14, weight: FontWeight.bold).copyWith(
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTheme.body(context, size: 14, weight: FontWeight.w500),
    );
  }

  Widget _socialButton(IconData icon, String text) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(
          icon,
          color: AppTheme.text1(context),
          size: 28,
        ),
      ),
    );
  }
}
