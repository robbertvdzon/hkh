import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'backend/backend_client.dart';
import 'backend/backend_status.dart';
import 'config/app_config.dart';
import 'news/latest_news.dart';
import 'product_vision_page.dart';
import 'self_update_prompt.dart';

void main() {
  final backend = BackendClient(AppConfig.apiBaseUrl);
  runApp(HkhApp(statusSource: backend, newsSource: backend));
}

class HkhApp extends StatelessWidget {
  const HkhApp({
    required this.statusSource,
    required this.newsSource,
    super.key,
  });

  final BackendStatusSource statusSource;
  final LatestNewsSource newsSource;

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
      home: HomePage(statusSource: statusSource, newsSource: newsSource),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.statusSource,
    required this.newsSource,
    super.key,
  });

  final BackendStatusSource statusSource;
  final LatestNewsSource newsSource;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<BackendStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = widget.statusSource.load();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybePromptSelfUpdate(context);
      });
    }
  }

  void _retry() => setState(() => _status = widget.statusSource.load());

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
              child: FutureBuilder<BackendStatus>(
                future: _status,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _LoadingState();
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(onRetry: _retry);
                  }
                  return _ReadyState(
                    status: snapshot.requireData,
                    newsSource: widget.newsSource,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('De historische omgeving wordt voorbereid…'),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'De HKH-service is niet bereikbaar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Controleer de verbinding en probeer het opnieuw.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Opnieuw proberen'),
        ),
      ],
    );
  }
}

class _ReadyState extends StatelessWidget {
  const _ReadyState({required this.status, required this.newsSource});

  final BackendStatus status;
  final LatestNewsSource newsSource;

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
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Service beschikbaar'),
            subtitle: Text(
              '${status.application} ${status.version} · ${status.commit}',
            ),
          ),
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
