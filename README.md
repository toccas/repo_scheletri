# Gioco Scheletri — prototipo

Tower defense roguelike: sei un necromante chiuso nella sua torre e devi resistere a 100 ondate di eroi.
Prototipo per **Godot 4.3** (funziona anche con le versioni 4.x successive).

## Come aprirlo

1. Estrai lo zip.
2. Apri Godot, scegli **Importa** e seleziona il file `project.godot` nella cartella estratta.
3. Premi **F5** (o il pulsante ▶ in alto a destra) per giocare.

## Come si gioca

- **Mappa:** una corsia vista di lato. A sinistra la torre del necromante, al centro la griglia di schieramento (9 colonne x 4 file), a destra la striscia rossa di spawn. I nemici compaiono in un punto qualsiasi della striscia e avanzano verso la torre, senza percorso prestabilito: devi coprire le file da cui arrivano.
- **Schieramento:** clicca una casella qualsiasi della griglia per evocare una squadra di scheletri (massimo 3). Tasto destro su una squadra per rimuoverla. Poi premi **Inizia ondate**.
- **Necromante:** spara da solo al nemico più vicino alla torre, fino alla linea verde visibile durante lo schieramento.
- **Level-up:** uccidendo nemici il necromante sale di livello e scegli fra 3 opzioni: buff per sé o per le unità, debuff per i nemici, oppure evocare una nuova squadra (poi clicchi la casella dove metterla).
- **Abilità:** tasti **1** Palla di fuoco, **2** Area curativa, **3** Saetta (o i pulsanti in alto). Poi clicca sulla mappa per lanciarle; tasto destro annulla. L'area curativa cura solo gli scheletri, mai la torre.
- **Velocità:** barra spaziatrice o pulsante "Velocità" (x1, x2, x3).
- **Fine ondata:** il necromante rianima le squadre cadute e le riporta a piena vita.
- **Boss:** ogni 10 ondate arriva un umano gigante potenziato, con la corona.
- **Sconfitta:** la vita della torre arriva a zero. **Vittoria:** superi l'ondata 100.
- A fine partita guadagni punti progresso (ondate superate + uccisioni/20), salvati su disco per il futuro albero dei progressi.

## Struttura

| File | Cosa contiene |
|---|---|
| `scripts/game_data.gd` | **Tutti i numeri del bilanciamento**: statistiche delle unità, abilità, torre, scaling delle ondate, boss. Parti da qui per il tuning. |
| `scripts/main.gd` | Gestore della partita: mappa, ondate, necromante, level-up, abilità, interfaccia, salvataggio. |
| `scripts/unit.gd` | Unità generica (scheletro alleato o umano nemico): comportamento e grafica segnaposto. |
| `scripts/projectile.gd` | Frecce, magie e colpi del necromante. |
| `scripts/fx.gd` | Effetti visivi (onde d'urto, fulmine). |
| `scenes/main.tscn` | Unica scena: tutto il resto viene creato da codice. |

La mappa è definita in cima a `main.gd`: `COLS` e `ROWS` (dimensioni della griglia), `CELL_W` e `CELL_D` (dimensioni di una casella), `SKEW` e `DEPTH_SCALE` (inclinazione e schiacciamento della prospettiva).

La logica di gioco lavora in coordinate di terreno (x = distanza lungo la corsia, y = profondità) e la funzione `to_screen()` le proietta in vista isometrica laterale. Le unità sono ordinate per profondità con `z_index`, quindi quelle davanti coprono quelle dietro, anche rispetto alla torre.

## Cosa manca rispetto al documento di design

- **Pixel art:** per ora la grafica è disegnata via codice con forme semplici, già in vista laterale. Per ogni unità basterà sostituire `_draw()` in `unit.gd` con un `AnimatedSprite2D` con i piedi nell'origine del nodo; la torre si disegna in `_draw_tower()` in `main.gd`.
- **Albero dei progressi:** i punti vengono già guadagnati e salvati (`user://progressi.cfg`), manca la schermata per spenderli. Per ora tutte e tre le abilità sono sbloccate per poterle provare.

## Test automatico

Da terminale puoi far giocare il computer da solo (piazzamento fisso, scelte casuali) per controllare il bilanciamento:

```
godot --headless --path . --fixed-fps 60 -- --autotest
```

Stampa l'andamento ogni 5 ondate e il risultato finale. Con i valori attuali un giocatore automatico così semplice cade di solito al primo boss (ondata 10) e a volte lo supera.
