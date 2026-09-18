import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'answer_html.dart';
import 'answer_sharing.dart';

class SharedAnswerPage extends StatefulWidget {
  const SharedAnswerPage({
    required this.source,
    required this.token,
    super.key,
  });
  final AiAnswerShareSource source;
  final String token;
  @override
  State<SharedAnswerPage> createState() => _SharedAnswerPageState();
}

class _SharedAnswerPageState extends State<SharedAnswerPage> {
  late Future<SharedAiAnswer?> _answer = widget.source.loadSharedAnswer(
    widget.token,
  );
  @override
  void didUpdateWidget(covariant SharedAnswerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _answer = widget.source.loadSharedAnswer(widget.token);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: HkhAppBar(context: context, title: const Text('Gedeeld antwoord')),
    body: FutureBuilder<SharedAiAnswer?>(
      future: _answer,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final answer = snapshot.data;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: EdgeInsets.all(isNarrowLayout(context) ? 16 : 28),
              children: [
                if (snapshot.hasError)
                  AppCard(
                    child: Column(
                      children: [
                        const Text('Het antwoord kon niet worden geladen.'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(
                            () => _answer = widget.source.loadSharedAnswer(
                              widget.token,
                            ),
                          ),
                          child: const Text('Opnieuw proberen'),
                        ),
                      ],
                    ),
                  )
                else if (answer == null)
                  const AppCard(
                    child: Column(
                      children: [
                        Icon(Icons.link_off, size: 36, color: appMutedText),
                        SizedBox(height: 16),
                        Text(
                          'Deze deellink is niet meer beschikbaar.',
                          style: TextStyle(fontSize: 22, color: appGreen),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'De eigenaar heeft het delen gestopt of de link is onjuist. Vraag de afzender om een nieuwe link.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    'GEDEELD UIT HET HKH-ARCHIEF',
                    style: TextStyle(
                      color: appMutedText,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SelectionArea(
                    child: Text(
                      answer.title ?? 'Een antwoord uit het archief',
                      style: const TextStyle(
                        fontFamily: 'HkhSerif',
                        fontSize: 28,
                        color: appGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gedeeld op ${answer.sharedAt.day}-${answer.sharedAt.month}-${answer.sharedAt.year} · Onderzocht met AI',
                    style: const TextStyle(color: appMutedText),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    color: appAccentBackground,
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'De vraag',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: appGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            answer.question,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: SelectionArea(child: AnswerHtml(answer.answerHtml)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
