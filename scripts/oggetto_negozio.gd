@tool
class_name OggettoNegozio
extends Resource
## Un oggetto in vendita nel NEGOZIO.
##
## Si aggiunge e si modifica dall'Inspector della scena negozio.tscn: seleziona
## il nodo Negozio, apri la lista "Oggetti", premi "Aggiungi elemento" e scegli
## "Nuovo OggettoNegozio" (oppure duplica uno di quelli che ci sono già).

enum Valuta { MONETE_D_OSSO, EURO }

## Identificativo unico (minuscole, senza spazi). Serve per ricordare gli
## acquisti fatti una sola volta e, più avanti, per i pagamenti veri.
@export var id := ""
## Nome mostrato sulla scheda.
@export var nome := "Nuovo oggetto"
## Descrizione mostrata sotto il nome (va a capo da sola).
@export_multiline var descrizione := ""
## Icona dell'oggetto (meglio pixel art 16x16 o 32x32: viene ingrandita senza sfocare).
@export var icona: Texture2D
## Con cosa si paga. EURO per ora è solo un'anteprima: nelle build di prova
## l'acquisto viene simulato, nelle build finali compare "in arrivo".
@export var valuta: Valuta = Valuta.MONETE_D_OSSO
## Prezzo (monete d'osso, oppure euro con i centesimi, es. 1.99).
@export_range(0, 100000, 0.01) var prezzo := 50.0

@export_group("Cosa ottieni")
## Pergamene da aprire nel portale.
@export_range(0, 999) var pergamene := 0
## Monete d'osso aggiunte al portafoglio.
@export_range(0, 1000000) var monete := 0
## Sblocca il pacchetto VIP (velocità di gioco x3).
@export var sblocca_vip := false

@export_group("Vendita")
## Si può comprare una volta sola (poi la scheda mostra ACQUISTATO).
@export var una_sola_volta := false
## Piccola scritta sulla scheda, per esempio "MIGLIORE" o "-15%". Vuota = niente.
@export var etichetta := ""
## ID del prodotto su Google Play (per i pagamenti veri, più avanti).
@export var id_store := ""


## Prezzo da mostrare: "60" oppure "1,99 €".
func prezzo_testo() -> String:
	if valuta == Valuta.EURO:
		return ("%.2f €" % prezzo).replace(".", ",")
	return "%d" % int(prezzo)
