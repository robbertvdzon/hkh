# PDF-export testen op acceptatie en previews

De overlays activeren `HKH_AI_SEARCH_FIXTURE_ENABLED=true`. Alleen de externe AI-generatie wordt dan vervangen door herkenbare synthetische inhoud. De echte bezoekerscookie, sessieopslag, bronresolutie, HTML-sanitisatie en PDF-renderer blijven actief. De bron `beeldbank/test-pdf-001` wordt eenmalig toegevoegd als deze ontbreekt. Dit bewijst de exportketen, niet de kwaliteit of beschikbaarheid van live AI. Andere AI-taaktypen worden door deze fixture expliciet geweigerd.

Deze optie vereist een gevalideerde preview-/acceptatiemarkering met een database binnen dezelfde namespace. Buiten die omgeving weigert de backend op te starten. Productie houdt standaard de bestaande runtime-integratie.

Gebruik `/api/auth/agent-login` voor de native testsessie. De gebruikersapp herstelt deze via `/api/auth/me`, ook als Google-login niet geconfigureerd is. Maak een zoekvraag, wacht op het gemarkeerde testantwoord en exporteer dit vanuit het scherm. Voor een dossierartikel: maak een testdossier en artikel met de bron `[testbron](hkh:beeldbank/test-pdf-001)`, exporteer, wijzig het artikel en exporteer opnieuw. Controleer ook geweigerde export met een andere bezoeker/gebruiker en de zichtbare foutmelding bij een geforceerde exportfout.

`HKH_PUBLIC_ORIGIN` zorgt dat de bronlinks in antwoorden, artikelen en PDF's naar de eigen omgeving wijzen. Acceptatie en previews gebruiken hun eigen origin. Google-login, prod-tokens of productiegegevens zijn hiervoor niet nodig.
