import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'backend/backend_client.dart';
import 'backend/backend_status.dart';
import 'config/app_config.dart';
import 'self_update_prompt.dart';

void main() {
  runApp(HkhApp(statusSource: BackendClient(AppConfig.apiBaseUrl)));
}

class HkhApp extends StatelessWidget {
  const HkhApp({required this.statusSource, super.key});

  final BackendStatusSource statusSource;

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
      home: HomePage(statusSource: statusSource),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({required this.statusSource, super.key});

  final BackendStatusSource statusSource;

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
                  return _ReadyState(status: snapshot.requireData);
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
  const _ReadyState({required this.status});

  final BackendStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.account_balance,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'Ontdek de geschiedenis van Heemskerk',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Dit is de technische basis. Verhalen, plaatsen en historische bronnen worden in volgende productiteraties toegevoegd.',
          textAlign: TextAlign.center,
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
      ],
    );
  }
}
