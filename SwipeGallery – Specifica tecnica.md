# SwipeGallery – Specifica tecnica

Oct 25, 2026 · @Samuele

## 1. Obiettivo e contesto

App iOS nativa per ripulire la galleria: mostra foto e video uno alla volta, swipe da un lato per tenere e dall'altro per spostare nel cestino dell'app, poi svuotamento del cestino che elimina davvero gli elementi dalla Libreria Foto.

- **Nome provvisorio:** SwipeGallery (bundle id `com.samuelecozza.swipegallery`, modificabile).
- **Lingua dell'interfaccia:** italiano.
- **Vincolo principale:** lo sviluppatore non ha un Mac. Il progetto non verrà mai aperto in Xcode in locale: deve compilare solo tramite GitHub Actions su runner macOS.
- **Distribuzione:** `.ipa` non firmato prodotto dalla CI, installato sull'iPhone con Sideloadly e Apple ID gratuito.
- **Uso:** personale, un solo utente, iPhone con iOS 26.

## 2. Piattaforma e stack

| Voce | Scelta |
| --- | --- |
| Target minimo | iOS 26.0, solo iPhone, solo verticale |
| Linguaggio | Swift 6, strict concurrency attiva |
| UI | SwiftUI con API native Liquid Glass di iOS 26 (`glassEffect`, `GlassEffectContainer`, TabView di sistema) |
| Accesso foto | PhotoKit (`PHPhotoLibrary`, `PHFetchResult`, `PHCachingImageManager`) |
| Persistenza | SwiftData per le decisioni, `@AppStorage` per le impostazioni |
| Video / Live Photo | AVKit (`AVPlayer`), PhotosUI (`PHLivePhotoView`) |
| Progetto | XcodeGen (`project.yml`), il `.xcodeproj` non va committato |
| Dipendenze esterne | Nessuna (niente Swift Package di terze parti) |

State management con `@Observable` e pattern MVVM leggero.

## 3. Navigazione

La navigazione usa la `TabView` nativa di iOS 26. Si presenta come una barra piccola e fluttuante in Liquid Glass, e si riduce durante lo scorrimento con `.tabBarMinimizeBehavior(.onScrollDown)`.

| Tab | Icona SF Symbol | Contenuto |
| --- | --- | --- |
| Galleria | `photo.stack` | Tutte le foto e i video della libreria |
| Album | `rectangle.stack` | Elenco album, con swipe dentro ciascun album |
| Cestino | `trash` | Elementi scartati, con badge del conteggio |

Le **Impostazioni** si aprono come sheet da un'icona ingranaggio (`gearshape`) nella toolbar del tab Galleria, così la barra resta a tre voci.

I controlli che fluttuano sopra il contenuto, come i pulsanti dello swipe e il selettore swipe/griglia, usano `glassEffect` con `GlassEffectContainer`.

## 4. Tab Galleria

All'apertura l'app mostra subito la modalità swipe, partendo dall'elemento più recente non ancora valutato. Un selettore Liquid Glass in alto (Swipe / Griglia) passa alla vista a griglia.

**Modalità swipe (predefinita)**

- La coda contiene foto e video della libreria non ancora valutati (né tenuti né nel cestino), dal più recente al più vecchio.
- In alto è visibile il contatore "N da valutare".
- Quando la coda è vuota compare uno stato vuoto ("Hai valutato tutto") con un pulsante per andare al cestino.

**Modalità griglia**

- `LazyVGrid` a 3 colonne con miniature quadrate, dal più recente. Contiene tutti gli elementi della libreria.
- Badge sulle miniature: spunta per quelli tenuti, icona cestino e opacità ridotta per quelli nel cestino, durata in basso a destra per i video.
- Toccando una miniatura si apre un menu con due opzioni: "Vai verso le più recenti" e "Vai verso le più vecchie". Lo swipe parte da quella foto nella direzione scelta.
- In questo avvio manuale la coda include anche gli elementi già tenuti, che si possono rivalutare. Restano esclusi quelli nel cestino.
- Toccando un elemento che è nel cestino compare l'opzione "Ripristina".
- Nella vista swipe aperta dalla griglia c'è un pulsante nella toolbar per invertire la direzione.

## 5. Comportamento dello swipe

Una card a schermo intero per volta, con la successiva visibile in trasparenza dietro. Il lato "elimina" si configura nelle Impostazioni: il predefinito è **sinistra = cestino, destra = tieni**.

**Gesto**

- `DragGesture` con traslazione e rotazione proporzionale (massimo circa 12°).
- Durante il trascinamento compare un'etichetta con opacità proporzionale: "TIENI" in verde, "CESTINO" in rosso.
- L'azione scatta se lo spostamento supera il 30% della larghezza dello schermo o se la velocità finale è alta. Altrimenti la card torna al centro con un'animazione spring.
- A ogni decisione c'è un feedback aptico (disattivabile).
- Lo swipe verticale non fa nulla. Il pinch-to-zoom sulla foto deve funzionare senza far partire lo swipe.

**Pulsanti di supporto** in una barra Liquid Glass in basso: Cestino, Annulla, Tieni. I pulsanti si dispongono secondo il lato configurato.

**Annulla:** pila delle ultime 20 azioni della sessione. Annullare riporta la card in cima alla coda e rimuove la decisione salvata.

**Info sovrapposte:** data e ora dello scatto, tipo (Foto, Video, Live Photo, Screenshot) e posizione ("n / totale").

**Video:** riproduzione automatica in loop e senza audio; un tocco attiva o disattiva l'audio. La durata è visibile.

**Live Photo:** si riproduce con una pressione prolungata (`PHLivePhotoView`).

**Caricamento e prestazioni**

- `PHCachingImageManager` precarica i 3 elementi successivi alla risoluzione dello schermo.
- Prima viene mostrata una versione a bassa qualità, poi quella definitiva (`.opportunistic`).
- `isNetworkAccessAllowed = true`, per scaricare gli originali da iCloud con un indicatore di progresso. Se il download fallisce, si mostra la miniatura con un avviso.
- La libreria può contenere decine di migliaia di elementi. Non va convertito tutto il `PHFetchResult` in array: si scorre per indice, scartando gli id già decisi tramite un `Set<String>` in memoria.

## 6. Tab Album

Il tab mostra una griglia a 2 colonne di album. Ogni album ha copertina (l'elemento più recente), nome, numero totale di elementi e numero di quelli ancora da valutare.

**Album inclusi**

- Album dell'utente (`.album` / `.albumRegular`), comprese le cartelle annidate.
- Smart album utili: Preferiti, Video, Selfie, Live Photo, Ritratti, Screenshot, Registrazioni schermo, Panoramiche, Raffiche.
- Vanno esclusi gli album vuoti, gli album condivisi iCloud (non se ne possono eliminare elementi), "Recenti" (coincide con la Galleria) e "Nascosti".

Dentro un album il comportamento è identico al tab Galleria: swipe predefinito, selettore Swipe / Griglia, avvio da una foto con scelta della direzione. Il tutto è limitato agli elementi dell'album.

**Regole importanti**

- Le decisioni sono globali, legate al `localIdentifier` dell'elemento. Una foto tenuta in un album risulta tenuta ovunque.
- Mandare nel cestino un elemento da un album significa eliminarlo **dall'intera libreria**, non solo dall'album. Al primo swipe verso il cestino dentro un album va mostrato un avviso una tantum che lo spiega.

## 7. Tab Cestino

Il cestino è interno all'app: finché non viene svuotato, nessun elemento viene toccato nella Libreria Foto.

**Contenuto**

- Griglia a 3 colonne degli elementi nel cestino, ordinati dal più recentemente scartato.
- Intestazione con il numero di elementi e lo spazio stimato, sommando `PHAssetResource` → `fileSize`. Se il valore non è disponibile, si mostra solo il conteggio.
- Il tab Cestino ha un badge con il numero di elementi.

**Azioni**

- Un tocco apre l'anteprima a schermo intero, con i pulsanti "Ripristina" ed "Elimina definitivamente".
- La modalità selezione permette di scegliere più elementi e poi "Ripristina" o "Elimina".
- Ci sono i pulsanti "Ripristina tutto" e **"Svuota cestino"**.
- Un elemento ripristinato torna "da valutare": la sua decisione viene cancellata.

**Svuotamento**

1. Alert dell'app: "Eliminare N elementi dalla libreria?"
2. `PHPhotoLibrary.shared().performChanges { PHAssetChange.deleteAssets(...) }` con tutti gli asset in un'unica chiamata. iOS mostra la propria conferma di sistema, ed è un comportamento che non si può evitare.
3. Se l'operazione riesce, i record vengono rimossi dallo store e compare un messaggio: "Gli elementi sono in Eliminati di recente nell'app Foto per 30 giorni. Svuotalo lì per liberare spazio subito."
4. Se l'utente annulla dalla conferma di sistema o c'è un errore, il cestino resta invariato e viene mostrato l'errore.

Se un elemento nel cestino è già stato eliminato fuori dall'app, il suo record viene rimosso in silenzio.

## 8. Impostazioni

Sheet con `Form`; i valori sono salvati in `@AppStorage`.

| Impostazione | Tipo | Predefinito |
| --- | --- | --- |
| Lato swipe per mandare nel cestino | Picker: Sinistra / Destra | Sinistra |
| Includi video | Toggle | Attivo |
| Feedback aptico | Toggle | Attivo |
| Azzera progresso | Pulsante distruttivo con conferma | — |
| Permesso libreria | Riga di stato + "Gestisci selezione" se l'accesso è limitato | — |
| Versione app | Testo | — |

"Azzera progresso" rimuove tutte le decisioni "tenuto". Non tocca il cestino.

Il cambio di lato vale subito per etichette, colori e ordine dei pulsanti.

## 9. Permessi, persistenza e architettura

**Permessi**

- `NSPhotoLibraryUsageDescription` in italiano: "SwipeGallery accede alle tue foto per aiutarti a decidere quali tenere ed eliminare."
- La richiesta va fatta con `PHPhotoLibrary.requestAuthorization(for: .readWrite)`.
- Al primo avvio compare una schermata di benvenuto con il pulsante "Consenti accesso".
- Con accesso **limitato** appare un banner che invita a dare l'accesso completo o a modificare la selezione (`presentLimitedLibraryPicker`).
- Con accesso **negato** appare una schermata con il pulsante per aprire le Impostazioni di iOS.

**Persistenza (SwiftData)**

```swift
@Model final class AssetDecision {
    @Attribute(.unique) var localIdentifier: String
    var decision: Decision   // .kept | .trashed
    var decidedAt: Date
}
```

- All'avvio i record vengono caricati in un `Set` in memoria, per filtrare le code velocemente.
- `PHPhotoLibraryChangeObserver` aggiorna fetch result e griglie quando la libreria cambia. Elimina anche i record di asset che non esistono più.

**Struttura suggerita**

- `App/`: `SwipeGalleryApp`, `RootTabView`
- `Services/`: `PhotoLibraryService` (fetch, album, eliminazione, change observer), `ImageLoader` (caching), `DecisionStore` (SwiftData)
- `Features/Swipe/`: `SwipeDeckView`, `SwipeCardView`, `SwipeQueue` (logica di coda e direzione), `UndoStack`
- `Features/Grid/`, `Features/Albums/`, `Features/Trash/`, `Features/Settings/`, `Features/Onboarding/`
- `Shared/`: componenti Liquid Glass, badge, formattatori data e dimensioni

La logica di coda (`SwipeQueue`, `UndoStack`, filtro delle decisioni) va tenuta separata da PhotoKit e coperta da unit test, dato che non c'è modo di provare l'app in un simulatore locale.

## 10. Build e distribuzione

Il risultato atteso è un file `SwipeGallery.ipa` non firmato, scaricabile dagli Artifacts del workflow e installabile con Sideloadly.

**Workflow `.github/workflows/build.yml`**

- **Trigger:** push su `main` e `workflow_dispatch`.
- **Runner:** `macos-26`, o l'immagine macOS più recente con Xcode 26. Verificare l'etichetta disponibile e selezionare Xcode 26 con `xcode-select`.
- **Passi:**
  1. Checkout.
  2. `brew install xcodegen` e `xcodegen generate`.
  3. Unit test su simulatore iPhone: `xcodebuild test -scheme SwipeGallery -destination 'platform=iOS Simulator,name=iPhone 17'`. Usare un simulatore effettivamente presente sul runner.
  4. Build Release per dispositivo, senza firma:

```bash
xcodebuild -project SwipeGallery.xcodeproj -scheme SwipeGallery \
  -configuration Release -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
mkdir Payload
cp -R build/Build/Products/Release-iphoneos/SwipeGallery.app Payload/
zip -qr SwipeGallery.ipa Payload
```

- **Pubblicazione:** `actions/upload-artifact` con `SwipeGallery.ipa`, conservato 30 giorni.
- **Timeout:** 30 minuti, con cache di DerivedData facoltativa.

**Altri requisiti**

- `project.yml` con deployment target 26.0, `TARGETED_DEVICE_FAMILY = 1`, solo orientamento verticale, Info.plist generato con le chiavi necessarie, icona app semplice in `Assets.xcassets`.
- `README.md` in italiano con i passi per scaricare l'artifact, installarlo con Sideloadly e attivare Modalità sviluppatore e fiducia nel profilo.
- Il repository sarà pubblico (minuti di GitHub Actions gratuiti): nessun segreto o dato personale nel codice.

## 11. Fuori ambito e criteri di accettazione

**Fuori ambito (prima versione):** ricerca di duplicati o foto simili, modifica delle foto, sincronizzazione delle decisioni tra dispositivi, iPad, widget, analytics o chiamate di rete.

**Criteri di accettazione**

- [ ] La CI completa test e build e produce `SwipeGallery.ipa` scaricabile.
- [ ] L'`.ipa` si installa con Sideloadly e l'app si apre su iOS 26.
- [ ] All'apertura parte lo swipe dall'elemento più recente non valutato.
- [ ] Lo swipe sul lato configurato manda nel cestino, l'altro tiene; il cambio di lato nelle Impostazioni ha effetto subito.
- [ ] Annulla ripristina l'ultima decisione.
- [ ] Dalla griglia, toccando una foto si sceglie la direzione e lo swipe parte da lì.
- [ ] Il tab Album elenca gli album e lo swipe al loro interno si comporta come in Galleria.
- [ ] Gli elementi tenuti non ricompaiono nella coda predefinita dopo il riavvio; "Azzera progresso" li riporta.
- [ ] Il cestino mostra il conteggio, permette di ripristinare e lo svuotamento elimina dalla libreria dopo la conferma di iOS.
- [ ] La barra dei tab è fluttuante in Liquid Glass e i controlli sovrapposti usano il vetro.
- [ ] Con 20.000+ elementi lo scorrimento resta fluido e l'avvio richiede meno di 2 secondi.
