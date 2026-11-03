@tool
class_name ElencoLivelli
extends Resource
## Elenco dei livelli in ordine: ognuno si sblocca finendo quello prima.
## Doppio clic su livelli/elenco_livelli.tres per aggiungerne o riordinarli.

@export var livelli: Array[InfoLivello] = []
