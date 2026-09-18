import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_style.dart';
import 'collection_config.dart';
import 'collection_search.dart';
import 'img_embed/img_embed.dart';
import 'pdf_embed/pdf_embed.dart';

class CollectionResultContext {
  const CollectionResultContext({
    required this.items,
    required this.total,
    required this.page,
    required this.searchUri,
  });
  final List<CollectionItemSummary> items;
  final int total, page;
  final Uri searchUri;
}

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    required this.source,
    required this.collection,
    required this.ident,
    required this.title,
    this.resultContext,
    this.searchUri,
    super.key,
  });
  final CollectionSearchSource source;
  final String collection, ident, title;
  final CollectionResultContext? resultContext;
  final Uri? searchUri;
  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late Future<CollectionItemDetail> _detail;
  CollectionResultContext? _results;
  bool _zoom = false, _navigating = false;
  String _tab = 'details';
  @override
  void initState() {
    super.initState();
    _detail = widget.source.loadDetail(widget.collection, widget.ident);
    _results = widget.resultContext;
    if (_results == null && widget.searchUri != null) _loadContext();
  }

  Future<CollectionResultContext> _loadResults(Uri uri, int page) async {
    final q = uri.queryParameters;
    final result = await widget.source.search(
      query: q['q'] ?? '',
      collection: q['collection'],
      fieldQueries: {
        for (final e in q.entries)
          if (e.key.startsWith('field.')) e.key.substring(6): e.value,
      },
      year: int.tryParse(q['year'] ?? ''),
      page: page,
      options: CollectionSearchOptions.fromParameters(uri.queryParametersAll),
    );
    return CollectionResultContext(
      items: result.items,
      total: result.total,
      page: page,
      searchUri: uri,
    );
  }

  Future<void> _loadContext() async {
    try {
      final uri = widget.searchUri!;
      final result = await _loadResults(
        uri,
        int.tryParse(uri.queryParameters['page'] ?? '') ?? 0,
      );
      if (mounted) setState(() => _results = result);
    } catch (_) {
      /* The object itself remains usable if the original search fails. */
    }
  }

  Future<void> _next(int step) async {
    final current = _results;
    if (current == null) return;
    setState(() => _navigating = true);
    try {
      var results = current;
      var index =
          results.items.indexWhere(
            (r) => r.collection == widget.collection && r.ident == widget.ident,
          ) +
          step;
      if (index < 0 || index >= results.items.length) {
        results = await _loadResults(current.searchUri, current.page + step);
        index = step < 0 ? results.items.length - 1 : 0;
      }
      if (!mounted) return;
      if (index < 0 || index >= results.items.length) {
        setState(() => _navigating = false);
        return;
      }
      final item = results.items[index];
      final uri = results.searchUri.replace(
        path:
            '/zoeken/objecten/${Uri.encodeComponent(item.collection)}/${Uri.encodeComponent(item.ident)}',
        queryParameters: {
          ...results.searchUri.queryParametersAll,
          'page': ['${results.page}'],
        },
      );
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.replace(uri.toString(), extra: results);
      } else {
        Navigator.of(context).pushReplacement(
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
    } catch (_) {
      if (mounted) {
        setState(() => _navigating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Het volgende resultaat kon niet worden geladen. Probeer opnieuw.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: appDossierTheme(context),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: HkhAppBar(
          context: context,
          title: Text(collectionConfig(widget.collection).label),
        ),
        body: SafeArea(
          child: FutureBuilder<CollectionItemDetail>(
            future: _detail,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Dit item kon niet worden geladen.'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(
                          () => _detail = widget.source.loadDetail(
                            widget.collection,
                            widget.ident,
                          ),
                        ),
                        child: const Text('Opnieuw proberen'),
                      ),
                    ],
                  ),
                );
              }
              final detail = snapshot.requireData,
                  config = collectionConfig(detail.collection);
              final currentIndex =
                  _results?.items.indexWhere(
                    (r) =>
                        r.collection == widget.collection &&
                        r.ident == widget.ident,
                  ) ??
                  -1;
              final position = currentIndex < 0
                  ? null
                  : _results!.page * 20 + currentIndex;
              final metadata = itemMetadata(
                detail.collection,
                detail.year,
                detail.fields,
              );
              final text = detail.fields.entries
                  .where(
                    (e) => documentFieldNames.any(
                      (k) => k.toLowerCase() == e.key.toLowerCase(),
                    ),
                  )
                  .map((e) => e.value)
                  .where((v) => v.trim().isNotEmpty)
                  .join('\n\n');
              final core = <String, String>{
                config.number: detail.ident,
                if (detail.year != null && detail.collection != 'bidprent')
                  'Jaar': '${detail.year}',
                for (final k in config.detailFields)
                  if (detail.fields[k]?.trim().isNotEmpty == true)
                    k: detail.fields[k]!,
              };
              final data = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(config.icon, size: 18, color: appMutedText),
                      Text(
                        '${config.label} · ${detail.ident}',
                        style: const TextStyle(color: appMutedText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    collectionTitle(
                      detail.title,
                      detail.collection,
                      detail.fields,
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Georgia',
                      color: appGreen,
                    ),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(metadata, style: const TextStyle(color: appMutedText)),
                  ],
                  if (detail.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(detail.description),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final e in {
                        'details': config.detailsLabel,
                        'original': 'Alle bronvelden',
                        if (text.isNotEmpty) 'text': 'Documenttekst',
                      }.entries)
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text(e.value),
                          selected: _tab == e.key,
                          onSelected: (_) => setState(() => _tab = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_tab == 'text') ...[
                    Text(text),
                    const SizedBox(height: 12),
                    const Text(
                      'Herkende documenttekst kan fouten bevatten. Controleer de scan.',
                      style: TextStyle(color: appMutedText),
                    ),
                  ] else
                    _FieldsTable(
                      fields: _tab == 'original' ? detail.fields : core,
                    ),
                  if (detail.collection == 'library')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Een catalogusvermelding betekent niet dat het volledige boek digitaal beschikbaar is.',
                        style: TextStyle(color: appMutedText),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text('Link naar dit object:'),
                  const SizedBox(height: 4),
                  _LinkText(url: detail.detailUrl),
                ],
              );
              final media = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (detail.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(appCardRadius),
                      child: ColoredBox(
                        color: appAccentBackground,
                        child: SizedBox(
                          height: _zoom ? 680 : 400,
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 6,
                            child: buildNetworkImage(
                              detail.imageUrl!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _zoom = !_zoom),
                          icon: Icon(_zoom ? Icons.zoom_out : Icons.zoom_in),
                          label: Text(_zoom ? 'Verkleinen' : 'Vergroten'),
                        ),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(detail.imageUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Afbeelding openen'),
                        ),
                      ],
                    ),
                  ],
                  if (detail.pdfUrl != null) ...[
                    const SizedBox(height: 16),
                    _PdfBlock(url: detail.pdfUrl!),
                  ],
                  if (detail.imageUrl == null && detail.pdfUrl == null)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: appAccentBackground,
                        borderRadius: BorderRadius.circular(appCardRadius),
                      ),
                      child: Column(
                        children: [
                          Icon(config.icon, size: 48, color: appMutedText),
                          const SizedBox(height: 12),
                          Text(
                            detail.collection == 'library'
                                ? 'Geen digitale uitgave beschikbaar'
                                : 'Geen afbeelding beschikbaar',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              );
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: SelectionArea(
                    child: ListView(
                      padding: EdgeInsets.all(
                        isNarrowLayout(context) ? 16 : 28,
                      ),
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (GoRouter.maybeOf(context)?.canPop() ??
                                Navigator.canPop(context))
                              TextButton.icon(
                                onPressed: () {
                                  final router = GoRouter.maybeOf(context);
                                  if (router != null) {
                                    router.pop();
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Terug naar resultaten'),
                              ),
                            if (position != null)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${position + 1} van ${_results!.total}',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Vorig resultaat',
                                    onPressed: position > 0 && !_navigating
                                        ? () => _next(-1)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  IconButton(
                                    tooltip: 'Volgend resultaat',
                                    onPressed:
                                        position + 1 < _results!.total &&
                                            !_navigating
                                        ? () => _next(1)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, c) => c.maxWidth < 800
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    data,
                                    const SizedBox(height: 24),
                                    media,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: media),
                                    const SizedBox(width: 28),
                                    Expanded(child: data),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _FieldsTable extends StatelessWidget {
  const _FieldsTable({required this.fields});
  final Map<String, String> fields;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in fields.entries.where((e) => e.value.trim().isNotEmpty))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: appCardBorder)),
            ),
            child: constraints.maxWidth < 400
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: const TextStyle(color: appMutedText)),
                      const SizedBox(height: 4),
                      Text(e.value),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          e.key,
                          style: const TextStyle(color: appMutedText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: Text(e.value)),
                    ],
                  ),
          ),
      ],
    ),
  );
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
