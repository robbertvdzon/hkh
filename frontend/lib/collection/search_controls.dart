import 'package:flutter/material.dart';
import 'collection_config.dart';
import 'collection_search.dart';
import '../theme/app_style.dart';

/// Invoer voor gericht zoeken, inclusief zelf toegevoegde collectievelden.
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

class CollectionAdvancedControls extends StatelessWidget {
  const CollectionAdvancedControls({
    super.key,
    required this.collection,
    required this.controllers,
    required this.options,
    required this.onChanged,
    required this.onSubmit,
    required this.onReset,
    required this.onPeriod,
    this.yearError,
  });
  final String? collection;
  final String? yearError;
  final SearchFieldControllers controllers;
  final CollectionSearchOptions options;
  final ValueChanged<CollectionSearchOptions> onChanged;
  final VoidCallback onSubmit, onReset, onPeriod;

  @override
  Widget build(BuildContext context) {
    final fields = searchFields(collection);
    final available = fields.entries
        .where(
          (e) =>
              ![
                'all',
                'title',
                'description',
                'title_description',
                'name_place',
              ].contains(e.key) &&
              !controllers.extra.containsKey(e.key),
        )
        .toList();
    final period = options.yearFrom != null || options.yearTo != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vul in wat u weet. Resultaten voldoen aan alle ingevulde velden.',
              style: TextStyle(color: appMutedText),
            ),
            const SizedBox(height: 20),
            _field('Titel', controllers.title),
            const SizedBox(height: 20),
            _field('Beschrijving', controllers.description),
            const SizedBox(height: 20),
            if (!period)
              _field('Jaar', controllers.year, number: true)
            else
              Text(
                '${collectionConfig(collection).periodLabel}: '
                '${options.yearFrom ?? '…'} – ${options.yearTo ?? '…'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onPeriod,
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(
                      period ? 'Periode wijzigen' : 'Periode invullen',
                    ),
                  ),
                  if (period)
                    TextButton(
                      onPressed: () =>
                          onChanged(options.copyWith(clearPeriod: true)),
                      child: const Text('Eén jaar invullen'),
                    ),
                ],
              ),
            ),
            for (final entry in controllers.extra.entries)
              Padding(
                key: ValueKey(entry.key),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        fields[entry.key] ?? entry.key,
                        entry.value,
                      ),
                    ),
                    IconButton(
                      tooltip: '${fields[entry.key] ?? entry.key} verwijderen',
                      onPressed: () {
                        final removed = controllers.extra.remove(entry.key);
                        onChanged(options);
                        // The old field is still mounted until the next frame.
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => removed?.dispose(),
                        );
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: available.isEmpty
                    ? null
                    : () async {
                        final chosen = await showDialog<String>(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: const Text('Zoekveld toevoegen'),
                            children: [
                              for (final entry in available)
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, entry.key),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(entry.value),
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
                label: const Text('Zoekveld toevoegen'),
              ),
            ),
            if (collection == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Kies een collectie voor extra zoekvelden, zoals Straatnaam bij Beeldbank.',
                style: TextStyle(color: appMutedText),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                TextButton(onPressed: onReset, child: const Text('Wissen')),
                FilledButton.icon(
                  key: const Key('targeted-search-submit'),
                  onPressed: onSubmit,
                  icon: const Icon(Icons.search),
                  label: const Text('Zoeken'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) => TextField(
    controller: controller,
    keyboardType: number ? TextInputType.number : null,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => onSubmit(),
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: number ? 'Bijvoorbeeld 1950' : null,
      errorText: number ? yearError : null,
    ),
  );
}
