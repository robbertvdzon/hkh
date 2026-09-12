import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'backend/backend_client.dart';
import 'ai_search/ai_search.dart';
import 'ai_search/ai_search_page.dart';
import 'collection/collection_search.dart';
import 'collection/collection_search_page.dart';
import 'collection/img_embed/img_embed.dart';
import 'collection/search_controls.dart';
import 'config/app_config.dart';
import 'self_update_prompt.dart';

void main() {
  final backend = BackendClient(AppConfig.apiBaseUrl);
  runApp(HkhApp(searchSource: backend, aiSearchSource: backend));
}

class HkhApp extends StatelessWidget {
  const HkhApp({required this.searchSource, this.aiSearchSource, super.key});

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;

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
      home: HomePage(
        searchSource: searchSource,
        aiSearchSource: aiSearchSource,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({required this.searchSource, this.aiSearchSource, super.key});

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;

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
                searchSource: widget.searchSource,
                aiSearchSource: widget.aiSearchSource,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.searchSource,
    required this.aiSearchSource,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;

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
        if (aiSearchSource != null) ...[
          _AiHomeCard(source: aiSearchSource!),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'of zoek zelf',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _HomeSearchSection(source: searchSource),
      ],
    );
  }
}

class _AiHomeCard extends StatefulWidget {
  const _AiHomeCard({required this.source});
  final AiSearchSource source;

  @override
  State<_AiHomeCard> createState() => _AiHomeCardState();
}

class _AiHomeCardState extends State<_AiHomeCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    final question = _controller.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiSearchPage(
          source: widget.source,
          initialQuestion: question.isEmpty ? null : question,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Vraag het archief',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Stel een vrije vraag. De digitale onderzoeker zoekt zelf de relevante bronnen, verhalen en afbeeldingen bij elkaar.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _open(),
            decoration: InputDecoration(
              hintText: 'Bijv. wat is er bekend over de Kerklaan?',
              prefixIcon: const Icon(Icons.question_answer_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _open,
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Vraag stellen',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Zoekbalk direct op de startpagina, mét "Uitgebreid zoeken": toont meteen een
/// paar treffers, met een link door naar het volledige zoekscherm.
class _HomeSearchSection extends StatefulWidget {
  const _HomeSearchSection({required this.source});

  final CollectionSearchSource source;

  @override
  State<_HomeSearchSection> createState() => _HomeSearchSectionState();
}

class _HomeSearchSectionState extends State<_HomeSearchSection> {
  final _controller = TextEditingController();
  final _fieldControllers = SearchFieldControllers();
  bool _advancedOpen = false;
  List<CollectionItemSummary>? _results;
  int _total = 0;
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    _fieldControllers.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    final fieldQueries = _fieldControllers.fieldQueries;
    final year = _fieldControllers.yearValue;
    if (query.isEmpty && fieldQueries.isEmpty && year == null) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final result = await widget.source.search(
        query: query,
        fieldQueries: fieldQueries,
        year: year,
        size: 3,
      );
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
          initialFieldQueries: _fieldControllers.fieldQueries,
          initialYear: _fieldControllers.yearValue,
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
        const SizedBox(height: 4),
        Text(
          'Los woorden voor een EN-zoekopdracht, of zet een zin tussen '
          '"aanhalingstekens" voor een exacte frase.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => setState(() => _advancedOpen = !_advancedOpen),
          icon: Icon(_advancedOpen ? Icons.expand_less : Icons.expand_more),
          label: const Text('Uitgebreid zoeken'),
        ),
        if (_advancedOpen) ...[
          const SizedBox(height: 4),
          AdvancedSearchFields(
            controllers: _fieldControllers,
            onSubmit: _search,
          ),
        ],
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
                  ? 'Alle $_total resultaten'
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
        leading: SizedBox(
          width: 40,
          height: 40,
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: buildNetworkImage(item.imageUrl!, fit: BoxFit.cover),
                )
              : Icon(
                  item.hasPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.description_outlined,
                ),
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
