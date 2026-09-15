import 'package:flutter/material.dart';
import 'collection_config.dart';
import 'collection_search.dart';
import '../theme/app_style.dart';

/// Bundelt de invulvelden voor "Uitgebreid zoeken": Titel en Beschrijving (dezelfde
/// velden als in het zoekresultaat) en Jaar (exacte match). Bewust geen losse
/// invulvelden per collectie-specifiek attribuut - dat gaf een onoverzichtelijke,
/// tientallen velden lange lijst.
class SearchFieldControllers {
  final title = TextEditingController();
  final description = TextEditingController();
  final year = TextEditingController();
  final extra = <String, TextEditingController>{};

  void load(Map<String, String> values, int? exactYear) {
    title.text = values['title'] ?? '';
    description.text = values['description'] ?? '';
    year.text = exactYear?.toString() ?? '';
    for (final c in extra.values) {
      c.dispose();
    }
    extra.clear();
    for (final e in values.entries) {
      if (e.key != 'title' && e.key != 'description') {
        extra[e.key] = TextEditingController(text: e.value);
      }
    }
  }

  Map<String, String> get fieldQueries => {
    if (title.text.trim().isNotEmpty) 'title': title.text.trim(),
    if (description.text.trim().isNotEmpty)
      'description': description.text.trim(),
    for (final e in extra.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
  };

  int? get yearValue => int.tryParse(year.text.trim());

  void dispose() {
    title.dispose();
    description.dispose();
    year.dispose();
    for (final c in extra.values) {
      c.dispose();
    }
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
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class CollectionAdvancedControls extends StatelessWidget {
  const CollectionAdvancedControls({
    super.key,
    required this.collection,
    required this.controllers,
    required this.options,
    required this.onChanged,
    required this.onSubmit,
    required this.documentTextAvailable,
  });
  final String? collection;
  final SearchFieldControllers controllers;
  final CollectionSearchOptions options;
  final ValueChanged<CollectionSearchOptions> onChanged;
  final VoidCallback onSubmit;
  final bool documentTextAvailable;

  @override
  Widget build(BuildContext context) {
    final fields = searchFields(collection);
    if (!fields.containsKey(options.field)) {
      fields[options.field] = options.field;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final controls = [
                  DropdownButtonFormField<String>(
                    initialValue: options.mode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Zoekwoorden combineren',
                    ),
                    items: [
                      if (options.mode == 'web')
                        const DropdownMenuItem(
                          value: 'web',
                          child: Text('Alle woorden / aanhalingstekens'),
                        ),
                      const DropdownMenuItem(
                        value: 'and',
                        child: Text('Alle woorden (AND)'),
                      ),
                      const DropdownMenuItem(
                        value: 'or',
                        child: Text('Eén van de woorden (OR)'),
                      ),
                      const DropdownMenuItem(
                        value: 'phrase',
                        child: Text('Exacte tekst'),
                      ),
                    ],
                    onChanged: (v) => onChanged(options.copyWith(mode: v)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: options.field,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Zoeken in veld',
                    ),
                    items: [
                      for (final e in fields.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => onChanged(options.copyWith(field: v)),
                  ),
                ];
                return constraints.maxWidth < 580
                    ? Column(
                        children: [
                          controls[0],
                          const SizedBox(height: 16),
                          controls[1],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: controls[0]),
                          const SizedBox(width: 16),
                          Expanded(child: controls[1]),
                        ],
                      );
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Ook delen van woorden'),
              value: options.partial,
              onChanged: (v) => onChanged(
                options.copyWith(
                  partial: v,
                  mode: options.mode == 'web' ? 'and' : options.mode,
                ),
              ),
            ),
            if (collection == null ||
                collection == 'archief' ||
                collection == 'artikelen')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Ook documenttekst (OCR)'),
                subtitle: Text(
                  documentTextAvailable
                      ? 'Zoekt ook in geïmporteerde documenttekst.'
                      : 'Er is nog geen documenttekst geïmporteerd.',
                ),
                value: documentTextAvailable && options.documentText,
                onChanged: documentTextAvailable
                    ? (v) => onChanged(options.copyWith(documentText: v))
                    : null,
              ),
            const Divider(),
            const Text(
              'En deze velden bevatten:',
              style: TextStyle(color: appMutedText),
            ),
            const SizedBox(height: 8),
            AdvancedSearchFields(controllers: controllers, onSubmit: onSubmit),
            for (final entry in controllers.extra.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onSubmit(),
                        decoration: InputDecoration(
                          labelText: fields[entry.key] ?? entry.key,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Veld verwijderen',
                      onPressed: () {
                        controllers.extra.remove(entry.key)?.dispose();
                        onChanged(options);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final available = fields.entries
                        .where(
                          (e) =>
                              ![
                                'all',
                                'title',
                                'description',
                              ].contains(e.key) &&
                              !controllers.extra.containsKey(e.key),
                        )
                        .toList();
                    if (available.isEmpty) return;
                    final chosen = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Veld toevoegen'),
                        children: [
                          for (final e in available)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, e.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(e.value),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (chosen != null && context.mounted) {
                      controllers.extra[chosen] = TextEditingController();
                      onChanged(options);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Veld toevoegen'),
                ),
                FilledButton(
                  onPressed: onSubmit,
                  child: const Text('Zoek met deze instellingen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
