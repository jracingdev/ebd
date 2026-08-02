import 'package:flutter/material.dart';
import 'package:livro_registro/data/bible/bible_models.dart';
import 'package:livro_registro/theme/app_theme.dart';

/// Seletor de capítulo com scroll real (GridView) — funciona em livros longos
/// (Salmos 150, Isaías 66, etc.).
Future<int?> showBibleChapterPicker(
  BuildContext context, {
  required BibleBook book,
  int? currentChapter,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final maxH = (size.height * 0.72).clamp(280.0, 640.0);
      final maxW = (size.width * 0.92).clamp(280.0, 420.0);

      return Dialog(
        backgroundColor: AppColors.cream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SizedBox(
          width: maxW,
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${book.name} · ${book.chapters} capítulos',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: book.chapters,
                  itemBuilder: (context, index) {
                    final n = index + 1;
                    final selected = currentChapter == n;
                    return Material(
                      color: selected ? AppColors.green : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(ctx, n),
                        child: Center(
                          child: Text(
                            '$n',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
