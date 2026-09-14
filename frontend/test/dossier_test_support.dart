import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/dossier/dossier.dart';

final testDate = DateTime(2026, 9, 12, 10);

DossierSummary dossierSummary({
  String id = 'd1',
  String title = 'De Kerklaan',
  String goal = 'Artikel voor het verenigingsblad',
  DossierRole role = DossierRole.owner,
  int questionCount = 2,
  int articleCount = 1,
  int memberCount = 1,
}) => DossierSummary(
  id: id,
  title: title,
  goal: goal,
  role: role,
  ownerEmail: 'jan@example.com',
  memberCount: memberCount,
  questionCount: questionCount,
  articleCount: articleCount,
  createdAt: testDate,
  updatedAt: testDate,
);

FactSheet factSheet({
  String markdown = '- Kerklaan 12: familie Jansen (1932)',
  String html = '<ul><li>Kerklaan 12: familie Jansen (1932)</li></ul>',
  String status = 'IDLE',
  bool dirty = false,
  String? error,
}) => FactSheet(
  markdown: markdown,
  html: html,
  sources: const [],
  status: status,
  dirty: dirty,
  updatedAt: testDate,
  error: error,
);

ArticleSummary articleSummary({
  String id = 'a1',
  String title = 'De bewoners van de Kerklaan',
  int version = 2,
  String? proposalState,
}) => ArticleSummary(
  id: id,
  title: title,
  currentVersionNumber: version,
  proposalState: proposalState,
  createdByEmail: 'jan@example.com',
  createdAt: testDate,
  updatedAt: testDate,
);

/// Lid van een dossier, standaard met een gewoon kort e-mailadres.
Member member({
  String email = 'lid@example.com',
  DossierRole role = DossierRole.researcher,
}) => Member(email: email, role: role);

/// Formaten waarop ieder scherm getest wordt: smal (≤600px) en breed.
const narrowSize = Size(360, 780);
const wideSize = Size(1280, 900);

/// Extreem smal scherm voor de overflowtests.
const tinySize = Size(320, 720);

/// Zet het testvenster; wordt na de test weer teruggedraaid.
void setViewport(WidgetTester tester, Size size, {double textScaleFactor = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pompt [home] op het gevraagde formaat en wacht tot alles stil staat.
Future<void> pumpDossierApp(
  WidgetTester tester,
  Widget home, {
  required Size size,
  double textScaleFactor = 1,
}) async {
  setViewport(tester, size, textScaleFactor: textScaleFactor);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

/// Scherm met één knop die een dialoog opent.
class DialogHost extends StatelessWidget {
  const DialogHost({required this.open, super.key});

  final Future<void> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => FilledButton(
          onPressed: () => open(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

/// Opent de dialoog van een [DialogHost].
Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Het vlak van de dialoog zelf (zonder de marges eromheen).
Rect dialogSurfaceRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);

/// De achtergrond en rand van een kaart uit `AppCard`.
BoxDecoration cardDecoration(WidgetTester tester, Key key) {
  final ink = tester.widget<Ink>(
    find.descendant(of: find.byKey(key), matching: find.byType(Ink)).first,
  );
  return ink.decoration! as BoxDecoration;
}

/// De decoratie van een gekleurde chip (rolchip, statuschip).
BoxDecoration chipDecoration(WidgetTester tester, Key key) =>
    tester.widget<Container>(find.byKey(key)).decoration! as BoxDecoration;

/// De afronding van een `RoundedRectangleBorder`-vorm.
BorderRadius radiusOf(ShapeBorder? shape) =>
    (shape! as RoundedRectangleBorder).borderRadius as BorderRadius;

/// De vorm van een knop zoals die uit het thema bij [finder] volgt.
BorderRadius buttonRadius(WidgetTester tester, Finder finder) {
  final theme = Theme.of(tester.element(finder));
  return radiusOf(theme.filledButtonTheme.style!.shape!.resolve({}));
}

/// De rand van een tekstveld zoals die na het thema geldt.
InputBorder fieldBorder(WidgetTester tester, Finder field) {
  final decorator = tester.widget<InputDecorator>(
    find.descendant(of: field, matching: find.byType(InputDecorator)).first,
  );
  return decorator.decoration.border!;
}

/// Controleert dat er niets buiten het venster valt en niets is overgelopen.
void expectNoHorizontalOverflow(WidgetTester tester, List<Finder> finders) {
  expect(tester.takeException(), isNull);
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (final finder in finders) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$finder');
      expect(rect.right, lessThanOrEqualTo(width + 0.5), reason: '$finder');
    }
  }
}

DossierDetail dossierDetail({
  String id = 'd1',
  String title = 'De Kerklaan',
  DossierRole role = DossierRole.owner,
  FactSheet? sheet,
  List<Member> members = const [],
  List<ArticleSummary>? articles,
}) => DossierDetail(
  id: id,
  title: title,
  goal: 'Artikel voor het verenigingsblad',
  role: role,
  ownerEmail: 'jan@example.com',
  members: members,
  factSheet: sheet ?? factSheet(),
  questions: const [],
  articles: articles ?? [articleSummary()],
  createdAt: testDate,
  updatedAt: testDate,
);

ArticleVersion articleVersion({
  String id = 'v2',
  int number = 2,
  String title = 'De bewoners van de Kerklaan',
  String markdown =
      'De familie Jansen woonde op [Kerklaan 12](hkh:beeldbank/1).',
  String html =
      '<p>De familie Jansen woonde op <a href="https://example.test/beeldbank/1">Kerklaan 12</a>.</p>',
  String authorKind = 'USER',
  String state = 'ACCEPTED',
  String? jobStatus,
  String? progressMessage,
  String? changeSummary,
  String? aiInstruction,
  List<String> unknownSources = const [],
}) => ArticleVersion(
  id: id,
  versionNumber: number,
  title: title,
  contentMarkdown: markdown,
  contentHtml: html,
  sources: const [
    ArticleSource(
      collection: 'beeldbank',
      ident: '1',
      title: 'Kerklaan 12 in 1932',
      detailUrl: 'https://example.test/beeldbank/1',
      imageUrl: null,
    ),
  ],
  unknownSources: unknownSources,
  authorKind: authorKind,
  authorEmail: authorKind == 'AI' ? null : 'jan@example.com',
  aiInstruction: aiInstruction,
  changeSummary: changeSummary,
  state: state,
  jobStatus: jobStatus,
  progressMessage: progressMessage,
  errorMessage: null,
  basedOnVersionNumber: number > 1 ? number - 1 : null,
  createdAt: testDate,
  decidedAt: null,
  decidedByEmail: null,
);

ArticleDetail articleDetail({
  String id = 'a1',
  DossierRole role = DossierRole.owner,
  ArticleVersion? current,
  ArticleVersion? proposal,
}) => ArticleDetail(
  id: id,
  dossierId: 'd1',
  dossierTitle: 'De Kerklaan',
  title: (current ?? articleVersion()).title,
  role: role,
  current: current ?? articleVersion(),
  proposal: proposal,
  versionCount: 2,
  createdAt: testDate,
  updatedAt: testDate,
);

VersionSummary versionSummary({
  required int number,
  bool isCurrent = false,
  String authorKind = 'USER',
  String state = 'ACCEPTED',
  String? changeSummary,
  String? aiInstruction,
}) => VersionSummary(
  id: 'v$number',
  versionNumber: number,
  title: 'De bewoners van de Kerklaan',
  authorKind: authorKind,
  authorEmail: authorKind == 'AI' ? null : 'jan@example.com',
  aiInstruction: aiInstruction,
  changeSummary: changeSummary,
  state: state,
  jobStatus: null,
  errorMessage: null,
  basedOnVersionNumber: number > 1 ? number - 1 : null,
  isCurrent: isCurrent,
  createdAt: testDate,
  decidedAt: null,
  decidedByEmail: null,
);

/// In-memory dossierbron voor widget-tests. Registreert aanroepen in [calls].
class FakeDossierSource implements DossierSource {
  FakeDossierSource({
    List<DossierSummary>? dossiers,
    DossierDetail? detail,
    ArticleDetail? article,
    List<VersionSummary>? versions,
  }) : dossiers = dossiers ?? [dossierSummary()],
       detail = detail ?? dossierDetail(),
       article = article ?? articleDetail(),
       versions =
           versions ??
           [
             versionSummary(number: 2, isCurrent: true),
             versionSummary(number: 1),
           ];

  List<DossierSummary> dossiers;
  DossierDetail detail;
  ArticleDetail article;
  List<VersionSummary> versions;
  final List<String> calls = [];
  Map<String, Object?>? lastSave;

  @override
  Future<List<DossierSummary>> listDossiers() async {
    calls.add('listDossiers');
    return dossiers;
  }

  @override
  Future<DossierDetail> createDossier({
    required String title,
    required String goal,
  }) async {
    calls.add('createDossier:$title');
    return detail;
  }

  @override
  Future<DossierDetail> loadDossier(String dossierId) async {
    calls.add('loadDossier:$dossierId');
    return detail;
  }

  @override
  Future<DossierDetail> updateDossier(
    String dossierId, {
    required String title,
    required String goal,
  }) async {
    calls.add('updateDossier:$title');
    return detail;
  }

  @override
  Future<void> deleteDossier(String dossierId) async {
    calls.add('deleteDossier:$dossierId');
  }

  @override
  Future<DossierDetail> setMember(
    String dossierId,
    String email,
    DossierRole role,
  ) async {
    calls.add('setMember:$email:${role.wireName}');
    return detail;
  }

  @override
  Future<void> removeMember(String dossierId, String email) async {
    calls.add('removeMember:$email');
  }

  @override
  Future<DossierDetail> updateFactSheet(
    String dossierId,
    String markdown,
  ) async {
    calls.add('updateFactSheet:$markdown');
    return detail;
  }

  @override
  Future<DossierDetail> refreshFactSheet(String dossierId) async {
    calls.add('refreshFactSheet');
    return detail;
  }

  @override
  Future<List<AiSearchSummary>> listQuestions(String dossierId) async {
    calls.add('listQuestions');
    return detail.questions;
  }

  @override
  Future<AiSearchSession> askQuestion(String dossierId, String question) async {
    calls.add('askQuestion:$question');
    return const AiSearchSession(id: 'q1', turns: []);
  }

  @override
  Future<AiSearchSession> loadQuestion(
    String dossierId,
    String sessionId,
  ) async => const AiSearchSession(id: 'q1', turns: []);

  @override
  Future<AiSearchSession> askFollowUpQuestion(
    String dossierId,
    String sessionId,
    String question,
  ) async => const AiSearchSession(id: 'q1', turns: []);

  @override
  Future<AiSearchSession> cancelQuestion(
    String dossierId,
    String sessionId,
  ) async => const AiSearchSession(id: 'q1', turns: []);

  @override
  Future<void> deleteQuestion(String dossierId, String sessionId) async {}

  @override
  Future<AiSearchSession> adoptSearch(
    String dossierId,
    String sessionId,
  ) async {
    calls.add('adoptSearch:$dossierId:$sessionId');
    return const AiSearchSession(id: 'q1', turns: []);
  }

  @override
  Future<List<ArticleSummary>> listArticles(String dossierId) async =>
      detail.articles;

  @override
  Future<ArticleDetail> createArticle(
    String dossierId, {
    required String title,
    required String contentMarkdown,
  }) async {
    calls.add('createArticle:$title');
    return article;
  }

  @override
  Future<ArticleDetail> generateArticle(
    String dossierId, {
    required String title,
    required String instruction,
  }) async {
    calls.add('generateArticle:$title');
    return article;
  }

  @override
  Future<ArticleDetail> loadArticle(String articleId) async {
    calls.add('loadArticle:$articleId');
    return article;
  }

  @override
  Future<ArticleDetail> saveArticle(
    String articleId, {
    required String title,
    required String contentMarkdown,
    required String basedOnVersionId,
  }) async {
    calls.add('saveArticle');
    lastSave = {
      'title': title,
      'contentMarkdown': contentMarkdown,
      'basedOnVersionId': basedOnVersionId,
    };
    article = articleDetail(
      current: articleVersion(
        id: 'v3',
        number: 3,
        title: title,
        markdown: contentMarkdown,
        html: '<p>$contentMarkdown</p>',
      ),
    );
    return article;
  }

  @override
  Future<void> deleteArticle(String articleId) async {
    calls.add('deleteArticle:$articleId');
  }

  @override
  Future<List<VersionSummary>> listVersions(String articleId) async {
    calls.add('listVersions');
    return versions;
  }

  @override
  Future<ArticleVersion> loadVersion(
    String articleId,
    int versionNumber,
  ) async => articleVersion(number: versionNumber);

  @override
  Future<ArticleDiff> loadDiff(
    String articleId, {
    required int versionNumber,
    required int against,
  }) async {
    calls.add('loadDiff:$versionNumber:$against');
    return ArticleDiff(
      fromVersion: against,
      toVersion: versionNumber,
      lines: const [
        DiffLine(
          type: 'EQUAL',
          text: 'De familie Jansen woonde op de Kerklaan.',
        ),
        DiffLine(type: 'DELETE', text: 'Oude regel.'),
        DiffLine(type: 'INSERT', text: 'Nieuwe regel over de school.'),
      ],
    );
  }

  @override
  Future<ArticleDetail> restoreVersion(
    String articleId,
    int versionNumber,
  ) async {
    calls.add('restoreVersion:$versionNumber');
    return article;
  }

  @override
  Future<ArticleDetail> proposeChange(
    String articleId, {
    required String instruction,
    required String basedOnVersionId,
  }) async {
    calls.add('proposeChange:$instruction:$basedOnVersionId');
    return article;
  }

  @override
  Future<ArticleDetail> acceptProposal(
    String articleId,
    String versionId,
  ) async {
    calls.add('acceptProposal:$versionId');
    article = articleDetail(current: article.proposal!);
    return article;
  }

  @override
  Future<ArticleDetail> rejectProposal(
    String articleId,
    String versionId,
  ) async {
    calls.add('rejectProposal:$versionId');
    article = articleDetail(current: article.current);
    return article;
  }
}
