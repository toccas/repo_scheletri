@tool
class_name BattutaDialogo
extends Resource
## Una battuta di un Dialogo: cosa dice il personaggio e con che faccia.

enum Espressione { NORMALE, FELICE, ARRABBIATO, PENSIEROSO, SORPRESO }

## Il testo del fumetto (va a capo da solo). Scrivilo in italiano:
## le traduzioni stanno in lingue/testi.csv (stessa frase nella colonna "keys").
@export_multiline var testo := ""
## La faccia del necromante mentre dice questa battuta.
@export var espressione: Espressione = Espressione.NORMALE
