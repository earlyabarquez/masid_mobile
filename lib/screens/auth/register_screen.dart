import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../utils/token_storage.dart';
import '../home/home_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  /// Converts full middle name to initial: "Santos" → "S."
  String _middleInitial() {
    final mn = _middleNameCtrl.text.trim();
    if (mn.isEmpty) return '';
    return '${mn[0].toUpperCase()}.';
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Build payload
    final payload = {
      'firstName': _firstNameCtrl.text.trim(),
      'middleInitial': _middleInitial(),
      'lastName': _lastNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
    };

    // TODO: Replace with actual Spring Boot API call
    // final response = await ApiService.post('/auth/register', payload);
    await Future.delayed(const Duration(seconds: 1));

    debugPrint('Register payload: $payload');

    // Simulate saving token after registration
    await TokenStorage.saveToken('temp_jwt_token');

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Back button ──
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Header ──
              const Text(
                'Create Account',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Register as an MDRRMO responder',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),

              const SizedBox(height: 28),

              // ── Form ──
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name row ──
                    Row(
                      children: [
                        // First name
                        Expanded(
                          flex: 2,
                          child: _buildField(
                            label: 'First Name',
                            controller: _firstNameCtrl,
                            hint: 'Juan',
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Middle name
                        Expanded(
                          flex: 2,
                          child: _buildField(
                            label: 'Middle Name',
                            controller: _middleNameCtrl,
                            hint: 'Santos',
                            helperText: 'Auto-converts to initial',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Last name
                    _buildField(
                      label: 'Last Name',
                      controller: _lastNameCtrl,
                      hint: 'Dela Cruz',
                      validator: _required,
                    ),

                    const SizedBox(height: 16),

                    // Phone
                    _buildField(
                      label: 'Phone Number',
                      controller: _phoneCtrl,
                      hint: '09XX XXX XXXX',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone is required';
                        }
                        if (v.trim().length < 11) return 'Enter a valid number';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Email
                    _buildField(
                      label: 'Email',
                      controller: _emailCtrl,
                      hint: 'you@email.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password
                    const _FieldLabel('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: AppColors.label,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.label,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Password is required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirm password
                    const _FieldLabel('Confirm Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: AppColors.label,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.label,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Confirm your password';
                        if (v != _passCtrl.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleRegister,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Login link ──
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: build a labeled text field ──
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperStyle: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 11,
              color: AppColors.label,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: AppColors.label)
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    return null;
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Sora',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.body,
      ),
    );
  }
}
