@tool
class_name InfoLivello
extends Resource
## Una voce della schermata di scelta del livello (livelli/elenco_livelli.tres).
## Il livello si sblocca quando hai finito quello prima nell'elenco.

## Nome usato nei salvataggi: deve essere uguale a "Id Livello" nella scena del livello.
@export var id := ""
@export var nome := ""
@export_multiline var descrizione := ""
## La scena del livello (una copia di main.tscn con la sua griglia e il suo bioma).
@export_file("*.tscn") var scena := ""
## Per l'anteprima nella scheda.
@export var bioma: Bioma
