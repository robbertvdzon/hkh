import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weergave van de site: het eenvoudige zoekscherm (standaard, voor de
/// demo van de AI-zoekfunctie) of de volledige nieuwe website.
///
/// De keuze wordt per browser onthouden. Directe links naar andere pagina's
/// werken in beide standen; de stand bepaalt alleen de startpagina en of de
/// kop het menu toont op de zoekschermen.
class SiteModeController extends ChangeNotifier {
  SiteModeController({bool website = false, this.persist = true})
    : _website = website;

  static const _key = 'site-mode';

  /// Of de keuze in de browser wordt bewaard (uit in tests).
  final bool persist;
  bool _website;

  /// True als de volledige website de startpagina is.
  bool get website => _website;

  /// True als het eenvoudige zoekscherm de startpagina is.
  bool get simple => !_website;

  /// Leest de bewaarde keuze; zonder bewaarde keuze blijft het zoekscherm.
  Future<void> load() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null) return;
      final website = stored == 'website';
      if (website != _website) {
        _website = website;
        notifyListeners();
      }
    } catch (_) {
      // Zonder opslag blijft de standaardweergave gelden.
    }
  }

  Future<void> setWebsite(bool value) async {
    if (value == _website) return;
    _website = value;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value ? 'website' : 'search');
    } catch (_) {
      // De keuze geldt dan alleen voor deze sessie.
    }
  }
}

/// Routes die in de eenvoudige weergave zonder menu worden getoond.
bool isSearchRoute(String location) =>
    location == '/' ||
    location.startsWith('/vragen') ||
    location.startsWith('/zoeken') ||
    location.startsWith('/objecten') ||
    location.startsWith('/gedeeld');
