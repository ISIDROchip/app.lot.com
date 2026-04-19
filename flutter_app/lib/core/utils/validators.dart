class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'El correo es requerido';
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!regex.hasMatch(value)) return 'Correo inválido';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'El teléfono es requerido';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15) return 'Teléfono inválido (8-15 dígitos)';
    return null;
  }

  static String? required(String? value, [String field = 'Este campo']) {
    if (value == null || value.trim().isEmpty) return '$field es requerido';
    return null;
  }

  static String? dreamText(String? value) {
    if (value == null || value.length < 10) return 'Describe tu sueño con al menos 10 caracteres';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    return null;
  }
}
