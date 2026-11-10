@tool
class_name Necromante
extends Resource
## Un necromante giocabile. I tre necromanti sono i file in necromanti/:
##   ossa.tres     Signore delle Ossa     (gratis: quello di partenza)
##   strega.tres   Strega Pestilenziale   (si compra nel negozio)
##   lich.tres     Lich del Ghiaccio      (si compra nel negozio)
## Doppio clic su un file per cambiarne nome, colore, prezzo, magie e poteri.
##
## Ogni necromante ha il suo albero delle ricerche (research_data.gd, campo
## "tree" = id del necromante): i punti ricerca sono in comune.
## Il necromante si sceglie nella schermata "Prepara la legione".

## Identificativo (minuscole): "ossa", "strega" o "lich". È anche l'albero delle ricerche.
@export var id := ""
## Nome mostrato (viene tradotto).
@export var nome := ""
## Riga sotto il nome, per esempio "Più evocazioni".
@export var titolo := ""
## Il potere sempre attivo, spiegato in una frase.
@export_multiline var descrizione := ""
## Sprite 16x16 sulla torre e nelle schermate (un AtlasTexture va benissimo).
@export var ritratto: Texture2D
## Colore d'accento: colpi della torre, sfera sul tetto, scritte.
@export var colore := Color("9c5ccc")
## Prezzo in monete d'osso nel negozio (0 = lo hai già dall'inizio).
@export_range(0, 100000) var prezzo := 0
## Le tre magie della barra in basso (tasti 1, 2, 3), in ordine.
## Valori possibili: palla_di_fuoco, area_curativa, saetta, nube_di_peste,
## maledizione, sciame, bufera, prigione_di_ghiaccio, cometa_gelata.
@export var magie: Array[String] = ["palla_di_fuoco", "area_curativa", "saetta"]

@export_group("Attacco della torre")
## Moltiplicatore del danno dei colpi della torre (1 = normale).
@export_range(0.1, 3.0, 0.05) var danno := 1.0
## Moltiplicatore della velocità d'attacco della torre (1 = normale).
@export_range(0.1, 3.0, 0.05) var velocita_attacco := 1.0

@export_group("Evocazioni (Signore delle Ossa)")
## Squadre in più da schierare a inizio partita.
@export_range(0, 10) var squadre_extra := 0
## Probabilità che un nemico ucciso si rialzi come scheletro (0.1 = 10%).
@export_range(0.0, 1.0, 0.01) var rialza_probabilita := 0.0
## Secondi di vita dello scheletro rialzato.
@export_range(1.0, 120.0, 0.5) var rialza_durata := 20.0

@export_group("Veleno e maledizioni (Strega)")
## Veleno dei colpi della torre: danni al secondo, in frazione del danno del colpo (0.3 = 30%).
@export_range(0.0, 3.0, 0.05) var veleno := 0.0
## Secondi di veleno.
@export_range(0.0, 20.0, 0.5) var veleno_durata := 3.0
## Secondi di maledizione a ogni colpo (0 = nessuna).
@export_range(0.0, 20.0, 0.5) var maledizione_durata := 0.0
## Danni in più subiti dai maledetti (0.3 = +30%; gli altri maledicono a +30%).
@export_range(0.0, 2.0, 0.05) var maledizione_forza := 0.3

@export_group("Gelo (Lich)")
## Rallentamento dei colpi della torre (0.3 = -30% di velocità).
@export_range(0.0, 0.9, 0.05) var rallenta := 0.0
## Secondi di rallentamento.
@export_range(0.0, 20.0, 0.5) var rallenta_durata := 2.0
## Probabilità di congelare a ogni colpo (0.08 = 8%). I congelati non si muovono né attaccano.
@export_range(0.0, 1.0, 0.01) var congela_probabilita := 0.0
## Secondi di congelamento (dimezzati sui boss e sui campioni).
@export_range(0.0, 10.0, 0.1) var congela_durata := 1.0
