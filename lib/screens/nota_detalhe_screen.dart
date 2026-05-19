import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nota_lenha.dart';

class NotaDetalheScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const NotaDetalheScreen({super.key, this.arguments});

  @override
  State<NotaDetalheScreen> createState() => _NotaDetalheScreenState();
}

class _NotaDetalheScreenState extends State<NotaDetalheScreen> {
  final _supabase = Supabase.instance.client;
  NotaLenha? _nota;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _nota = widget.arguments?['nota'] as NotaLenha?;
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Nota'),
        content: Text(
            'Deseja excluir a nota ${_nota?.numeroNota}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _delete();
    }
  }

  Future<void> _delete() async {
    if (_nota?.id == null) return;
    setState(() => _deleting = true);
    try {
      await _supabase
          .from('notas_lenha')
          .delete()
          .eq('id', _nota!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota excluída com sucesso')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_nota == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhe da Nota')),
        body: const Center(child: Text('Nota não encontrada')),
      );
    }
    final nota = _nota!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nota ${nota.numeroNota}'),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _confirmDelete,
            tooltip: 'Excluir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            if (nota.imagemUrl != null && nota.imagemUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: nota.imagemUrl!,
                  height: 220,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 220,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 220,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image,
                        size: 48, color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported,
                      size: 48, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 20),

            // Details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informações da Nota',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    _InfoRow(
                        icon: Icons.receipt,
                        label: 'Número',
                        value: nota.numeroNota),
                    _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Data',
                        value: nota.dataNotaFormatada),
                    _InfoRow(
                        icon: Icons.person,
                        label: 'Motorista',
                        value: nota.motorista),
                    _InfoRow(
                        icon: Icons.directions_car,
                        label: 'Placa',
                        value: nota.placaFormatada),
                    _InfoRow(
                        icon: Icons.business,
                        label: 'Cliente',
                        value: nota.cliente),
                    _InfoRow(
                        icon: Icons.folder,
                        label: 'Projeto',
                        value: nota.projeto),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Measurements card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medições',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _MeasurementTile(
                            label: 'S1 (st)',
                            value: nota.s1 != null
                                ? nota.s1!.toStringAsFixed(3)
                                : '-',
                            icon: Icons.straighten,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        Expanded(
                          child: _MeasurementTile(
                            label: 'M² (área)',
                            value: nota.m2 != null
                                ? nota.m2!.toStringAsFixed(3)
                                : '-',
                            icon: Icons.square_foot,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                        Expanded(
                          child: _MeasurementTile(
                            label: 'Total m³',
                            value: nota.totalM3Formatado,
                            icon: Icons.inventory,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (nota.criadoEm != null) ...[
              const SizedBox(height: 12),
              Text(
                'Cadastrado em: ${nota.criadoEm!.toLocal().toString().substring(0, 16)}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text('$label: ',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MeasurementTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
      ],
    );
  }
}
