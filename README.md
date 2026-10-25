# SwipeGallery

App iOS per ripulire la galleria: mostra foto e video uno alla volta, swipe da un lato per tenere e dall'altro per spostare nel cestino dell'app. Svuotando il cestino gli elementi vengono eliminati davvero dalla Libreria Foto (finiscono in "Eliminati di recente" per 30 giorni).

- iOS 26, solo iPhone, interfaccia in italiano, Liquid Glass.
- Nessuna connessione di rete, nessuna dipendenza esterna.
- Il progetto Xcode non è nel repository: viene generato da [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partire da `project.yml`.

## Scaricare l'app

La build avviene solo su GitHub Actions (workflow `Build`), a ogni push su `main` oppure a mano.

1. Apri la scheda **Actions** del repository e scegli il workflow **Build**.
2. Per avviarlo a mano: **Run workflow** → **Run workflow**.
3. Apri l'esecuzione completata (spunta verde) e, in fondo alla pagina, scarica l'artifact **SwipeGallery-ipa**. GitHub lo fornisce come `.zip`: estrailo per ottenere `SwipeGallery.ipa`.

Gli artifact restano disponibili per 30 giorni.

## Installare con Sideloadly

Serve un computer (Windows o Mac) con [Sideloadly](https://sideloadly.io) e iTunes/Apple Devices installati, un cavo USB e un Apple ID gratuito.

1. Collega l'iPhone al computer e, se richiesto, tocca **Autorizza** sull'iPhone.
2. Apri Sideloadly, trascina `SwipeGallery.ipa` nella finestra.
3. Seleziona il tuo iPhone, inserisci l'Apple ID e premi **Start**. Sideloadly firma l'app con il tuo account e la installa.
4. Con un Apple ID gratuito l'app scade dopo **7 giorni**: per rinnovarla ripeti l'installazione (i dati restano se non la elimini).

## Primo avvio sull'iPhone

1. **Modalità sviluppatore** (richiesta da iOS 16 in poi): *Impostazioni → Privacy e sicurezza → Modalità sviluppatore*, attivala e riavvia l'iPhone. Dopo il riavvio conferma con **Attiva**.
2. **Fiducia nel profilo**: *Impostazioni → Generali → VPN e gestione dispositivi*, tocca il profilo con il tuo Apple ID e poi **Autorizza**.
3. Apri SwipeGallery e tocca **Consenti accesso** per dare il permesso alla Libreria Foto. Con l'accesso limitato l'app vede solo le foto selezionate; puoi cambiarlo dalle Impostazioni dell'app.

## Come si usa

- **Galleria**: parte dall'elemento più recente non ancora valutato. Swipe a sinistra = cestino, a destra = tieni (invertibile nelle Impostazioni). I pulsanti in basso fanno lo stesso; **Annulla** ripristina fino alle ultime 20 azioni.
- **Griglia**: dal selettore in alto. Tocca una miniatura per far partire lo swipe da lì verso le più recenti o le più vecchie (include anche gli elementi già tenuti).
- **Album**: stesso funzionamento, limitato all'album. Le decisioni valgono ovunque e il cestino elimina dall'intera libreria.
- **Cestino**: nulla viene toccato finché non premi **Svuota cestino**; iOS chiede una conferma di sistema.
- Video: partono muti in loop, tocca per l'audio. Live Photo: tieni premuto per riprodurle. Pinch per lo zoom sulle foto.

## Sviluppo

```text
SwipeCore/            logica pura (coda, annulla, filtri, soglie del gesto), senza PhotoKit
SwipeCoreTests/       unit test della logica (Swift Testing)
SwipeGallery/
  App/                entry point, radice e tab
  Services/           PhotoKit, caricamento immagini, decisioni (SwiftData), album
  Features/           Gallery, Swipe, Grid, Albums, Trash, Settings, Onboarding
  Shared/             componenti Liquid Glass, miniature, media, formattatori
project.yml           definizione del progetto per XcodeGen
.github/workflows/    build su GitHub Actions
```

Con un Mac e Xcode 26 si può comunque lavorare in locale:

```bash
brew install xcodegen
xcodegen generate
open SwipeGallery.xcodeproj
```
