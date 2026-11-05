class_name Campione
extends Resource
## UN CAMPIONE DEGLI EROI: arriva da solo nella sua ondata (10, 20, ... 100) al posto
## del vecchio "umano gigante" e ha le sue mosse. Un file per campione in campioni/
## (doppio clic per aprirlo nell'Inspector); l'elenco con le ondate è in
## campioni/elenco_campioni.tres.

## Id (nome del file), es. "capitano".
@export var id := ""
## Nome mostrato quando arriva e sopra la sua barra della vita.
@export var nome := ""
## Sottotitolo, es. "Primo scudo del Re".
@export var titolo := ""
## Battuta quando entra in campo.
@export_multiline var frase := ""
## Battuta quando passa alla seconda fase.
@export_multiline var frase_fase2 := ""
## Ondata in cui arriva (in modalità infinita i campioni tornano, più forti).
@export_range(1, 1000) var ondata := 10
## Sprite: 3 frame quadrati in fila (camminata, camminata, attacco/mossa), che guardano a destra.
@export var sprite: Texture2D
## Righe vuote sotto i piedi nella sprite (l'arcangelo vola più in alto).
@export_range(0, 32) var spazio_sotto_i_piedi := 0
## Colore d'accento: proiettili, effetti, barra della vita.
@export var colore := Color.WHITE

@export_group("Statistiche (prima della crescita con l'ondata)")
## Tipo di eroe da cui parte (per le regole di base: suono, resti...).
@export_enum("soldato", "arciere", "mago", "gigante") var tipo_base := "soldato"
@export var corpo_a_corpo := true
## Vita alla prima ondata: poi cresce come quella degli altri eroi.
@export_range(10.0, 20000.0, 10.0) var vita := 700.0
@export_range(0.0, 500.0, 0.5) var danno := 18.0
## Secondi tra un attacco e l'altro.
@export_range(0.1, 10.0, 0.05) var cadenza := 1.3
## Gittata (corpo a corpo: distanza dal bordo del bersaglio).
@export_range(0.0, 300.0, 1.0) var gittata := 5.0
@export_range(0.0, 100.0, 0.5) var velocita := 12.0
## Raggio del corpo (per le collisioni).
@export_range(2.0, 30.0, 0.5) var raggio := 9.0
## Area dei suoi colpi normali (0 = bersaglio singolo).
@export_range(0.0, 60.0, 1.0) var area := 0.0
## Altezza da terra da cui partono i suoi colpi e su cui arrivano i tuoi.
@export_range(4.0, 60.0, 1.0) var altezza_colpo := 16.0
## Vola: passa sopra acqua, crepacci e ostacoli.
@export var volante := false
@export_range(0, 500) var esperienza := 40
## Monete d'osso guadagnate quando lo sconfiggi.
@export_range(0, 1000) var monete := 20

@export_group("Seconda fase")
## Sotto questa parte di vita si arrabbia (0 = niente seconda fase).
@export_range(0.0, 1.0, 0.05) var soglia_fase2 := 0.5
## Nella seconda fase si muove, attacca e usa le mosse più in fretta.
@export_range(1.0, 3.0, 0.05) var velocita_fase2 := 1.3

@export_group("Mosse")
@export var mosse: Array[MossaCampione] = []
