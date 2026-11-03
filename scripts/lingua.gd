extends RefCounted
## LINGUE DEL GIOCO: italiano, inglese, spagnolo.
##
## Tutti i testi stanno in lingue/testi.csv (si apre con Excel / LibreOffice /
## Google Fogli, separatore virgola): la prima colonna "keys" è il testo
## italiano usato nel codice, le altre sono le traduzioni (it, en, es).
## Godot importa il CSV da solo e crea i file testi.it/en/es.translation.
##
## Per aggiungere un testo nuovo: scrivilo nel codice dentro tr("...") (nei nodi)
## oppure Lingua.t("...") (negli script statici), poi aggiungi una riga al CSV.
## Se una riga manca, il gioco mostra il testo italiano.
##
## La lingua scelta si salva in user://progressi.cfg, sezione [impostazioni].

const LINGUE := ["it", "en", "es"]
const NOMI := {"it": "ITALIANO", "en": "ENGLISH", "es": "ESPAÑOL"}
const CSV_PATH := "res://lingue/testi.csv"
const TRANSLATION_PATH := "res://lingue/testi.%s.translation"
const SAVE_PATH := "user://progressi.cfg"

static var _loaded := false


## Prepara le traduzioni e imposta la lingua salvata (o quella del sistema).
static func setup() -> void:
	if _loaded or Engine.is_editor_hint():
		return  # nell'editor i testi restano in italiano (e non tocchiamo la lingua dell'editor)
	_loaded = true
	for code in LINGUE:
		var tr_res: Translation = null
		var path: String = TRANSLATION_PATH % code
		if ResourceLoader.exists(path):
			tr_res = load(path) as Translation
		if tr_res == null:
			tr_res = _from_csv(code)  # CSV non ancora importato (es. appena copiato)
		if tr_res != null:
			TranslationServer.add_translation(tr_res)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var code: String = cfg.get_value("impostazioni", "lingua", "")
	if not code in LINGUE:
		var sys := OS.get_locale_language()
		code = sys if sys in LINGUE else "en"
	TranslationServer.set_locale(code)


## Il giocatore ha già scelto una lingua? (al primo avvio no: il menu gliela chiede)
static func scelta_fatta() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return String(cfg.get_value("impostazioni", "lingua", "")) in LINGUE


## Dimentica la lingua scelta: al prossimo avvio del menu viene richiesta.
static func dimentica_scelta() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	if cfg.has_section_key("impostazioni", "lingua"):
		cfg.erase_section_key("impostazioni", "lingua")
	cfg.save(SAVE_PATH)


## Testo tradotto nella lingua attuale (per gli script che non sono nodi).
static func t(s: String) -> String:
	if Engine.is_editor_hint():
		return s
	setup()
	return String(TranslationServer.translate(s))


static func current() -> String:
	setup()
	var loc := TranslationServer.get_locale().left(2)
	return loc if loc in LINGUE else "it"


## Cambia lingua e la ricorda per le prossime partite.
static func set_lang(code: String) -> void:
	if not code in LINGUE:
		return
	setup()
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # conserva tutto il resto del salvataggio
	cfg.set_value("impostazioni", "lingua", code)
	cfg.save(SAVE_PATH)


## Legge il CSV direttamente (solo se Godot non l'ha ancora importato).
static func _from_csv(code: String) -> Translation:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return null
	var header := f.get_csv_line()
	var col := header.find(code)
	if col < 0:
		return null
	var res := Translation.new()
	res.locale = code
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > col and row[0] != "" and row[col] != "":
			res.add_message(row[0], row[col])
	return res
