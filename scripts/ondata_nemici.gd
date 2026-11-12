@tool
class_name OndataNemici
extends Resource
## UN'ONDATA SU MISURA: quali e quanti eroi arrivano in una o più ondate.
## Si aggiungono nell'Inspector del nodo Main di un livello, gruppo "Ondate su misura":
## Aggiungi elemento > Nuovo OndataNemici, poi scegli le ondate e i numeri.
##
##   SOSTITUISCI  in quelle ondate arrivano SOLO questi eroi (niente volanti o guaritori
##                automatici); il campione delle ondate 10, 20, 30... arriva lo stesso
##                se "Tieni campione" è attivo
##   AGGIUNGI     questi eroi si aggiungono a quelli normali dell'ondata
##
## Vita e danni degli eroi crescono comunque con l'ondata (gruppo "Difficoltà delle ondate").
## Se più righe valgono per la stessa ondata: vince l'ultima SOSTITUISCI, le AGGIUNGI si sommano.

enum Modo { SOSTITUISCI, AGGIUNGI }

## Prima ondata in cui vale.
@export_range(1, 9999) var dalla_ondata := 1
## Ultima ondata in cui vale (0 = solo "Dalla ondata").
@export_range(0, 9999) var alla_ondata := 0
## Tra la prima e l'ultima, ogni quante ondate (1 = tutte, 5 = una ogni 5).
@export_range(1, 100) var ogni := 1
@export var modo: Modo = Modo.SOSTITUISCI

@export_group("Eroi")
@export_range(0, 300) var soldati := 0
@export_range(0, 300) var arcieri := 0
@export_range(0, 300) var maghi := 0
@export_range(0, 300) var giganti := 0
## Curano gli altri eroi; arrivano nella seconda metà della fila.
@export_range(0, 100) var guaritori := 0
## Volano dritti verso la torre: li colpiscono solo unità a distanza, torre e magie.
@export_range(0, 100) var volanti := 0

@export_group("Opzioni")
## Ondate dei campioni (10, 20, 30...): il campione arriva anche in modalità SOSTITUISCI.
@export var tieni_campione := true
## Mescola gli eroi a caso; spento = arrivano in fila: soldati, arcieri, maghi, giganti.
@export var mescola := true
## Promemoria per te (non compare nel gioco).
@export_multiline var nota := ""


## Vale per l'ondata `n`?
func comprende(n: int) -> bool:
	var fine := alla_ondata if alla_ondata >= dalla_ondata else dalla_ondata
	if n < dalla_ondata or n > fine:
		return false
	return (n - dalla_ondata) % maxi(1, ogni) == 0


func totale() -> int:
	return soldati + arcieri + maghi + giganti + guaritori + volanti


## La fila degli eroi (senza campione), nel formato della coda di main.gd.
func coda() -> Array:
	var q: Array = []
	for coppia: Array in [["soldato", soldati], ["arciere", arcieri], ["mago", maghi], ["gigante", giganti]]:
		for _i in int(coppia[1]):
			q.append({"kind": coppia[0], "boss": false})
	if mescola:
		q.shuffle()
	for _i in guaritori:  # dietro agli altri
		q.insert(randi_range(floori(q.size() * 0.5), q.size()), {"kind": "guaritore", "boss": false})
	for _i in volanti:
		q.insert(randi_range(0, q.size()), {"kind": "volante", "boss": false})
	return q
