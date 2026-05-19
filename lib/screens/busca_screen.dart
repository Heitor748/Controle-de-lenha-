import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/routes.dart';
import '../models/nota_lenha.dart';

class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key});

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<NotaLenha> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });

    try {
      // Search by numero_nota, motorista, placa, or cliente using ilike
      final response = await _supabase
          .from('notas_lenha')
          .select()
          .or(
            'numero_nota.ilike.%$q%,'
            'motorista.ilike.%$q%,'
            'placa.ilike.%$q%,'
            'cliente.ilike.%$q%,'
            'projeto.ilike.%$q%',
          )
          .order('criado_em', ascending: false)
          .limit(100);

      final list = (response as List)
          .map((e) => NotaLenha.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _results = list;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Notas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText:
                    'Buscar por nota, motorista, placa, cliente…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _results = [];
                            _searched = false;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (!_searched)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Digite para buscar notas',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Nenhuma nota encontrada',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${_results.length} resultado(s)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final n = _results[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(Icons.receipt_long,
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  size: 20),
                            ),
                            title: Text(
                              'Nota: ${n.numeroNota}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${n.dataNotaFormatada} | ${n.motorista}'),
                                Text(
                                    '${n.placaFormatada} | ${n.cliente}'),
                              ],
                            ),
                            trailing: Text(
                              '${n.totalM3Formatado} m³',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.notaDetalhe,
                              arguments: {'nota': n},
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
