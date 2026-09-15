import 'dart:typed_data';

import '../ai_search/ai_search.dart';

/// Rol van de ingelogde gebruiker in een dossier. De volgorde loopt op in rechten.
enum DossierRole {
  reader('READER', 'Lezer'),
  researcher('RESEARCHER', 'Onderzoeker'),
  editor('EDITOR', 'Bewerker'),
  owner('OWNER', 'Eigenaar');

  const DossierRole(this.wireName, this.label);

  /// Naam zoals de backend die gebruikt.
  final String wireName;

  /// Nederlandse naam voor in de UI.
  final String label;

  static DossierRole fromJson(Object? value) => DossierRole.values.firstWhere(
    (role) => role.wireName == value,
    orElse: () => DossierRole.reader,
  );

  bool get canResearch => index >= DossierRole.researcher.index;
  bool get canEdit => index >= DossierRole.editor.index;
  bool get canManage => this == DossierRole.owner;

  /// Rollen die een eigenaar aan een lid kan geven.
  static const assignable = [
    DossierRole.reader,
    DossierRole.researcher,
    DossierRole.editor,
  ];
}

DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

class DossierSummary {
  const DossierSummary({
    required this.id,
    required this.title,
    required this.goal,
    required this.role,
    required this.ownerEmail,
    required this.memberCount,
    required this.questionCount,
    required this.articleCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DossierSummary.fromJson(Map<String, dynamic> json) => DossierSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    goal: json['goal'] as String? ?? '',
    role: DossierRole.fromJson(json['role']),
    ownerEmail: json['ownerEmail'] as String? ?? '',
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    articleCount: (json['articleCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String title;
  final String goal;
  final DossierRole role;
  final String ownerEmail;
  final int memberCount;
  final int questionCount;
  final int articleCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Member {
  const Member({required this.email, required this.role});

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    email: json['email'] as String,
    role: DossierRole.fromJson(json['role']),
  );

  final String email;
  final DossierRole role;
}

class FactSheet {
  const FactSheet({
    required this.markdown,
    required this.html,
    required this.sources,
    required this.status,
    required this.dirty,
    required this.updatedAt,
    required this.error,
  });

  factory FactSheet.fromJson(Map<String, dynamic> json) => FactSheet(
    markdown: json['markdown'] as String? ?? '',
    html: json['html'] as String? ?? '',
    sources: ArticleSource.listFromJson(json['sources']),
    status: json['status'] as String? ?? 'IDLE',
    dirty: json['dirty'] as bool? ?? false,
    updatedAt: _optionalDate(json['updatedAt']),
    error: json['error'] as String?,
  );

  final String markdown;
  final String html;
  final List<ArticleSource> sources;

  /// IDLE, RUNNING of FAILED.
  final String status;
  final bool dirty;
  final DateTime? updatedAt;
  final String? error;

  bool get isRunning => status == 'RUNNING';
  bool get isFailed => status == 'FAILED';
}

class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    required this.currentVersionNumber,
    required this.proposalState,
    required this.createdByEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) => ArticleSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    currentVersionNumber: (json['currentVersionNumber'] as num?)?.toInt() ?? 0,
    proposalState: json['proposalState'] as String?,
    createdByEmail: json['createdByEmail'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String title;
  final int currentVersionNumber;

  /// null zonder open voorstel, anders RUNNING (AI schrijft nog) of READY.
  final String? proposalState;
  final String? createdByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class DossierDetail {
  const DossierDetail({
    required this.id,
    required this.title,
    required this.goal,
    required this.role,
    required this.ownerEmail,
    required this.members,
    required this.factSheet,
    required this.questions,
    required this.articles,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DossierDetail.fromJson(Map<String, dynamic> json) => DossierDetail(
    id: json['id'] as String,
    title: json['title'] as String,
    goal: json['goal'] as String? ?? '',
    role: DossierRole.fromJson(json['role']),
    ownerEmail: json['ownerEmail'] as String? ?? '',
    members: (json['members'] as List<dynamic>? ?? const [])
        .map((item) => Member.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    factSheet: FactSheet.fromJson(
      json['factSheet'] as Map<String, dynamic>? ?? const {},
    ),
    questions: (json['questions'] as List<dynamic>? ?? const [])
        .map((item) => AiSearchSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    articles: (json['articles'] as List<dynamic>? ?? const [])
        .map((item) => ArticleSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String title;
  final String goal;
  final DossierRole role;
  final String ownerEmail;
  final List<Member> members;
  final FactSheet factSheet;
  final List<AiSearchSummary> questions;
  final List<ArticleSummary> articles;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Een archiefbron waarnaar een artikel of feitenlijst verwijst.
class ArticleSource {
  const ArticleSource({
    required this.collection,
    required this.ident,
    required this.title,
    required this.detailUrl,
    required this.imageUrl,
  });

  factory ArticleSource.fromJson(Map<String, dynamic> json) => ArticleSource(
    collection: json['collection'] as String? ?? '',
    ident: json['ident'] as String? ?? '',
    title: json['title'] as String? ?? '',
    detailUrl: json['detailUrl'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
  );

  static List<ArticleSource> listFromJson(Object? value) =>
      (value as List<dynamic>? ?? const [])
          .map((item) => ArticleSource.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

  final String collection;
  final String ident;
  final String title;
  final String detailUrl;
  final String? imageUrl;

  String get ref => '$collection/$ident';
}

/// Volledige versie van een artikel, inclusief gerenderde HTML.
class ArticleVersion {
  const ArticleVersion({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.contentMarkdown,
    required this.contentHtml,
    required this.sources,
    required this.unknownSources,
    required this.authorKind,
    required this.authorEmail,
    required this.aiInstruction,
    required this.changeSummary,
    required this.state,
    required this.jobStatus,
    required this.progressMessage,
    required this.errorMessage,
    required this.basedOnVersionNumber,
    required this.createdAt,
    required this.decidedAt,
    required this.decidedByEmail,
  });

  factory ArticleVersion.fromJson(Map<String, dynamic> json) => ArticleVersion(
    id: json['id'] as String,
    versionNumber: (json['versionNumber'] as num).toInt(),
    title: json['title'] as String? ?? '',
    contentMarkdown: json['contentMarkdown'] as String? ?? '',
    contentHtml: json['contentHtml'] as String? ?? '',
    sources: ArticleSource.listFromJson(json['sources']),
    unknownSources: (json['unknownSources'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    authorKind: json['authorKind'] as String? ?? 'USER',
    authorEmail: json['authorEmail'] as String?,
    aiInstruction: json['aiInstruction'] as String?,
    changeSummary: json['changeSummary'] as String?,
    state: json['state'] as String? ?? 'ACCEPTED',
    jobStatus: json['jobStatus'] as String?,
    progressMessage: json['progressMessage'] as String?,
    errorMessage: json['errorMessage'] as String?,
    basedOnVersionNumber: (json['basedOnVersionNumber'] as num?)?.toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    decidedAt: _optionalDate(json['decidedAt']),
    decidedByEmail: json['decidedByEmail'] as String?,
  );

  final String id;
  final int versionNumber;
  final String title;
  final String contentMarkdown;
  final String contentHtml;
  final List<ArticleSource> sources;
  final List<String> unknownSources;

  /// USER of AI.
  final String authorKind;
  final String? authorEmail;
  final String? aiInstruction;
  final String? changeSummary;

  /// ACCEPTED, PROPOSED of REJECTED.
  final String state;

  /// SUBMITTING, RUNNING, SUCCEEDED, FAILED of CANCELLED; alleen bij AI-versies.
  final String? jobStatus;
  final String? progressMessage;
  final String? errorMessage;
  final int? basedOnVersionNumber;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decidedByEmail;

  bool get isAi => authorKind == 'AI';

  /// Of de AI nog aan deze versie schrijft.
  bool get jobActive => const {'SUBMITTING', 'RUNNING'}.contains(jobStatus);
  bool get jobFailed => jobStatus == 'FAILED';
}

class VersionSummary {
  const VersionSummary({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.authorKind,
    required this.authorEmail,
    required this.aiInstruction,
    required this.changeSummary,
    required this.state,
    required this.jobStatus,
    required this.errorMessage,
    required this.basedOnVersionNumber,
    required this.isCurrent,
    required this.createdAt,
    required this.decidedAt,
    required this.decidedByEmail,
  });

  factory VersionSummary.fromJson(Map<String, dynamic> json) => VersionSummary(
    id: json['id'] as String,
    versionNumber: (json['versionNumber'] as num).toInt(),
    title: json['title'] as String? ?? '',
    authorKind: json['authorKind'] as String? ?? 'USER',
    authorEmail: json['authorEmail'] as String?,
    aiInstruction: json['aiInstruction'] as String?,
    changeSummary: json['changeSummary'] as String?,
    state: json['state'] as String? ?? 'ACCEPTED',
    jobStatus: json['jobStatus'] as String?,
    errorMessage: json['errorMessage'] as String?,
    basedOnVersionNumber: (json['basedOnVersionNumber'] as num?)?.toInt(),
    isCurrent: json['isCurrent'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    decidedAt: _optionalDate(json['decidedAt']),
    decidedByEmail: json['decidedByEmail'] as String?,
  );

  final String id;
  final int versionNumber;
  final String title;
  final String authorKind;
  final String? authorEmail;
  final String? aiInstruction;
  final String? changeSummary;
  final String state;
  final String? jobStatus;
  final String? errorMessage;
  final int? basedOnVersionNumber;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decidedByEmail;

  bool get isAi => authorKind == 'AI';
}

class ArticleDetail {
  const ArticleDetail({
    required this.id,
    required this.dossierId,
    required this.dossierTitle,
    required this.title,
    required this.role,
    required this.current,
    required this.proposal,
    required this.versionCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) => ArticleDetail(
    id: json['id'] as String,
    dossierId: json['dossierId'] as String,
    dossierTitle: json['dossierTitle'] as String? ?? '',
    title: json['title'] as String,
    role: DossierRole.fromJson(json['role']),
    current: ArticleVersion.fromJson(json['current'] as Map<String, dynamic>),
    proposal: json['proposal'] == null
        ? null
        : ArticleVersion.fromJson(json['proposal'] as Map<String, dynamic>),
    versionCount: (json['versionCount'] as num?)?.toInt() ?? 1,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String dossierId;
  final String dossierTitle;
  final String title;
  final DossierRole role;
  final ArticleVersion current;
  final ArticleVersion? proposal;
  final int versionCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class DiffLine {
  const DiffLine({required this.type, required this.text});

  factory DiffLine.fromJson(Map<String, dynamic> json) => DiffLine(
    type: json['type'] as String? ?? 'EQUAL',
    text: json['text'] as String? ?? '',
  );

  /// EQUAL, INSERT of DELETE.
  final String type;
  final String text;
}

/// Verschil van `fromVersion` naar `toVersion`.
class ArticleDiff {
  const ArticleDiff({
    required this.fromVersion,
    required this.toVersion,
    required this.lines,
  });

  factory ArticleDiff.fromJson(Map<String, dynamic> json) => ArticleDiff(
    fromVersion: (json['fromVersion'] as num).toInt(),
    toVersion: (json['toVersion'] as num).toInt(),
    lines: (json['lines'] as List<dynamic>? ?? const [])
        .map((item) => DiffLine.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final int fromVersion;
  final int toVersion;
  final List<DiffLine> lines;
}

/// Alle dossier- en artikelroutes van de backend.
abstract interface class DossierSource {
  Future<List<DossierSummary>> listDossiers();
  Future<DossierDetail> createDossier({
    required String title,
    required String goal,
  });
  Future<DossierDetail> loadDossier(String dossierId);
  Future<DossierDetail> updateDossier(
    String dossierId, {
    required String title,
    required String goal,
  });
  Future<void> deleteDossier(String dossierId);

  Future<DossierDetail> setMember(
    String dossierId,
    String email,
    DossierRole role,
  );
  Future<void> removeMember(String dossierId, String email);

  Future<DossierDetail> updateFactSheet(String dossierId, String markdown);
  Future<DossierDetail> refreshFactSheet(String dossierId);

  Future<List<AiSearchSummary>> listQuestions(String dossierId);
  Future<AiSearchSession> askQuestion(String dossierId, String question);
  Future<AiSearchSession> loadQuestion(String dossierId, String sessionId);
  Future<AiSearchSession> askFollowUpQuestion(
    String dossierId,
    String sessionId,
    String question,
  );
  Future<AiSearchSession> cancelQuestion(String dossierId, String sessionId);
  Future<void> deleteQuestion(String dossierId, String sessionId);
  Future<AiSearchSession> adoptSearch(String dossierId, String sessionId);

  Future<List<ArticleSummary>> listArticles(String dossierId);
  Future<ArticleDetail> createArticle(
    String dossierId, {
    required String title,
    required String contentMarkdown,
  });
  Future<ArticleDetail> generateArticle(
    String dossierId, {
    required String title,
    required String instruction,
  });
  Future<ArticleDetail> loadArticle(String articleId);
  Future<ArticleDetail> saveArticle(
    String articleId, {
    required String title,
    required String contentMarkdown,
    required String basedOnVersionId,
  });
  Future<void> deleteArticle(String articleId);
  Future<List<VersionSummary>> listVersions(String articleId);
  Future<ArticleVersion> loadVersion(String articleId, int versionNumber);
  Future<ArticleDiff> loadDiff(
    String articleId, {
    required int versionNumber,
    required int against,
  });
  Future<ArticleDetail> restoreVersion(String articleId, int versionNumber);
  Future<ArticleDetail> proposeChange(
    String articleId, {
    required String instruction,
    required String basedOnVersionId,
  });
  Future<ArticleDetail> acceptProposal(String articleId, String versionId);
  Future<ArticleDetail> rejectProposal(String articleId, String versionId);

  /// De huidige versie van een artikel als PDF-bytes; de backend rendert per verzoek.
  Future<Uint8List> exportArticlePdf(String dossierId, String articleId);
}
