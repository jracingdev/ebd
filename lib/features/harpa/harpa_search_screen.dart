import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/features/harpa/harpa_reader_screen.dart';
import 'package:livro_registro/services/harpa_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class HarpaSearchScreen extends StatefulWidget {
  const HarpaSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<HarpaSearchScreen> createState() => _HarpaSearchScreenState();
}

class _HarpaSearchScreenState extends State<HarpaSearchScreen> {
  late final _ctrl = TextEditingController(text: widget.initialQuery);
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<HarpaRepository>();
    final results = repo.search(_query);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Buscar hinos'),
      body: ResponsiveShell(
        maxWidth: 720,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Número ou título…',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum hino encontrado.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final e = results[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: AppColors.ink.withValues(alpha: 0.08),
                            ),
                          ),
                          tileColor: Colors.white,
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.green.withValues(alpha: 0.12),
                            foregroundColor: AppColors.green,
                            child: Text(
                              '${e.number}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(e.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    HarpaReaderScreen(number: e.number),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
