import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _userIdController = TextEditingController();
  final _scrollController = ScrollController();

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<dynamic> _contracts = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _userIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _contracts = [];
    });

    try {
      final userId = _userIdController.text.trim();
      if (userId.isEmpty) throw Exception('El campo Usuario (ID) es requerido.');

      final response = await dioInstance.get(
        '/admin/reports/contracts-detailed',
        queryParameters: {
          'user_id': userId,
          'from': _from.toIso8601String(),
          'to': _to.toIso8601String(),
        },
      );

      final body = response.data as Map<String, dynamic>;
      _contracts = body['contracts'] as List<dynamic>? ?? [];
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_contracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar.')),
      );
      return;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Reporte detallado de contratos', style: pw.TextStyle(fontSize: 22))),
            pw.Text('Usuario ID: ${_userIdController.text.trim()}'),
            pw.Text('Periodo: ${_from.toLocal().toIso8601String().split('T').first} - ${_to.toLocal().toIso8601String().split('T').first}'),
            pw.SizedBox(height: 16),
            ..._contracts.map((contract) {
              final pulls = (contract['pulls'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
              Uint8List? photoBytes;
              if ((contract['photo_data'] as String?)?.isNotEmpty == true) {
                try {
                  photoBytes = base64Decode(contract['photo_data'] as String);
                } catch (_) {
                  photoBytes = null;
                }
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Divider(),
                  pw.Text('Contrato ID: ${contract['contract_id']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Versión: ${contract['contract_version']}'),
                  pw.Text('Estado: ${contract['status']}'),
                  pw.Text('Firmado: ${contract['signed_at']}'),
                  pw.Text('IP: ${contract['ip_address'] ?? 'N/A'}'),
                  pw.Text('Ubicación: ${contract['location_address'] ?? 'N/A'}'),
                  pw.SizedBox(height: 8),
                  pw.Text('Firmante:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Nombre: ${contract['first_name']} ${contract['last_name']}'),
                  pw.Text('Cédula: ${contract['cedula']}'),
                  pw.Text('Teléfono: ${contract['phone']}'),
                  pw.Text('Dirección: ${contract['address']}'),
                  pw.Text('Aceptó cláusulas: ${contract['checkbox_acceptance'] == true ? 'Sí' : 'No'}'),
                  pw.SizedBox(height: 8),
                  if (photoBytes != null) ...[
                    pw.Text('Foto del firmante:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Center(child: pw.Image(pw.MemoryImage(photoBytes), width: 200, height: 200)),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Text('Firma digital:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(contract['signature_data'] ?? 'No disponible', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 12),
                  pw.Text('Pull de combinaciones:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if (pulls.isEmpty)
                    pw.Text('No se encontraron pulls asociados a este contrato.')
                  else
                    pw.Table.fromTextArray(
                      headers: ['ID', 'Fecha', 'Números', 'Match count', 'Ganador'],
                      data: pulls.map((item) {
                        final numbers = (item['numbers'] as List<dynamic>).join(', ');
                        return [
                          item['id'] ?? '',
                          item['created_at'] ?? '',
                          numbers,
                          item['matched_count']?.toString() ?? '0',
                          item['is_winner'] == true ? 'Sí' : 'No',
                        ];
                      }).toList(),
                    ),
                  pw.SizedBox(height: 12),
                ],
              );
            }).toList(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'reporte_contratos_${_userIdController.text.trim()}.pdf',
      onLayout: (format) => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('REPORTES'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterCard(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                ),
              )
            else
              Expanded(child: _buildReportContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filtrar reporte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'Usuario (ID)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFrom: true),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Desde',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: _from.toLocal().toIso8601String().split('T').first),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFrom: false),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Hasta',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: _to.toLocal().toIso8601String().split('T').first),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loadReport,
                  child: const Text('Cargar reporte'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _contracts.isEmpty ? null : _exportPdf,
                  child: const Text('Descargar PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    if (_contracts.isEmpty) {
      return Center(
        child: Text(
          'Ingrese el ID del usuario y presione Cargar reporte para ver contratos por fecha.',
          style: TextStyle(color: LuxoraColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _contracts.length,
        itemBuilder: (context, index) {
          final contract = _contracts[index] as Map<String, dynamic>;
          final pulls = (contract['pulls'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LuxoraColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LuxoraColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contrato ID: ${contract['contract_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _infoChip('Versión', contract['contract_version'] ?? ''),
                    _infoChip('Estado', contract['status'] ?? ''),
                    _infoChip('Firmado', contract['signed_at'] ?? ''),
                    _infoChip('IP', contract['ip_address'] ?? 'N/A'),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Firmante: ${contract['first_name']} ${contract['last_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Cédula: ${contract['cedula']}'),
                Text('Teléfono: ${contract['phone']}'),
                Text('Dirección: ${contract['address']}'),
                const SizedBox(height: 12),
                Text('Firma digital:', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(contract['signature_data'] ?? 'No disponible', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                if ((contract['photo_data'] as String?)?.isNotEmpty == true)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Foto de firma:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: LuxoraColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LuxoraColors.divider),
                        ),
                        child: Image.memory(
                          base64Decode(contract['photo_data'] as String),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                Text('Pulls de combinaciones (${pulls.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...pulls.map((pull) {
                  final numbers = (pull['numbers'] as List<dynamic>).join(', ');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LuxoraColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LuxoraColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pull ID: ${pull['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Fecha: ${pull['created_at'] ?? ''}'),
                        Text('Números: $numbers'),
                        Text('Match count: ${pull['matched_count']}'),
                        Text('Ganador: ${pull['is_winner'] == true ? 'Sí' : 'No'}'),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LuxoraColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
