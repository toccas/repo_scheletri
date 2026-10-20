<div align="center">

# 💀 Gioco Scheletri

**Tower defense roguelike in pixel art: sei un necromante chiuso nella sua torre e devi resistere a 100 ondate di eroi.**

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![Piattaforme](https://img.shields.io/badge/piattaforme-Windows%20%7C%20Android-555)
![Stato](https://img.shields.io/badge/stato-prototipo%20giocabile-orange)
![Grafica](https://img.shields.io/badge/grafica-pixel%20art%2016x16-222)

![Battaglia](docs/screenshots/battaglia.gif)

</div>

---

## Indice

- [Il gioco](#il-gioco)
- [Caratteristiche](#caratteristiche)
- [Screenshot](#screenshot)
- [Come si gioca](#come-si-gioca)
  - [Obiettivo](#obiettivo)
  - [La mappa](#la-mappa)
  - [Schieramento](#schieramento)
  - [Le unità scheletro](#le-unità-scheletro)
  - [Gli eroi nemici](#gli-eroi-nemici)
  - [Il necromante e la torre](#il-necromante-e-la-torre)
  - [Salire di livello](#salire-di-livello)
  - [Le abilità](#le-abilità)
  - [Le ricerche](#le-ricerche)
- [Comandi](#comandi)
- [Download e installazione](#download-e-installazione)
- [Aprire il progetto in Godot](#aprire-il-progetto-in-godot)
- [Personalizzazione dall'Inspector](#personalizzazione-dallinspector)
- [Struttura del progetto](#struttura-del-progetto)
- [Esportare le build](#esportare-le-build)
- [Test automatico](#test-automatico)
- [Roadmap: i prossimi aggiornamenti](#roadmap-i-prossimi-aggiornamenti)
- [Crediti](#crediti)

---

## Il gioco

Per secoli gli eroi del regno hanno dato la caccia ai necromanti. Ora è arrivato il tuo turno: chiuso nell'ultima torre rimasta, circondato da un cimitero, hai solo le ossa dei morti e la tua magia per sopravvivere.

**Gioco Scheletri** è un tower defense con elementi roguelike. Ondata dopo ondata soldati, arcieri, maghi e giganti umani avanzano verso la tua torre. Tu evochi squadre di scheletri, le schieri sul campo, potenzi il necromante a ogni livello e scagli magie devastanti. Quando la torre cade la partita finisce, ma ogni tentativo ti fa guadagnare punti da investire nell'albero delle ricerche, per tornare più forte alla run successiva.

L'obiettivo è arrivare all'**ondata 100**. Non ci riuscirai al primo tentativo: è fatto apposta.

> Ispirazione: *Outhold*.

## Caratteristiche

- 🏰 **Difendi la torre del necromante:** è la tua unica vita e non si cura mai.
- 💀 **Quattro tipi di scheletri** da evocare e schierare liberamente su una griglia: soldati, arcieri, maghi e giganti.
- ⚔️ **Eroi che arrivano da qualsiasi punto** della zona di spawn, senza un percorso fisso: devi leggere le ondate e coprire le file giuste.
- 👑 **Un boss ogni 10 ondate:** un campione degli eroi con la corona, molto più resistente.
- 📈 **Level-up con scelte**: a ogni livello scegli tra tre potenziamenti casuali (buff, debuff ai nemici o nuove evocazioni).
- 🔥 **Tre abilità magiche** con tempo di ricarica: Palla di fuoco, Area curativa e Saetta.
- 🌳 **Albero delle ricerche** con 16 nodi in tre rami: la progressione permanente tra una run e l'altra.
- 🦴 **Il necromante rianima i caduti** a fine ondata e ogni squadra torna al completo.
- 🎨 **Pixel art 16x16 in scala di grigi**, nitida a qualsiasi risoluzione.
- ✨ **Animazioni e feedback:** affondi, fendenti, scintille, lampi quando un'unità viene colpita, scie dei proiettili; gli scheletri escono dalla torre e marciano fino alla loro casella.
- 🎯 **Anteprime della gittata** di arcieri, maghi e torre, per piazzare le unità con precisione.
- 🛠️ **Tutto regolabile dall'Inspector di Godot:** dimensioni della griglia, posizioni degli elementi, statistiche delle unità, gittata della torre, tema dell'interfaccia.

## Screenshot

| Menu principale | Schieramento |
|---|---|
| ![Menu](docs/screenshots/menu.png) | ![Schieramento](docs/screenshots/schieramento.png) |
| **Battaglia** | **Ricerche** |
| ![Battaglia](docs/screenshots/battaglia.png) | ![Ricerche](docs/screenshots/research.png) |

---

## Come si gioca

### Obiettivo

- **Vittoria:** sopravvivi fino all'**ondata 100**.
- **Sconfitta:** la vita della torre arriva a zero. La torre non può essere curata: ogni danno subito è permanente per tutta la run.

A fine partita, vinta o persa, guadagni **punti progresso**: uno per ogni ondata superata, più uno ogni 20 nemici uccisi, più 50 di bonus se vinci. Si spendono nelle [ricerche](#le-ricerche).

### La mappa

Il campo di battaglia è una corsia vista di lato:

```
 ┌──────┐ ┌───┬───┬───┬───┬───┬───┬───┬───┬───┐ ┃
 │      │ │   │   │   │   │   │   │   │   │   │ ┃
 │TORRE │ ├───┼───┼───┼───┼───┼───┼───┼───┼───┤ ┃  zona
 │      │ │   │ griglia di schieramento    │   │ ┃  di
 │  ⌂   │ ├───┼───┼───┼───┼───┼───┼───┼───┼───┤ ┃  spawn
 └──────┘ │   │   │   │   │   │   │   │   │   │ ┃
          └───┴───┴───┴───┴───┴───┴───┴───┴───┘ ┃
   ◄──────────────── i nemici avanzano ──────────
```

- **A sinistra la torre del necromante**, il bersaglio degli eroi.
- **Al centro la griglia di schieramento** (di base 9 colonne × 4 file), dove puoi evocare le tue squadre in qualsiasi casella.
- **A destra la zona di spawn**: i nemici compaiono in un punto qualsiasi e avanzano verso la torre nella loro fila. Quando si avvicinano convergono verso la sua base.

### Schieramento

1. Prima della prima ondata clicca una casella della griglia: si apre il pannello di scelta accanto alla casella.
2. Scegli quale squadra evocare. Passando sopra un'unità a distanza vedi subito la sua **gittata** disegnata sulla mappa.
3. Gli scheletri **escono dalla porta della torre** e marciano fino alla casella.
4. Puoi schierare fino a **3 squadre** (di più con la ricerca *Legione*). Tasto destro su una squadra per rimuoverla.
5. Premi **Inizia ondate**.

Durante la partita puoi evocare altre squadre con le scelte del level-up.

### Le unità scheletro

All'inizio della carriera hai solo il **soldato scheletro**: gli altri si sbloccano con le ricerche.

| Unità | Squadra | Vita | Attacco | Attacchi/s | Gittata | Ruolo |
|---|:---:|:---:|:---:|:---:|:---:|---|
| ⚔️ **Soldato scheletro** | 4 | 60 | 6 | 1,1 | corpo a corpo | Linea di difesa, intercetta chi passa vicino |
| 🏹 **Arciere scheletro** | 3 | 30 | 6 | 0,9 | 2,8 caselle | Danno costante da lontano |
| 🔮 **Scheletro mago** | 2 | 25 | 14 | 0,6 | 2 caselle | Magie con danno ad area |
| 🦴 **Scheletro gigante** | 1 | 260 | 14 | 0,7 | corpo a corpo | Muro di ossa, assorbe i colpi |

Comportamento in battaglia:

- **Il corpo a corpo intercetta** i nemici che passano nelle file vicine e poi torna alla sua casella.
- **Contrattacco:** quando uno scheletro corpo a corpo viene colpito, quel singolo scheletro va verso chi lo sta attaccando, arcieri e maghi lontani compresi, e lo insegue finché non lo uccide. Il resto della squadra resta in posizione.
- **Le unità a distanza** restano ferme e colpiscono chiunque entri nella loro gittata.
- **A fine ondata il necromante rianima i caduti:** le squadre tornano al completo e a piena vita, ed escono di nuovo dalla torre.

### Gli eroi nemici

Gli umani hanno le stesse quattro classi degli scheletri: **soldati**, **arcieri**, **maghi** e **giganti**. Le ondate diventano più numerose e i nemici più forti:

| Ondata | Cosa cambia |
|---|---|
| 1–2 | Solo soldati |
| 3+ | Arrivano gli arcieri |
| 7+ | Arrivano i maghi |
| 12+ | Arrivano i giganti |
| ogni 10 | 👑 **Boss:** un umano gigante con la corona, con vita ×2,5 e danno ×1,2 |

La vita e i danni dei nemici crescono a ogni ondata. I nemici attaccano gli scheletri che incontrano; arrivati alla torre la colpiscono. Frecce e magie infliggono alla torre solo metà del danno, perché le mura reggono.

### Il necromante e la torre

Il necromante sta in cima alla torre e **spara da solo** al nemico più vicino. Passa il mouse sulla torre per vedere fin dove arriva. Parametri di base:

| Torre | Necromante |
|---|---|
| 100 punti vita | 15 danni a colpo |
| Non si cura mai | 1,25 colpi al secondo |
| Danno dimezzato da frecce e magie | Gittata ≈ 2,7 caselle dalla torre |

### Salire di livello

Uccidere eroi dà esperienza al necromante. A ogni livello il gioco si ferma e ti propone **tre opzioni a caso** tra:

- **Necromante:** attacco +25%, velocità d'attacco +20%, vita della torre +25 (massima *e* attuale: è l'unico modo di recuperare vita).
- **Unità:** attacco +20%, velocità d'attacco +15%, vita +20%.
- **Debuff ai nemici:** velocità −10%, vita −10%, attacco −10%.
- **Evocazioni:** una nuova squadra di scheletri da piazzare dove vuoi.

### Le abilità

Si sbloccano nel ramo *Arcano* delle ricerche. Selezionala (tasto o pulsante), poi clicca sul campo per lanciarla.

| Abilità | Tasto | Effetto | Area | Ricarica |
|---|:---:|---|:---:|:---:|
| 🔥 **Palla di fuoco** | `1` | Danni alti | media | 12 s |
| ➕ **Area curativa** | `2` | Cura gli scheletri (mai la torre) | ampia | 15 s |
| ⚡ **Saetta** | `3` | Danni altissimi | piccola | 8 s |

La potenza delle abilità cresce con l'attacco del necromante.

### Le ricerche

Dal menu principale, **Research** apre l'albero delle ricerche: è la progressione permanente tra una run e l'altra. Clicca un nodo per vederne i dettagli, poi **SBLOCCA** o **POTENZIA**. "Azzera ricerche" restituisce tutti i punti spesi.

<details>
<summary><b>Tutti i nodi dell'albero</b> (clicca per aprire)</summary>

**Ramo Necromante**

| Ricerca | Effetto per livello | Livelli | Costi | Richiede |
|---|---|:---:|---|---|
| Mura rinforzate | Vita torre +20 | 5 | 4 · 6 · 9 · 12 · 16 | — |
| Furia oscura | Danno necromante +10% | 5 | 5 · 8 · 12 · 16 · 22 | — |
| Occhio della notte | Gittata necromante +10% | 3 | 6 · 10 · 15 | Mura rinforzate |
| Rito rapido | Velocità d'attacco necromante +8% | 3 | 8 · 12 · 18 | Furia oscura |
| Saggezza proibita | Esperienza +10% | 3 | 6 · 10 · 15 | Rito rapido |

**Ramo Evocazioni**

| Ricerca | Effetto per livello | Livelli | Costi | Richiede |
|---|---|:---:|---|---|
| Lame d'osso | Danno scheletri +10% | 5 | 5 · 8 · 12 · 16 · 22 | — |
| Ossa robuste | Vita scheletri +10% | 5 | 5 · 8 · 12 · 16 · 22 | — |
| Arcieri scheletro | Sblocca l'arciere | 1 | 6 | Lame d'osso |
| Maghi scheletro | Sblocca il mago | 1 | 12 | Arcieri scheletro |
| Giganti d'osso | Sblocca il gigante | 1 | 14 | Ossa robuste |
| Legione | +1 squadra schierabile | 2 | 25 · 40 | Giganti d'osso |

**Ramo Arcano**

| Ricerca | Effetto per livello | Livelli | Costi | Richiede |
|---|---|:---:|---|---|
| Palla di fuoco | Sblocca l'abilità | 1 | 8 | — |
| Area curativa | Sblocca l'abilità | 1 | 8 | — |
| Saetta | Sblocca l'abilità | 1 | 14 | Palla di fuoco |
| Potere arcano | Potenza abilità +15% | 3 | 10 · 16 · 24 | Saetta |
| Concentrazione | Ricarica abilità −10% | 3 | 10 · 16 · 24 | Area curativa |

</details>

---

## Comandi

| Azione | Mouse / tastiera | Android |
|---|---|---|
| Evocare una squadra | Clic su una casella | Tocco su una casella |
| Rimuovere una squadra (schieramento) | Tasto destro | *non ancora disponibile* |
| Vedere la gittata | Passa il mouse su un'unità o sulla torre | *non ancora disponibile* |
| Lanciare un'abilità | `1` `2` `3` o pulsanti, poi clic sul campo | Pulsanti, poi tocco |
| Annullare un'abilità | Tasto destro | *non ancora disponibile* |
| Velocità ×1 / ×2 / ×3 | `Spazio` o pulsante | Pulsante |
| Pausa (riprendi, ricomincia, menu) | `Esc` o pulsante | Pulsante |
| Menu | Mouse, oppure frecce + `Invio` | Tocco |

## Download e installazione

Scarica l'ultima versione dalla pagina [**Releases**](../../releases).

**🪟 Windows**
1. Scarica `GiocoScheletri_Windows.zip` ed estrailo.
2. Avvia `GiocoScheletri.exe`.
3. Se Windows mostra "PC protetto", clicca **Ulteriori informazioni → Esegui comunque**: l'eseguibile non è firmato.

**🤖 Android**
1. Scarica `GiocoScheletri.apk` sul telefono.
2. Aprilo e consenti l'installazione da origini sconosciute quando richiesto.
3. Funziona su dispositivi ARM a 32 e 64 bit.

## Aprire il progetto in Godot

1. Installa **[Godot 4.7](https://godotengine.org/download)** (versione standard, non .NET).
2. Clona la repo:
   ```bash
   git clone https://github.com/<tuo-utente>/gioco-scheletri.git
   ```
3. In Godot scegli **Importa** e seleziona `project.godot`.
4. Premi **F5**: il gioco parte dal menu principale.

---

## Personalizzazione dall'Inspector

Quasi tutto si regola senza toccare il codice.

**Scena `main.tscn`, nodo `Main`**

| Gruppo | Cosa controlla |
|---|---|
| Griglia di schieramento | **Colonne** (lunghezza), **File** (larghezza), **Tile Per Casella** |
| Schermo | **Scala Pixel**: se la mappa non entra nello schermo il gioco la riduce da solo |
| Interfaccia | **Tema Ui**: il tuo tema `.tres` per pulsanti, finestre e font |
| Torre del necromante | **Gittata** del necromante |
| Soldato / Arciere / Mago / Gigante | **Vita**, **Attacco**, **Velocità Attacco** (attacchi al secondo), **Gittata** (solo unità a distanza) |

Le distanze sono in pixel dell'arte: 32 corrisponde a una casella. Ricerche e potenziamenti si applicano sopra questi valori.

**Posizioni degli elementi**

Ogni scena ha dei nodi `Marker2D` da trascinare nella vista 2D o da spostare dal loro **Transform**:

| Scena | Segnaposto |
|---|---|
| `main.tscn` | `Griglia` (angolo in alto a sinistra), `Torre` (centro della base) |
| `menu.tscn` | `Titolo`, `Voci`, `Torre`, `Luna`, `Albero`, `Terreno` |
| `research.tscn` | `Titolo`, `Indietro`, `Punti`, `Albero`, `Dettagli` |

Menu e Ricerche si disegnano anche nell'editor, quindi vedi subito il risultato mentre sposti gli elementi.

**Bilanciamento e contenuti nel codice**

- `scripts/game_data.gd`: statistiche base, nemici, abilità, crescita delle ondate, boss.
- `scripts/research_data.gd`: nodi, costi, requisiti ed effetti delle ricerche. Ogni nodo è un blocco di testo facile da copiare e modificare.

**Grafica**

Tutta la pixel art sta in `assets/sprites.png`, un atlante di tile 16×16 in scala di grigi. Puoi ridisegnarlo con Aseprite, LibreSprite o Piskel mantenendo le stesse posizioni:

| Riga (y) | Contenuto |
|---|---|
| 0 | Scheletri: soldato A·B, arciere A·B, mago A·B, gigante A·B (2 frame di camminata) |
| 16 | Umani, stesso ordine |
| 32 | Erba ×2, terreno, spawn, necromante, corona del boss |
| 48 | Torre 48×96; a destra le icone delle ricerche |
| 64 / 80 | Altre icone delle ricerche |

Le sprite guardano a destra (gli umani vengono specchiati dal gioco) e hanno i piedi sull'ultima riga di pixel.

## Struttura del progetto

```
gioco-scheletri/
├── project.godot
├── tema.tres                 # tema dell'interfaccia (font pixel)
├── assets/
│   ├── sprites.png           # atlante pixel art 16x16
│   ├── font/                 # font dell'interfaccia
│   └── music/                # colonna sonora
├── scenes/
│   ├── menu.tscn             # menu principale (scena di avvio)
│   ├── main.tscn             # la partita
│   └── research.tscn         # albero delle ricerche
├── scripts/
│   ├── main.gd               # partita: mappa, ondate, level-up, abilità, interfaccia
│   ├── unit.gd               # scheletri e umani: comportamento, animazioni
│   ├── projectile.gd         # frecce, magie, colpi del necromante
│   ├── fx.gd                 # effetti: fendenti, scintille, onde, fulmini
│   ├── game_data.gd          # numeri del bilanciamento
│   ├── research_data.gd      # nodi delle ricerche e salvataggio
│   ├── research.gd           # schermata delle ricerche
│   ├── menu.gd               # menu animato
│   ├── pixel_font.gd         # font bitmap 5x7
│   └── layout_marker.gd      # anteprima dei segnaposto nell'editor
└── docs/screenshots/         # immagini di questo README
```

I progressi (punti e ricerche) vengono salvati in `user://progressi.cfg`.

## Esportare le build

Il progetto usa il renderer **Compatibility**, quindi gira anche su PC poco potenti e su Android.

1. In Godot: **Editor → Gestisci modelli di esportazione** e scarica i template 4.7.
2. **Progetto → Esporta**: i preset *Windows Desktop* e *Android* sono in `export_presets.cfg`.
3. **Per Android:**
   - imposta in **Impostazioni editor → Export → Android** il percorso dell'Android SDK e un keystore;
   - nelle Impostazioni progetto attiva **Rendering → Textures → VRAM Compression → Import ETC2 ASTC**, che Android richiede.

> 🔑 Non pubblicare mai il keystore di rilascio nella repo: aggiungilo al `.gitignore`.

## Test automatico

Il gioco può giocare da solo per controllare il bilanciamento:

```bash
godot --headless --path . --fixed-fps 60 -- --autotest          # tutto sbloccato, nessun bonus
godot --headless --path . --fixed-fps 60 -- --autotest --fresh  # come un giocatore alla prima run
```

Stampa l'andamento ogni 5 ondate e il risultato finale. Con i valori attuali, questo giocatore automatico molto semplice cade di solito intorno al primo boss (ondata 10).

---

## Roadmap: i prossimi aggiornamenti

Idee in arrivo, dalle più vicine alle più ambiziose. Suggerimenti e contributi sono benvenuti: apri una *issue*!

### 🔜 v0.2: "Ossa e suoni"
- [ ] 📱 **Controlli touch completi:** tieni premuto per vedere la gittata o rimuovere una squadra, pulsante "annulla" per le abilità.
- [ ] 🎵 **Colonna sonora chiptune ed effetti sonori:** spade, frecce, magie, ossa che si sbriciolano e il rintocco di campana a ogni ondata.
- [ ] 💥 **Animazioni di morte:** gli scheletri si sbriciolano in un mucchietto d'ossa, gli umani lasciano l'elmo a terra.
- [ ] 🔢 **Numeri del danno** che saltano fuori dai bersagli, con i colpi critici più grandi.
- [ ] ⚙️ **Menu impostazioni:** volume, schermo intero, velocità di gioco predefinita.

### ⚰️ v0.3: "Il raccolto di ossa"
- [ ] 🧟 **Rianima i nemici caduti:** gli eroi uccisi lasciano ossa da raccogliere. Spendile per trasformare un nemico morto in uno scheletro della sua classe, con un boss rianimato come premio massimo.
- [ ] 🛡️ **Nuove unità:**
  - **Scudiero d'osso:** blocca le frecce per chi gli sta dietro.
  - **Cavaliere scheletro su destriero fantasma:** carica lungo tutta la fila.
  - **Banshee:** il suo urlo rallenta i nemici.
  - **Catapulta d'ossa:** lancia teschi che rimbalzano.
- [ ] ⚔️ **Nuovi eroi:**
  - **Chierico:** cura gli alleati.
  - **Paladino:** aura che indebolisce i non-morti.
  - **Cacciatore di streghe:** punta direttamente la torre.
  - **Ariete d'assedio:** lento ma devastante contro le mura.
- [ ] 🧩 **Formazioni:** squadre adiacenti danno bonus, per esempio arcieri dietro ai soldati per +gittata o maghi vicino ai giganti per scudi magici.

### 🌕 v0.4: "Notti maledette"
- [ ] 🎲 **Reliquie roguelike:** dopo ogni boss scegli un oggetto maledetto con un effetto potente e un prezzo. Qualche esempio:
  - *Teschio del Re Lich:* ogni 10 uccisioni evochi uno scheletro gratis.
  - *Clessidra incrinata:* abilità più rapide, ma la torre perde 1 punto vita a ondata.
- [ ] 🌘 **Eventi delle ondate:**
  - *Luna di sangue:* scheletri più forti.
  - *Alba:* gli eroi brillano di luce sacra.
  - *Nebbia:* gittate ridotte per tutti.
  - *Eclissi:* i nemici arrivano da entrambi i lati.
- [ ] 👑 **Boss unici ogni 10 ondate**, ognuno con le sue mosse: il *Capitano della Guardia*, l'*Inquisitore*, il *Gran Paladino*, la *Regina Crociata*… fino all'**Arcangelo** dell'ondata 100.
- [ ] 🔥 **Trappole e terreno:** fosse di ossa, rovi maledetti, lapidi che bloccano il passaggio.

### 🗺️ v0.5: "Oltre il cimitero"
- [ ] 🧙 **Necromanti giocabili**, ognuno con un proprio albero delle ricerche:
  - **Signore delle Ossa:** più evocazioni.
  - **Strega Pestilenziale:** veleni e maledizioni.
  - **Lich del Ghiaccio:** rallenta e congela.
- [ ] 🏞️ **Nuovi biomi e mappe:** palude nebbiosa, cattedrale in rovina, passo di montagna innevato, con corsie multiple e ostacoli.
- [ ] 🌗 **Ciclo giorno/notte** durante la run: di notte gli scheletri sono più forti, di giorno gli eroi.

### 🏆 v1.0 e oltre
- [ ] ♾️ **Modalità infinita** dopo l'ondata 100, con classifica.
- [ ] 📅 **Sfida giornaliera:** stesso seed per tutti, una sola possibilità.
- [ ] 📖 **Bestiario** con le schede di unità e nemici, e **obiettivi** sbloccabili.
- [ ] 🌍 **Traduzione in inglese** e altre lingue.
- [ ] 🎨 **Palette alternative sbloccabili:** seppia, verde "fosforo", rosso sangue.
- [ ] 🛒 Pubblicazione su **itch.io**, **Google Play** e, perché no, **Steam**.

---

## Crediti

- **Game design e sviluppo:** *il tuo nome qui*
- **Motore:** [Godot Engine](https://godotengine.org) (licenza MIT)
- **Font:** `Minecraft.ttf`, `The Inquisition.ttf` *(aggiungi autori e licenze)*
- **Musica:** `chiptune-grooving` *(aggiungi autore e licenza)*
- **Ispirazione:** *Outhold*

## Licenza

*Scegli una licenza e aggiungi il file `LICENSE`.* Per esempio MIT per il codice e CC BY-NC per la grafica.

<div align="center">

---

*Fatto con 💀 e Godot.*

</div>
