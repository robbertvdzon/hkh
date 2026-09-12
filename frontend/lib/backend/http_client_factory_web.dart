import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Cookies zijn de anonieme sleutel voor de opgeslagen AI-zoekopdrachten.
/// `withCredentials` houdt dit ook werkend wanneer een lokale frontend de
/// ontwikkel- of acceptatie-API op een ander origin gebruikt.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
