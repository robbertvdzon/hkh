import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'backend/backend_client.dart';
import 'collection/collection_search.dart';
import 'collection/collection_search_page.dart';
import 'config/app_config.dart';
import 'news/latest_news.dart';
import 'product_vision_page.dart';
import 'self_update_prompt.dart';

void main() {
  final backend = BackendClient(AppConfig.apiBaseUrl);
  runApp(HkhApp(newsSource: backend, searchSource: backend));
}

class HkhApp extends StatelessWidget {
  const HkhApp({
    required this.newsSource,
    required this.searchSource,
    super.key,
  });

  final LatestNewsSource newsSource;
  final CollectionSearchSource searchSource;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Historisch Heemskerk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315B52),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomePage(newsSource: newsSource, searchSource: searchSource),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.newsSource,
    required this.searchSource,
    super.key,
  });

  final LatestNewsSource newsSource;
  final CollectionSearchSource searchSource;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybePromptSelfUpdate(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historisch Heemskerk')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _HomeContent(
                newsSource: widget.newsSource,
                searchSource: widget.searchSource,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.newsSource, required this.searchSource});

  final LatestNewsSource newsSource;
  final CollectionSearchSource searchSource;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Icon(
          Icons.account_balance,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        const Text(
          'Ontdek de geschiedenis van Heemskerk vanuit een vraag, plek, persoon of gebeurtenis.\n'
          'Verken betrouwbare historische bronnen en hun verbindingen met de wereld daarbuiten.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _HomeSearchSection(source: searchSource),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const ProductVisionPage(),
            ),
          ),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('Lees onze productvisie'),
        ),
        const SizedBox(height: 28),
        Text(
          'Laatste nieuws',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _LatestNewsSection(source: newsSource),
      ],
    );
  }
}

/// Zoekbalk direct op de startpagina: toont meteen een paar treffers, met een
/// link door naar het volledige zoekscherm (incl. uitgebreid zoeken per veld).
class _HomeSearchSection extends StatefulWidget {
  const _HomeSearchSection({required this.source});

  final CollectionSearchSource source;

  @override
  State<_HomeSearchSection> createState() => _HomeSearchSectionState();
}

class _HomeSearchSectionState extends State<_HomeSearchSection> {
  final _controller = TextEditingController();
  List<CollectionItemSummary>? _results;
  int _total = 0;
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final result = await widget.source.search(query: query, size: 3);
      if (!mounted) return;
      setState(() {
        _results = result.items;
        _total = result.total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _openFullSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CollectionSearchPage(
          source: widget.source,
          initialQuery: _controller.text.trim().isEmpty
              ? null
              : _controller.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  hintText: 'Zoek in de collectie…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _search, child: const Text('Zoeken')),
          ],
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ] else if (_searched) ...[
          const SizedBox(height: 12),
          if ((_results ?? const []).isEmpty)
            const Text('Geen resultaten gevonden.')
          else
            Column(
              children: [
                for (final item in _results!) ...[
                  _HomeResultTile(item: item, source: widget.source),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openFullSearch,
            icon: const Icon(Icons.manage_search),
            label: Text(
              _searched && _total > 0
                  ? 'Alle $_total resultaten en uitgebreid zoeken'
                  : 'Doorzoek de collectie',
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeResultTile extends StatelessWidget {
  const _HomeResultTile({required this.item, required this.source});

  final CollectionItemSummary item;
  final CollectionSearchSource source;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          item.imageUrl != null
              ? Icons.image_outlined
              : item.hasPdf
              ? Icons.picture_as_pdf_outlined
              : Icons.description_outlined,
        ),
        title: Text(
          item.title.isEmpty ? '(zonder titel)' : item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CollectionDetailPage(
              source: source,
              collection: item.collection,
              ident: item.ident,
              title: item.title,
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestNewsSection extends StatefulWidget {
  const _LatestNewsSection({required this.source});

  final LatestNewsSource source;

  @override
  State<_LatestNewsSection> createState() => _LatestNewsSectionState();
}

class _LatestNewsSectionState extends State<_LatestNewsSection> {
  late Future<List<LatestNewsItem>> _news;

  @override
  void initState() {
    super.initState();
    _news = widget.source.loadLatestNews();
  }

  @override
  void didUpdateWidget(covariant _LatestNewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) {
      _news = widget.source.loadLatestNews();
    }
  }

  void _retry() => setState(() => _news = widget.source.loadLatestNews());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LatestNewsItem>>(
      future: _news,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Het laatste nieuws kon niet worden geladen.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Opnieuw proberen'),
                  ),
                ],
              ),
            ),
          );
        }
        final news = snapshot.requireData;
        if (news.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Er zijn nog geen nieuwsberichten.'),
            ),
          );
        }
        return Column(
          children: news
              .map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(item.publishedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(item.message),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-${local.year}';
  }
}
