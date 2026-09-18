# Accounts en dossiers

Ontwerp voor optioneel inloggen met Google in de publieke app, blijvende sessies (ook voor het
beheerscherm) en persoonlijke onderzoeksdossiers met AI-vragen, artikelen, versiegeschiedenis en
delen. Vastgesteld op 12 september 2026.

## Besluiten

| Onderwerp | Besluit |
| --- | --- |
| Inloggen | Optioneel, met Google, in de publieke app. Anoniem gebruik blijft volledig werken. |
| Sessieduur | Eén jaar, verlengend bij gebruik. Alleen expliciet uitloggen beëindigt de sessie. |
| Beheerscherm | Gebruikt hetzelfde sessiemechanisme; het uur-probleem verdwijnt daarmee. |
| Artikelformaat | Markdown, met een vaste linkvorm voor archiefbronnen. |
| AI-wijzigingen | Altijd eerst een voorstel; de gebruiker accepteert of verwerpt. |
| Delen | De eigenaar nodigt uit per e-mailadres en kiest per lid een rol. |

## 1. Accounts en sessies

### Waarom het oude beheerscherm na een uur uitlogde

De eerdere admin-frontend bewaarde het ruwe Google ID-token en stuurde dat bij elk verzoek mee; de
backend verifieerde dat token bij elk verzoek opnieuw (`AdminAuthenticator`). Google ID-tokens zijn
één uur geldig. De software factory lost dit op door het ID-token één keer in te wisselen voor een
eigen sessietoken (`dashboard-backend` `AuthService.loginWithGoogle`). HKH gebruikt nu hetzelfde
principe, maar met een sessie in de database zodat sessies intrekbaar zijn.

### Model

```
app_user      id UUID, email (uniek, lowercase), display_name, created_at, last_login_at
user_session  id UUID, user_id, token_hash (SHA-256 van het token), created_at,
              last_used_at, expires_at, revoked_at
```

- Het sessietoken is 32 willekeurige bytes, base64url. Alleen de hash staat in de database.
- `expires_at` is aanmaak plus 365 dagen. Bij gebruik ouder dan een dag schuift `expires_at` op
  naar nu plus 365 dagen ("sliding").
- Uitloggen zet `revoked_at`. "Uitloggen op alle apparaten" doet dat voor alle sessies van de
  gebruiker.

### API

```
POST /api/auth/google      { idToken }  -> { token, email, displayName, roles }
GET  /api/auth/me          Bearer token -> { email, displayName, roles }
POST /api/auth/logout      Bearer token -> 204
POST /api/auth/logout-all  Bearer token -> 204
```

- `roles` bevat `ADMIN` als het e-mailadres op `HKH_ADMIN_ALLOWED_EMAILS` staat.
- Beheer-endpoints accepteren voortaan het sessietoken en eisen `ADMIN`. Het ruwe Google-token
  wordt bij `/api/admin/**` niet meer geaccepteerd; de preview-header blijft werken.
- `AdminAuthConfig` eist nu dat client-id en allowlist samen gezet of samen leeg zijn. Nieuw:
  de client-id alleen schakelt publieke login in; de allowlist bepaalt alleen wie beheerder is.

### Frontends

- De publieke app krijgt `google_sign_in`, `google_sign_in_web` en `shared_preferences`, met
  dezelfde web-knop als in de admin-app (`google_signin_button_web.dart`).
- Het sessietoken en e-mailadres staan in `shared_preferences`. Bij opstarten: token herstellen,
  `GET /api/auth/me`, bij 401 lokaal wissen en uitgelogd tonen.
- Google Cloud: de origin van de publieke app (productie en `http://localhost:*`) toevoegen als
  toegestane JavaScript-origin op de bestaande OAuth-client.
- De AI-bezoekerscookie blijft de sleutel voor anonieme zoekopdrachten. Een ingelogde gebruiker
  krijgt bestaande browservragen automatisch aan zijn account gekoppeld. Nieuwe persoonlijke
  vragen horen direct bij het account en zijn vanaf andere pc’s beschikbaar. Na koppelen wordt
  `visitor_id` gewist; de oude cookie geeft geen toegang tot accountvragen. Een dossierkoppeling
  bewaart een kopie en laat het persoonlijke origineel bestaan.

## 2. Dossiers

Een dossier is een onderzoek met een titel en een doel (bijvoorbeeld "Artikel over de Kerklaan en
haar bewoners voor het verenigingsblad"). Het bevat vragen aan het archief, een feitenlijst en
artikelen.

### Model

```
dossier          id, owner_user_id, title (200), goal (2000), fact_sheet_md (tekst),
                 fact_sheet_updated_at, created_at, updated_at
dossier_member   dossier_id, user_email (lowercase), role, invited_by_user_id, created_at
                 rol: READER | RESEARCHER | EDITOR
ai_search_session  + dossier_id (nullable), + user_id (nullable), + created_by_email
```

- Leden staan op e-mailadres, niet op `user_id`, zodat je iemand kunt uitnodigen die nog nooit
  heeft ingelogd. Na de eerste login ziet die persoon het dossier direct.
- Vragen in een dossier zijn gewone `ai_search_session`-rijen met `dossier_id`. De bestaande
  turn-verwerking, voortgang, bronnen en weergave worden hergebruikt.
- Een sessie met `dossier_id` is zichtbaar voor alle dossierleden, ongeacht bezoekerscookie.

### Rollen

| Actie | Eigenaar | EDITOR | RESEARCHER | READER |
| --- | :-: | :-: | :-: | :-: |
| Dossier, vragen, feitenlijst en artikelen lezen | x | x | x | x |
| Vragen stellen en vervolgvragen stellen | x | x | x | |
| Feitenlijst laten bijwerken | x | x | x | |
| Artikelen maken, bewerken, AI-voorstellen vragen en accepteren | x | x | | |
| Titel en doel wijzigen | x | x | | |
| Leden toevoegen, rol wijzigen, leden verwijderen | x | | | |
| Dossier verwijderen | x | | | |

Een lid kan zichzelf altijd verwijderen. De eigenaar kan een dossier overdragen aan een lid.

### Feitenlijst als AI-context

De huidige prompt neemt de laatste drie antwoorden mee, elk maximaal 4000 tekens. Voor een dossier
met tientallen vragen is dat te weinig en tegelijk te veel ruis. Daarom houdt elk dossier een
feitenlijst bij in Markdown: personen, adressen, jaartallen, gebeurtenissen en bronnen, elk met
`collection/ident`. Na iedere geslaagde vraag start de backend een korte runtime-job die de
feitenlijst bijwerkt met de nieuwe feiten (samenvoegen, geen duplicaten, tegenstrijdigheden
benoemen). De feitenlijst is zichtbaar en handmatig bewerkbaar in het dossier.

Elke nieuwe vraag in een dossier krijgt mee:

1. titel en doel van het dossier;
2. de feitenlijst;
3. de titels van alle eerdere vragen;
4. de volledige tekst van de laatste twee antwoorden, elk maximaal 6000 tekens.

Als een dossier daar overheen groeit, worden de oudere antwoorden als invoerobjecten aan de
runtime-job meegegeven (de runtime ondersteunt resumable uploads en `input.objects`), zodat de
agent er zelf in kan zoeken. Dat is een latere uitbreiding, niet nodig voor fase twee.

### API

```
GET    /api/dossiers                       lijst (eigen en gedeeld)
POST   /api/dossiers                       { title, goal }
GET    /api/dossiers/{id}                  dossier, leden, vragen (samenvatting), artikelen, feitenlijst
PUT    /api/dossiers/{id}                  { title, goal }
DELETE /api/dossiers/{id}
PUT    /api/dossiers/{id}/fact-sheet       { markdown }   handmatige aanpassing
POST   /api/dossiers/{id}/fact-sheet/refresh                AI werkt de lijst bij op basis van alle antwoorden
PUT    /api/dossiers/{id}/members/{email}  { role }
DELETE /api/dossiers/{id}/members/{email}
POST   /api/dossiers/{id}/questions        { question }   -> ai_search_session met dossier_id
POST   /api/dossiers/{id}/questions/adopt  { sessionId }  koppelt een cookie-zoekopdracht aan het dossier
```

De bestaande `/api/ai-search/sessions/{id}`-routes blijven de detail-, vervolg-, annuleer- en
verwijderroutes; de autorisatie wordt: account of bezoekerscookie voor losse sessies, dossierrol voor
sessies met `dossier_id`.

## 3. Artikelen en versies

### Model

```
article          id, dossier_id, title (200), created_by_user_id, created_at, updated_at,
                 current_version_id
article_version  id, article_id, version_number, content_md, author_kind (USER | AI),
                 author_email, ai_instruction (tekst), change_summary (1000),
                 state (ACCEPTED | PROPOSED | REJECTED), based_on_version_id,
                 runtime_job_id, status (SUBMITTING | RUNNING | SUCCEEDED | FAILED), error_message,
                 created_at, decided_at, decided_by_email
```

- Elke opslag door een gebruiker is direct een `ACCEPTED`-versie en wordt de huidige versie.
- Een AI-bewerking maakt een `PROPOSED`-versie. De gebruiker ziet het verschil met de huidige
  versie en kiest accepteren of verwerpen. Accepteren maakt de versie `ACCEPTED` en actueel.
  Verwerpen zet `REJECTED`; de versie blijft in de geschiedenis zichtbaar.
- Er is per artikel hooguit één open voorstel tegelijk.
- Terugzetten naar een oude versie maakt een nieuwe `ACCEPTED`-versie met die inhoud en
  `change_summary` "Teruggezet naar versie N".
- Optimistic locking: opslaan stuurt `based_on_version_id` mee. Wijkt dat af van de huidige
  versie, dan antwoordt de backend 409 met de huidige versie, en de client toont dat iemand anders
  heeft opgeslagen.
- Verschillen worden bij het tonen berekend (java-diff-utils op regelniveau, aan de backend).

### Markdown en bronnen

Artikelen zijn Markdown. Een archiefbron staat als link met het schema `hkh:`:

```
De familie Jansen woonde in 1932 op [Kerklaan 12](hkh:beeldbank/12345).
```

De backend controleert bij opslaan en bij AI-resultaten dat elke `hkh:`-link naar een bestaand
`collection/ident` verwijst, precies zoals `AiAnswerRenderer` nu doet voor `data-hkh-source`.
Onbekende bronnen worden als gewone tekst gerenderd met een waarschuwing in de editor. De
frontend rendert Markdown met `flutter_markdown` en zet `hkh:`-links om naar dezelfde
gecontroleerde detailweergave als in AI-antwoorden. Andere links, afbeeldingen en HTML in
Markdown worden niet gerenderd.

### AI-jobs voor artikelen

Beide jobs draaien als `STRUCTURED_GENERATION` op de Agent Runtime met resultschema
`{ title, contentMarkdown, changeSummary }`.

- **Nieuw artikel**: invoer is doel, feitenlijst, alle antwoorden (binnen het budget) en een
  vrije instructie ("Schrijf een artikel van circa 800 woorden over de bewoners van de Kerklaan").
- **Wijziging**: invoer is het huidige artikel, de instructie ("Voeg een hoofdstuk toe over de
  school en noem alle bewoners van nummer 12"), de feitenlijst en de relevante antwoorden. De
  prompt eist dat alleen het gevraagde verandert en dat elke nieuwe feitelijke passage een
  `hkh:`-bron krijgt die in de feitenlijst of antwoorden voorkomt.

Artikeljobs doen geen API-onderzoek en zijn kort. Ze tellen wel mee in
`HKH_AI_SEARCH_MAX_ACTIVE`. Nieuw: maximaal één lopende AI-job per gebruiker, zodat één persoon
niet alle plekken bezet.

### API

```
GET    /api/dossiers/{id}/articles
POST   /api/dossiers/{id}/articles                  { title, contentMarkdown }        lege of eigen tekst
POST   /api/dossiers/{id}/articles/generate         { title, instruction }            AI schrijft versie 1 als voorstel
GET    /api/articles/{id}                           artikel, huidige versie, open voorstel
PUT    /api/articles/{id}                           { title, contentMarkdown, basedOnVersionId }
GET    /api/articles/{id}/versions                  geschiedenis
GET    /api/articles/{id}/versions/{v}/diff?against={w}
POST   /api/articles/{id}/versions/{v}/restore
POST   /api/articles/{id}/proposals                 { instruction, basedOnVersionId }  AI-voorstel
POST   /api/articles/{id}/proposals/{v}/accept
POST   /api/articles/{id}/proposals/{v}/reject
DELETE /api/articles/{id}
GET    /api/dossiers/{id}/articles/{articleId}/export/pdf   huidige versie als PDF (attachment)
```

De PDF-export gebruikt exact dezelfde autorisatie als de overige artikelroutes en de gedeelde
module `nl.vdzon.hkh.docexport`; de gerenderde HTML en de bronvermeldingen zijn die van het
artikelscherm. Zonder toegang is het antwoord dezelfde `404` als bij een onbekend artikel, een
renderfout geeft `500` zonder lichaam. Er wordt niets opgeslagen of gecachet.

## 4. Schermen in de publieke app

- **Gedeelde vormgeving**: de dossierschermen en -dialogen gebruiken hetzelfde ontwerpsysteem als
  de homepage. De waarden staan één keer in `frontend/lib/theme/app_style.dart`: achtergrond
  `#FBF6EE`, dominante accentkleur `#1F3B2E`, dunne randen `#D9CFBB`, kaarten met 16 px en velden
  en knoppen met 10 px afronding, en minimaal 32 px tussen inhoudelijke secties. Rolchips hebben
  een vaste kleur per rol: Eigenaar `#DCE9DA`, Bewerker `#F0E6D2`, Onderzoeker `#D9ECE7` en Lezer
  `#ECE8DD`. Tot en met 600 px gebruiken dialogen de beschikbare breedte binnen de normale
  schermmarges en stapelen kaartinhoud, dialoogvelden en ledenacties verticaal; lange
  e-mailadressen worden met ellipsis afgekapt.
- **Kop van de app**: voor bezoekers de knop "Inloggen met Google". Ingelogde
  gebruikers zien "Mijn dossiers" als losse appbalkactie (op smalle schermen
  alleen als toegankelijk gelabeld icoon) naast een accountmenu dat uitsluitend
  "Uitloggen" bevat.
- **Mijn dossiers**: eigen en gedeelde dossiers als kaarten, elk met een rolchip, het doel,
  het aantal vragen en artikelen, het aantal leden bij een gedeeld dossier en de laatste
  wijzigingsdatum. Knop "Nieuw dossier" met titel (verplicht) en doel (optioneel).
- **Dossier**: drie tabbladen. *Vragen* toont de vragen zoals de bestaande AI-zoekpagina, met een
  invoerveld voor een nieuwe vraag. *Feitenlijst* toont de Markdown met knoppen "Bewerken" en
  "Laten bijwerken". *Artikelen* toont de artikelen met titel, versie en of er een open voorstel
  is.
- **Artikel**: gerenderde weergave, knop "Bewerken" (Markdown-tekstveld, opslaan, annuleren),
  knop "Vraag AI om een wijziging" (instructieveld) en rechtsboven het artikelmenu met
  "Geschiedenis", "Exporteren als PDF" en — voor wie mag bewerken — "Artikel verwijderen". Het
  menu verschijnt pas als er een artikelversie geladen is en is tijdens het bewerken afwezig, zodat
  een export nooit zonder inhoud start. Een open voorstel wordt bovenaan getoond als verschil met
  de huidige versie, met "Accepteren" en "Verwerpen".
- **Geschiedenis**: lijst van versies met nummer, auteur, tijd, samenvatting en de gebruikte
  AI-instructie. Twee versies selecteren toont het verschil. Knop "Terugzetten".
- **Delen**: dialoog in het dossier met leden, rol per lid en een veld voor een nieuw e-mailadres.

## 5. Fasering

1. **Accounts en sessies.** Tabellen, `/api/auth/**`, sessiecontrole voor beheer, Google-knop in
   de publieke app, blijvende sessie in beide frontends. Configuratie losser maken. Resultaat:
   beheerders blijven ingelogd; bezoekers kunnen inloggen maar zien nog niets extra's.
2. **Dossiers.** Tabellen, dossier-API, rollen, vragen in dossiers, feitenlijst, adopteren van
   cookie-zoekopdrachten, schermen Mijn dossiers en Dossier.
3. **Artikelen.** Tabellen, artikel-API, Markdown-rendering met `hkh:`-bronnen, AI-generatie en
   AI-voorstellen, geschiedenis en verschillen, per-gebruiker joblimiet.
4. **Later.** Bewust nog niet gebouwd; ideeën voor een volgende versie, vastgelegd op
   12 september 2026:
   - export van een artikel naar Word (PDF-export is er inmiddels wel, via het artikelmenu);
   - oude antwoorden als invoerobjecten aan de runtime meegeven zodra een dossier te groot
     wordt voor het promptbudget;
   - notificatie bij een nieuw AI-voorstel in een gedeeld dossier;
   - eigenaarschap overdragen in de UI (de backend heeft `POST /api/dossiers/{id}/transfer` al);
   - account verwijderen in de UI (de backend heeft `DELETE /api/auth/account` al);
   - de feitenlijst op verzoek door AI laten bewerken, net als bij artikelen;
   - een AI-voorstel bewerken voordat je het accepteert;
   - meer dan één lopende AI-opdracht per gebruiker toestaan;
   - een alleen-lezen deellink voor mensen zonder Google-account.

## 6. Privacy en beveiliging

- Opgeslagen persoonsgegevens: e-mailadres en weergavenaam uit Google, plus e-mailadressen van
  uitgenodigde leden. Geen andere Google-gegevens; scope blijft `email`.
- Sessietokens staan alleen gehasht in de database en alleen in `shared_preferences` van de
  eigen browser of het eigen toestel.
- Alle dossier- en artikelroutes controleren de rol server-side per verzoek; het `dossier_id`
  in de URL is nooit voldoende.
- Gebruikersvragen, antwoorden, feitenlijsten en artikelen gaan als data naar de AI, nooit als
  instructie; de bestaande regel in de prompt blijft staan.
- Een gebruiker kan zijn account verwijderen: sessies worden ingetrokken, eigen dossiers
  verwijderd, en lidmaatschappen van andermans dossiers vervallen.
