// Kiest per platform hoe een geëxporteerde PDF bij de gebruiker terechtkomt:
// een directe download op web, een deel-/opslagdialoog op Android.
export 'answer_pdf_saver_io.dart'
    if (dart.library.html) 'answer_pdf_saver_web.dart';
