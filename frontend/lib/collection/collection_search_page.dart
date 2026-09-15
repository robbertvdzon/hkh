import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../navigation.dart';
import '../theme/app_style.dart';
import 'collection_config.dart';
import 'collection_search.dart';
import 'collection_detail_page.dart';
import 'collection_filters.dart';
import 'img_embed/img_embed.dart';
import 'search_controls.dart';
export 'collection_detail_page.dart';

class CollectionSearchPage extends StatefulWidget {
  const CollectionSearchPage({
    required this.source,
    this.initialQuery,
    this.initialFieldQueries = const {},
    this.initialYear,
    this.initialCollection,
    this.initialPage = 0,
    this.initialOptions = const CollectionSearchOptions(),
    super.key,
  });
  final CollectionSearchSource source;
  final String? initialQuery, initialCollection;
  final Map<String, String> initialFieldQueries;
  final int? initialYear;
  final int initialPage;
  final CollectionSearchOptions initialOptions;
  @override
  State<CollectionSearchPage> createState() => _CollectionSearchPageState();
}

class _CollectionSearchPageState extends State<CollectionSearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _scrollController = ScrollController();
  final _fieldControllers = SearchFieldControllers();
  CollectionOverview? _overview;
  late String? _collection = widget.initialCollection;
  late CollectionSearchOptions _options = widget.initialOptions;
  late int _page = widget.initialPage;
  late bool _advancedOpen =
      widget.initialFieldQueries.isNotEmpty || widget.initialYear != null;
  bool _moreFilters = false, _loading = true, _documentTextAvailable = false;
  List<CollectionItemSummary> _results = [];
  int _request = 0, _total = 0;
  String? _error;
  final _saved =
      <
        String,
        ({
          CollectionSearchOptions options,
          Map<String, String> fields,
          int? year,
        })
      >{};
  @override
  void initState() {
    super.initState();
    _fieldControllers.load(widget.initialFieldQueries, widget.initialYear);
    _loadOverview();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant CollectionSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialCollection != widget.initialCollection ||
        oldWidget.initialPage != widget.initialPage ||
        oldWidget.initialYear != widget.initialYear ||
        oldWidget.initialOptions.toParameters().toString() !=
            widget.initialOptions.toParameters().toString() ||
        oldWidget.initialFieldQueries.toString() !=
            widget.initialFieldQueries.toString()) {
      _controller.text = widget.initialQuery ?? '';
      _collection = widget.initialCollection;
      _options = widget.initialOptions;
      _page = widget.initialPage;
      _fieldControllers.load(widget.initialFieldQueries, widget.initialYear);
      _fetch();
    }
  }

  @override
  void dispose() {
    _request++;
    _controller.dispose();
    _scrollController.dispose();
    _fieldControllers.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final overview = await widget.source.loadOverview();
      if (mounted) setState(() => _overview = overview);
    } catch (_) {
      /* Collection entrances remain available without counts. */
    }
  }

  void _runSearch({int page = 0}) {
    final yearText = _fieldControllers.year.text.trim();
    if (yearText.isNotEmpty &&
        (int.tryParse(yearText) == null ||
            int.parse(yearText) < 1 ||
            int.parse(yearText) > 2100)) {
      setState(() => _error = 'Vul een geldig jaar tussen 1 en 2100 in.');
      return;
    }
    final location = searchLocation(
      query: _controller.text.trim(),
      collection: _collection,
      fields: _fieldControllers.fieldQueries,
      year: _fieldControllers.yearValue,
      page: page,
      options: _options,
    );
    final router = GoRouter.maybeOf(context);
    if (router != null &&
        router.routeInformationProvider.value.uri.toString() != location) {
      router.go(location);
      return;
    }
    _page = page;
    _fetch();
  }

  Future<void> _fetch() async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final result = await widget.source.search(
        query: _controller.text.trim(),
        collection: _collection,
        fieldQueries: _fieldControllers.fieldQueries,
        year: _fieldControllers.yearValue,
        page: _page,
        size: 20,
        options: _options,
      );
      if (!mounted || id != _request) return;
      if (result.items.isEmpty && result.total > 0 && _page > 0) {
        _runSearch(page: (result.total - 1) ~/ 20);
        return;
      }
      setState(() {
        _results = result.items;
        _total = result.total;
        _loading = false;
        _documentTextAvailable = result.documentTextAvailable;
      });
    } catch (_) {
      if (mounted && id == _request) {
        setState(() {
          _loading = false;
          _error = 'Zoeken is mislukt. Probeer het opnieuw.';
        });
      }
    }
  }

  void _selectCollection(String? key) {
    _saved[_collection ?? 'all'] = (
      options: _options,
      fields: _fieldControllers.fieldQueries,
      year: _fieldControllers.yearValue,
    );
    final restored = _saved[key ?? 'all'];
    setState(() {
      _collection = key;
      _options = restored?.options ?? const CollectionSearchOptions();
      _fieldControllers.load(restored?.fields ?? {}, restored?.year);
      _moreFilters = false;
    });
    _runSearch();
  }

  void _reset() {
    _controller.clear();
    _fieldControllers.load({}, null);
    _options = const CollectionSearchOptions();
    _runSearch();
  }

  bool get _gallery =>
      (_options.view ??
          (collectionConfig(_collection).gallery ? 'gallery' : 'list')) ==
      'gallery';
  bool get _hasFilters =>
      _controller.text.trim().isNotEmpty ||
      _fieldControllers.fieldQueries.isNotEmpty ||
      _fieldControllers.yearValue != null ||
      _options.filters.isNotEmpty ||
      _options.yearFrom != null ||
      _options.yearTo != null ||
      _options.recentDays != null ||
      _options.field != 'all' ||
      _options.mode == 'or' ||
      _options.mode == 'phrase';
  Future<void> _facet(String field) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => CollectionFacetDialog(
        source: widget.source,
        collection: _collection!,
        field: field,
        query: _controller.text.trim(),
        fieldQueries: _fieldControllers.fieldQueries,
        year: _fieldControllers.yearValue,
        options: _options,
      ),
    );
    if (!mounted || selected == null) return;
    final filters = {..._options.filters};
    if (selected.isEmpty) {
      filters.remove(field);
    } else {
      filters[field] = selected;
    }
    _options = _options.copyWith(filters: filters);
    _runSearch();
  }

  Future<void> _period() async {
    final next = await showPeriodFilter(
      context,
      _options,
      collectionConfig(_collection).periodLabel,
    );
    if (mounted && next != null) {
      _options = next;
      _fieldControllers.year.clear();
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: appDossierTheme(context),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Collecties'),
          actions: [
            IconButton(
              tooltip: 'Hulp bij zoeken',
              icon: const Icon(Icons.help_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AppDialog(
                  title: 'Zoeken zoals u gewend bent',
                  content: const Text(
                    'Kies uw vertrouwde collectie of zoek in alles tegelijk. Een leeg zoekveld toont de hele collectie. Kies een thema of type om te bladeren. Uitgebreid zoeken biedt afzonderlijke velden, alle woorden (AND), één van de woorden (OR) en exacte tekst. Filters worden per collectie onthouden.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Sluiten'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.all(isNarrowLayout(context) ? 16 : 28),
                children: [
                  Text(
                    'HET GEHEUGEN VAN HEEMSKERK',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: appMutedText,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wat wilt u ontdekken?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Georgia',
                      color: appGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Zoek een naam, straat, onderwerp of collectienummer.',
                    style: TextStyle(color: appMutedText),
                  ),
                  const SizedBox(height: 20),
                  CollectionChips(
                    overview: _overview,
                    selected: _collection,
                    onSelect: _selectCollection,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final field = TextField(
                        key: const Key('collection-query'),
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                        decoration: InputDecoration(
                          labelText: 'Zoekterm',
                          hintText: _collection == 'bidprent'
                              ? 'Naam, geboorteplaats of volgnummer'
                              : 'Bijvoorbeeld: Marquette of Dorpskerk',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      );
                      final button = FilledButton.icon(
                        onPressed: () => _runSearch(),
                        icon: const Icon(Icons.search),
                        label: const Text('Zoeken'),
                      );
                      return c.maxWidth < 420
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                field,
                                const SizedBox(height: 10),
                                button,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: field),
                                const SizedBox(width: 12),
                                button,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Zoeken in ${collectionConfig(_collection).label.toLowerCase()} · leeg = alles',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: appMutedText),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _advancedOpen = !_advancedOpen),
                        icon: const Icon(Icons.tune),
                        label: const Text('Uitgebreid zoeken'),
                      ),
                    ],
                  ),
                  if (_advancedOpen)
                    CollectionAdvancedControls(
                      collection: _collection,
                      controllers: _fieldControllers,
                      options: _options,
                      documentTextAvailable: _documentTextAvailable,
                      onChanged: (o) => setState(() => _options = o),
                      onSubmit: () => _runSearch(),
                    ),
                  const SizedBox(height: 12),
                  _filters(context),
                  if (_hasFilters) ...[const SizedBox(height: 12), _chips()],
                  const SizedBox(height: 24),
                  _body(context),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _filters(BuildContext context) {
    final config = collectionConfig(_collection);
    final narrow = isNarrowLayout(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final field in config.facets)
          if (!narrow ||
              _moreFilters ||
              config.facets.indexOf(field) < 2 ||
              _options.filters.containsKey(field))
            OutlinedButton(
              onPressed: () => _facet(field),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '$field${_options.filters[field]?.isNotEmpty == true ? ' · ${_options.filters[field]!.length}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
        OutlinedButton.icon(
          onPressed: _period,
          icon: const Icon(Icons.date_range_outlined, size: 18),
          label: Text(config.periodLabel),
        ),
        if (!narrow || _moreFilters || config.facets.isEmpty)
          PopupMenuButton<int>(
            tooltip: 'Recent toegevoegd',
            onSelected: (days) {
              _options = _options.copyWith(
                recentDays: days == 0 ? null : days,
                clearRecent: true,
              );
              _runSearch();
            },
            itemBuilder: (_) => [
              for (final e in {
                7: 'Laatste week',
                30: 'Laatste maand',
                90: 'Laatste kwartaal',
                183: 'Laatste halfjaar',
                365: 'Laatste jaar',
                0: 'Alle toevoegdatums',
              }.entries)
                PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 6),
                  Text('Recent toegevoegd'),
                  Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        if (narrow && config.facets.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() => _moreFilters = !_moreFilters),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(_moreFilters ? 'Minder filters' : 'Alle filters'),
          ),
      ],
    );
  }

  Widget _chips() => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (_controller.text.trim().isNotEmpty)
        Chip(
          label: Text('Zoekterm: ${_controller.text.trim()}'),
          onDeleted: () {
            _controller.clear();
            _runSearch();
          },
        ),
      for (final entry in _options.filters.entries)
        for (final value in entry.value)
          Chip(
            label: Text('${entry.key}: $value'),
            onDeleted: () {
              final filters = {..._options.filters};
              final values = entry.value.where((v) => v != value).toList();
              if (values.isEmpty) {
                filters.remove(entry.key);
              } else {
                filters[entry.key] = values;
              }
              _options = _options.copyWith(filters: filters);
              _runSearch();
            },
          ),
      if (_options.yearFrom != null || _options.yearTo != null)
        Chip(
          label: Text(
            '${_collection == 'bidprent' ? 'Geboren' : 'Jaar'}: ${_options.yearFrom ?? '…'}–${_options.yearTo ?? '…'}',
          ),
          onDeleted: () {
            _options = _options.copyWith(clearPeriod: true);
            _runSearch();
          },
        ),
      if (_options.recentDays != null)
        Chip(
          label: Text('Toegevoegd: laatste ${_options.recentDays} dagen'),
          onDeleted: () {
            _options = _options.copyWith(clearRecent: true);
            _runSearch();
          },
        ),
      for (final entry in _fieldControllers.fieldQueries.entries)
        Chip(
          label: Text(
            '${searchFields(_collection)[entry.key] ?? entry.key}: ${entry.value}',
          ),
          onDeleted: () {
            if (entry.key == 'title') {
              _fieldControllers.title.clear();
            } else if (entry.key == 'description') {
              _fieldControllers.description.clear();
            } else {
              _fieldControllers.extra.remove(entry.key)?.dispose();
            }
            _runSearch();
          },
        ),
      if (_fieldControllers.yearValue != null)
        Chip(
          label: Text('Jaar: ${_fieldControllers.yearValue}'),
          onDeleted: () {
            _fieldControllers.year.clear();
            _runSearch();
          },
        ),
      if (_options.field != 'all' ||
          _options.mode == 'or' ||
          _options.mode == 'phrase')
        ActionChip(
          label: Text(
            '${_options.mode == 'or'
                ? 'Eén van de woorden'
                : _options.mode == 'phrase'
                ? 'Exacte tekst'
                : 'Alle woorden'} · ${searchFields(_collection)[_options.field] ?? _options.field}',
          ),
          onPressed: () => setState(() => _advancedOpen = true),
        ),
      TextButton(onPressed: _reset, child: const Text('Wis zoekopdracht')),
    ],
  );
  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          Text(_error!, semanticsLabel: _error),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
            label: const Text('Opnieuw proberen'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                '$_total ${_total == 1 ? 'resultaat' : 'resultaten'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_options.sort),
                    initialValue: _options.sort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sorteer op',
                      isDense: true,
                    ),
                    items: [
                      for (final e in {
                        'relevance': 'Standaardvolgorde',
                        'number': collectionConfig(_collection).number,
                        'title': _collection == 'bidprent'
                            ? 'Naam A–Z'
                            : 'Titel A–Z',
                        'newest': _collection == 'bidprent'
                            ? 'Geboortejaar: nieuw–oud'
                            : 'Jaar: nieuw–oud',
                        'oldest': _collection == 'bidprent'
                            ? 'Geboortejaar: oud–nieuw'
                            : 'Jaar: oud–nieuw',
                        'author': 'Auteur A–Z',
                        'added': 'Recent toegevoegd',
                      }.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      _options = _options.copyWith(sort: value);
                      _runSearch();
                    },
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'list',
                      label: Text('Lijst'),
                      icon: Icon(Icons.view_list_outlined),
                    ),
                    ButtonSegment(
                      value: 'gallery',
                      label: Text('Galerij'),
                      icon: Icon(Icons.grid_view),
                    ),
                  ],
                  selected: {_gallery ? 'gallery' : 'list'},
                  onSelectionChanged: (values) {
                    _options = _options.copyWith(view: values.single);
                    _runSearch(page: _page);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Text('Geen resultaten gevonden.'),
                const SizedBox(height: 8),
                const Text('Probeer minder woorden of verwijder een filter.'),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Wis filters en bekijk alles'),
                ),
              ],
            ),
          )
        else if (_gallery)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 480
                  ? 1
                  : constraints.maxWidth < 850
                  ? 2
                  : 3;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in _results)
                    SizedBox(
                      width: width,
                      child: CollectionResultCard(
                        item: item,
                        gallery: true,
                        onTap: () => _openDetail(item),
                      ),
                    ),
                ],
              );
            },
          )
        else ...[
          for (final item in _results)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CollectionResultCard(
                item: item,
                onTap: () => _openDetail(item),
              ),
            ),
        ],
        if (_total > 20)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Vorige pagina',
                  onPressed: _page > 0
                      ? () => _runSearch(page: _page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Flexible(
                  child: Text(
                    'Pagina ${_page + 1} van ${(_total / 20).ceil()}',
                  ),
                ),
                IconButton(
                  tooltip: 'Volgende pagina',
                  onPressed: (_page + 1) * 20 < _total
                      ? () => _runSearch(page: _page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _openDetail(CollectionItemSummary item) {
    final router = GoRouter.maybeOf(context);
    final searchUri =
        router?.routeInformationProvider.value.uri ??
        Uri.parse(
          searchLocation(
            query: _controller.text,
            collection: _collection,
            fields: _fieldControllers.fieldQueries,
            year: _fieldControllers.yearValue,
            page: _page,
            options: _options,
          ),
        );
    final location = searchUri.replace(
      path:
          '/zoeken/objecten/${Uri.encodeComponent(item.collection)}/${Uri.encodeComponent(item.ident)}',
    );
    final results = CollectionResultContext(
      items: _results,
      total: _total,
      page: _page,
      searchUri: searchUri,
    );
    if (router != null) {
      router.push(location.toString(), extra: results);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailPage(
            source: widget.source,
            collection: item.collection,
            ident: item.ident,
            title: item.title,
            resultContext: results,
          ),
        ),
      );
    }
  }
}

class CollectionChips extends StatelessWidget {
  const CollectionChips({
    required this.overview,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final CollectionOverview? overview;
  final String? selected;
  final ValueChanged<String?> onSelect;
  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final c in overview?.collections ?? <CollectionCount>[])
        c.collection: c.count,
    };
    final keys = [
      ...collectionConfigs.map((c) => c.key),
      ...counts.keys.where((k) => !collectionConfigs.any((c) => c.key == k)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: Text(
            'Alles${overview == null ? '' : ' (${overview!.total})'}',
          ),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final key in keys)
          Tooltip(
            message: counts.containsKey(key)
                ? '${counts[key]} items in deze collectie'
                : 'Zoeken in ${collectionConfig(key).label}',
            child: ChoiceChip(
              label: Text(
                '${collectionConfig(key).label}${counts.containsKey(key) ? ' (${counts[key]})' : ''}',
              ),
              selected: selected == key,
              onSelected: (_) => onSelect(key),
            ),
          ),
      ],
    );
  }
}

class CollectionResultCard extends StatelessWidget {
  const CollectionResultCard({
    super.key,
    required this.item,
    required this.onTap,
    this.gallery = false,
  });
  final CollectionItemSummary item;
  final VoidCallback onTap;
  final bool gallery;
  @override
  Widget build(BuildContext context) {
    final config = collectionConfig(item.collection);
    final metadata = itemMetadata(item.collection, item.year, item.fields);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(config.icon, size: 15, color: appMutedText),
            Text(
              config.label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: appMutedText),
            ),
            Text(
              item.ident,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: appMutedText),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          collectionTitle(item.title, item.collection, item.fields),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'Georgia',
            color: appGreen,
          ),
        ),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            metadata,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: appMutedText),
          ),
        ],
        if (!gallery && item.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: gallery ? double.infinity : 76,
        height: gallery ? 180 : 92,
        child: IgnorePointer(
          child: item.imageUrl == null && item.thumbnailUrl == null
              ? item.hasPdf
                    ? ColoredBox(
                        color: appAccentBackground,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: appMutedText,
                              size: 34,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Scan beschikbaar',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: appMutedText),
                            ),
                          ],
                        ),
                      )
                    : ColoredBox(
                        color: appAccentBackground,
                        child: Icon(config.icon, color: appMutedText, size: 28),
                      )
              : buildNetworkImage(
                  item.imageUrl ?? item.thumbnailUrl!,
                  fit: gallery ? BoxFit.contain : BoxFit.cover,
                  placeholder: (context) => ColoredBox(
                    color: appAccentBackground,
                    child: Icon(config.icon, color: appMutedText),
                  ),
                ),
        ),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: gallery
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, const SizedBox(height: 14), text],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    image,
                    const SizedBox(width: 14),
                    Expanded(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}
