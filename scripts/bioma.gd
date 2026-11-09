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

@export_group("Eroi nemici")
## Aspetto degli eroi in questo campo (elfi, vichinghi...): una striscia 128x16 con
## 8 sprite da 16x16 nello stesso ordine della riga degli umani di sprites.png:
## soldato A,B · arciere A,B · mago A,B · gigante A,B (guardano a destra).
## Vuoto = i cavalieri normali. I campioni restano sempre gli stessi.
@export var sprite_nemici: Texture2D
## Colore d'accento di ogni tipo di eroe (frecce, magie, scintille), per abbinarlo
## alle sprite. Chiavi: soldato, arciere, mago, gigante. Un tipo assente = colore normale.
@export var colori_nemici: Dictionary[String, Color] = {}
