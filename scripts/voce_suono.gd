@tool
class_name VoceSuono
extends Resource
## Un effetto sonoro della LibreriaSuoni (assets/suoni/libreria_suoni.tres).
## Per cambiarlo trascina un altro file audio (.wav / .ogg / .mp3) in "Suono".

## Il file audio.
@export var suono: AudioStream
## Volume di questo suono (0 = normale, negativo = più basso).
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db := 0.0
## Variazione casuale dell'altezza a ogni riproduzione (0 = sempre uguale).
## Un po' di variazione evita l'effetto "mitragliatrice" quando suona spesso.
@export_range(0.0, 0.5, 0.01) var variazione_tono := 0.06
## Tempo minimo tra due riproduzioni dello stesso suono (secondi).
@export_range(0.0, 1.0, 0.01, "suffix:s") var intervallo_minimo := 0.03
## Quante copie di questo suono possono suonare insieme.
@export_range(1, 8) var voci_massime := 3
