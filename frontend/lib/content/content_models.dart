/// Inhoudsmodel van de publieke site.
///
/// In fase 1 staat alle inhoud als vaste gegevens in `generated_content.dart`
/// (overgenomen van de huidige website) en `site_structure.dart` (de indeling).
/// In fase 2 komen dezelfde modellen uit de backend; de schermen blijven gelijk.
library;

/// Eén inhoudselement van een pagina, in leesvolgorde.
sealed class ContentBlock {
  const ContentBlock();
}

class HeadingBlock extends ContentBlock {
  const HeadingBlock(this.text, {this.level = 2});
  final String text;
  final int level;
}

class ParagraphBlock extends ContentBlock {
  const ParagraphBlock(this.text, {this.links = const [], this.strong = false});
  final String text;

  /// Links die in de tekst voorkomen; de linktekst staat letterlijk in [text].
  final List<ContentLink> links;

  /// Korte vetgedrukte regel die als tussenkop dient.
  final bool strong;
}

class ImageBlock extends ContentBlock {
  const ImageBlock(this.src, {this.caption = '', this.alt = ''});
  final String src;
  final String caption;
  final String alt;
}

class ListBlock extends ContentBlock {
  const ListBlock(this.items, {this.ordered = false});
  final List<String> items;
  final bool ordered;
}

class ContentLink {
  const ContentLink(this.text, this.href);
  final String text;
  final String href;
}

/// Een gewone inhoudspagina (verhaal, verenigingspagina, document).
class ContentPage {
  const ContentPage({
    required this.slug,
    required this.title,
    required this.blocks,
    this.image,
    this.gallery = const [],
    this.published,
  });
  final String slug;
  final String title;
  final String? image;
  final List<ContentBlock> blocks;
  final List<String> gallery;
  final String? published;

  String get summary => blocks
      .whereType<ParagraphBlock>()
      .map((b) => b.text)
      .firstWhere((t) => t.length > 40, orElse: () => '');
}

enum ActivityKind {
  lezing('Lezing', 'Lezingen'),
  film('Film', 'Films'),
  wandeling('Wandeling', 'Wandelingen'),
  expositie('Expositie', 'Exposities'),
  ledenvergadering('Ledenvergadering', 'Ledenvergaderingen'),
  overig('Activiteit', 'Overige activiteiten');

  const ActivityKind(this.label, this.plural);
  final String label;
  final String plural;
}

/// Inschrijfgegevens van een activiteit. In fase 1 zijn de aantallen vaste
/// voorbeeldwaarden; het formulier bewaart nog niets.
class ActivityRegistration {
  const ActivityRegistration({
    this.capacity,
    this.registered = 0,
    this.waitlist = 0,
    this.externalUrl,
    this.externalLabel,
  });

  /// Maximaal aantal plaatsen; null betekent vrij toegankelijk.
  final int? capacity;
  final int registered;
  final int waitlist;

  /// Inschrijven loopt via een andere organisatie.
  final String? externalUrl;
  final String? externalLabel;

  bool get isExternal => externalUrl != null;
  bool get isFull => capacity != null && registered >= capacity!;
  int get free => capacity == null ? 0 : (capacity! - registered).clamp(0, capacity!);
}

class Activity {
  const Activity({
    required this.slug,
    required this.title,
    required this.start,
    required this.blocks,
    this.end,
    this.allDay = false,
    this.kind = ActivityKind.overig,
    this.venueName = '',
    this.venueAddress = '',
    this.organizer = '',
    this.price,
    this.image,
    this.partner = false,
    this.registration,
    this.published,
  });

  final String slug;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final ActivityKind kind;
  final String venueName;
  final String venueAddress;
  final String organizer;

  /// Vrije prijsomschrijving, bijvoorbeeld 'Gratis' of '€ 5,00 · leden € 3,50'.
  final String? price;
  final String? image;

  /// Activiteit van een partnerorganisatie.
  final bool partner;
  final ActivityRegistration? registration;
  final List<ContentBlock> blocks;
  final String? published;

  /// Een activiteit telt als afgelopen zodra ook de einddatum voorbij is.
  bool isUpcoming(DateTime now) => (end ?? start).isAfter(now);

  /// Meerdaags als begin en einde op verschillende dagen vallen.
  bool get multiDay =>
      end != null &&
      (end!.year != start.year ||
          end!.month != start.month ||
          end!.day != start.day);

  String get summary => blocks
      .whereType<ParagraphBlock>()
      .map((b) => b.text)
      .firstWhere((t) => t.length > 40, orElse: () => '');
}

class NewsPost {
  const NewsPost({
    required this.slug,
    required this.title,
    required this.published,
    required this.blocks,
    this.image,
  });
  final String slug;
  final String title;
  final DateTime published;
  final String? image;
  final List<ContentBlock> blocks;

  String get summary => blocks
      .whereType<ParagraphBlock>()
      .map((b) => b.text)
      .firstWhere((t) => t.length > 40, orElse: () => '');
}

class Newsletter {
  const Newsletter({
    required this.number,
    required this.title,
    required this.description,
    required this.pdfUrl,
  });
  final int number;
  final String title;
  final String description;
  final String pdfUrl;
}

class Publication {
  const Publication({
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    this.image,
    this.memberPrice,
    this.price,
    this.availability = 'Het Historisch Huis van de HKH',
  });
  final String slug;
  final String title;
  final String description;
  final String category;
  final String? image;
  final String? memberPrice;
  final String? price;
  final String availability;
}

class BoardMember {
  const BoardMember({
    required this.name,
    required this.role,
    required this.email,
    required this.since,
    required this.bio,
    this.phone = '(0251) 25 26 58',
    this.image,
  });
  final String name;
  final String role;
  final String phone;
  final String email;
  final String since;
  final String bio;
  final String? image;
}

class Workgroup {
  const Workgroup(this.name, this.description);
  final String name;
  final String description;
}

class EducationItem {
  const EducationItem({
    required this.slug,
    required this.title,
    required this.kind,
    required this.groups,
    required this.description,
    required this.goals,
    this.duration,
    this.cost,
    this.organisation,
    this.status,
    this.registration,
    this.image,
    this.requestable = true,
    this.actionLabel = 'Aanvragen',
  });
  final String slug;
  final String title;

  /// Soort: rondleiding, presentatie, wandeling, lesprogramma, workshop.
  final String kind;
  final String groups;
  final String description;

  /// Koppeling aan kerndoelen en leergebieden.
  final List<String> goals;
  final String? duration;
  final String? cost;
  final String? organisation;
  final String? status;
  final String? registration;
  final String? image;
  final bool requestable;
  final String actionLabel;
}

class PartnerLink {
  const PartnerLink(this.name, this.url);
  final String name;
  final String url;
}

/// Een rubriek binnen Ontdek Heemskerk: een naam en de pagina's erin.
class StoryCategory {
  const StoryCategory({
    required this.slug,
    required this.title,
    required this.description,
    required this.pageSlugs,
  });
  final String slug;
  final String title;
  final String description;
  final List<String> pageSlugs;
}

/// Een verhaal uit het Geheugen van Heemskerk (2005-2010, sinds 2012 bij de HKH).
class MemoryStory {
  const MemoryStory({
    required this.slug,
    required this.title,
    required this.narrator,
    required this.author,
    required this.theme,
    required this.neighbourhood,
    required this.intro,
    required this.body,
    this.period = '',
    this.figures = const [],
    this.relatedSlugs = const [],
  });

  final String slug;
  final String title;

  /// Degene die het verhaal vertelt ("Aan het woord").
  final String narrator;

  /// De verhalenverzamelaar die het optekende.
  final String author;
  final String theme;
  final String neighbourhood;
  final String period;
  final List<String> intro;
  final List<String> body;
  final List<MemoryFigure> figures;
  final List<String> relatedSlugs;

  String get summary => intro.isNotEmpty
      ? intro.first
      : (body.isNotEmpty ? body.first : '');

  String? get image => figures.isEmpty ? null : figures.first.src;
}

class MemoryFigure {
  const MemoryFigure(this.src, {this.caption = '', this.alt = ''});
  final String src;
  final String caption;
  final String alt;
}
