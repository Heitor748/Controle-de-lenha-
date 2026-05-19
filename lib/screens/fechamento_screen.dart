import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nota_lenha.dart';

class FechamentoScreen extends StatefulWidget {
  const FechamentoScreen({super.key});

  @override
  State<FechamentoScreen> createState() => _FechamentoScreenState();
}

class _FechamentoScreenState extends State<FechamentoScreen> {
  final _supabase = Supabase.instance.client;

  DateTime _inicio = DateTime(
      DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  String? _clienteSelecionado;
  List<String> _clientes = [];
  List<NotaLenha> _notas = [];
  bool _loading = false;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    try {
      final response =
          await _supabase.from('notas_lenha').select('cliente');
      final list = (response as List)
          .map((e) => e['cliente'] as String)
          .toSet()
          .toList()
        ..sort();
      if (mounted) setState(() => _clientes = list);
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var query = _supabase
          .from('notas_lenha')
          .select()
          .gte('data_nota', DateFormat('yyyy-MM-dd').format(_inicio))
          .lte('data_nota', DateFormat('yyyy-MM-dd').format(_fim));

      if (_clienteSelecionado != null && _clienteSelecionado!.isNotEmpty) {
        query = query.eq('cliente', _clienteSelecionado!);
      }

      final response = await query.order('data_nota');
      final list = (response as List)
          .map((e) => NotaLenha.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _notas = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_notas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma nota para gerar PDF')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final bytes = await _buildPdf();
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name:
              'Fechamento_${DateFormat('yyyyMM').format(_inicio)}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final totalM3 = _notas.fold(0.0, (s, n) => s + (n.totalM3 ?? 0));
    final fmt = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Fechamento de Notas de Lenha',
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Período: ${fmt.format(_inicio)} a ${fmt.format(_fim)}'
            '${_clienteSelecionado != null ? " | Cliente: $_clienteSelecionado" : ""}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: [
              'Nota',
              'Data',
              'Motorista',
              'Placa',
              'Cliente',
              'Projeto',
              'M³',
            ],
            data: _notas
                .map((n) => [
                      n.numeroNota,
                      n.dataNotaFormatada,
                      n.motorista,
                      n.placaFormatada,
                      n.cliente,
                      n.projeto,
                      n.totalM3Formatado,
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            border: pw.TableBorder.all(width: 0.5),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              6: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total: ${totalM3.toStringAsFixed(3).replaceAll('.', ',')} m³',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _inicio : _fim;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _inicio = picked;
        } else {
          _fim = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');
    final totalM3 = _notas.fold(0.0, (s, n) => s + (n.totalM3 ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fechamento'),
        actions: [
          if (_notas.isNotEmpty)
            IconButton(
              icon: _generating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              onPressed: _generating ? null : _generatePdf,
              tooltip: 'Gerar PDF',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Filtros', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Início: ${fmt.format(_inicio)}'),
                          onPressed: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Fim: ${fmt.format(_fim)}'),
                          onPressed: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _clienteSelecionado,
                    hint: const Text('Todos os clientes'),
                    decoration: const InputDecoration(
                      labelText: 'Cliente',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Todos')),
                      ..._clientes.map((c) =>
                          DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) =>
                        setState(() => _clienteSelecionado = v),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: Text(_loading ? 'Buscando…' : 'Buscar'),
                  ),
                ],
              ),
            ),
          ),

          // Results
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_notas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_notas.length} notas encontradas',
                      style: theme.textTheme.bodyMedium),
                  Text(
                    'Total: ${totalM3.toStringAsFixed(3).replaceAll('.', ',')} m³',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _notas.isEmpty
                ? Center(
                    child: Text(
                      'Use os filtros acima para buscar notas',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notas.length,
                    itemBuilder: (context, index) {
                      final n = _notas[index];
                      return Card(
                        child: ListTile(
                          dense: true,
                          title: Text('Nota ${n.numeroNota} — ${n.dataNotaFormatada}'),
                          subtitle: Text(
                              '${n.motorista} | ${n.placaFormatada} | ${n.cliente}'),
                          trailing: Text(
                            '${n.totalM3Formatado} m³',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
