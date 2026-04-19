import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/auth_dto.dart';
import '../domain/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _service = AuthService();
  DateTime? _birthDate;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  bool _isAdult(DateTime date) {
    final now = DateTime.now();
    final age = now.year - date.year;
    final hadBirthday = now.month > date.month ||
        (now.month == date.month && now.day >= date.day);
    return (hadBirthday ? age : age - 1) >= 18;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: LuxoraColors.primary,
            surface: LuxoraColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      setState(() => _error = 'La fecha de nacimiento es requerida');
      return;
    }
    if (!_isAdult(_birthDate!)) {
      setState(() => _error = 'Debes ser mayor de 18 años para registrarte');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.register(RegisterRequest(
        fullName: _nameCtrl.text.trim(),
        birthDate: DateFormat('yyyy-MM-dd').format(_birthDate!),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada! Inicia sesión.')),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      if (status == 403) {
        _error = 'Debes ser mayor de 18 años para registrarte';
      } else if (status == 409) {
        _error = 'El correo ya está registrado';
      } else if (status == 422) {
        final msg = body is Map ? body['error'] as String? : null;
        _error = msg ?? 'Datos inválidos. Revisa los campos';
      } else {
        _error = 'Error inesperado. Intenta de nuevo';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  LuxoraColors.primary.withValues(alpha: 0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: LuxoraColors.textSecondary),
                        onPressed: () => context.go('/login'),
                      ),
                      const Text('CREAR CUENTA',
                          style: TextStyle(
                              color: LuxoraColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1)),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: Opacity(opacity: _fadeAnim.value, child: child),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: LuxoraColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: LuxoraColors.divider),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildField(
                                    ctrl: _nameCtrl,
                                    label: 'Nombre completo',
                                    icon: Icons.person_outline,
                                    validator: (v) =>
                                        Validators.required(v, 'El nombre'),
                                  ),
                                  const SizedBox(height: 14),

                                  // Date picker
                                  GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: LuxoraColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _birthDate != null
                                              ? LuxoraColors.primary
                                              : LuxoraColors.divider,
                                          width: _birthDate != null ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.cake_outlined,
                                              color: _birthDate != null
                                                  ? LuxoraColors.primary
                                                  : LuxoraColors.textSecondary,
                                              size: 20),
                                          const SizedBox(width: 12),
                                          Text(
                                            _birthDate == null
                                                ? 'Fecha de nacimiento'
                                                : DateFormat('dd/MM/yyyy')
                                                    .format(_birthDate!),
                                            style: TextStyle(
                                              color: _birthDate == null
                                                  ? LuxoraColors.textSecondary
                                                  : LuxoraColors.textPrimary,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _buildField(
                                    ctrl: _emailCtrl,
                                    label: 'Correo electrónico',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: Validators.email,
                                  ),
                                  const SizedBox(height: 14),

                                  _buildField(
                                    ctrl: _phoneCtrl,
                                    label: 'Teléfono',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    validator: Validators.phone,
                                  ),
                                  const SizedBox(height: 14),

                                  _buildField(
                                    ctrl: _passwordCtrl,
                                    label: 'Contraseña',
                                    icon: Icons.lock_outline,
                                    obscure: _obscure,
                                    validator: Validators.password,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: LuxoraColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color:
                                      LuxoraColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: LuxoraColors.error
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: LuxoraColors.error, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(_error!,
                                            style: const TextStyle(
                                                color: LuxoraColors.error,
                                                fontSize: 13))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Submit button
                            GestureDetector(
                              onTap: _loading ? null : _submit,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: _loading
                                      ? LinearGradient(colors: [
                                          LuxoraColors.primary
                                              .withValues(alpha: 0.4),
                                          LuxoraColors.primary
                                              .withValues(alpha: 0.4),
                                        ])
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFFE07820),
                                            Color(0xFFC8620A)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  boxShadow: _loading
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: LuxoraColors.primary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                ),
                                alignment: Alignment.center,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text(
                                        'CREAR CUENTA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('¿Ya tienes cuenta? ',
                                    style: TextStyle(
                                        color: LuxoraColors.textSecondary)),
                                GestureDetector(
                                  onTap: () => context.go('/login'),
                                  child: const Text('Inicia sesión',
                                      style: TextStyle(
                                          color: LuxoraColors.accent,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: LuxoraColors.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: LuxoraColors.background,
      ),
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: LuxoraColors.textPrimary),
      validator: validator,
    );
  }
}
