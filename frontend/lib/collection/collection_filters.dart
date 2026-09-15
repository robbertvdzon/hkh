import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import 'collection_search.dart';

class CollectionFacetDialog extends StatefulWidget {
  const CollectionFacetDialog({
    super.key,
    required this.source,
    required this.collection,
    required this.field,
    required this.query,
    required this.fieldQueries,
    required this.options,
    this.year,
  });
  final CollectionSearchSource source;
  final String collection, field, query;
  final Map<String, String> fieldQueries;
  final CollectionSearchOptions options;
  final int? year;
  @override
  State<CollectionFacetDialog> createState() => _CollectionFacetDialogState();
}

class _CollectionFacetDialogState extends State<CollectionFacetDialog> {
  final _search = TextEditingController();
  late final _selected = {...?widget.options.filters[widget.field]};
  Timer? _debounce;
  int _request = 0;
  CollectionFacet? _facet;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.source.loadFacet(
        collection: widget.collection,
        field: widget.field,
        query: widget.query,
        fieldQueries: widget.fieldQueries,
        year: widget.year,
        options: widget.options,
        valueQuery: _search.text.trim(),
      );
      if (mounted && id == _request) {
        setState(() {
          _facet = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && id == _request) {
        setState(() {
          _error = 'Filterwaarden konden niet worden geladen.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.field,
    maxWidth: 560,
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Zoek in ${widget.field.toLowerCase()}',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              ++_request;
              _debounce = Timer(const Duration(milliseconds: 250), _fetch);
            },
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final value in _selected)
                    Chip(
                      label: Text(value),
                      onDeleted: () => setState(() => _selected.remove(value)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _fetch,
              child: const Text('Opnieuw proberen'),
            ),
          ],
          if (!_loading && _error == null) ...[
            if (_facet!.values.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Geen filterwaarden gevonden.'),
              ),
            SizedBox(
              height: (_facet!.values.length * 72.0).clamp(0, 320),
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final v in _facet!.values)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(v.value),
                      secondary: Text(
                        '${v.count}',
                        style: const TextStyle(color: appMutedText),
                      ),
                      value: _selected.contains(v.value),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _selected.add(v.value);
                        } else {
                          _selected.remove(v.value);
                        }
                      }),
                    ),
                ],
              ),
            ),
            if (_facet!.totalValues > _facet!.values.length)
              Text(
                'Eerste ${_facet!.values.length} van ${_facet!.totalValues} waarden. Typ om verder te zoeken.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuleren'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, <String>[]),
        child: const Text('Wis dit filter'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _selected.toList()),
        child: const Text('Toepassen'),
      ),
    ],
  );
}

Future<CollectionSearchOptions?> showPeriodFilter(
  BuildContext context,
  CollectionSearchOptions options,
  String label,
) async {
  final from = TextEditingController(text: options.yearFrom?.toString() ?? '');
  final to = TextEditingController(text: options.yearTo?.toString() ?? '');
  final form = GlobalKey<FormState>();
  final result = await showDialog<CollectionSearchOptions>(
    context: context,
    builder: (context) => AppDialog(
      title: label,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: from,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Van jaar',
                hintText: 'Bijvoorbeeld 1900',
              ),
              validator: (v) => _validateYear(v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: to,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tot en met jaar',
                hintText: 'Bijvoorbeeld 1950',
              ),
              validator: (v) {
                final error = _validateYear(v);
                if (error != null) return error;
                final a = int.tryParse(from.text), b = int.tryParse(v ?? '');
                return a != null && b != null && a > b
                    ? 'Het eindjaar ligt vóór het beginjaar.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              label == 'Geboorteperiode'
                  ? 'Filtert op geboortejaar.'
                  : 'Laat een veld leeg voor een open periode.',
              style: const TextStyle(color: appMutedText),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, options.copyWith(clearPeriod: true)),
          child: const Text('Hele periode'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(
                context,
                options.copyWith(
                  yearFrom: int.tryParse(from.text),
                  yearTo: int.tryParse(to.text),
                  clearPeriod: true,
                ),
              );
            }
          },
          child: const Text('Toepassen'),
        ),
      ],
    ),
  );
  // The dialog's dismissal transition may still use the controllers.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  from.dispose();
  to.dispose();
  return result;
}

String? _validateYear(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final year = int.tryParse(value);
  return year == null || year < 1 || year > 2100
      ? 'Vul een jaar tussen 1 en 2100 in.'
      : null;
}
