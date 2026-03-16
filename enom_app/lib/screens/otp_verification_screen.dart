import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final bool isFromRegistration;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isFromRegistration = true,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final otp = _otpCode;
    if (otp.length != 6) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.verifyOtp(otp: otp);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
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

  Future<void> _handleResendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isResending = true);

    try {
      final result = await AuthService.resendOtp(email: widget.email);

      if (!mounted) return;
      setState(() => _isResending = false);

      AppTheme.showSnackBar(
        context,
        result.message,
        isError: !result.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Logo
                  Center(child: AppTheme.logo(context, size: 80)),
                  const SizedBox(height: 32),
                  // Title
                  Text(
                    l10n.translate('verify_email'),
                    style: AppTheme.heading(context, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.translate('verify_email_desc')}\n${widget.email}',
                    style: GoogleFonts.jost(
                      color: AppTheme.text2(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // OTP input fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: TextFormField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: GoogleFonts.jost(
                            color: AppTheme.text1(context),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: AppTheme.glassBg(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppTheme.glassBorder(context),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppTheme.glassBorder(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: AppTheme.gold1.withValues(alpha: 0.4)),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            if (_otpCode.length == 6) {
                              _handleVerify();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 40),
                  // Verify button
                  AppTheme.goldCTAButton(
                    label: l10n.translate('verify'),
                    onPressed: _isLoading ? null : _handleVerify,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 32),
                  // Resend OTP
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.translate('didnt_receive_code'),
                          style: GoogleFonts.jost(
                            color: AppTheme.text2(context),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isResending ? null : _handleResendOtp,
                          child: _isResending
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.goldColor(context),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  ' ${l10n.translate('resend_otp')}',
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
        ],
      ),
    );
  }
}
