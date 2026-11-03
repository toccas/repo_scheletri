@tool
class_name Dialogo
extends Resource
## Un dialogo del tutorial (file .tres nella cartella dialoghi/).
## Doppio clic sul file per modificarlo nell'Inspector: nella lista "Battute"
## premi "Aggiungi elemento" > "Nuovo BattutaDialogo" e scrivi il testo.
## Le battute si possono riordinare trascinandole.

## Nome usato nel salvataggio per ricordare che il giocatore l'ha già visto.
## Se lo cambi, il dialogo verrà mostrato di nuovo a tutti.
@export var id := ""
## Nome del personaggio che parla (sopra il ritratto).
@export var nome := "NECROMANTE"
## Mostralo solo la prima volta (spento = ogni volta che si entra nella scena).
@export var solo_la_prima_volta := true
## Lettere al secondo dell'effetto macchina da scrivere.
@export_range(5.0, 200.0, 1.0) var velocita_testo := 45.0
@export var battute: Array[BattutaDialogo] = []


func chiave() -> String:
	return id if id != "" else resource_path.get_file().get_basename()
