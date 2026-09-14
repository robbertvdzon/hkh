import 'package:flutter/material.dart';

/// Bundelt de invulvelden voor "Uitgebreid zoeken": Titel en Beschrijving (dezelfde
/// velden als in het zoekresultaat) en Jaar (exacte match). Bewust geen losse
/// invulvelden per collectie-specifiek attribuut - dat gaf een onoverzichtelijke,
/// tientallen velden lange lijst.
class SearchFieldControllers {
  final title = TextEditingController();
  final description = TextEditingController();
  final year = TextEditingController();

  Map<String, String> get fieldQueries => {
    if (title.text.trim().isNotEmpty) 'title': title.text.trim(),
    if (description.text.trim().isNotEmpty)
      'description': description.text.trim(),
  };

  int? get yearValue => int.tryParse(year.text.trim());

  void dispose() {
    title.dispose();
    description.dispose();
    year.dispose();
  }
}

/// De drie invulvelden onder elkaar, elk optioneel; alle ingevulde velden gelden
/// als EN naast de algemene zoekbalk.
class AdvancedSearchFields extends StatelessWidget {
  const AdvancedSearchFields({
    required this.controllers,
    required this.onSubmit,
    super.key,
  });

  final SearchFieldControllers controllers;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            _row(context, 'Titel', controllers.title),
            _row(context, 'Beschrijving', controllers.description),
            _row(
              context,
              'Jaar',
              controllers.year,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
