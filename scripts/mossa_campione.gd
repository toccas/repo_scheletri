class_name MossaCampione
extends Resource
## UNA MOSSA di un campione degli eroi (vedi campione.gd). Ogni mossa usa solo
## alcuni campi: qui sotto quali, per ogni tipo.
##
##   GRIDO          i nemici entro `raggio` fanno +`potenza` danni e vanno più veloci per `durata` s
##   EVOCA          chiama `numero` eroi di tipo `evoca` accanto a sé
##   CURA           cura gli eroi entro `raggio` di `potenza` della loro vita (sé stesso un quarto)
##   SCHIANTO       colpo attorno a sé: `danno` x danno del campione entro `raggio`, stordisce `durata` s
##   ROGO           fuoco a terra su uno scheletro: `danno` al secondo per `durata` s, largo `raggio`
##   METEORA        segnale per `ritardo` s, poi esplosione di `danno` entro `raggio`
##   PIOGGIA        `numero` piccoli colpi sparsi entro `raggio` attorno a uno scheletro (`danno` ciascuno)
##   CARICA         scatta in avanti per `raggio` pixel: `danno` e stordimento `durata` a chi travolge
##   SCUDO          per `durata` s subisce `potenza` danni in meno (0.7 = -70%)
##   LUCE           acceca: stordisce gli scheletri entro `raggio` per `durata` s
##   RESURREZIONE   rialza fino a `numero` eroi caduti entro `raggio` (se non ce ne sono, chiama soldati)
##   RAGGIO         segnale lungo la corsia per `ritardo` s, poi `danno` a tutti gli scheletri lungo `raggio` pixel
##   COLONNE        `numero` colonne di luce sugli scheletri: segnale `ritardo` s, poi `danno` entro `raggio`
##   TELETRASPORTO  scompare e ricompare `raggio` pixel più avanti
##
## Distanze in pixel dell'arte (una casella = 32). `danno` moltiplica il danno del campione,
## che cresce con l'ondata come quello degli altri eroi.

enum Tipo { GRIDO, EVOCA, CURA, SCHIANTO, ROGO, METEORA, PIOGGIA, CARICA, SCUDO, LUCE, RESURREZIONE, RAGGIO, COLONNE, TELETRASPORTO }

## Nome mostrato quando la usa (si traduce in lingue/testi.csv).
@export var nome := ""
@export var tipo: Tipo = Tipo.SCHIANTO
## Secondi tra un uso e l'altro.
@export_range(1.0, 60.0, 0.5) var ricarica := 8.0
## Secondi dall'arrivo del campione al primo uso.
@export_range(0.0, 60.0, 0.5) var primo_uso := 4.0
## La usa solo nella seconda fase (sotto la soglia di vita del campione).
@export var solo_fase2 := false
@export_range(0.0, 10.0, 0.05) var danno := 1.0
@export_range(0.0, 200.0, 1.0) var raggio := 20.0
@export_range(0.0, 20.0, 0.1) var durata := 3.0
@export_range(1, 12) var numero := 3
@export_range(0.0, 2.0, 0.05) var potenza := 0.3
## Secondi di preavviso (cerchio o linea a terra) prima del colpo.
@export_range(0.0, 5.0, 0.1) var ritardo := 1.0
## Tipo di eroe chiamato da EVOCA (e da RESURREZIONE se non trova caduti).
@export_enum("soldato", "arciere", "mago", "gigante") var evoca := "soldato"
