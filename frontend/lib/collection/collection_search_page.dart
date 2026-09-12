import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'collection_search.dart';
import 'img_embed/img_embed.dart';
import 'pdf_embed/pdf_embed.dart';
import 'search_controls.dart';

/// Zoekscherm over alle gescrapete ZCBS-collecties.
class CollectionSearchPage extends StatefulWidget {
  const CollectionSearchPage({
    required this.source,
    this.initialQuery,
    this.initialFieldQueries = const {},
    this.initialYear,
    super.key,
  });

  final CollectionSearchSource source;

  /// Vooraf ingevulde zoekterm (bv. vanaf de startpagina); start meteen een zoekopdracht.
  final String? initialQuery;
  final Map<String, String> initialFieldQueries;
  final int? initialYear;

  @override
  State<CollectionSearchPage> createState() => _CollectionSearchPageState();
}

class _CollectionSearchPageState extends State<CollectionSearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _scrollController = ScrollController();
  late final _fieldControllers = SearchFieldControllers()
    ..title.text = widget.initialFieldQueries['title'] ?? ''
    ..description.text = widget.initialFieldQueries['description'] ?? ''
    ..year.text = widget.initialYear?.toString() ?? '';

  CollectionOverview? _overview;
  String? _collectionFilter;
  late bool _advancedOpen =
      widget.initialFieldQueries.isNotEmpty || widget.initialYear != null;
  final List<CollectionItemSummary> _results = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadOverview();
    final hasInitialQuery =
        widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty;
    if (hasInitialQuery || _advancedOpen) {
      _runSearch();
    }
  }

  @override
  void dispose() {
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
      // Overzicht is niet kritiek; het zoeken werkt ook zonder.
    }
  }

  Future<void> _runSearch({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
        _results.clear();
        _searched = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await widget.source.search(
        query: _controller.text,
        collection: _collectionFilter,
        fieldQueries: _fieldControllers.fieldQueries,
        year: _fieldControllers.yearValue,
        page: _page,
        size: 20,
      );
      if (!mounted) return;
      setState(() {
        _results.addAll(result.items);
        _total = result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Zoeken is mislukt. Probeer het opnieuw.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _results.length >= _total) return;
    _page += 1;
    await _runSearch(reset: false);
  }

  void _selectCollection(String? collection) {
    setState(() => _collectionFilter = collection);
    if (_searched) _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doorzoek de collectie')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchBar(
                    controller: _controller,
                    onSubmit: () => _runSearch(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los woorden voor een EN-zoekopdracht, of zet een zin '
                    'tussen "aanhalingstekens" voor een exacte frase.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _advancedOpen = !_advancedOpen),
                    icon: Icon(
                      _advancedOpen ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: const Text('Uitgebreid zoeken'),
                  ),
                  if (_advancedOpen) ...[
                    const SizedBox(height: 4),
                    AdvancedSearchFields(
                      controllers: _fieldControllers,
                      onSubmit: () => _runSearch(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  _CollectionChips(
                    overview: _overview,
                    selected: _collectionFilter,
                    onSelect: _selectCollection,
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _runSearch(),
              icon: const Icon(Icons.refresh),
              label: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      );
    }
    if (!_searched) {
      final total = _overview?.total;
      return Center(
        child: Text(
          total == null
              ? 'Typ een zoekterm om de historische collectie te doorzoeken.'
              : 'Doorzoek $total items uit de collectie van de HKH.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('Geen resultaten gevonden.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$_total resultaten',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: _results.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == _results.length) {
                if (_results.length >= _total) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: _loadMore,
                            child: const Text('Meer laden'),
                          ),
                  ),
                );
              }
              return _ResultCard(
                item: _results[index],
                onTap: () => _openDetail(_results[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDetail(CollectionItemSummary item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionDetailPage(
          source: widget.source,
          collection: item.collection,
          ident: item.ident,
          title: item.title,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: 'Zoek op titel, auteur, plaats, jaar…',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: onSubmit,
        ),
      ),
    );
  }
}

/// Lijst van alle bekende velden onder elkaar, elk met een eigen invulveld.
/// Ingevulde velden gelden als EN, naast de algemene zoekbalk; leeg = geen
/// beperking op dat veld.
class _CollectionChips extends StatelessWidget {
  const _CollectionChips({
    required this.overview,
    required this.selected,
    required this.onSelect,
  });

  final CollectionOverview? overview;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final overview = this.overview;
    if (overview == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: Text('Alles (${overview.total})'),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final c in overview.collections)
          ChoiceChip(
            label: Text('${_label(c.collection)} (${c.count})'),
            selected: selected == c.collection,
            onSelected: (_) => onSelect(c.collection),
          ),
      ],
    );
  }

  String _label(String key) => switch (key) {
    'artikelen' => 'Artikelen',
    'archief' => 'Archief',
    'beeldbank' => "Foto's",
    'library' => 'Bibliotheek',
    'bidprent' => 'Bidprentjes',
    'objecten' => 'Objecten',
    'transcripties' => 'Transcripties',
    _ => key,
  };
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.onTap});

  final CollectionItemSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: item.imageUrl, hasPdf: item.hasPdf),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? '(zonder titel)' : item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item.year != null) '${item.year}',
                        item.collection,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.hasPdf});

  final String? url;
  final bool hasPdf;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    if (url == null) {
      return Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          hasPdf
              ? Icons.picture_as_pdf_outlined
              : Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: buildNetworkImage(
        url!,
        fit: BoxFit.cover,
        placeholder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

/// Detailpagina die alle metadata + het volledige beeld toont.
class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    required this.source,
    required this.collection,
    required this.ident,
    required this.title,
    super.key,
  });

  final CollectionSearchSource source;
  final String collection;
  final String ident;
  final String title;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late Future<CollectionItemDetail> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.source.loadDetail(widget.collection, widget.ident);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? 'Detail' : widget.title),
      ),
      body: SafeArea(
        child: FutureBuilder<CollectionItemDetail>(
          future: _detail,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Dit item kon niet worden geladen.'),
              );
            }
            final detail = snapshot.requireData;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: SelectionArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (detail.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 420,
                            child: buildNetworkImage(
                              detail.imageUrl!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        detail.title.isEmpty ? '(zonder titel)' : detail.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (detail.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(detail.description),
                      ],
                      if (detail.pdfUrl != null) ...[
                        const SizedBox(height: 16),
                        _PdfBlock(url: detail.pdfUrl!),
                      ],
                      const SizedBox(height: 16),
                      _FieldsTable(fields: detail.fields),
                      const SizedBox(height: 16),
                      Text(
                        'Bron op de HKH-website:',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      _LinkText(url: detail.detailUrl),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FieldsTable extends StatelessWidget {
  const _FieldsTable({required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final entries = fields.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final e in entries)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Text(
                  e.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(e.value),
              ),
            ],
          ),
      ],
    );
  }
}

/// Toont de PDF ingesloten in de pagina (op web), met daaronder knoppen om 'm
/// in een nieuw tabblad te openen of te downloaden. Op platforms zonder
/// ingesloten weergave (nog) blijven alleen de knoppen over.
class _PdfBlock extends StatelessWidget {
  const _PdfBlock({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (supportsEmbeddedPdf)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 600,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: buildEmbeddedPdf(url),
            ),
          ),
        SizedBox(height: supportsEmbeddedPdf ? 8 : 0),
        SelectionContainer.disabled(
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in nieuwe pagina'),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Klikbare bron-URL. Selectie staat hier bewust uit (SelectionContainer.disabled)
/// zodat een tik betrouwbaar de link opent i.p.v. tekst te selecteren.
class _LinkText extends StatelessWidget {
  const _LinkText({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Text(
          url,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
