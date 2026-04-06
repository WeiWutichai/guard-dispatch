import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import 'registration_pending_screen.dart';
import 'role_selection_screen.dart';
import 'phone_input_screen.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  final String phone;
  final String? profileToken;

  const CustomerRegistrationScreen({
    super.key,
    required this.phone,
    this.profileToken,
  });

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactPhoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final isAlreadyAuthenticated = authProvider.isAuthenticated;

      // Use profile token from widget, or request a fresh one via updateRole.
      // Authenticated users (approved guard adding customer profile) can get a
      // new profile_token without OTP because they already have a valid JWT.
      // Unauthenticated users without a token must re-verify via OTP.
      var profileToken = widget.profileToken;
      if (profileToken == null) {
        if (isAlreadyAuthenticated) {
          // Authenticated user — get fresh profile_token via updateRole
          try {
            profileToken = await authProvider.updateRole(widget.phone, 'customer');
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _isSubmitting = false;
              _errorMessage = '$e';
            });
            return;
          }
        }
        if (profileToken == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LanguageProvider.of(context).isThai
                  ? 'เซสชันหมดอายุ กรุณายืนยันเบอร์โทรอีกครั้ง'
                  : 'Session expired. Please verify your phone again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
            (route) => false,
          );
          return;
        }
      }

      // Only save pending state for users who are NOT already authenticated.
      if (!isAlreadyAuthenticated) {
        await Future.wait([
          AuthService.savePendingProfile({
            'phone': widget.phone,
            'role': 'customer',
            'full_name': _fullNameController.text.trim(),
            'contact_phone': _contactPhoneController.text.trim(),
            'email': _emailController.text.trim(),
            'company_name': _companyController.text.trim(),
            'address': _addressController.text.trim(),
          }),
          AuthService.setPendingApproval(role: 'customer'),
        ]);
      }

      // Submit to backend
      await authProvider.submitCustomerProfile(
        profileToken: profileToken,
        address: _addressController.text.trim(),
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty
            ? null
            : _contactPhoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        companyName: _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
      );

      if (!mounted) return;

      final isThai = LanguageProvider.of(context).isThai;
      final strings = CustomerRegistrationStrings(isThai: isThai);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(strings.successMessage),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Refresh profile to pick up customer_approval_status
      await authProvider.fetchProfile();
      if (!mounted) return;

      // Navigate to pending screen — customer profile needs admin approval
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationPendingScreen(role: 'customer')),
        (route) => false,
      );
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] as String?;
      setState(() {
        _errorMessage = message ?? 'Failed to submit application';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = CustomerRegistrationStrings(isThai: isThai);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            // P-Guard green header
            Container(
              padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoleSelectionScreen(phone: widget.phone),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'P-Guard',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.appBarTitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        strings.fillInfo,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error message
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full name (required)
                      _buildLabel(strings.fullName),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _inputDecoration(strings.fullNameHint),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return isThai ? 'กรุณากรอกชื่อ-นามสกุล' : 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Contact phone (required)
                      _buildLabel(strings.contactPhone),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDecoration(strings.contactPhoneHint)
                            .copyWith(counterText: ''),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return isThai ? 'กรุณากรอกเบอร์ติดต่อ' : 'Contact phone is required';
                          }
                          if (v.length != 10 || !v.startsWith('0')) {
                            return strings.contactPhoneInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email (optional)
                      _buildLabel(strings.email),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(strings.emailHint),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return null;
                          if (!v.contains('@') || !v.contains('.')) {
                            return strings.emailInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Company name (required)
                      _buildLabel(strings.companyName),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _companyController,
                        decoration: _inputDecoration(strings.companyHint),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return isThai ? 'กรุณากรอกชื่อบริษัท' : 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Address (required)
                      _buildLabel(strings.address),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: _inputDecoration(strings.addressHint),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              strings.submitting,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          strings.submitApplication,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ), // ElevatedButton
              ), // SizedBox
            ), // Padding
          ], // outer Column children
        ), // outer Column (body)
      ), // Scaffold
    ); // PopScope
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.danger, width: 2),
      ),
    );
  }
}
