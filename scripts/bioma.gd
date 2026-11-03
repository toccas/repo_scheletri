@tool
class_name Bioma
extends Resource
## Aspetto di un livello: sfondo, lastre della griglia, ostacoli e animazioni.
## I biomi stanno in biomi/*.tres: doppio clic per modificarli nell'Inspector.
## Le immagini hanno lo stesso formato di quelle del cimitero (assets/campo/):
##   cielo 432x110, terreno 432x240, lastre 128x80 (stesso atlante), ostacoli 128x32.

enum Ambiente { CIMITERO, PALUDE, CATTEDRALE, MONTAGNA }

@export var nome := "Cimitero"
## Panorama in alto (il bordo basso va sull'orizzonte).
@export var cielo: Texture2D
## Terreno in prospettiva dall'orizzonte in giù.
@export var terreno: Texture2D
## Atlante delle lastre del campo, del muretto e degli oggetti decorativi.
@export var lastre: Texture2D
## 4 ostacoli da 32x32 (uno per casella), scelti a caso per ogni ostacolo.
@export var ostacoli: Texture2D
## Animazioni e meteo: nebbia e fuochi fatui, polvere e candele, neve...
## Decide anche come sono disegnate le file bloccate (fossa, acqua, voragine, crepaccio).
@export var ambiente: Ambiente = Ambiente.CIMITERO

@export_group("Sfondo")
@export var stelle := true
@export var pipistrelli := true
## Eroi che marciano all'orizzonte e fuochi del loro accampamento.
@export var eroi_lontani := true
## Colore delle file bloccate (acqua, fondo del crepaccio...).
@export var colore_barriera := Color("1a1c1e")
