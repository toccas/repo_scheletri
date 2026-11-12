extends RefCounted
## REPORT DEV: con la modalità dev attiva (codice sviluppatore o build di prova) il gioco
## scrive in un registro tutto quello che succede: partite (livello, necromante, squadra,
## ricerche, ogni ondata con nemici, vita della torre, magie, morti, level-up, campioni,
## risultato finale) e cosa fa il giocatore fuori dalla battaglia (scene aperte, ricerche
## comprate, pergamene aperte, negozio, squadra, specializzazioni, livello scelto).
##
## Il registro sta in user://report_dev.log. Dal PANNELLO DEV, scheda REPORT:
##   - leggerlo direttamente nel gioco
##   - SALVA REPORT: crea un file .txt con il riepilogo dei progressi e tutto il registro
##     (nella cartella Documenti sul computer; sul telefono nella cartella dei dati del
##     gioco) e lo copia anche negli appunti, pronto da incollare in un messaggio
##   - INVIA REPORT: lo manda con il modulo di "Bug e consigli" (Formspree, se l'hai
##     impostato nel menu) o apre l'app email
##   - AZZERA: ricomincia da capo
## Uso dagli script:  ReportDev.evento("PARTITA", "Ondata 5 superata", {"torre": 80})

const Portafoglio := preload("res://scripts/portafoglio.gd")
const PERCORSO := "user://report_dev.log"
## Oltre questa grandezza il registro tiene solo la seconda metà (le cose più recenti).
const MAX_BYTE := 3 * 1024 * 1024
const VERSIONE_REPORT := 1

static var _sessione := false  # la prima riga di ogni avvio del gioco apre una sezione


## Il registro è attivo? (solo con la modalità dev)
static func attivo() -> bool:
	if Engine.is_editor_hint():
		return false  # nell'editor (scene @tool) non si registra niente
	return Portafoglio.dev_attivo() and not "--autotest" in OS.get_cmdline_user_args()


## Scrive una riga nel registro: [ora] CATEGORIA  testo  {dati}
static func evento(categoria: String, messaggio: String, dati: Dictionary = {}) -> void:
	if not attivo():
		return
	var riga := "[%s] %-10s %s" % [Time.get_datetime_string_from_system(false, true), categoria, messaggio]
	if not dati.is_empty():
		riga += "  " + JSON.stringify(dati)
	_scrivi(riga + "\n")


## Una riga di separazione con un titolo (inizio di una partita, nuova sessione...).
static func sezione(titolo: String) -> void:
	if not attivo():
		return
	_scrivi("\n==================== %s · %s ====================\n" % [titolo, Time.get_datetime_string_from_system(false, true)])


static func _scrivi(s: String) -> void:
	if not _sessione:  # prima riga di questo avvio del gioco
		_sessione = true
		s = "\n#################### AVVIO DEL GIOCO · %s · %s %s ####################\n" % [
			Time.get_datetime_string_from_system(false, true), OS.get_name(), OS.get_model_name()] + s
	var f := FileAccess.open(PERCORSO, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(PERCORSO, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string(s)
	var lung := f.get_length()
	f.close()
	if lung > MAX_BYTE:
		_accorcia()


## Tiene solo la seconda metà del registro.
static func _accorcia() -> void:
	var t := testo()
	var da := t.find("\n", floori(t.length() * 0.5))
	var f := FileAccess.open(PERCORSO, FileAccess.WRITE)
	if f != null:
		f.store_string("(... registro accorciato: le righe più vecchie sono state tolte ...)\n" + t.substr(maxi(0, da + 1)))
		f.close()


## Tutto il registro.
static func testo() -> String:
	if not FileAccess.file_exists(PERCORSO):
		return ""
	return FileAccess.get_file_as_string(PERCORSO)


static func righe() -> int:
	return testo().count("\n")


static func azzera() -> void:
	var f := FileAccess.open(PERCORSO, FileAccess.WRITE)
	if f != null:
		f.store_string("")
		f.close()


## Il report completo: dispositivo, progressi salvati e registro.
static func report_completo() -> String:
	var r := "REPORT DEV · Gioco Scheletri\n"
	r += "Creato: %s\n" % Time.get_datetime_string_from_system(false, true)
	var versione := String(load("res://scripts/impostazioni.gd").codici_dal_menu().get("versione", ""))
	if versione == "":  # non cambiata nell'Inspector: il valore predefinito dello script del menu
		versione = str((load("res://scripts/menu_castello.gd") as Script).get_property_default_value("versione_gioco"))
	r += "Versione gioco: %s · Godot %s\n" % [versione, Engine.get_version_info()["string"]]
	r += "Dispositivo: %s · %s · schermo %s · lingua %s\n" % [OS.get_name(), OS.get_model_name(), str(DisplayServer.screen_get_size()), TranslationServer.get_locale()]
	r += "\n---------- SALVATAGGIO (progressi.cfg) ----------\n"
	var cfg := ConfigFile.new()
	if cfg.load("user://progressi.cfg") == OK:
		for sez in cfg.get_sections():
			if sez == "dev":
				continue  # niente codici nel report
			r += "[%s]\n" % sez
			for k in cfg.get_section_keys(sez):
				r += "  %s = %s\n" % [k, var_to_str(cfg.get_value(sez, k))]
	else:
		r += "(nessun salvataggio)\n"
	r += "\n---------- REGISTRO ----------\n"
	var t := testo()
	r += t if t != "" else "(vuoto)\n"
	return r


## Salva il report in un file .txt e lo copia negli appunti. Ritorna dove l'ha salvato.
static func salva() -> String:
	var r := report_completo()
	var nome := "report_scheletri_%s.txt" % Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	var dove: Array[String] = []
	# copia sempre nella cartella del gioco
	var f := FileAccess.open("user://" + nome, FileAccess.WRITE)
	if f != null:
		f.store_string(r)
		f.close()
		dove.append(ProjectSettings.globalize_path("user://" + nome))
	# sul computer anche in Documenti (sul telefono le app non possono scriverci liberamente)
	if not OS.has_feature("mobile"):
		var doc := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if doc != "":
			var f2 := FileAccess.open(doc.path_join(nome), FileAccess.WRITE)
			if f2 != null:
				f2.store_string(r)
				f2.close()
				dove.push_front(doc.path_join(nome))
	DisplayServer.clipboard_set(r)
	return dove[0] if not dove.is_empty() else ""


## Apre la cartella in cui c'è il file (solo sul computer).
static func mostra_cartella(path: String) -> void:
	if path != "" and not OS.has_feature("mobile"):
		OS.shell_show_in_file_manager(path)
