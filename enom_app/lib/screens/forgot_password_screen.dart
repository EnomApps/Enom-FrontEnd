import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      AppTheme.showSnackBar(context, result.message);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ForgotPasswordOtpScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
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
                    Center(child: AppTheme.logo(context, size: 80)),
                    const SizedBox(height: 32),
                    Text(
                      l10n.translate('forgot_password_title'),
                      style: AppTheme.heading(context, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.translate('forgot_password_desc'),
                      style: GoogleFonts.jost(
                        color: AppTheme.text2(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Email field
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
                    const SizedBox(height: 40),
                    AppTheme.goldCTAButton(
                      label: l10n.translate('send_otp'),
                      onPressed: _isLoading ? null : _handleSendOtp,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.translate('back_to_login'),
                          style: GoogleFonts.jost(
                            color: AppTheme.goldColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
