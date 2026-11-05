class_name Specializzazione
extends Resource
## UN RAMO DI SPECIALIZZAZIONE di un'unità (es. "Arciere di fuoco").
## Si sceglie in preparazione quando l'unità arriva al rango 3 e al rango 5
## (vedi RamiUnita, un file per unità in specializzazioni/).
##
## Tutti i valori partono "neutri" (1 = invariato, 0 = niente): cambia solo quelli
## che servono. La descrizione degli effetti nel gioco si scrive da sola leggendo
## questi numeri, quindi resta sempre giusta anche se li ritocchi.
## Le specializzazioni del rango 3 e del rango 5 si sommano.

## Nome mostrato nel gioco (si traduce in lingue/testi.csv).
@export var nome := ""
## Frase facoltativa mostrata sotto gli effetti (vuota = solo gli effetti).
@export_multiline var descrizione := ""
## Nuovo colore dell'elemento colorato della sprite, dei proiettili e degli effetti.
## Trasparente = resta il colore d'accento normale dell'unità.
@export var colore := Color(0, 0, 0, 0)

@export_group("Statistiche (1 = invariato)")
## Moltiplicatore della vita (1.3 = +30%).
@export_range(0.1, 5.0, 0.05) var vita := 1.0
## Moltiplicatore del danno.
@export_range(0.1, 5.0, 0.05) var danno := 1.0
## Velocità d'attacco (1.5 = attacca il 50% più spesso, 0.8 = più lento).
@export_range(0.1, 5.0, 0.05) var cadenza := 1.0
@export_range(0.1, 5.0, 0.05) var gittata := 1.0
## Velocità di movimento.
@export_range(0.1, 5.0, 0.05) var velocita := 1.0
## Area di esplosioni, nubi, aure e colpi ad area.
@export_range(0.1, 5.0, 0.05) var area := 1.0
## Scheletri in più in ogni squadra.
@export_range(0, 6) var unita_extra := 0

@export_group("Effetti dei colpi")
## Colpisce anche altri N nemici (a distanza: altri proiettili; corpo a corpo: fendente).
@export_range(0, 6) var colpi_extra := 0
## Danno dei colpi extra rispetto al colpo normale.
@export_range(0.0, 2.0, 0.05) var danno_colpi_extra := 0.6
## Il colpo rimbalza come un fulmine su altri N nemici vicini.
@export_range(0, 6) var catena := 0
@export_range(0.0, 2.0, 0.05) var danno_catena := 0.6
## Probabilità di colpo critico (0.25 = 25%).
@export_range(0.0, 1.0, 0.01) var critico := 0.0
@export_range(1.0, 5.0, 0.1) var danno_critico := 2.0
## Fuoco / veleno: ogni secondo il nemico perde questa parte del danno del colpo.
@export_range(0.0, 3.0, 0.05) var danno_nel_tempo := 0.0
@export_range(0.5, 10.0, 0.5) var durata_danno_nel_tempo := 3.0
## Rallenta il nemico colpito (0.4 = -40% velocità).
@export_range(0.0, 0.8, 0.05) var rallenta := 0.0
@export_range(0.5, 10.0, 0.5) var durata_rallenta := 2.0
## Probabilità di stordire (i campioni restano storditi metà del tempo).
@export_range(0.0, 1.0, 0.01) var stordisci := 0.0
@export_range(0.2, 5.0, 0.1) var durata_stordisci := 0.8
## Secondi di maledizione (+30% danni subiti da tutti). 0 = niente.
@export_range(0.0, 10.0, 0.5) var maledici := 0.0
## Si cura di questa parte del danno inflitto.
@export_range(0.0, 2.0, 0.05) var rubavita := 0.0
## I colpi esplodono: raggio in pixel dell'arte (una casella = 32). 0 = niente.
@export_range(0.0, 60.0, 1.0) var esplosione := 0.0
@export_range(0.0, 2.0, 0.05) var danno_esplosione := 0.5
## Moltiplicatore del danno contro i campioni (boss).
@export_range(0.1, 5.0, 0.05) var danno_campioni := 1.0
## Finisce all'istante i nemici (non i campioni) sotto questa parte di vita.
@export_range(0.0, 0.6, 0.01) var esecuzione := 0.0
## Spinge indietro il nemico colpito di questi pixel (non i campioni).
@export_range(0.0, 40.0, 1.0) var respingi := 0.0

@export_group("Difesa")
## Danni subiti in meno (0.25 = -25%).
@export_range(0.0, 0.8, 0.01) var riduzione_danni := 0.0
## Rimanda a chi lo colpisce in corpo a corpo questa parte del danno.
@export_range(0.0, 3.0, 0.05) var spine := 0.0
## Recupera ogni secondo questa parte della vita massima (0.03 = 3%).
@export_range(0.0, 0.2, 0.005) var rigenera := 0.0
## Probabilità di schivare un colpo.
@export_range(0.0, 0.75, 0.01) var schiva := 0.0
## Quando muore esplode: raggio in pixel dell'arte (0 = niente).
@export_range(0.0, 60.0, 1.0) var esplode_alla_morte := 0.0

@export_group("Abilità speciale e aure")
## Rende più forte l'abilità speciale dell'unità (furia, carica, trafiggi, schianto,
## falce, peste, maledizione, urlo, aura del totem, durata dei rianimati...).
@export_range(0.1, 5.0, 0.05) var potenza_speciale := 1.0
## Cura gli scheletri vicini di questa parte della loro vita ogni secondo.
@export_range(0.0, 0.2, 0.005) var aura_cura := 0.0
## Rallenta i nemici vicini (0.4 = -40%).
@export_range(0.0, 0.8, 0.05) var aura_rallenta := 0.0
## Negromante: scheletri rianimati in più contemporaneamente.
@export_range(0, 6) var rianimati_extra := 0

## Come si sommano due specializzazioni (rango 3 + rango 5).
const MOLTIPLICA := ["vita", "danno", "cadenza", "gittata", "velocita", "area", "danno_campioni", "potenza_speciale"]
const SOMMA := ["unita_extra", "colpi_extra", "catena", "critico", "danno_nel_tempo", "rallenta", "stordisci",
	"rubavita", "esecuzione", "respingi", "riduzione_danni", "spine", "rigenera", "schiva",
	"aura_cura", "aura_rallenta", "rianimati_extra"]
const MASSIMO := ["danno_colpi_extra", "danno_catena", "danno_critico", "durata_danno_nel_tempo", "durata_rallenta",
	"durata_stordisci", "maledici", "esplosione", "danno_esplosione", "esplode_alla_morte"]
## Limiti dopo la somma.
const LIMITI := {"rallenta": 0.8, "riduzione_danni": 0.8, "schiva": 0.75, "critico": 1.0, "stordisci": 1.0, "aura_rallenta": 0.8}
