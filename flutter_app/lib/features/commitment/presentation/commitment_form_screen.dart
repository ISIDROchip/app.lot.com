import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../shared/theme/app_theme.dart';
import '../domain/commitment_service.dart';

class CommitmentFormScreen extends StatefulWidget {
  const CommitmentFormScreen({super.key});

  @override
  State<CommitmentFormScreen> createState() => _CommitmentFormScreenState();
}

class _CommitmentFormScreenState extends State<CommitmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CommitmentService();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _checkboxAccepted = false;
  bool _loading = false;

  // Signature canvas
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _signatureEmpty = true;

  // Photo
  String? _photoBase64;

  // Location
  double? _latitude;
  double? _longitude;
  String? _locationAddress;
  bool _loadingLocation = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _cedulaCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Signature ──────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
      _signatureEmpty = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) =>
      setState(() => _currentStroke.add(d.localPosition));

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
    });
  }

  void _clearSignature() => setState(() {
        _strokes.clear();
        _currentStroke = [];
        _signatureEmpty = true;
      });

  Future<String?> _exportSignature(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = LuxoraColors.surface,
    );
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return base64Encode(bytes.buffer.asUint8List());
  }

  // ── Photo ──────────────────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se requieren permisos de cámara para tomar la foto'),
              action: SnackBarAction(
                label: 'Configurar',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photoBase64 = base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo acceder a la cámara')),
        );
      }
    }
  }

  // ── Location ───────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Activa el GPS para obtener tu ubicación')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationAddress =
            'Lat: ${pos.latitude.toStringAsFixed(6)}, Lon: ${pos.longitude.toStringAsFixed(6)}';
        // Also fill address field if empty
        if (_addressCtrl.text.isEmpty) {
          _addressCtrl.text = _locationAddress!;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_signatureEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor dibuja tu firma')),
      );
      return;
    }
    if (!_checkboxAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar las cláusulas')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final signatureBase64 = await _exportSignature(const Size(300, 200));
      if (signatureBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al exportar la firma')),
        );
        return;
      }

      final result = await _service.submitForm(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        cedula: _cedulaCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        signatureBase64: signatureBase64,
        checkboxAccepted: _checkboxAccepted,
        photoBase64: _photoBase64,
        latitude: _latitude,
        longitude: _longitude,
        locationAddress: _locationAddress,
      );

      if (result.containsKey('contract_id') && mounted) {
        context.go('/pull-10');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['error']?.toString() ?? 'Error al firmar')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tiempo de espera agotado. Intenta de nuevo')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('CONTRATO DE COMPROMISO')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Personal data ──────────────────────────────────────
              _SectionHeader(
                  title: 'DATOS PERSONALES', icon: Icons.person_outline),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LuxoraColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LuxoraColors.divider),
                ),
                child: Column(
                  children: [
                    _buildField(_firstNameCtrl, 'Nombre', Icons.badge_outlined,
                        validator: _validateName),
                    const SizedBox(height: 12),
                    _buildField(_lastNameCtrl, 'Apellido', Icons.badge_outlined,
                        validator: _validateName),
                    const SizedBox(height: 12),
                    _buildField(
                        _cedulaCtrl, 'Cédula', Icons.credit_card_outlined,
                        validator: _validateCedula),
                    const SizedBox(height: 12),
                    _buildField(_phoneCtrl, 'Teléfono', Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Location ───────────────────────────────────────────
              _SectionHeader(
                  title: 'DIRECCIÓN Y UBICACIÓN',
                  icon: Icons.location_on_outlined),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LuxoraColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LuxoraColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildField(_addressCtrl, 'Dirección', Icons.home_outlined,
                        validator: _validateAddress),
                    const SizedBox(height: 12),
                    // GPS button
                    GestureDetector(
                      onTap: _loadingLocation ? null : _getLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _latitude != null
                              ? LuxoraColors.accent.withValues(alpha: 0.1)
                              : LuxoraColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _latitude != null
                                ? LuxoraColors.accent.withValues(alpha: 0.5)
                                : LuxoraColors.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_loadingLocation)
                              const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: LuxoraColors.accent))
                            else
                              Icon(
                                _latitude != null
                                    ? Icons.check_circle_rounded
                                    : Icons.my_location_rounded,
                                color: _latitude != null
                                    ? LuxoraColors.accent
                                    : LuxoraColors.textSecondary,
                                size: 18,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _latitude != null
                                    ? 'Ubicación capturada ✓'
                                    : 'Capturar mi ubicación GPS',
                                style: TextStyle(
                                  color: _latitude != null
                                      ? LuxoraColors.accent
                                      : LuxoraColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_locationAddress != null) ...[
                      const SizedBox(height: 6),
                      Text(_locationAddress!,
                          style: const TextStyle(
                              color: LuxoraColors.textSecondary, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Photo ──────────────────────────────────────────────
              _SectionHeader(
                  title: 'FOTO DEL FIRMANTE', icon: Icons.camera_alt_outlined),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: LuxoraColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _photoBase64 != null
                          ? LuxoraColors.accent.withValues(alpha: 0.5)
                          : LuxoraColors.divider,
                      width: _photoBase64 != null ? 1.5 : 1,
                    ),
                  ),
                  child: _photoBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.memory(
                            base64Decode(_photoBase64!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded,
                                color: LuxoraColors.textSecondary
                                    .withValues(alpha: 0.5),
                                size: 36),
                            const SizedBox(height: 8),
                            const Text('Tomar foto',
                                style: TextStyle(
                                    color: LuxoraColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Legal clauses ──────────────────────────────────────
              _SectionHeader(
                  title: 'CLÁUSULAS LEGALES', icon: Icons.gavel_rounded),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LuxoraColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LuxoraColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 150,
                      child: SingleChildScrollView(
                        child: Text(
                          'El usuario se compromete irrevocablemente a pagar el treinta por ciento (30 %) '
                          'del monto neto de cualquier premio obtenido mediante las combinaciones generadas '
                          'en el Pull de 10 de Luxora Smart Lottery. Este compromiso aplica a cada combinación '
                          'individualmente y al conjunto de combinaciones del Pull. El pago deberá realizarse '
                          'dentro de los cinco (5) días hábiles siguientes a la fecha de cobro del premio, '
                          'mediante transferencia a las cuentas bancarias oficiales de Luxora indicadas en la '
                          'aplicación. El incumplimiento de este compromiso podrá resultar en la suspensión '
                          'del acceso al servicio Pull de 10.',
                          style: const TextStyle(
                              color: LuxoraColors.textSecondary,
                              fontSize: 13,
                              height: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Signature canvas ───────────────────────────────────
              _SectionHeader(title: 'FIRMA MANUAL', icon: Icons.draw_outlined),
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: LuxoraColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _signatureEmpty
                        ? LuxoraColors.divider
                        : LuxoraColors.primary,
                    width: _signatureEmpty ? 1 : 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: _SignaturePainter(
                          strokes: _strokes, currentStroke: _currentStroke),
                      child: Container(),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearSignature,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpiar'),
                ),
              ),
              const SizedBox(height: 8),

              // ── Checkbox ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _checkboxAccepted
                      ? LuxoraColors.primary.withValues(alpha: 0.08)
                      : LuxoraColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _checkboxAccepted
                        ? LuxoraColors.primary.withValues(alpha: 0.4)
                        : LuxoraColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checkboxAccepted,
                      onChanged: (v) =>
                          setState(() => _checkboxAccepted = v ?? false),
                      activeColor: LuxoraColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const Expanded(
                      child: Text(
                        'He leído y acepto todas las cláusulas del contrato',
                        style: TextStyle(
                            color: LuxoraColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────
              GestureDetector(
                onTap: _loading ? null : _submit,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _loading
                        ? LinearGradient(colors: [
                            LuxoraColors.primary.withValues(alpha: 0.4),
                            LuxoraColors.primary.withValues(alpha: 0.4),
                          ])
                        : const LinearGradient(
                            colors: [Color(0xFFE07820), Color(0xFFC8620A)],
                          ),
                    boxShadow: _loading
                        ? []
                        : [
                            BoxShadow(
                              color:
                                  LuxoraColors.primary.withValues(alpha: 0.4),
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
                              strokeWidth: 2, color: Colors.white))
                      : const Text(
                          'FIRMAR Y CONTINUAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: LuxoraColors.textSecondary, size: 18),
      ),
      style: const TextStyle(color: LuxoraColors.textPrimary),
      validator: validator,
    );
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().length < 2 || v.trim().length > 60) {
      return 'Entre 2 y 60 caracteres';
    }
    if (!RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ\s]+$').hasMatch(v.trim())) {
      return 'Solo letras y espacios';
    }
    return null;
  }

  String? _validateAddress(String? v) {
    if (v == null || v.trim().length < 10 || v.trim().length > 255) {
      return 'Entre 10 y 255 caracteres';
    }
    return null;
  }

  String? _validateCedula(String? v) {
    if (v == null || !RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(v.trim())) {
      return '6-20 caracteres alfanuméricos';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || !RegExp(r'^\d{8,15}$').hasMatch(v.trim())) {
      return '8-15 dígitos numéricos';
    }
    return null;
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: LuxoraColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: LuxoraColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ── Signature painter ──────────────────────────────────────────────────────

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  const _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in [...strokes, currentStroke]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}
