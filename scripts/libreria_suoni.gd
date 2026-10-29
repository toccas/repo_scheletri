@tool
class_name LibreriaSuoni
extends Resource
## TUTTI GLI EFFETTI SONORI DEL GIOCO, modificabili dall'Inspector.
## Apri assets/suoni/libreria_suoni.tres (doppio clic nel FileSystem): per ogni
## suono puoi cambiare il file audio, il volume, la variazione di tono, ecc.
## I nomi delle voci sono quelli usati nel codice: Suoni.play("spada").

## Spegne tutti gli effetti sonori.
@export var muto := false
## Volume di tutti gli effetti.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_generale := 0.0

@export_group("Interfaccia")
## Pulsanti premuti (anche tutti i Button di Godot, in automatico).
@export var click: VoceSuono
## Scelte importanti: inizia la partita, entra in un edificio.
@export var conferma: VoceSuono
## Azione non possibile (es. monete insufficienti).
@export var errore: VoceSuono
## Acquisto nel negozio.
@export var moneta: VoceSuono

@export_group("Attacchi")
## Colpo del corpo a corpo.
@export var spada: VoceSuono
## Freccia o dardo scoccato.
@export var freccia: VoceSuono
## Magia lanciata (maghi, lich, peste...).
@export var magia: VoceSuono
## Colpo del necromante dalla torre.
@export var necromante: VoceSuono
## Proiettile che colpisce.
@export var impatto: VoceSuono

@export_group("Abilità")
@export var palla_di_fuoco: VoceSuono
@export var saetta: VoceSuono
@export var area_curativa: VoceSuono

@export_group("Morti")
## Uno scheletro si sbriciola.
@export var morte_scheletro: VoceSuono
## Un eroe cade.
@export var morte_eroe: VoceSuono
## A fine ondata il terreno inghiotte teschi e armi.
@export var assorbimento: VoceSuono

@export_group("Partita")
## Corno degli eroi: inizia un'ondata.
@export var ondata: VoceSuono
@export var ondata_superata: VoceSuono
## Il necromante sale di livello.
@export var livello: VoceSuono
@export var torre_colpita: VoceSuono

@export_group("Evocazione")
## Il portale si carica.
@export var evoca_carica: VoceSuono
## Appare l'unità evocata.
@export var evoca_rivela: VoceSuono
## Una carta si gira (apertura di 10 pergamene).
@export var carta: VoceSuono
