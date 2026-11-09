extends Node2D
## Gestore della partita: mappa, ondate, torre del necromante, level-up,
## abilità, interfaccia e salvataggio dei punti per l'albero dei progressi.
##
## MAPPA (dal documento di design): una corsia vista di lato.
##   - a sinistra la torre del necromante, che i nemici cercano di raggiungere
##   - al centro la griglia di schieramento: il giocatore può evocare le unità
##     in qualsiasi casella. Colonne e file si scelgono dall'Inspector.
##   - a destra la striscia di spawn: i nemici compaiono in un punto qualsiasi
##     e avanzano verso sinistra, senza un percorso prestabilito
##
## PIXEL ART: tutta la grafica è in tile da 16x16 (assets/sprites.png) in
## scala di grigi. Ogni pixel dell'arte diventa un quadrato di `px` x `px`
## pixel sullo schermo, e tutte le posizioni sono allineate a quella griglia.
##
## COORDINATE: la logica di gioco usa coordinate di TERRENO in pixel
## dell'arte, relative all'angolo in alto a sinistra della griglia:
##   x = distanza lungo la corsia, y = profondità (0 = fila in fondo)

const Data := preload("res://scripts/game_data.gd")
const Lingua := preload("res://scripts/lingua.gd")
const Dialoghi := preload("res://scripts/dialoghi.gd")
const Research := preload("res://scripts/research_data.gd")
const UnitScript := preload("res://scripts/unit.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const CampioneScript := preload("res://scripts/campione_unita.gd")
const FinePartitaScript := preload("res://scripts/fine_partita.gd")
const Pietra := preload("res://scripts/ui_pietra.gd")
const Collezione := preload("res://scripts/collezione.gd")
const Specializzazioni := preload("res://scripts/specializzazioni.gd")
const Portafoglio := preload("res://scripts/portafoglio.gd")
const Suoni := preload("res://scripts/suoni.gd")
const Livelli := preload("res://scripts/livelli.gd")
const AURA_RADIUS := 40.0  # raggio dell'aura del totem
const RAISE_RADIUS := 60.0  # il negromante minore rianima i nemici morti entro questa distanza
const RAISE_MAX := 3
const RAISE_LIFE := 14.0
## Le statistiche delle unità si modificano nell'Inspector di questa scena.
const PREP_SCENE_PATH := "res://scenes/preparazione.tscn"
const ATLAS := preload("res://assets/sprites.png")
# grafica 3D del campo (generata da make_campo_art.py, stesso stile del menu)
const TEX_SKY := preload("res://assets/campo/cielo.png")
const TEX_GROUND := preload("res://assets/campo/terreno.png")
const TEX_TILES := preload("res://assets/campo/lastre.png")
const TEX_TOWER := preload("res://assets/campo/torre.png")
const TEX_TOWER_MERLI := preload("res://assets/campo/torre_merli.png")
const TEX_PILLAR := preload("res://assets/campo/pilastro.png")

enum State { DEPLOY, PLAYING, LEVEL_UP, PLACING, GAME_OVER, VICTORY }

## Dialogo del necromante che spiega questa scena (compare solo la prima volta).
## Doppio clic sul file .tres per cambiare le battute; vuoto = nessun dialogo.
@export var dialogo_tutorial: Dialogo = preload("res://dialoghi/battaglia.tres")

@export_group("Livello")
## Nome del livello nei salvataggi (finito, record): ogni livello ne ha uno diverso,
## uguale all'id in livelli/elenco_livelli.tres.
@export var id_livello := "cimitero"
## Aspetto del livello (cielo, terreno, lastre, ostacoli, meteo): biomi/*.tres.
## Vuoto = il cimitero.
@export var bioma: Bioma
## Ondate da superare per finire il livello (e sbloccare il successivo).
@export_range(1, 200) var ondate_totali := 100
## File della griglia che non si possono usare (acqua, fosse, crepacci): dividono il
## campo in corsie separate. 0 = la fila in fondo. Gli eroi restano nella loro corsia.
@export var file_bloccate: PackedInt32Array = []
## Caselle con un ostacolo (x = colonna, y = fila, da 0): nessuno ci passa e non ci si schiera.
@export var ostacoli: Array[Vector2i] = []
## Avviando direttamente questa scena (F6) gioca in modalità infinita.
## Nel gioco vero la modalità la sceglie il giocatore nella schermata dei livelli.
@export var prova_modalita_infinita := false
@export_group("Campioni degli eroi")
## Un campione unico ogni 10 ondate (Capitano della Guardia, Inquisitore, ... Arcangelo).
## Doppio clic per cambiare ondate e campioni; ogni campione è un file in campioni/.
@export var campioni: ElencoCampioni = preload("res://campioni/elenco_campioni.tres")
## Spento = come prima: nelle ondate dei campioni arriva un umano gigante potenziato.
@export var campioni_attivi := true

@export_group("Griglia di schieramento")
## Lunghezza della griglia: numero di caselle lungo la corsia.
@export_range(1, 20) var colonne := 9
## Larghezza della griglia: numero di file in profondità.
@export_range(1, 10) var file := 4
## Lato di una casella, in tile da 16x16 pixel.
@export_range(1, 4) var tile_per_casella := 2
@export_group("Schermo")
## Quanti pixel dello schermo per ogni pixel dell'arte. Se la mappa non entra
## nello schermo, il gioco usa automaticamente la scala più grande che entra.
@export_range(1, 6) var scala_pixel := 3
@export_group("Interfaccia")
## Il tuo tema (.tres). Se lo lasci vuoto si usa il tema in scala di grigi.
@export var tema_ui: Theme
## Fine partita a schermo intero (bande nere, cronaca delle ondate, pulsanti grandi
## per il telefono). Spento = il vecchio pannello con l'elenco dei pulsanti.
@export var schermata_finale_cinematica := true

@export_group("Torre del necromante", "torre_")
## Attiva: la torre si mette da sola sul bordo sinistro della griglia (anche se
## cambi colonne, file, dimensione delle caselle o sposti la griglia) e il
## segnaposto "Torre" la segue nell'editor. Disattiva: la posizioni tu con il
## segnaposto "Torre" (la base resta comunque dentro il campo).
@export var torre_attaccata_alla_griglia := true
## Su quale fila sta la torre quando è attaccata alla griglia
## (0 = quella in fondo, -1 = quella davanti).
@export_range(-1, 9) var torre_fila := -1
## Fin dove spara il necromante, misurato dal lato destro della torre, in pixel
## dell'arte (32 = una casella). La ricerca "Occhio della notte" la aumenta.
@export_range(8, 600, 1) var torre_gittata: float = Data.NECRO_RANGE

@export_group("Colori degli effetti")
## Fiamme e onda d'urto della palla di fuoco.
@export var colore_palla_di_fuoco := Color("ec8a30")
## Fulmine della saetta.
@export var colore_saetta := Color("5292ec")
## Cerchio e crocette dell'area curativa.
@export var colore_area_curativa := Color("68be4c")
## Colpi del necromante e bagliore del suo bastone.
@export var colore_necromante := Color("9c5ccc")
## Nubi dello stregone della peste.
@export var colore_nube_peste := Color("b6d640")
@export_group("Feedback")
## Lo schermo trema con palla di fuoco, saetta, colpi alla torre e morte dei campioni.
@export var scuoti_schermo := true
## Quanto trema (1 = normale).
@export_range(0.0, 4.0, 0.1) var forza_scuotimento := 1.0
## Teschi e armi che possono restare per terra insieme (i più vecchi affondano prima).
@export_range(0, 400) var resti_massimi := 120
## I SUONI si modificano in assets/suoni/libreria_suoni.tres (doppio clic → Inspector).
@export_group("")

## STATISTICHE DEGLI SCHELETRI: ora si modificano tutte (anche le unità delle
## pergamene) nell'Inspector della scena PREPARAZIONE (scenes/preparazione.tscn).

## POSIZIONI: nella scena ci sono due nodi figli da spostare nell'editor
## (trascinandoli nella vista 2D o dal loro Transform nell'Inspector):
##   Griglia  -> angolo in alto a sinistra della griglia di schieramento
##   Torre    -> centro della base della torre
## Se uno dei due manca, la sua posizione viene calcolata in automatico.

# --- Misure in pixel dell'arte ---------------------------------------------
const TILE := 16
const TOWER_W := 48
const TOWER_H := 96
const SPAWN_W := 16
const LEFT_MARGIN := 6
const WALL_X := -4.0  # i nemici colpiscono la torre quando arrivano qui
const UI_TOP := 72  # pixel dello schermo occupati dalla barra in alto
const HINT_SPACE := 48  # spazio per i messaggi sotto la barra
const UI_BOTTOM := 96  # spazio per il pulsante "Inizia ondate"
const MAX_DEPLOY := 3  # squadre schierabili senza ricerche (vedi "Legione")
const SAVE_PATH := "user://progressi.cfg"

# Regioni dell'atlante
const R_GRASS_A := Rect2(0, 32, 16, 16)
const R_GRASS_B := Rect2(16, 32, 16, 16)
const R_DIRT := Rect2(32, 32, 16, 16)
const R_SPAWN := Rect2(48, 32, 16, 16)
const R_NECRO := Rect2(64, 32, 16, 16)
const R_TOWER := Rect2(0, 48, 48, 96)
# torre 3D: l'immagine ha 30 pixel in più sopra (torretta) e 3 di margine
const TOWER_IMG_OFFSET := Vector2(-3, -30)
const TOWER_WINDOWS := [Vector2(6, 20), Vector2(26, 20), Vector2(6, 46), Vector2(26, 46)]
const TOWER_DOOR_X := 18.0  # centro del portone, dal bordo sinistro della torre
const NECRO_FEET := Vector2(24, 9)  # dove sta il necromante sul tetto
# atlante lastre.png
const R_SLABS := [Rect2(0, 0, 16, 16), Rect2(16, 0, 16, 16), Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16), Rect2(64, 0, 16, 16), Rect2(80, 0, 16, 16)]
const R_FACE := [Rect2(0, 16, 16, 16), Rect2(16, 16, 16, 16), Rect2(32, 16, 16, 16)]
const R_WALL_OK := Rect2(48, 16, 16, 16)
const R_WALL_BROKEN := Rect2(64, 16, 16, 16)
const R_WALL_SKULL := Rect2(80, 16, 16, 16)
const R_WALL_TORCH := Rect2(96, 16, 16, 16)
const R_PROPS_SMALL := [Rect2(0, 32, 16, 16), Rect2(16, 32, 16, 16), Rect2(32, 32, 16, 16), Rect2(48, 32, 16, 16),
	Rect2(64, 32, 16, 16), Rect2(80, 32, 16, 16), Rect2(96, 32, 16, 16), Rect2(112, 32, 16, 16)]
const R_PROPS_TALL := [Rect2(0, 48, 16, 32), Rect2(16, 48, 16, 32), Rect2(32, 48, 16, 32)]
const FACE_H := 7  # spessore visibile del bordo davanti del campo
# icone 16x16 in sprites.png
const R_IC_FIRE := Rect2(48, 48, 16, 16)
const R_IC_BOLT := Rect2(64, 48, 16, 16)
const R_IC_HEAL := Rect2(80, 48, 16, 16)
const R_IC_HOURGLASS := Rect2(96, 48, 16, 16)
const R_IC_STAR := Rect2(112, 48, 16, 16)
const R_IC_EYE := Rect2(48, 64, 16, 16)
const R_IC_HEART := Rect2(80, 64, 16, 16)
const R_IC_SWORD := Rect2(96, 64, 16, 16)
const R_IC_FAST := Rect2(48, 80, 16, 16)
const ABILITY_ICONS := {"palla_di_fuoco": R_IC_FIRE, "area_curativa": R_IC_HEAL, "saetta": R_IC_BOLT}
# crepe della torre (coordinate nel rettangolo della torre), una lista per livello di danno
const TOWER_CRACKS := [
	[[Vector2(9, 15), Vector2(9, 19), Vector2(11, 19), Vector2(11, 24), Vector2(10, 24), Vector2(10, 28)],
	 [Vector2(28, 62), Vector2(28, 66), Vector2(30, 66), Vector2(30, 71)]],
	[[Vector2(10, 28), Vector2(10, 33), Vector2(12, 33), Vector2(12, 38)],
	 [Vector2(22, 34), Vector2(22, 38), Vector2(20, 38), Vector2(20, 44), Vector2(21, 44), Vector2(21, 49)],
	 [Vector2(33, 16), Vector2(33, 22), Vector2(31, 22), Vector2(31, 26)]],
	[[Vector2(3, 58), Vector2(3, 63), Vector2(5, 63), Vector2(5, 69), Vector2(4, 69), Vector2(4, 74)],
	 [Vector2(30, 71), Vector2(30, 77), Vector2(32, 77), Vector2(32, 84)],
	 [Vector2(15, 50), Vector2(15, 55), Vector2(17, 55), Vector2(17, 58)],
	 [Vector2(21, 49), Vector2(21, 54), Vector2(24, 54), Vector2(24, 60)]],
]
const SKY_FIRES := [Vector2(268, 9), Vector2(318, 7), Vector2(372, 10), Vector2(402, 6)]

# Scala di grigi
const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

var px := 3
var cell := 32
var cols := 9
var rows := 4
var depth := 128.0
var lane_len := 288.0
var wall_x := WALL_X
var origin := Vector2.ZERO  # angolo in alto a sinistra della griglia, in pixel dell'arte
var art_size := Vector2.ZERO  # schermo in pixel dell'arte
var tower_base_y := 0.0  # profondità (terreno) della base della torre

var state: int = State.DEPLOY
var slots: Array = []  # una per casella: {cell, center, kind, units}
var hover_slot := -1

var allies_root: Node2D
var enemies_root: Node2D
var projectiles_root: Node2D
var fx_root: Node2D
var tower_node: Node2D
var tower_flash := 0.0
var necro_flash := 0.0  # bagliore del bastone quando il necromante spara
var _icon_cache := {}
var ambient_node: Node2D  # animazioni dello sfondo (sopra il terreno, sotto le unità)
var front_node: Node2D  # cose davanti alle unità (pilastro crollato del portale)
var amb_t := 0.0
var horizon := 0.0
var props: Array = []  # oggetti decorativi: {r, pos}
var wall_tiles: Array = []  # muretto dietro il campo: {r, x}
var stars: Array = []
var bats: Array = []
var marchers: Array = []  # eroi lontani che marciano verso il portale
var embers: Array = []

const BIOMA_BASE := "res://biomi/cimitero.tres"
var tex_sky: Texture2D = TEX_SKY
var tex_ground: Texture2D = TEX_GROUND
var tex_tiles: Texture2D = TEX_TILES
var tex_obst: Texture2D = null
## Eroi di questo campo (elfi, vichinghi, ...) e i loro colori: dal bioma.
var tex_nemici: Texture2D
var colori_nemici: Dictionary = {}
var ambiente := 0  # Bioma.Ambiente
var lanes: Array[Vector2] = []  # corsie libere: (y inizio, y fine) in pixel dell'arte
var obstacle_rects: Array[Rect2] = []  # caselle con un ostacolo, in coordinate del terreno
var weather: Array = []  # neve, polvere, fuochi fatui
var dev_invincibile := false  # pannello dev (Ctrl+Shift+D): la torre non perde vita
var dev_senza_ricarica := false  # pannello dev: le magie si ricaricano subito
var dev_x5 := false  # pannello dev: il pulsante della velocità arriva fino a x5
var remains_root: Node2D
var remains: Array = []  # resti per terra (scripts/resti.gd)
var shake_t := 0.0
var shake_amp := 0.0
var tower_max_hp := Data.TOWER_HP
var tower_hp := Data.TOWER_HP

var necro_level := 1
var necro_xp := 0.0
var necro_xp_next := Data.xp_to_next(1)
var necro_dmg := Data.NECRO_DMG
var necro_cooldown := Data.NECRO_COOLDOWN
var necro_range := Data.NECRO_RANGE
var necro_timer := 0.0

## Moltiplicatori dei buff/debuff scelti durante la run.
var mods := {
	"ally_dmg": 1.0, "ally_rate": 1.0, "ally_hp": 1.0,
	"enemy_dmg": 1.0, "enemy_speed": 1.0, "enemy_hp": 1.0,
}

var wave := 0
var spawn_queue: Array = []
var spawn_timer := 0.0
var wave_running := false
var next_wave_timer := 0.0
var kills := 0

var ability_cd := {}
var selected_ability := ""
var pending_levelups := 0
var pending_summon := ""
var autotest := false

# Effetti dell'albero delle ricerche (vedi _apply_research)
var max_deploy := MAX_DEPLOY
var unlocked_units: Array = ["soldato"]  # la squadra della run (scelta in preparazione)
var unit_ranks := {}  # rango di ogni unità della collezione
## Effetti delle specializzazioni scelte (rango 3 e 5) per ogni unità, calcolati a inizio partita.
var spec_cache := {}
## Prove: "--rami=ab" sceglie il ramo a al rango 3 e b al rango 5 per tutte le unità.
var spec_forza := {}
var role_bonus := {}  # bonus delle ricerche per ruolo: {"dmg_corpo": 0.12, ...}
var clouds: Array = []  # nubi di peste: {p, t, dps}
## Campioni: quello in campo (per la barra in alto), presentazione e ultima mossa usata.
var campione_attivo = null
var intro_campione: Campione
var intro_t := 0.0
var mossa_testo := ""
var mossa_t := 0.0
var lampo_t := 0.0
var boss_hud: Control
var segnali_root: Node2D
## Fuoco a terra delle mosse dei campioni (ROGO): {p, r, t, dps, col, fx}
var zone_nemiche: Array = []
## Eroi caduti di recente (per la RESURREZIONE): {kind, g}
var eroi_caduti: Array = []
## Campioni sconfitti in questa partita (id), per la cronaca di fine partita.
var campioni_battuti: Array[String] = []
var fine_node: Control
var scrolls_earned := 0
## Modalità infinita: niente fine all'ondata finale, la corsa entra in classifica.
var infinita := false
## Ondate e uccisioni già premiate (quando continui dopo aver vinto, non si pagano due volte).
var ondate_pagate := 0
var uccisioni_pagate := 0
var unit_overrides := {}  # statistiche base dall'Inspector della preparazione
var unlocked_abilities: Array = []
var xp_mult := 1.0
var ability_cd_mult := 1.0
var ability_power_mult := 1.0

# Interfaccia
var ui: CanvasLayer
var ui_root: Control
var wave_label: Label
var tower_label: Label
var tower_bar: ProgressBar
var level_label: Label
var xp_bar: ProgressBar
var hint_label: Label
var hint_timer := 0.0
var start_button: Button
var speed_button: Button
var ability_buttons := {}
var modal: PanelContainer
var modal_box: VBoxContainer
var picker: Control  # scelta dell'unità: lapidi attorno alla casella cliccata
var picker_tip: Control  # scheda con le statistiche dell'unità sotto il mouse
var ui_font: Font
var wave_banner: Control  # stendardo con l'ondata e i nemici, accanto al portale
var spell_row: Control  # fila degli incantesimi in basso
var spell_slots := {}
var levelup: Control  # scelta del level-up: tre lapidi
var levelup_opts: Array = []
var next_queue: Array = []  # composizione della prossima ondata (per lo stendardo)
var next_queue_wave := 0
var smoke: Array = []  # fumo della torre danneggiata
var picker_slot := -1
var picker_hover := ""  # unità sotto il mouse nella scelta (per l'anteprima della gittata)
var pause_overlay: Control
var pause_button: Button
var soul_orb: Control  # sfera d'anima del necromante (livello + esperienza)
var orb_flash := 0.0  # bagliore quando il necromante sale di livello
var orb_level := 1
var paused := false


func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0
	Portafoglio.install_dev_tool(get_tree())
	Suoni.install()
	Lingua.setup()
	_apply_bioma()
	infinita = prova_modalita_infinita or (Livelli.modalita_infinita() and Livelli.scelto() == id_livello)
	if OS.is_debug_build():  # x5 scelto nel pannello dev resta attivo tra una partita e l'altra
		var dcfg := ConfigFile.new()
		dcfg.load(SAVE_PATH)
		dev_x5 = bool(dcfg.get_value("dev", "velocita_x5", false))
	_compute_layout()
	_apply_research()
	for r in rows:
		for c in cols:
			var barrier := r in file_bloccate
			var obstacle := Vector2i(c, r) in ostacoli
			slots.append({
				"cell": Vector2i(c, r),
				"center": Vector2((c + 0.5) * cell, (r + 0.5) * cell),
				"kind": "", "units": [],
				"blocked": barrier or obstacle, "barrier": barrier, "obstacle": obstacle,
			})
	_build_lanes()
	tower_node = Node2D.new()
	tower_node.name = "tower"
	tower_node.z_index = int(to_screen(Vector2(0, tower_base_y)).y)
	tower_node.draw.connect(_draw_tower)
	add_child(tower_node)
	ambient_node = Node2D.new()
	ambient_node.name = "ambient"
	ambient_node.z_index = 1
	ambient_node.draw.connect(_draw_ambient)
	add_child(ambient_node)
	front_node = Node2D.new()
	front_node.name = "front"
	front_node.z_index = 2000
	front_node.draw.connect(_draw_front)
	add_child(front_node)
	_setup_scenery()
	_build_obstacles()
	for n in ["remains", "segnali", "enemies", "allies", "projectiles", "fx"]:
		var node := Node2D.new()
		node.name = n
		add_child(node)
	enemies_root = $enemies
	allies_root = $allies
	projectiles_root = $projectiles
	fx_root = $fx
	remains_root = $remains
	segnali_root = $segnali
	for k in Data.ABILITY_ORDER:
		ability_cd[k] = 0.0
	next_queue = _coda_ondata(1)
	next_queue_wave = 1
	_build_ui()
	Dialoghi.avvia(self, dialogo_tutorial)
	_show_deploy_hint()
	if "--autotest" in OS.get_cmdline_user_args():
		_start_autotest()


# --- Layout, proiezione e griglia --------------------------------------------

## Calcola scala dei pixel e posizione della griglia a partire dai valori
## dell'Inspector, centrando torre + griglia + spawn nello schermo.
func _compute_layout() -> void:
	cols = colonne
	rows = file
	cell = TILE * tile_per_casella
	lane_len = cols * cell
	depth = rows * cell
	tower_base_y = depth - cell * 0.5
	wall_x = WALL_X
	var vp := get_viewport_rect().size
	var need_w := LEFT_MARGIN + TOWER_W + 4 + int(lane_len) + SPAWN_W + 4
	px = scala_pixel
	while px > 1:
		var aw := floori(vp.x / px)
		var ah := floori(vp.y / px) - ceili(float(UI_TOP + HINT_SPACE + UI_BOTTOM) / px)
		if need_w <= aw and depth <= ah:
			break
		px -= 1
	if px < scala_pixel:
		push_warning("Griglia %dx%d troppo grande per la scala %d: uso la scala %d." % [cols, rows, scala_pixel, px])
	art_size = Vector2(floori(vp.x / px), floori(vp.y / px))
	var top := ceili(float(UI_TOP + HINT_SPACE) / px)
	var bottom := ceili(float(UI_BOTTOM) / px)
	origin.x = LEFT_MARGIN + TOWER_W + 4 + maxi(0, floori((art_size.x - need_w) / 2.0))
	origin.y = top + maxi(0, floori((art_size.y - top - bottom - depth) / 2.0))
	# la cima della torre (con il necromante) non deve finire sotto la barra
	var tower_top := origin.y + tower_base_y - TOWER_H - 14.0
	var min_top := ceilf(float(UI_TOP) / px) + 2.0
	if tower_top < min_top:
		origin.y += min_top - tower_top
	# posizioni scelte nell'editor (allineate alla griglia dei pixel)
	var grid_marker := get_node_or_null("Griglia") as Node2D
	if grid_marker:
		origin = (grid_marker.position / px).round()
	var tower_marker := get_node_or_null("Torre") as Node2D
	if torre_attaccata_alla_griglia or tower_marker == null:
		wall_x = WALL_X
		tower_base_y = tower_row_base(torre_fila, rows, cell)
	else:
		var base := (tower_marker.position / px).round()
		wall_x = base.x + TOWER_W / 2.0 - origin.x
		# la torre deve poggiare sul campo, sennò i nemici non possono raggiungerla
		tower_base_y = clampf(base.y - origin.y, cell * 0.5, depth)
	_fit_on_screen()


## Se il campo (o la torre) esce dallo schermo, sposta la griglia quanto basta.
## Succede quando cambi colonne/file/caselle senza spostare il segnaposto "Griglia".
func _fit_on_screen() -> void:
	var before := origin
	var tower_left := wall_x - TOWER_W
	var min_x := maxf(2.0, 2.0 - tower_left)
	var max_x := art_size.x - lane_len - SPAWN_W - 2.0
	origin.x = clampf(origin.x, min_x, maxf(min_x, max_x))
	# la cima della torre (torretta compresa) non deve finire sotto la barra in alto
	var min_y := ceilf(float(UI_TOP) / px) + 2.0 - (tower_base_y - TOWER_H + TOWER_IMG_OFFSET.y)
	min_y = maxf(min_y, ceilf(float(UI_TOP) / px) + 14.0)
	# il bordo davanti del campo deve restare dentro lo schermo
	var max_y := art_size.y - depth - FACE_H - 2.0
	origin.y = maxf(origin.y, min_y)
	origin.y = minf(origin.y, maxf(max_y, ceilf(float(UI_TOP) / px)))
	origin = origin.round()
	if origin != before:
		push_warning("Il campo non entrava nello schermo: l'ho spostato di %s pixel. Sposta il segnaposto \"Griglia\" (o riduci colonne/file) per sistemarlo." % str((origin - before) * px))
	if origin.x + lane_len + SPAWN_W > art_size.x or origin.y + depth > art_size.y:
		push_warning("La griglia è troppo grande per lo schermo: riduci colonne, file o caselle dall'Inspector.")


## Legge l'albero delle ricerche e applica i bonus a questa partita.
## L'autotest normale sblocca tutto senza bonus (per misurare il bilanciamento
## di base); con --fresh simula un giocatore che non ha ancora fatto ricerche.
func _apply_research() -> void:
	var args := OS.get_cmdline_user_args()
	var levels: Dictionary = {} if "--autotest" in args else Research.load_state()["levels"]
	var b := Research.bonuses(levels)
	if "--autotest" in args and not "--fresh" in args:
		for k in ["unlock_arciere", "unlock_mago", "unlock_gigante",
				"unlock_palla_di_fuoco", "unlock_area_curativa", "unlock_saetta"]:
			b[k] = 1.0
	tower_max_hp += b.get("tower_hp", 0.0)
	tower_hp = tower_max_hp
	necro_dmg *= 1.0 + b.get("necro_dmg", 0.0)
	necro_cooldown /= 1.0 + b.get("necro_rate", 0.0)
	necro_range = torre_gittata * (1.0 + b.get("necro_range", 0.0))
	xp_mult = 1.0 + b.get("xp", 0.0)
	mods["ally_dmg"] *= 1.0 + b.get("ally_dmg", 0.0)
	mods["ally_hp"] *= 1.0 + b.get("ally_hp", 0.0)
	max_deploy = MAX_DEPLOY + int(b.get("deploy", 0.0))
	# squadra della run: le 4 unità scelte nella preparazione (collezione salvata)
	var col := Collezione.load_state()
	unit_ranks = col["owned"]
	unlocked_units = col["squad"].duplicate()
	if "--autotest" in args:
		unlocked_units = Data.STARTING_UNITS.duplicate()
		unit_ranks = {}
		for a in args:
			if a.begins_with("--squadra="):
				unlocked_units = Array(a.substr(10).split(","))
			if a.begins_with("--rango="):  # prove: tutte le unità a quel rango
				for k in Data.ALLY_ORDER:
					unit_ranks[k] = int(a.substr(8))
			if a.begins_with("--rami=") and a.length() >= 9:  # prove: rami scelti (a/b)
				spec_forza = {3: 0 if a[7] == "a" else 1, 5: 0 if a[8] == "a" else 1}
	for k in b:
		if k.begins_with("dmg_") or k.begins_with("hp_"):
			role_bonus[k] = b[k]
	print("[squadra] unità della run: ", unlocked_units)
	_load_unit_overrides()

	unlocked_abilities = []
	for k in Data.ABILITY_ORDER:
		if b.has("unlock_" + k):
			unlocked_abilities.append(k)
	ability_cd_mult = maxf(0.3, 1.0 - b.get("ability_cd", 0.0))
	ability_power_mult = 1.0 + b.get("ability_power", 0.0)


## Legge le statistiche delle unità dall'Inspector della scena di preparazione
## (anche quando avvii direttamente main.tscn).
func _load_unit_overrides() -> void:
	unit_overrides = {}
	if not ResourceLoader.exists(PREP_SCENE_PATH):
		return
	var packed := load(PREP_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var prep := packed.instantiate()
	if prep.has_method("stats_for"):
		for k in Data.ALLY_ORDER:
			unit_overrides[k] = prep.stats_for(k)
	prep.free()


## Quanti scheletri evoca una squadra di questo tipo.
func unit_count(kind: String) -> int:
	var extra := int(spec_effects(kind)["unita_extra"])  # specializzazioni
	if unit_overrides.has(kind):
		return maxi(1, int(unit_overrides[kind]["count"])) + extra
	return int(Data.UNITS[kind]["count"]) + extra


## Effetti delle specializzazioni scelte per un'unità (vedi scripts/specializzazioni.gd).
func spec_effects(kind: String) -> Dictionary:
	if not spec_cache.has(kind):
		spec_cache[kind] = Specializzazioni.effetti(kind, int(unit_ranks.get(kind, 1)), spec_forza)
	return spec_cache[kind]


## Profondità della base della torre quando è attaccata alla griglia
## (usata anche dal segnaposto nell'editor).
static func tower_row_base(fila: int, n_rows: int, cell_size: int) -> float:
	var r := n_rows - 1 if fila < 0 else clampi(fila, 0, n_rows - 1)
	return (r + 0.5) * cell_size


func to_screen(g: Vector2) -> Vector2:
	return (origin + g.round()) * px


func to_ground(s: Vector2) -> Vector2:
	return s / px - origin


## Distanza di un punto del terreno dalla torre (i nemici attaccano a distanza 0).
func tower_distance(g: Vector2) -> float:
	return g.x - wall_x


func slot_index(c: int, r: int) -> int:
	return clampi(r, 0, rows - 1) * cols + clampi(c, 0, cols - 1)


func slot_at_screen(p: Vector2) -> int:
	var g := to_ground(p)
	var c := floori(g.x / cell)
	var r := floori(g.y / cell)
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return -1
	if slots[r * cols + c]["blocked"]:
		return -1  # acqua, crepaccio o ostacolo: lì non si schiera
	return r * cols + c


func deployed_count() -> int:
	var n := 0
	for s in slots:
		if s["kind"] != "":
			n += 1
	return n


func free_slot_count() -> int:
	var n := 0
	for s in slots:
		if s["kind"] == "" and not s["blocked"]:
			n += 1
	return n


# --- Biomi, corsie e ostacoli ----------------------------------------------------

func _apply_bioma() -> void:
	var b := bioma
	if b == null and ResourceLoader.exists(BIOMA_BASE):
		b = load(BIOMA_BASE) as Bioma
	if b == null:
		return
	bioma = b
	tex_sky = b.cielo if b.cielo else TEX_SKY
	tex_ground = b.terreno if b.terreno else TEX_GROUND
	tex_tiles = b.lastre if b.lastre else TEX_TILES
	tex_obst = b.ostacoli
	ambiente = b.ambiente
	tex_nemici = b.sprite_nemici
	colori_nemici = b.colori_nemici


## Corsie = gruppi di file vicine non bloccate.
func _build_lanes() -> void:
	lanes.clear()
	var start := -1
	for r in rows + 1:
		var free := r < rows and not r in file_bloccate
		if free and start < 0:
			start = r
		elif not free and start >= 0:
			lanes.append(Vector2(start * cell, r * cell))
			start = -1
	if lanes.is_empty():
		lanes.append(Vector2(0, depth))
	obstacle_rects.clear()
	for o in ostacoli:
		if o.x >= 0 and o.x < cols and o.y >= 0 and o.y < rows:
			obstacle_rects.append(Rect2(Vector2(o) * cell, Vector2(cell, cell)))


func lane_of(y: float) -> int:
	var best := 0
	var best_d := INF
	for i in lanes.size():
		var l: Vector2 = lanes[i]
		var d := 0.0 if (y >= l.x and y <= l.y) else minf(absf(y - l.x), absf(y - l.y))
		if d < best_d:
			best_d = d
			best = i
	return best


## Due punti sono nella stessa corsia? (a sinistra della griglia, vicino alla torre, sì)
func same_lane(a: Vector2, b: Vector2) -> bool:
	if lanes.size() <= 1 or a.x < 0.0 or b.x < 0.0:
		return true
	return lane_of(a.y) == lane_of(b.y)


## Tiene un punto dentro la sua corsia e fuori dagli ostacoli.
func constrain(g: Vector2, radius: float) -> Vector2:
	if lanes.size() > 1 and g.x >= 0.0 and g.x <= lane_len + SPAWN_W:
		var l: Vector2 = lanes[lane_of(g.y)]
		g.y = clampf(g.y, l.x + minf(radius, (l.y - l.x) / 2.0), l.y - minf(radius, (l.y - l.x) / 2.0))
	for r in obstacle_rects:
		var rr := r.grow(radius * 0.8)
		if rr.has_point(g):
			# esce dal lato più vicino (di solito sopra o sotto: così si gira attorno)
			var dl := g.x - rr.position.x
			var dr := rr.end.x - g.x
			var du := g.y - rr.position.y
			var dd := rr.end.y - g.y
			var m := minf(minf(dl, dr), minf(du, dd))
			if m == du:
				g.y = rr.position.y
			elif m == dd:
				g.y = rr.end.y
			elif m == dl:
				g.x = rr.position.x
			else:
				g.x = rr.end.x
	return g


## Passo che gira attorno agli ostacoli: se `step` porterebbe dentro un ostacolo,
## l'unità scivola in su o in giù verso il lato libero più vicino (dentro la sua
## corsia) invece di restare bloccata dietro. Chi arriva da sopra o da sotto scivola di lato.
func aggira(g: Vector2, step: Vector2, radius: float) -> Vector2:
	if obstacle_rects.is_empty() or step == Vector2.ZERO:
		return step
	var next := g + step
	var pad := radius * 0.8 + 0.5
	for r in obstacle_rects:
		var rr := r.grow(pad)
		if not rr.has_point(next):
			continue
		var da_lato := g.x >= rr.end.x - 0.5 or g.x <= rr.position.x + 0.5
		if not da_lato:  # arriva da sopra o da sotto: scivola di lato
			return Vector2(step.x, 0.0) if absf(step.x) > 0.01 else Vector2(-step.length(), 0.0)
		# bloccato davanti: sale o scende, verso il lato libero più vicino
		var l: Vector2 = lanes[lane_of(g.y)] if not lanes.is_empty() else Vector2(0, depth)
		var su_y := rr.position.y - 0.5
		var giu_y := rr.end.y + 0.5
		var su_ok := su_y >= l.x + minf(radius, 2.0) and not _dentro_ostacolo(Vector2(rr.get_center().x, su_y - 1.0), pad)
		var giu_ok := giu_y <= l.y - minf(radius, 2.0) and not _dentro_ostacolo(Vector2(rr.get_center().x, giu_y + 1.0), pad)
		var su := g.y - rr.position.y <= rr.end.y - g.y
		if su and not su_ok and giu_ok:
			su = false
		elif not su and not giu_ok and su_ok:
			su = true
		var v := maxf(step.length(), 0.01)
		return Vector2(0.0, -v if su else v)
	return step


func _dentro_ostacolo(p: Vector2, pad: float) -> bool:
	for r in obstacle_rects:
		if r.grow(pad).has_point(p):
			return true
	return false


## Punto di partenza di un eroe: a caso in una delle corsie.
func _spawn_point() -> Vector2:
	var tot := 0.0
	for l in lanes:
		tot += l.y - l.x
	var pick := randf() * tot
	for l in lanes:
		var h := l.y - l.x
		if pick <= h:
			return Vector2(lane_len + randf_range(3.0, SPAWN_W - 3.0), randf_range(l.x + minf(5.0, h / 2.0), l.y - minf(2.0, h / 2.0)))
		pick -= h
	return Vector2(lane_len + 8.0, depth / 2.0)


# --- Ciclo di gioco ----------------------------------------------------------

func is_running() -> bool:
	return state == State.PLAYING and not paused


func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		var a := roundf(shake_amp * forza_scuotimento * clampf(shake_t / 0.2, 0.3, 1.0))
		position = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * a * px if shake_t > 0.0 else Vector2.ZERO
	hover_slot = slot_at_screen(get_global_mouse_position())
	if tower_flash > 0.0:
		tower_flash -= delta
	necro_flash = maxf(0.0, necro_flash - delta)
	orb_flash = maxf(0.0, orb_flash - delta * 1.5)
	intro_t = maxf(0.0, intro_t - delta)
	mossa_t = maxf(0.0, mossa_t - delta)
	lampo_t = maxf(0.0, lampo_t - delta)
	if boss_hud != null:
		boss_hud.queue_redraw()
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.text = ""
	if is_running():
		for k in ability_cd:
			ability_cd[k] = maxf(0.0, ability_cd[k] - delta)
		_process_waves(delta)
		_process_necro(delta)
		_update_clouds(delta)
		_update_zone_nemiche(delta)
		if autotest:
			_autotest_cast()
	_update_hud()
	_update_ambient(delta)
	queue_redraw()
	tower_node.queue_redraw()
	ambient_node.queue_redraw()
	front_node.queue_redraw()


func _process_waves(delta: float) -> void:
	if wave_running:
		if not spawn_queue.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_enemy(spawn_queue.pop_front())
				spawn_timer = maxf(0.25, 0.8 - wave * 0.006)
		elif _alive_count(enemies_root) == 0:
			wave_running = false
			if wave >= ondate_totali and not infinita:
				_end_run(true)
				return
			next_wave_timer = 3.0
			_revive_squads()
			_absorb_remains()
			Suoni.play("ondata_superata")
			if infinita and wave == ondate_totali:
				set_hint(tr("Ondata %d superata! Da qui ogni ondata vale per la classifica.") % wave, 4.0)
			else:
				set_hint(tr("Ondata %d superata! Il necromante rianima i caduti.") % wave, 2.5)
			if wave % Data.WAVES_PER_SCROLL == 0:
				scrolls_earned += 1
				if not autotest:
					Collezione.add_scrolls(1)
				set_hint(tr("Ondata %d superata: hai ottenuto una PERGAMENA! Aprila nel portale.") % wave, 4.0)
	else:
		next_wave_timer -= delta
		if next_wave_timer <= 0.0:
			_start_wave(wave + 1)


func _start_wave(n: int) -> void:
	wave = n
	spawn_queue = next_queue.duplicate() if next_queue_wave == n else _coda_ondata(n)
	next_queue = _coda_ondata(n + 1)
	next_queue_wave = n + 1
	spawn_timer = 0.0
	wave_running = true
	Suoni.play("ondata", 0.85 if n % Data.BOSS_EVERY == 0 else 1.0)
	if n % Data.BOSS_EVERY == 0 and not _campione_in_coda(spawn_queue):
		set_hint(tr("Ondata %d: arriva un campione degli eroi!") % n, 3.0)
	elif n % Data.BOSS_EVERY == 0:
		set_hint(tr("Ondata %d · arriva un campione: %s") % [n, tr(_campione_in_coda(spawn_queue).nome)], 3.0)
	else:
		set_hint(tr("Ondata %d") % n, 1.5)
	if autotest and n % 5 == 0:
		print("[autotest] ondata %d | torre %.0f/%.0f | livello %d | uccisioni %d | scheletri vivi %d" % [
			n, tower_hp, tower_max_hp, necro_level, kills, _alive_count(allies_root)])


func _spawn_enemy(entry: Dictionary) -> void:
	var hp_mult: float = Data.enemy_hp_mult(wave) * mods["enemy_hp"]
	if entry.get("campione") is Campione:
		var c := CampioneScript.new()
		c.game = self
		c.setup_campione(entry["campione"], hp_mult, Data.enemy_dmg_mult(wave))
		c.ground = _spawn_point()
		enemies_root.add_child(c)
		_annuncia_campione(c)
		return
	var u := UnitScript.new()
	u.game = self
	u.setup_enemy(entry["kind"], hp_mult, Data.enemy_dmg_mult(wave), entry["boss"])
	# punto qualsiasi della striscia di spawn
	u.ground = _spawn_point()
	enemies_root.add_child(u)


func _process_necro(delta: float) -> void:
	necro_timer -= delta
	if necro_timer > 0.0:
		return
	var t = nearest_to_tower(enemies_root, necro_range)
	if t != null:
		spawn_projectile(0, Vector2(wall_x - TOWER_W / 2.0, tower_base_y), TOWER_H + 6.0, t, false, necro_dmg, 0.0, false, "necro")
		Suoni.play("necromante")
		necro_flash = 0.2
		necro_timer = necro_cooldown


# --- Servizi usati da unità e proiettili --------------------------------------

func _alive_count(root: Node) -> int:
	var n := 0
	for c in root.get_children():
		if not c.dead:
			n += 1
	return n


## Punto del terreno davanti alla porta della torre, da cui escono gli scheletri.
func tower_door() -> Vector2:
	return Vector2(wall_x - TOWER_W + TOWER_DOOR_X, tower_base_y)


## `stessa_corsia`: per il corpo a corpo, ignora chi sta in un'altra corsia.
func nearest_unit(root: Node, from: Vector2, max_dist: float, stessa_corsia: bool = false):
	var best = null
	var best_d := max_dist
	for c in root.get_children():
		if c.dead or not c.visible:  # chi è ancora dentro la torre non si può colpire
			continue
		if stessa_corsia and not same_lane(from, c.ground):
			continue
		var d := from.distance_to(c.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


func nearest_to_tower(root: Node, max_dist: float):
	var best = null
	var best_d := max_dist
	for c in root.get_children():
		if c.dead:
			continue
		var d := tower_distance(c.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


func damage_area(center: Vector2, area_radius: float, amount: float, target_team: int, attacker = null) -> void:
	var root := enemies_root if target_team == 1 else allies_root
	for c in root.get_children():
		if not c.dead and center.distance_to(c.ground) <= area_radius + c.radius:
			c.take_damage(amount, attacker)


func spawn_projectile(team: int, from: Vector2, from_height: float, target, to_tower: bool,
		dmg: float, splash: float, magic: bool, look_override: String = "", shooter = null) -> void:
	var p := ProjectileScript.new()
	p.game = self
	p.team = team
	p.shooter = shooter
	p.target = target
	p.to_tower = to_tower
	p.dmg = dmg
	p.splash = splash
	p.look = look_override if look_override != "" else ("magic" if magic else "arrow")
	if p.look == "necro":
		p.tint = colore_necromante
	elif shooter != null and is_instance_valid(shooter):
		p.tint = shooter.accent()
	p.ground = from
	p.height = from_height
	p.start_height = from_height
	projectiles_root.add_child(p)


## Effetto sul corpo di un'unità (fendenti, scintille): `lift` è l'altezza da terra
## in pixel dell'arte, `dir` il verso (1 = verso destra).
func spawn_unit_fx(g: Vector2, kind: String, lift: float, dir: float = 1.0, life: float = 0.2, color: Color = C6) -> void:
	var f := FxScript.new()
	f.kind = kind
	f.color = color
	f.life = life
	f.dir = 1.0 if dir >= 0.0 else -1.0
	f.scale = Vector2.ONE * px
	f.position = to_screen(g) - Vector2(0, roundf(lift) * px)
	f.z_index = 3000
	fx_root.add_child(f)


## Icona in pixel art di uno scheletro (primo frame dell'atlante, ingrandito senza sfocare).
func unit_icon(kind: String, size: int = 48) -> Texture2D:
	var key := "%s_%d" % [kind, size]
	if not _icon_cache.has(key):
		var img := Data.ally_texture(kind).get_image().get_region(Rect2i(Data.ally_region(kind)))
		img.resize(size, size, Image.INTERPOLATE_NEAREST)
		_icon_cache[key] = ImageTexture.create_from_image(img)
	return _icon_cache[key]


## Fulmine tra due unità (specializzazioni con il colpo a catena).
func spawn_zap(from_g: Vector2, from_h: float, to_g: Vector2, to_h: float, color: Color) -> void:
	var f := FxScript.new()
	f.kind = "zap"
	f.color = color
	f.life = 0.22
	f.scale = Vector2.ONE * px
	f.position = to_screen(from_g) - Vector2(0, roundf(from_h) * px)
	f.to = (to_screen(to_g) - Vector2(0, roundf(to_h) * px) - f.position) / px
	f.z_index = 3000
	fx_root.add_child(f)


## Effetto disegnato sul terreno (onde, fulmini).
func spawn_ground_fx(g: Vector2, fx_radius: float, color: Color, life: float, kind: String = "ring") -> void:
	var f := FxScript.new()
	f.kind = kind
	f.radius = fx_radius
	f.color = color
	f.life = life
	f.scale = Vector2.ONE * px
	f.position = to_screen(g)
	f.z_index = 3000
	fx_root.add_child(f)


func damage_tower(amount: float) -> void:
	if state != State.PLAYING or dev_invincibile:
		return
	tower_hp -= amount
	tower_flash = 0.15
	Suoni.play("torre_colpita")
	shake(0.12, 1.0)
	if tower_hp <= 0.0:
		tower_hp = 0.0
		_end_run(false)


func on_enemy_killed(u) -> void:
	kills += 1
	if not u.is_boss and u.visible:  # per la RESURREZIONE dei campioni
		eroi_caduti.append({"kind": u.kind, "g": u.ground})
		if eroi_caduti.size() > 30:
			eroi_caduti.pop_front()
	if u.is_boss:
		shake(0.4, 2.0)
	_try_raise(u)
	necro_xp += u.xp_value * xp_mult
	while necro_xp >= necro_xp_next:
		necro_xp -= necro_xp_next
		necro_level += 1
		necro_xp_next = Data.xp_to_next(necro_level)
		pending_levelups += 1
	if pending_levelups > 0 and state == State.PLAYING:
		call_deferred("_open_level_up")


## Scuote lo schermo per `dur` secondi di `amp` pixel dell'arte (vedi "Feedback" nell'Inspector).
func shake(dur: float, amp: float) -> void:
	if not scuoti_schermo or autotest:
		return
	shake_amp = amp if shake_t <= 0.0 else maxf(shake_amp, amp)
	shake_t = maxf(shake_t, dur)


## Resti di un'unità morta (teschio o arma per terra), vedi scripts/resti.gd.
func add_remains(r: Node2D) -> void:
	remains = remains.filter(func(x) -> bool: return is_instance_valid(x))
	remains_root.add_child(r)
	remains.append(r)
	while remains.size() > resti_massimi:
		var old = remains.pop_front()
		if is_instance_valid(old):
			old.sink(0.0)


## Fine ondata: il terreno inghiotte teschi e armi, uno dopo l'altro.
func _absorb_remains() -> void:
	var any := false
	for r in remains:
		if is_instance_valid(r) and not r.sinking:
			r.sink(randf_range(0.2, 0.9))
			any = true
	remains.clear()
	if any:
		get_tree().create_timer(0.25).timeout.connect(func() -> void: Suoni.play("assorbimento"))


## La casella resta occupata anche se la squadra muore tutta:
## a fine ondata viene rianimata (vedi _revive_squads).
func on_ally_died(u) -> void:
	for s in slots:
		if u in s["units"]:
			s["units"].erase(u)


# --- Schieramento ------------------------------------------------------------

func _spawn_squad(idx: int, kind: String) -> void:
	var s: Dictionary = slots[idx]
	s["kind"] = kind
	s["units"] = []
	var n: int = unit_count(kind)
	var spread := cell * 0.22
	for i in n:
		var u := UnitScript.new()
		u.game = self
		u.setup_ally(kind, mods["ally_hp"], ally_stats(kind))
		var off := Vector2.ZERO if n == 1 else Vector2.from_angle(TAU * i / n - PI / 2.0) * spread
		u.home = s["center"] + off
		# escono dalla porta della torre uno dopo l'altro e marciano fino alla casella
		u.ground = tower_door() + Vector2(0, randf_range(0.0, 2.0))
		u.entering = true
		u.enter_delay = 0.05 + i * 0.22
		u.visible = false
		allies_root.add_child(u)
		s["units"].append(u)
	spawn_ground_fx(s["center"], cell * 0.45, C6, 0.45)


## A fine ondata ogni squadra torna al completo e a piena vita.
## Cura solo gli scheletri: la torre non si cura mai.
func _revive_squads() -> void:
	for i in slots.size():
		var kind: String = slots[i]["kind"]
		if kind == "":
			continue
		var full: bool = slots[i]["units"].size() == unit_count(kind)
		if full:
			for u in slots[i]["units"]:
				u.hp = u.max_hp
		else:
			_remove_squad(i)
			_spawn_squad(i, kind)


func _remove_squad(idx: int) -> void:
	var s: Dictionary = slots[idx]
	for u in s["units"]:
		u.queue_free()
	s["units"] = []
	s["kind"] = ""


## Statistiche base di uno scheletro, prese dall'Inspector del nodo Main.
## Statistiche base: quelle dell'Inspector della preparazione (o di game_data.gd).
## Il rango (doppioni delle pergamene) e le ricerche per ruolo si aggiungono sopra.
func ally_stats(kind: String) -> Dictionary:
	var d: Dictionary = Data.UNITS[kind]
	var st := {"hp": d["hp"], "dmg": d["dmg"], "cooldown": d["cooldown"], "range": d["range"],
		"speed": d["speed"], "splash": d["splash"], "count": d["count"]}
	if unit_overrides.has(kind):
		st.merge(unit_overrides[kind], true)
	var rank: int = unit_ranks.get(kind, 1)
	var rm := Collezione.rank_mult(rank)
	st["hp"] *= rm * (1.0 + role_bonus.get("hp_" + d["role"], 0.0))
	st["dmg"] *= rm
	st["rank"] = rank
	# specializzazioni del rango 3 e 5
	var e := spec_effects(kind)
	st["hp"] *= e["vita"]
	st["dmg"] *= e["danno"]
	st["cooldown"] /= maxf(0.05, e["cadenza"])
	st["range"] *= e["gittata"]
	st["speed"] *= e["velocita"]
	st["splash"] *= e["area"]
	st["spec"] = e
	return st


## Bonus delle ricerche per ruolo (es. role_mult("distanza", "dmg")).
func role_mult(role: String, stat: String) -> float:
	return 1.0 + role_bonus.get(stat + "_" + role, 0.0)


## +25% danni e velocità d'attacco vicino a un totem d'ossa.
func aura_bonus(u) -> float:
	if u.special == "aura":
		return 1.0
	for c in allies_root.get_children():
		if c.special == "aura" and not c.dead and c.visible and c.ground.distance_to(u.ground) <= AURA_RADIUS * c.sp("area", 1.0):
			return 1.0 + 0.25 * c.sp("potenza_speciale", 1.0)
	return 1.0


## Lo scheletro che provoca (scudiero, muro d'ossa) più vicino, entro `dist`.
func nearest_taunter(from: Vector2, dist: float):
	var best = null
	var best_d := dist
	for c in allies_root.get_children():
		if c.dead or not c.visible or c.entering or not (c.special == "provoca" or c.special == "muro"):
			continue
		if not same_lane(from, c.ground):
			continue
		var d := from.distance_to(c.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


## Nube di peste: avvelena (danno nel tempo) e rallenta i nemici dentro.
func add_plague_cloud(g: Vector2, dps: float, _rank: int = 1, raggio: float = 16.0, lento: float = 0.3, maledizione: float = 0.0) -> void:
	clouds.append({"p": g, "t": 3.0, "dps": dps, "r": raggio, "slow": lento, "curse": maledizione})


func _update_clouds(delta: float) -> void:
	for cl in clouds:
		cl["t"] -= delta
		for c in enemies_root.get_children():
			if not c.dead and c.ground.distance_to(cl["p"]) <= float(cl.get("r", 16.0)) + c.radius:
				c.poison(cl["dps"] * delta)
				c.slow_k = maxf(c.slow_k if c.slow_t > 0.0 else 0.0, float(cl.get("slow", 0.3)))
				c.slow_t = maxf(c.slow_t, 0.4)
				if float(cl.get("curse", 0.0)) > 0.0:
					c.curse_t = maxf(c.curse_t, float(cl["curse"]))
	clouds = clouds.filter(func(cl): return cl["t"] > 0.0)


## Il negromante minore rialza come scheletro un nemico morto vicino a lui.
func _try_raise(dead_enemy) -> void:
	for n in allies_root.get_children():
		if n.special != "rianima" or n.dead or n.ground.distance_to(dead_enemy.ground) > RAISE_RADIUS:
			continue
		var active := 0
		for m in allies_root.get_children():
			if m.summoner == n and not m.dead:
				active += 1
		if active >= RAISE_MAX + int(n.sp("rianimati_extra")):
			continue
		var u := UnitScript.new()
		u.game = self
		u.setup_ally("soldato", mods["ally_hp"] * 0.6, ally_stats("soldato"))
		u.ground = dead_enemy.ground
		u.home = dead_enemy.ground
		u.life_left = RAISE_LIFE * n.sp("potenza_speciale", 1.0)
		u.summoner = n
		allies_root.add_child(u)
		spawn_ground_fx(u.ground, 6.0, n.accent(), 0.4)
		spawn_unit_fx(u.ground, "spark", 6.0, 1.0, 0.3, n.accent())
		return


func is_ranged(kind: String) -> bool:
	return kind != "" and not Data.UNITS[kind]["melee"]


## Gittata in caselle, per i testi.
func _range_cells(kind: String) -> String:
	return ("%.1f" % (ally_stats(kind)["range"] / cell)).replace(".", ",")


## Scelta dell'unità da evocare: una lapide per unità attorno alla casella
## cliccata, così la mappa resta visibile. Passando il mouse su una lapide si
## vedono le statistiche e, per le unità a distanza, la gittata sulla griglia.
## Tasti 1-4 per scegliere al volo. Le unità non ancora ricercate sono incatenate.
func _open_unit_picker(idx: int) -> void:
	picker_slot = idx
	picker_hover = ""
	for c in picker.get_children():
		if c != picker_tip:
			picker.remove_child(c)
			c.queue_free()
	var vp := get_viewport_rect().size
	var cell_rect := Rect2(to_screen(slots[idx]["center"] - Vector2.ONE * cell / 2.0), Vector2.ONE * cell * px)
	var size := Vector2(94, 104)
	var c := cell_rect.get_center()
	var gap := 6.0
	var spots := [
		Vector2(c.x - size.x / 2.0, cell_rect.position.y - size.y - gap),  # sopra
		Vector2(cell_rect.end.x + gap, c.y - size.y / 2.0),  # destra
		Vector2(c.x - size.x / 2.0, cell_rect.end.y + gap),  # sotto
		Vector2(cell_rect.position.x - size.x - gap, c.y - size.y / 2.0),  # sinistra
	]
	for i in unlocked_units.size():
		var k: String = unlocked_units[i]
		var p: Vector2 = spots[i % spots.size()]
		p.x = clampf(p.x, 8.0, vp.x - size.x - 8.0)
		p.y = clampf(p.y, UI_TOP + 8.0, vp.y - size.y - 8.0)
		var b := _flat_button()
		b.position = p.round()
		b.size = size
		b.disabled = not k in unlocked_units
		b.mouse_entered.connect(func():
			picker_hover = k
			picker.queue_redraw())
		b.mouse_exited.connect(func():
			if picker_hover == k:
				picker_hover = ""
			picker.queue_redraw())
		b.pressed.connect(_pick_unit.bind(idx, k))
		b.draw.connect(_draw_unit_tomb.bind(b, k, i))
		b.set_meta("kind", k)
		picker.add_child(b)
	picker.move_child(picker_tip, -1)
	picker.show()


func _flat_button() -> Button:
	var b := Button.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _draw_unit_tomb(b: Button, k: String, i: int) -> void:
	var locked := not k in unlocked_units
	var hot := picker_hover == k and not locked
	var r := Rect2(Vector2(0, -4 if hot else 0), b.size)
	Pietra.tomb(b, r, Color("8a8a8a") if hot else (C3 if locked else C4), hot)
	b.draw_texture_rect_region(Data.ally_texture(k), Rect2(Vector2(r.get_center().x - 24, r.position.y + 10), Vector2(48, 48)),
		Data.ally_region(k), Color(1, 1, 1, 0.35 if locked else 1.0))
	var label := Data.nome_breve(k)
	var fs := 16 if ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= r.size.x - 10 else 12
	Pietra.text_c(b, ui_font, r.get_center().x, r.position.y + 60 + (16 - fs) / 2.0, label, fs, C5 if locked else C6)
	Pietra.text_c(b, ui_font, r.get_center().x, r.position.y + 79, tr("ricerca") if locked else "[%d]" % (i + 1), 16, C1, false)
	if locked:  # catene incrociate e lucchetto
		var a := r.position + Vector2(10, 14)
		var z := r.position + Vector2(r.size.x - 10, 54)
		b.draw_line(a, z, C1, 6.0)
		b.draw_line(Vector2(z.x, a.y), Vector2(a.x, z.y), C1, 6.0)
		var lk := Vector2(r.get_center().x, r.position.y + 34)
		b.draw_rect(Rect2(lk + Vector2(-9, -6), Vector2(18, 15)), C0)
		b.draw_rect(Rect2(lk + Vector2(-6, -3), Vector2(12, 9)), C5)


## Scheda con le statistiche dell'unità sotto il mouse, accanto alla sua lapide.
func _draw_picker_tip() -> void:
	if picker_hover == "":
		return
	var tomb: Control = null
	for c in picker.get_children():
		if c.has_meta("kind") and c.get_meta("kind") == picker_hover:
			tomb = c
	if tomb == null:
		return
	var d: Dictionary = Data.UNITS[picker_hover]
	var lines: Array = ["%s x%d" % [Data.nome(picker_hover).to_upper(), unit_count(picker_hover)]]
	if picker_hover in unlocked_units:
		var st := ally_stats(picker_hover)
		var l2 := tr("Vita %d") % int(st["hp"])
		if st["dmg"] > 0.0:
			l2 += tr(" · Attacco %d") % int(st["dmg"])
		if st["rank"] > 1:
			l2 += tr(" · rango %d") % st["rank"]
		lines.append(l2)
		var rami := Specializzazioni.nomi_attivi(picker_hover, st["rank"])
		if rami != "":
			lines.append(rami)
		var l3: String = Data.ruolo(d["role"])
		if is_ranged(picker_hover):
			l3 += tr(" · gittata %d") % int(st["range"])
		lines.append(l3)
	else:
		lines.append(tr("Sbloccalo nell'albero"))
		lines.append(tr("delle ricerche"))
	var w := 0.0
	for l in lines:
		w = maxf(w, ui_font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var size := Vector2(w + 28, lines.size() * 24 + 18)
	var vp := get_viewport_rect().size
	var pos := Vector2(tomb.position.x + tomb.size.x + 10, tomb.position.y)
	if pos.x + size.x > vp.x - 8:
		pos.x = tomb.position.x - size.x - 10
	pos.y = clampf(pos.y, UI_TOP + 8.0, vp.y - size.y - 8.0)
	var r := Rect2(pos, size)
	picker_tip.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.5))
	picker_tip.draw_rect(r, C5)
	picker_tip.draw_rect(r.grow(-3), C1)
	for i in lines.size():
		Pietra.text(picker_tip, ui_font, r.position + Vector2(14, 10 + i * 24), lines[i], 16, C6 if i == 0 else C5)


func _close_picker() -> void:
	picker.hide()
	picker_slot = -1
	picker_hover = ""


func _pick_unit(idx: int, kind: String) -> void:
	_close_picker()
	_spawn_squad(idx, kind)
	_show_deploy_hint()


func _show_deploy_hint() -> void:
	var n := deployed_count()
	if n < max_deploy:
		set_hint(tr("Clicca una casella della griglia per evocare un'unità (%d/%d). Tasto destro per rimuoverla.") % [n, max_deploy])
	else:
		set_hint(tr("Schieramento completo: premi \"Inizia ondate\"."))
	if start_button:
		start_button.disabled = n == 0


func _on_start_pressed() -> void:
	if state != State.DEPLOY or deployed_count() == 0:
		return
	state = State.PLAYING
	start_button.hide()
	next_wave_timer = 1.0
	set_hint(tr("Arrivano gli eroi!"), 2.0)


# --- Level-up ----------------------------------------------------------------

func _level_up_options() -> Array:
	var pool := [
		{"title": tr("Furia oscura"), "icon": R_IC_STAR, "text": tr("Attacco necromante +25%"), "fn": func(): necro_dmg *= 1.25},
		{"title": tr("Mano rapida"), "icon": R_IC_HOURGLASS, "text": tr("Velocità d'attacco necromante +20%"), "fn": func(): necro_cooldown /= 1.2},
		{"title": tr("Mura d'ossa"), "icon": R_IC_HEART, "text": tr("Vita torre +25 (massima e attuale)"), "fn": func():
			tower_max_hp += 25.0
			tower_hp += 25.0},
		{"title": tr("Lame affilate"), "icon": R_IC_SWORD, "text": tr("Attacco unità +20%"), "fn": func(): mods["ally_dmg"] *= 1.2},
		{"title": tr("Ossa leggere"), "icon": R_IC_FAST, "text": tr("Velocità d'attacco unità +15%"), "fn": func(): mods["ally_rate"] *= 1.15},
		{"title": tr("Ossa robuste"), "icon": R_IC_HEAL, "text": tr("Vita unità +20%"), "fn": func(): _scale_hp(allies_root, "ally_hp", 1.2)},
		{"title": tr("Nebbia gelida"), "icon": R_IC_EYE, "text": tr("Nemici: velocità -10%"), "fn": func(): mods["enemy_speed"] *= 0.9},
		{"title": tr("Peste"), "icon": R_IC_EYE, "text": tr("Nemici: vita -10%"), "fn": func(): _scale_hp(enemies_root, "enemy_hp", 0.9)},
		{"title": tr("Terrore"), "icon": R_IC_EYE, "text": tr("Nemici: attacco -10%"), "fn": func(): mods["enemy_dmg"] *= 0.9},
	]
	if free_slot_count() > 0:
		for k in unlocked_units:
			var d: Dictionary = Data.UNITS[k]
			pool.append({"title": tr("Evocazione"), "text": tr("Evoca: %s (x%d)") % [Data.nome(k), unit_count(k)], "summon": k})
	return pool


func _scale_hp(root: Node, mod_key: String, factor: float) -> void:
	mods[mod_key] *= factor
	for u in root.get_children():
		u.max_hp *= factor
		u.hp *= factor


func _open_level_up() -> void:
	if pending_levelups <= 0 or state != State.PLAYING:
		return
	state = State.LEVEL_UP
	selected_ability = ""
	Suoni.play("livello")
	var opts := _level_up_options()
	opts.shuffle()
	opts = opts.slice(0, 3)
	if autotest:
		_choose_level_up(opts[0])
		return
	_show_level_up(opts)


## Tre lapidi che emergono dal terreno, sopra il campo oscurato.
func _show_level_up(opts: Array) -> void:
	levelup_opts = opts
	for c in levelup.get_children():
		levelup.remove_child(c)
		c.queue_free()
	var vp := get_viewport_rect().size
	var size := Vector2(280, 320)
	var gap := 48.0
	var x0 := roundf((vp.x - (size.x * opts.size() + gap * (opts.size() - 1))) / 2.0)
	for i in opts.size():
		var b := _flat_button()
		b.position = Vector2(x0 + i * (size.x + gap), 214)
		b.size = size
		b.pressed.connect(_choose_level_up.bind(opts[i]))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		b.draw.connect(_draw_levelup_card.bind(b, i))
		levelup.add_child(b)
	levelup.show()
	levelup.queue_redraw()


func _draw_levelup_bg() -> void:
	var vp := get_viewport_rect().size
	levelup.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.05, 0.66))
	var br := Rect2(vp.x / 2.0 - 240, 45, 480, 124)
	Pietra.banner(levelup, br)
	Pietra.text_c(levelup, ui_font, vp.x / 2.0, 62, tr("IL NECROMANTE SALE"), 24, C0, false)
	Pietra.text_c(levelup, ui_font, vp.x / 2.0, 94, tr("AL LIVELLO %d") % necro_level, 32, C0, false)
	# terra smossa ai piedi delle lapidi
	levelup.draw_rect(Rect2(150, 534, vp.x - 300, 18), C1)
	levelup.draw_rect(Rect2(150, 534, vp.x - 300, 3), C3)
	for i in 9:
		var x := 176.0 + i * 112.0 + (i % 3) * 17.0
		levelup.draw_rect(Rect2(x, 527 + (i % 2) * 2, 12 + (i % 3) * 3, 9), C3 if i % 2 else C4)
	Pietra.text_c(levelup, ui_font, vp.x / 2.0, 590, tr("Scegli un dono · tasti 1 2 3"), 16, C5)


func _draw_levelup_card(b: Button, i: int) -> void:
	if i >= levelup_opts.size():
		return
	var o: Dictionary = levelup_opts[i]
	var hot := b.is_hovered()
	var r := Rect2(Vector2(0, -12 if hot else 0), b.size + Vector2(0, 12 if hot else 0))
	Pietra.tomb(b, r, C4 if hot else Color("5a5a5a"), hot, 6.0)
	var icon_rect := Rect2(Vector2(r.get_center().x - 48, r.position.y + 34), Vector2(96, 96))
	if o.has("summon"):
		b.draw_texture_rect_region(Data.ally_texture(o["summon"]), icon_rect, Data.ally_region(o["summon"]))
	else:
		b.draw_texture_rect_region(ATLAS, icon_rect, o["icon"])
	var title := String(o["title"]).to_upper()
	var ts := 24  # i titoli lunghi (inglese, spagnolo) si rimpiccioliscono per stare nella lapide
	while ts > 14 and ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x > r.size.x - 36.0:
		ts -= 1
	Pietra.text_c(b, ui_font, r.get_center().x, r.position.y + 150 + (24 - ts) / 2.0, title, ts, C6)
	Pietra.text_block(b, ui_font, Vector2(22, r.position.y + 192), r.size.x - 44, o["text"], 16, C6)
	Pietra.text_c(b, ui_font, r.get_center().x, r.end.y - 40, "[%d]" % (i + 1), 16, C1, false)


func _choose_level_up(o: Dictionary) -> void:
	if levelup:
		levelup.hide()
	pending_levelups -= 1
	if o.has("summon"):
		pending_summon = o["summon"]
		if autotest:
			_spawn_squad(_autotest_free_slot(), pending_summon)
			pending_summon = ""
		else:
			state = State.PLACING
			set_hint(tr("Clicca una casella libera della griglia per evocare: %s") % Data.nome(pending_summon))
			return
	else:
		o["fn"].call()
	_resume_after_choice()


func _resume_after_choice() -> void:
	state = State.PLAYING
	if pending_levelups > 0:
		_open_level_up()
	else:
		set_hint("", 0.0)


# --- Abilità -----------------------------------------------------------------

func _select_ability(key: String) -> void:
	if not is_running() or ability_cd[key] > 0.0:
		return
	if not key in unlocked_abilities:
		set_hint(tr("%s non è ancora sbloccata: cercala nell'albero delle ricerche.") % Data.nome_abilita(key), 2.5)
		return
	selected_ability = "" if selected_ability == key else key
	if selected_ability != "" and not get_viewport().gui_get_hovered_control() is BaseButton:
		Suoni.play("click")  # dalla tastiera (i pulsanti fanno già click da soli)
	if selected_ability != "":
		set_hint(tr("Clicca sul campo per lanciare %s (tasto destro: annulla)") % Data.nome_abilita(key))
	else:
		set_hint("", 0.0)


## `g` è il punto del terreno colpito.
func _cast(key: String, g: Vector2) -> void:
	var a: Dictionary = Data.ABILITIES[key]
	var power: float = a["power"] * necro_dmg / Data.NECRO_DMG * ability_power_mult
	ability_cd[key] = 0.0 if dev_senza_ricarica else a["cooldown"] * ability_cd_mult
	selected_ability = ""
	set_hint("", 0.0)
	match key:
		"palla_di_fuoco":
			damage_area(g, a["radius"], power, 1)
			spawn_ground_fx(g, a["radius"], colore_palla_di_fuoco, 0.7, "fire")
			Suoni.play("palla_di_fuoco")
			shake(0.3, 2.0)
		"saetta":
			damage_area(g, a["radius"], power, 1)
			spawn_ground_fx(g, a["radius"], colore_saetta, 0.4, "bolt")
			Suoni.play("saetta")
			shake(0.2, 1.0)
		"area_curativa":
			for u in allies_root.get_children():
				if not u.dead and g.distance_to(u.ground) <= a["radius"]:
					u.heal(a["power"])
			spawn_ground_fx(g, a["radius"], colore_area_curativa, 0.9, "heal")
			Suoni.play("area_curativa")


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		return
	if paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var num: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
		if levelup.visible and num >= 0 and num < levelup_opts.size():
			_choose_level_up(levelup_opts[num])
			return
		if picker.visible and num >= 0 and num < unlocked_units.size():
			_pick_unit(picker_slot, unlocked_units[num])
			return
		match event.keycode:
			KEY_1:
				_select_ability(Data.ABILITY_ORDER[0])
			KEY_2:
				_select_ability(Data.ABILITY_ORDER[1])
			KEY_3:
				_select_ability(Data.ABILITY_ORDER[2])
			KEY_SPACE:
				_cycle_speed()
		return
	if event is InputEventMouseButton and event.pressed and picker.visible:
		_close_picker()  # i clic sulle lapidi li prendono i pulsanti: qualsiasi altro clic chiude
		return
	if not (event is InputEventMouseButton and event.pressed) or modal.visible or levelup.visible:
		return
	var p := get_global_mouse_position()
	var idx := slot_at_screen(p)
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_ability != "":
			selected_ability = ""
			set_hint("", 0.0)
		elif state == State.DEPLOY and idx >= 0 and slots[idx]["kind"] != "":
			_remove_squad(idx)
			_show_deploy_hint()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	match state:
		State.DEPLOY:
			if idx >= 0 and slots[idx]["kind"] == "":
				if deployed_count() < max_deploy:
					Suoni.play("click")
					_open_unit_picker(idx)
				else:
					Suoni.play("errore")
					set_hint(tr("Puoi schierare %d squadre a inizio partita: togline una (tasto destro) per evocarne un'altra. Le altre arrivano col level-up.") % max_deploy, 4.0)
		State.PLACING:
			if idx >= 0 and slots[idx]["kind"] == "":
				Suoni.play("conferma")
				_spawn_squad(idx, pending_summon)
				pending_summon = ""
				_resume_after_choice()
		State.PLAYING:
			if selected_ability != "":
				_cast(selected_ability, to_ground(p))


func _cycle_speed() -> void:
	# x1 -> x2 -> x3 (VIP) -> x5 (solo modalità dev) -> x1
	var speeds: Array[float] = [1.0, 2.0, 3.0]
	if dev_x5:
		speeds.append(5.0)
	var i := speeds.find(Engine.time_scale)
	var next: float = speeds[(i + 1) % speeds.size()] if i >= 0 else 1.0
	if next == 3.0 and not Portafoglio.has_vip() and not dev_x5:
		next = 1.0
		set_hint(tr("La velocità x3 si sblocca con il PACCHETTO VIP del negozio."), 3.0)
	Engine.time_scale = next


# --- Fine partita e progressi --------------------------------------------------

func _end_run(won: bool) -> void:
	state = State.VICTORY if won else State.GAME_OVER
	selected_ability = ""
	Engine.time_scale = 1.0
	position = Vector2.ZERO
	shake_t = 0.0
	if won:
		Suoni.play("livello")
	else:
		Suoni.play("assorbimento", 0.6, 4.0)
		Suoni.play("torre_colpita", 0.7)
	var cleared := wave if won else maxi(0, wave - 1)
	# solo la parte non ancora premiata (se hai continuato dopo la vittoria)
	var earned := (cleared - ondate_pagate) + int((kills - uccisioni_pagate) / 20.0) + (50 if won else 0)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # se non esiste ancora parte da zero
	var total: int = cfg.get_value("progressi", "punti", 0) + earned
	var best: int = maxi(cfg.get_value("progressi", "record_ondata", 0), wave)
	cfg.set_value("progressi", "punti", total)
	cfg.set_value("progressi", "record_ondata", best)
	cfg.save(SAVE_PATH)
	var nuovo_livello := ""
	var record_prima := Livelli.record(id_livello)
	if not autotest:
		Livelli.salva_record(id_livello, wave)
		if won:
			var lista := Livelli.elenco()
			for i in lista.size() - 1:
				if lista[i].id == id_livello and not Livelli.finito(id_livello):
					nuovo_livello = lista[i + 1].nome
			Livelli.segna_finito(id_livello)  # sblocca il livello successivo
	var coins := (cleared - ondate_pagate) * Data.MONETE_PER_ONDATA + (Data.MONETE_VITTORIA if won else 0)
	Portafoglio.add_monete(coins)
	ondate_pagate = cleared
	uccisioni_pagate = kills
	var posto := -1
	if infinita and not autotest:
		posto = Livelli.aggiungi_classifica(id_livello, {
			"ondata": wave, "uccisioni": kills, "livello": necro_level,
			"data": Time.get_date_string_from_system(), "squadra": unlocked_units.duplicate()})

	if autotest:
		print("[autotest] fine partita: %s all'ondata %d | livello %d | uccisioni %d | punti %d" % [
			"vittoria" if won else "sconfitta", wave, necro_level, kills, earned])
		print("[autotest] monete d'osso: +%d" % coins)
		get_tree().quit()
		return

	if schermata_finale_cinematica:
		_mostra_fine(won, earned, total, coins, record_prima, nuovo_livello, posto)
		return
	var title := tr("Hai resistito alle %d ondate!") % ondate_totali if won else tr("La torre è caduta")
	var body := tr("Ondata raggiunta: %d   ·   Nemici uccisi: %d\nPunti progresso guadagnati: %d   (totale: %d)\nRecord: ondata %d") % [
		wave, kills, earned, total, best]
	body += "\n" + tr("Monete d'osso guadagnate: %d  ·  spendile nel negozio") % coins
	if scrolls_earned > 0:
		body += "\n" + tr("Pergamene ottenute: %d  ·  aprile nel portale del menu") % scrolls_earned
	if nuovo_livello != "":
		body += "\n" + tr("Nuovo livello sbloccato: %s!") % tr(nuovo_livello)
	var scelte: Array = []
	if won:
		body += "\n\n" + tr("Ora questo livello si gioca anche in modalità infinita.")
		scelte.append([tr("Continua in modalità infinita"), _continua_infinita])
	if infinita:
		title = tr("Fine della corsa infinita")
		body += "\n\n" + _testo_classifica(posto)
	scelte.append_array([
		[tr("Nuova partita"), _restart_game],
		[tr("Cambia squadra"), func(): get_tree().change_scene_to_file("res://scenes/preparazione.tscn")],
		[tr("Cambia livello"), func(): get_tree().change_scene_to_file("res://scenes/selezione_livello.tscn")],
		[tr("Torna al menu"), _go_to_menu],
	])
	_show_modal(title, body, scelte)


## Dopo la vittoria: la stessa corsa continua senza fine e poi entra in classifica.
func _continua_infinita() -> void:
	infinita = true
	_close_modal()
	if fine_node != null:
		fine_node.queue_free()
		fine_node = null
	state = State.PLAYING
	Livelli.scegli_modalita(true, id_livello, scene_file_path)
	next_wave_timer = 3.0
	_revive_squads()
	_absorb_remains()
	set_hint(tr("Modalità infinita! Resisti più che puoi: la corsa entra in classifica."), 4.0)


## Posizione in classifica e le prime 5 corse del livello.
func _testo_classifica(posto: int) -> String:
	var s := tr("NUOVO RECORD!") if posto == 0 else (tr("Posizione in classifica: %d") % (posto + 1) if posto > 0 else tr("Non sei entrato tra le 10 corse migliori"))
	var c := Livelli.classifica(id_livello)
	for i in mini(5, c.size()):
		var v: Dictionary = c[i]
		s += "\n%s%d. %s %d  ·  %s %d" % ["> " if i == posto else "", i + 1, tr("ondata"), int(v.get("ondata", 0)),
			tr("uccisioni"), int(v.get("uccisioni", 0))]
	return s


# --- Autotest (solo da riga di comando: godot -- --autotest) -------------------

func _start_autotest() -> void:
	autotest = true
	if Array(OS.get_cmdline_user_args()).any(func(x): return x.begins_with("--squadra=")):
		# prova di una squadra precisa: tutte e quattro le unità in campo
		var spots := [slot_index(2, 1), slot_index(1, 2), slot_index(1, 1), slot_index(2, 2)]
		for i in mini(4, unlocked_units.size()):
			var sp: int = spots[i] if not slots[spots[i]]["blocked"] and slots[spots[i]]["kind"] == "" else _autotest_free_slot()
			_spawn_squad(sp, unlocked_units[i])
		_on_start_pressed()
		return
	_spawn_squad(_slot_libero(2, 1), "soldato")
	_spawn_squad(_slot_libero(1, 2), unlocked_units[1] if unlocked_units.size() > 1 else "soldato")
	_spawn_squad(_slot_libero(1, 1), unlocked_units[3] if unlocked_units.size() > 3 else "soldato")
	_on_start_pressed()


## La casella (c, r) se si può usare, altrimenti un'altra libera.
func _slot_libero(c: int, r: int) -> int:
	var i := slot_index(c, r)
	return i if not slots[i]["blocked"] and slots[i]["kind"] == "" else _autotest_free_slot()


## Casella libera casuale nelle prime 4 colonne (o la prima libera).
func _autotest_free_slot() -> int:
	var choices := []
	for i in slots.size():
		if slots[i]["kind"] == "" and not slots[i]["blocked"] and slots[i]["cell"].x <= 3:
			choices.append(i)
	if not choices.is_empty():
		return choices.pick_random()
	for i in slots.size():
		if slots[i]["kind"] == "" and not slots[i]["blocked"]:
			return i
	return 0


## Simula un giocatore semplice: lancia le abilità appena sono pronte.
func _autotest_cast() -> void:
	if state != State.PLAYING:
		return
	var t = nearest_to_tower(enemies_root, 999.0)
	if t != null:
		for k in ["saetta", "palla_di_fuoco"]:
			if k in unlocked_abilities and ability_cd[k] <= 0.0:
				_cast(k, t.ground)
				return
	if "area_curativa" in unlocked_abilities and ability_cd["area_curativa"] <= 0.0:
		for u in allies_root.get_children():
			if not u.dead and u.hp < u.max_hp * 0.5:
				_cast("area_curativa", u.ground)
				return


# --- Interfaccia (in scala di grigi) ------------------------------------------

func set_hint(text: String, duration: float = 0.0) -> void:
	if hint_label == null:
		return
	hint_label.text = text
	hint_timer = duration


func _box(bg: Color, border: Color, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(margin)
	return sb


func _make_theme() -> Theme:
	if tema_ui:
		return tema_ui
	var th := Theme.new()
	th.set_stylebox("normal", "Button", _box(C1, C4))
	th.set_stylebox("hover", "Button", _box(C2, C5))
	th.set_stylebox("pressed", "Button", _box(C0, C6))
	th.set_stylebox("disabled", "Button", _box(C0, C2))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C6)
	th.set_color("font_hover_color", "Button", C6)
	th.set_color("font_pressed_color", "Button", C6)
	th.set_color("font_disabled_color", "Button", C3)
	th.set_color("font_color", "Label", C6)
	return th


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C0
	bg.border_color = C3
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	ui.add_child(ui_root)

	ui_font = ui_root.get_theme_default_font()

	# velocità e pausa: due pietre in alto a destra (al posto della barra in alto)
	var vpw := get_viewport_rect().size.x
	speed_button = _flat_button()
	speed_button.position = Vector2(vpw - 16 - 56 - 8 - 64, 16)
	speed_button.size = Vector2(64, 56)
	speed_button.tooltip_text = tr("Velocità (Spazio)")
	speed_button.pressed.connect(_cycle_speed)
	speed_button.mouse_entered.connect(speed_button.queue_redraw)
	speed_button.mouse_exited.connect(speed_button.queue_redraw)
	speed_button.draw.connect(_draw_speed_button)
	ui_root.add_child(speed_button)
	pause_button = _flat_button()
	pause_button.position = Vector2(vpw - 16 - 56, 16)
	pause_button.size = Vector2(56, 56)
	pause_button.tooltip_text = tr("Pausa (Esc)")
	pause_button.pressed.connect(toggle_pause)
	pause_button.mouse_entered.connect(pause_button.queue_redraw)
	pause_button.mouse_exited.connect(pause_button.queue_redraw)
	pause_button.draw.connect(func():
		Pietra.stone(pause_button, Rect2(Vector2.ZERO, pause_button.size), C3, pause_button.is_hovered())
		pause_button.draw_rect(Rect2(19, 16, 6, 24), C6)
		pause_button.draw_rect(Rect2(31, 16, 6, 24), C6))
	ui_root.add_child(pause_button)

	# sfera d'anima sopra il necromante: livello ed esperienza
	soul_orb = Control.new()
	soul_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul_orb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	soul_orb.draw.connect(_draw_soul_orb)
	ui_root.add_child(soul_orb)

	# Pulsante grande in basso al centro, visibile solo durante lo schieramento.
	start_button = Button.new()
	start_button.text = tr("Inizia ondate")
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	start_button.offset_left = -130
	start_button.offset_right = 130
	start_button.offset_top = -80
	start_button.offset_bottom = -24
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	ui_root.add_child(start_button)

	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 22
	hint_label.offset_bottom = 52
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_outline_color", C0)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hint_label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(center)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", _box(C0, C6, 24))
	center.add_child(modal)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 10)
	modal.add_child(modal_box)
	modal.hide()

	# campione degli eroi: presentazione e barra della vita in alto
	boss_hud = Control.new()
	boss_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_hud.draw.connect(_draw_boss_hud)
	ui_root.add_child(boss_hud)

	# stendardo degli eroi accanto al portale: ondata e nemici in arrivo
	wave_banner = Control.new()
	wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bx := to_screen(Vector2(lane_len + SPAWN_W, 0)).x + 12.0
	wave_banner.position = Vector2(minf(bx, get_viewport_rect().size.x - 88.0), to_screen(Vector2.ZERO).y + 12.0)
	wave_banner.draw.connect(_draw_wave_banner)
	ui_root.add_child(wave_banner)

	# fila degli incantesimi in basso (si vede durante la battaglia)
	spell_row = Control.new()
	spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	spell_row.offset_left = -372
	spell_row.offset_right = 372
	spell_row.offset_top = -74
	spell_row.offset_bottom = -4
	spell_row.draw.connect(func(): Pietra.stone(spell_row, Rect2(Vector2.ZERO, spell_row.size), C3))
	ui_root.add_child(spell_row)
	for i in Data.ABILITY_ORDER.size():
		var k: String = Data.ABILITY_ORDER[i]
		var sb := _flat_button()
		sb.position = Vector2(12 + i * 242, 9)
		sb.size = Vector2(230, 52)
		sb.pressed.connect(_select_ability.bind(k))
		sb.mouse_entered.connect(sb.queue_redraw)
		sb.mouse_exited.connect(sb.queue_redraw)
		sb.draw.connect(_draw_spell_slot.bind(sb, k))
		spell_row.add_child(sb)
		spell_slots[k] = sb

	picker = Control.new()
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(picker)
	picker_tip = Control.new()
	picker_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker_tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker_tip.draw.connect(_draw_picker_tip)
	picker.add_child(picker_tip)
	picker.draw.connect(picker_tip.queue_redraw)
	picker.hide()

	levelup = Control.new()
	levelup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	levelup.mouse_filter = Control.MOUSE_FILTER_STOP
	levelup.draw.connect(_draw_levelup_bg)
	ui_root.add_child(levelup)
	levelup.hide()

	pause_overlay = _build_pause_overlay()
	ui_root.add_child(pause_overlay)

	_update_hud()


## Menu di pausa: copre tutto lo schermo e blocca i clic sul gioco sotto.
func _build_pause_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(C0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(C0, C6, 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("PAUSA")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	for opt in [
		[tr("Riprendi"), toggle_pause],
		[tr("Ricomincia partita"), _restart_game],
		[tr("Torna al menu"), _go_to_menu],
	]:
		var btn := Button.new()
		btn.text = opt[0]
		btn.custom_minimum_size = Vector2(360, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(opt[1])
		box.add_child(btn)
	overlay.hide()
	return overlay


func toggle_pause() -> void:
	# a partita finita la schermata di fine offre già le stesse scelte
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	paused = not paused
	pause_overlay.visible = paused
	if paused:
		selected_ability = ""


func _restart_game() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _show_modal(title: String, body: String, options: Array) -> void:
	for c in modal_box.get_children():
		modal_box.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	modal_box.add_child(t)
	if body != "":
		var b := Label.new()
		b.text = body
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(440, 0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_box.add_child(b)
	for opt in options:
		var btn := Button.new()
		btn.text = opt[0]
		btn.custom_minimum_size = Vector2(440, 44)
		if opt.size() > 2 and opt[2] != null:
			btn.icon = opt[2]
			btn.custom_minimum_size.y = 56
		btn.pressed.connect(opt[1])
		modal_box.add_child(btn)
	modal.show()


func _close_modal() -> void:
	modal.hide()


func _update_hud() -> void:
	if necro_level != orb_level:
		orb_level = necro_level
		orb_flash = 1.0
	speed_button.queue_redraw()
	soul_orb.queue_redraw()
	spell_row.visible = state != State.DEPLOY and state != State.GAME_OVER and state != State.VICTORY
	for k in spell_slots:
		var b: Button = spell_slots[k]
		b.disabled = not k in unlocked_abilities or not is_running() or ability_cd[k] > 0.0
		b.queue_redraw()
	wave_banner.queue_redraw()


func _draw_speed_button() -> void:
	var b := speed_button
	Pietra.stone(b, Rect2(Vector2.ZERO, b.size), C3, b.is_hovered())
	b.draw_texture_rect_region(ATLAS, Rect2(Vector2(16, 4), Vector2(32, 32)), R_IC_FAST, Color(1, 1, 1, 0.5 + 0.5 * minf(1.0, Engine.time_scale - 1.0)))
	Pietra.text_c(b, ui_font, b.size.x / 2.0, 34, "x%d" % int(Engine.time_scale), 16, C6)


## Sfera d'anima sopra il necromante: si riempie con l'esperienza, dentro c'è il livello.
## Con il mouse sulla torre mostra anche la sua vita.
func _draw_soul_orb() -> void:
	var n := soul_orb
	var pos := origin + Vector2(wall_x, tower_base_y) - Vector2(TOWER_W, TOWER_H)
	var c := ((pos + Vector2(40, -24)) * px).round() + Vector2(1, 1)
	var r := 27.0
	var fill := clampf(necro_xp / maxf(1.0, necro_xp_next), 0.0, 1.0)
	var level_y := c.y + r - fill * 2.0 * r
	# cerchio a righe di 3 pixel (aspetto pixel art)
	for row in range(int(-r - 6), int(r + 6), 3):
		var y := c.y + row
		var half_out := floorf(sqrt(maxf(0.0, (r + 6) * (r + 6) - (row + 1.5) * (row + 1.5))) / 3.0) * 3.0
		var half_b := floorf(sqrt(maxf(0.0, (r + 3) * (r + 3) - (row + 1.5) * (row + 1.5))) / 3.0) * 3.0
		var half := floorf(sqrt(maxf(0.0, r * r - (row + 1.5) * (row + 1.5))) / 3.0) * 3.0
		if half_out > 0.0:
			n.draw_rect(Rect2(c.x - half_out, y, half_out * 2.0, 3), C3)
		if half_b > 0.0:
			n.draw_rect(Rect2(c.x - half_b, y, half_b * 2.0, 3), C0)
		if half > 0.0:
			var col := C1
			if y >= level_y:
				col = C4
			if absf(y - level_y) < 3.0 and fill > 0.0:
				col = C5
			n.draw_rect(Rect2(c.x - half, y, half * 2.0, 3), col)
	if orb_flash > 0.0:
		n.draw_circle(c, r + 8.0 + (1.0 - orb_flash) * 14.0, Color(1, 1, 1, 0.35 * orb_flash))
	Pietra.text_c(n, ui_font, c.x, c.y - 20, tr("LIV"), 16, C6)
	Pietra.text_c(n, ui_font, c.x, c.y - 4, "%d" % necro_level, 24, C6)
	# filo d'anima verso il bastone del necromante
	var dots := [Vector2(-18, 33), Vector2(-24, 40), Vector2(-29, 47)]
	for i in dots.size():
		var a := 0.4 + 0.6 * absf(sin(amb_t * 3.0 - i * 0.9))
		n.draw_rect(Rect2((c + dots[i]).round(), Vector2(3, 3)), Color(C5, a))
	# vita della torre, solo con il mouse sopra
	if _hovering_tower():
		var label := tr("TORRE %d/%d") % [ceili(tower_hp), int(tower_max_hp)]
		var w := ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24
		var base := (origin + Vector2(wall_x, tower_base_y)) * px
		var box := Rect2(Vector2(base.x - TOWER_W * px / 2.0 - w / 2.0, base.y + 12), Vector2(w, 32))
		box.position.x = maxf(8.0, box.position.x)
		Pietra.stone(n, box, C3)
		Pietra.text(n, ui_font, box.position + Vector2(12, 8), label, 16, C6)


## Uno slot della fila degli incantesimi: icona, tasto, nome e ricarica.
func _draw_spell_slot(b: Button, k: String) -> void:
	var a: Dictionary = Data.ABILITIES[k]
	var r := Rect2(Vector2.ZERO, b.size)
	var cd: float = ability_cd[k]
	var locked: bool = not k in unlocked_abilities
	var ready := not locked and cd <= 0.0 and is_running()
	var aiming := selected_ability == k
	Pietra.stone(b, r, C4 if ready or aiming else C2, aiming or (ready and b.is_hovered()))
	var icon := Rect2(Vector2(6, 6), Vector2(40, 40))
	b.draw_texture_rect_region(ATLAS, icon, ABILITY_ICONS.get(k, R_IC_STAR), Color(1, 1, 1, 1.0 if ready or aiming else 0.4))
	Pietra.text(b, ui_font, Vector2(8, 4), a["key"], 16, C6 if ready else C5)
	if cd > 0.0 and not locked:
		Pietra.text_c(b, ui_font, icon.get_center().x, 16, "%d" % ceili(cd), 16, C6)
	Pietra.text(b, ui_font, Vector2(54, 7), Data.nome_abilita(k).to_upper(), 16, C6 if ready or aiming else C5)
	if locked:
		Pietra.text(b, ui_font, Vector2(54, 28), tr("bloccata"), 16, C3, false)
		return
	var bar := Rect2(54, 32, r.size.x - 64, 8)
	b.draw_rect(bar, C1)
	var k_ready := 1.0 if cd <= 0.0 else 1.0 - cd / maxf(0.01, a["cooldown"] * ability_cd_mult)
	if aiming:
		k_ready = 1.0 if int(amb_t * 4.0) % 2 == 0 else 0.0
	b.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(k_ready, 0.0, 1.0)), bar.size.y)), C6 if ready or aiming else C4)


## Nemici dell'ondata in corso (rimasti) o della prossima: [[tipo, quanti, capo]].
func _wave_counts() -> Array:
	var counts := {}
	var champs := {}  # campioni: "@id" -> Campione
	var src: Array = spawn_queue if wave_running else next_queue
	for e in src:
		var key: String = e["kind"] + ("!" if e["boss"] else "")
		if e.get("campione") is Campione:
			key = "@" + e["campione"].id
			champs[key] = e["campione"]
		counts[key] = counts.get(key, 0) + 1
	if wave_running:
		for u in enemies_root.get_children():
			if not u.dead:
				var key: String = u.kind + ("!" if u.is_boss else "")
				if "dati" in u and u.dati != null:
					key = "@" + u.dati.id
					champs[key] = u.dati
				counts[key] = counts.get(key, 0) + 1
	var out := []
	for k in ["soldato", "arciere", "mago", "gigante", "soldato!", "arciere!", "mago!", "gigante!"]:
		if counts.has(k):
			out.append([k.trim_suffix("!"), counts[k], k.ends_with("!"), null])
	for k in champs:
		out.append([champs[k].tipo_base, counts[k], true, champs[k]])
	return out


## Stendardo degli eroi: numero dell'ondata e nemici (rimasti o in arrivo).
func _draw_wave_banner() -> void:
	var n := wave_banner
	var counts := _wave_counts()
	var w := 80.0
	var h := 74.0 + counts.size() * 36.0 + 28.0
	Pietra.banner(n, Rect2(Vector2.ZERO, Vector2(w, h)))
	var title := tr("ONDATA") if wave_running or wave == 0 else tr("PROSSIMA")
	var ts := 16 if ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= w - 8 else 12
	Pietra.text_c(n, ui_font, w / 2.0, 12, title, ts, C0, false)
	var num := wave if wave_running else wave + 1
	if infinita:
		Pietra.text_c(n, ui_font, w / 2.0, 32, "%d" % num, 24 if num < 1000 else 16, C0, false)
		Livelli.disegna_infinito(n, Vector2(w / 2.0 - 13.5, 58), 3.0, C2, false)
	else:
		Pietra.text_c(n, ui_font, w / 2.0, 32, "%d" % mini(num, ondate_totali), 24, C0, false)
		Pietra.text_c(n, ui_font, w / 2.0, 56, "/ %d" % ondate_totali, 12, C2, false)
	for i in counts.size():
		var e: Array = counts[i]
		var y := 74.0 + i * 36.0
		var col: int = UnitScript.ATLAS_COL[e[0]]
		var camp: Campione = e[3]
		if camp != null and camp.sprite != null:  # il campione con la sua sprite (girata verso sinistra)
			var fs := camp.sprite.get_height()
			n.draw_set_transform(Vector2(40, y - 4), 0.0, Vector2(-1, 1))  # girato verso sinistra
			n.draw_texture_rect_region(camp.sprite, Rect2(Vector2.ZERO, Vector2(36, 36)), Rect2(0, 0, fs, fs))
			n.draw_set_transform(Vector2.ZERO)
		elif tex_nemici != null:
			n.draw_texture_rect_region(tex_nemici, Rect2(Vector2(6, y), Vector2(32, 32)), Rect2(col * 16, 0, 16, 16))
		else:
			n.draw_texture_rect_region(ATLAS, Rect2(Vector2(6, y), Vector2(32, 32)), Rect2(col * 16, 16, 16, 16))
		if e[2]:  # corona del campione
			n.draw_rect(Rect2(14, y - 4, 16, 4), C0)
			n.draw_rect(Rect2(14, y - 8, 4, 4), C0)
			n.draw_rect(Rect2(20, y - 8, 4, 4), C0)
			n.draw_rect(Rect2(26, y - 8, 4, 4), C0)
		Pietra.text(n, ui_font, Vector2(42, y + 9), "x%d" % e[1], 16, C0, false)


# --- Disegno del campo (pixel art, coordinate in pixel dell'arte) ---------------

## Contorno di 1 pixel dell'arte, allineato alla griglia.
func _px_outline(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), col)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), col)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	_draw_scenery()

	# griglia di schieramento: lastre di pietra in rilievo (2x2 tile per casella)
	var placing := (state == State.DEPLOY and deployed_count() < max_deploy) or state == State.PLACING
	for i in slots.size():
		var s: Dictionary = slots[i]
		var c: Vector2i = s["cell"]
		if s["barrier"]:
			_draw_barrier(Rect2(origin + Vector2(c.x * cell, c.y * cell), Vector2(cell, cell)), c)
			continue
		var tint := Color.WHITE if (c.x + c.y) % 2 == 0 else Color(0.84, 0.84, 0.84)
		# più scuro in fondo, più chiaro davanti: aiuta la profondità
		tint = tint * (0.86 + 0.14 * float(c.y) / maxf(1.0, rows - 1.0))
		tint.a = 1.0
		for ty2 in tile_per_casella:
			for tx2 in tile_per_casella:
				var h := absi(c.x * 31 + c.y * 17 + c.x * c.y * 7) % R_SLABS.size()  # una pietra per casella
				var dst := Rect2(origin + Vector2(c.x * cell + tx2 * TILE, c.y * cell + ty2 * TILE), Vector2(TILE, TILE))
				draw_texture_rect_region(tex_tiles, dst, R_SLABS[h], tint)
		var rect := Rect2(origin + Vector2(c.x * cell, c.y * cell), Vector2(cell, cell))
		_draw_bevel(self, rect)
		if s["kind"] != "":
			draw_rect(rect, Color(C6, 0.12))
			# icona della squadra solo mentre scegli dove schierare
			if state == State.DEPLOY or state == State.PLACING:
				_draw_cell_badge(rect, s["kind"])
		elif placing and i == hover_slot:
			draw_rect(rect, Color(C6, 0.2))
			_px_outline(self, rect, C6)
	if placing:
		_px_outline(self, Rect2(origin - Vector2.ONE, Vector2(lane_len + 2, depth + 2)), C5)

	# striscia di spawn: lastre in ombra (la nebbia è animata in _draw_ambient)
	var sy := 0.0
	while sy < depth:
		var hh := minf(TILE, depth - sy)
		var r0: Rect2 = R_SLABS[int(sy / TILE) % R_SLABS.size()]
		draw_texture_rect_region(tex_tiles, Rect2(origin + Vector2(lane_len, sy), Vector2(SPAWN_W, hh)),
			Rect2(r0.position, Vector2(TILE, hh)), Color(0.5, 0.5, 0.5))
		_draw_bevel(self, Rect2(origin + Vector2(lane_len, sy), Vector2(SPAWN_W, hh)), 0.5)
		sy += TILE
	draw_rect(Rect2(origin + Vector2(lane_len, 0), Vector2(1, depth)), Color(C5, 0.6))

	# portata del necromante: con il mouse sulla torre si vede tutta l'area colpita
	if _hovering_tower():
		var x0 := origin.x + roundf(wall_x)
		var rw := roundf(necro_range)
		draw_rect(Rect2(x0, origin.y, rw, depth), Color(C6, 0.1))
		draw_rect(Rect2(x0 + rw, origin.y, 1, depth), C6)
		draw_rect(Rect2(x0 + rw - 1, origin.y, 1, depth), Color(C6, 0.35))
	elif state == State.DEPLOY:
		var nx := origin.x + roundf(wall_x + necro_range)
		var yy := 0.0
		while yy < depth:
			draw_rect(Rect2(nx, origin.y + yy, 1, 2), Color(C6, 0.7))
			yy += 4.0

	# anteprima della gittata delle unità a distanza
	var preview := _range_preview()
	if not preview.is_empty():
		_draw_range(preview[0], preview[1])

	# area dell'abilità selezionata
	if selected_ability != "":
		var ab: Dictionary = Data.ABILITIES[selected_ability]
		var g := to_ground(get_global_mouse_position()).round()
		FxScript.draw_pixel_circle(self, origin + g, ab["radius"], C6)


## Piccola icona (la testa dello scheletro) nell'angolo di una casella occupata.
func _draw_cell_badge(rect: Rect2, kind: String) -> void:
	var top := 3 if kind in ["soldato", "arciere"] else (0 if kind in ["mago", "gigante"] else 2)
	var src := Data.ally_region(kind)
	var p := rect.position + Vector2(2, 2)
	draw_rect(Rect2(p - Vector2.ONE, Vector2(10, 10)), Color(C0, 0.8))
	draw_texture_rect_region(Data.ally_texture(kind), Rect2(p, Vector2(8, 8)), Rect2(src.position + Vector2(4, top), Vector2(8, 8)))


## Il mouse è sopra la torre (o sul necromante in cima)?
func _hovering_tower() -> bool:
	if picker.visible or modal.visible or levelup.visible or paused or selected_ability != "":
		return false
	var m := get_global_mouse_position() / px
	var base := origin + Vector2(wall_x, tower_base_y)
	return Rect2(base - Vector2(TOWER_W, TOWER_H + 30), Vector2(TOWER_W + 6, TOWER_H + 30)).has_point(m)


## Cosa mostrare come anteprima della gittata: [centro sul terreno, gittata] o [].
##  1) l'unità sotto il mouse nella scelta da evocare
##  2) l'unità da piazzare dopo un'evocazione del level-up, sulla casella libera sotto il mouse
##  3) una squadra a distanza già schierata sotto il mouse
func _range_preview() -> Array:
	if picker.visible:
		if picker_slot >= 0 and is_ranged(picker_hover) and picker_hover in unlocked_units:
			return [slots[picker_slot]["center"], ally_stats(picker_hover)["range"]]
		return []
	if modal.visible or levelup.visible or paused or selected_ability != "" or hover_slot < 0:
		return []
	var s: Dictionary = slots[hover_slot]
	if state == State.PLACING and s["kind"] == "" and is_ranged(pending_summon):
		return [s["center"], ally_stats(pending_summon)["range"]]
	if is_ranged(s["kind"]) and state in [State.DEPLOY, State.PLACING, State.PLAYING]:
		return [s["center"], ally_stats(s["kind"])["range"]]
	return []


## Cerchio della gittata a pixel: riempimento leggero e bordo.
func _draw_range(center: Vector2, r: float) -> void:
	var c := origin + center.round()
	var ri := int(r)
	for y in range(-ri, ri + 1):
		var half := floorf(sqrt(r * r - y * y))
		draw_rect(Rect2(c.x - half, c.y + y, half * 2.0 + 1.0, 1), Color(C6, 0.1))
	FxScript.draw_pixel_circle(self, c, r, C6)
	FxScript.draw_pixel_circle(self, c, r - 1.0, Color(C6, 0.35))


## La torre è un nodo a parte con il suo z_index, così le unità nelle file
## davanti le passano davanti e quelle in fondo dietro.
## Ordine: torre, luci delle finestre, necromante, merli davanti (lo coprono dalle ginocchia in giù).
func _draw_tower() -> void:
	var t := tower_node
	t.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var base := origin + Vector2(wall_x, tower_base_y)  # angolo in basso a destra
	var pos := base - Vector2(TOWER_W, TOWER_H)
	# ombra verso destra (la luce viene da in alto a sinistra)
	for i in 5:
		t.draw_rect(Rect2(pos.x - 2 + i * 2, base.y - 1 + i, TOWER_W + 8 - i, 1), Color(0, 0, 0, 0.4 - i * 0.06))
	t.draw_texture(TEX_TOWER, pos + TOWER_IMG_OFFSET)
	if tower_flash > 0.0 and int(tower_flash * 40.0) % 2 == 0:
		t.draw_texture(TEX_TOWER, pos + TOWER_IMG_OFFSET, Color(4, 4, 4, 0.45))
	var dmg := tower_damage_level()
	# finestre che tremolano come candele (in fiamme quando la torre sta crollando)
	for wp in TOWER_WINDOWS:
		var k := 0.12 + 0.22 * absf(sin(amb_t * 3.1 + wp.x * 0.7 + wp.y))
		if dmg >= 3:
			k = 0.45 + 0.3 * absf(sin(amb_t * 11.0 + wp.x))
		t.draw_rect(Rect2(pos + wp + Vector2(0, 1), Vector2(4, 7)), Color(1, 1, 1, k))
		t.draw_rect(Rect2(pos + wp - Vector2(2, 1), Vector2(8, 11)), Color(1, 1, 1, k * 0.25))
	# crepe sempre più grandi
	for lvl in dmg:
		for crack in TOWER_CRACKS[lvl]:
			_draw_crack(t, pos, crack)
	if dmg >= 2:  # macerie alla base
		for rb in [Vector2(-2, 93), Vector2(3, 94), Vector2(37, 92), Vector2(42, 93), Vector2(40, 95)]:
			t.draw_rect(Rect2(pos + rb, Vector2(2, 2)), C4)
			t.draw_rect(Rect2(pos + rb + Vector2(0, 1), Vector2(2, 1)), C2)
	if dmg >= 3:  # stendardo strappato e fiamme dalle finestre
		t.draw_rect(Rect2(pos + Vector2(15, 26), Vector2(4, 9)), C0)
		t.draw_rect(Rect2(pos + Vector2(19, 30), Vector2(3, 5)), C0)
		for wp in TOWER_WINDOWS:
			var hgt := 2.0 + roundf(absf(sin(amb_t * 9.0 + wp.x + wp.y)) * 3.0)
			t.draw_rect(Rect2(pos + wp + Vector2(1, -hgt), Vector2(2, hgt)), C6)
			t.draw_rect(Rect2(pos + wp + Vector2(0, -1), Vector2(4, 2)), C5)
	# il necromante sul tetto, dietro i merli
	var necro := pos + NECRO_FEET - Vector2(8, 15)
	t.draw_texture_rect_region(ATLAS, Rect2(necro, Vector2(16, 16)), R_NECRO)
	t.draw_texture(TEX_TOWER_MERLI, pos + TOWER_IMG_OFFSET)
	if dmg >= 2:  # merli crollati
		for mx in ([24.0] if dmg == 2 else [24.0, 6.0]):
			t.draw_rect(Rect2(pos + Vector2(mx, 5), Vector2(4, 6)), C1)
			t.draw_rect(Rect2(pos + Vector2(mx, 10), Vector2(4, 1)), C3)
	for sm in smoke:
		var a: float = clampf(sm["life"] / sm["max"], 0.0, 1.0)
		var sz: float = sm["size"]
		t.draw_rect(Rect2((sm["p"] as Vector2).round(), Vector2(sz, sz)), Color(0.45, 0.45, 0.45, 0.55 * a))
	var orb := necro + Vector2(14, 2)  # punta del bastone
	var glow := 0.25 + 0.25 * absf(sin(amb_t * 2.2))
	t.draw_rect(Rect2(orb - Vector2.ONE * 2, Vector2(5, 5)), Color(colore_necromante, glow * 0.5))
	t.draw_rect(Rect2(orb - Vector2.ONE, Vector2(3, 3)), Color(colore_necromante.lightened(0.4), glow))
	if necro_flash > 0.0:
		var r := 1.0 + roundf(necro_flash * 15.0)
		t.draw_rect(Rect2(orb - Vector2(r, 0), Vector2(r * 2 + 1, 1)), colore_necromante.lightened(0.3))
		t.draw_rect(Rect2(orb - Vector2(0, r), Vector2(1, r * 2 + 1)), colore_necromante.lightened(0.3))
		t.draw_rect(Rect2(orb - Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1))


## 0 = intatta, 1 = crepe (sotto 75%), 2 = crepe, macerie e fumo (sotto 50%),
## 3 = in fiamme (sotto 25%).
func tower_damage_level() -> int:
	var k := tower_hp / maxf(1.0, tower_max_hp)
	if k < 0.25:
		return 3
	if k < 0.5:
		return 2
	if k < 0.75:
		return 1
	return 0


## Crepa a gradini: segmenti orizzontali/verticali, scuri con un bordo chiaro.
func _draw_crack(ci: CanvasItem, pos: Vector2, pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pos + pts[i]
		var b: Vector2 = pos + pts[i + 1]
		var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x) + 1, absf(b.y - a.y) + 1))
		ci.draw_rect(Rect2(r.position + Vector2(1, 0), r.size), Color(1, 1, 1, 0.18))
		ci.draw_rect(r, C0)


# --- Scenario 3D (stesso stile del menu) ------------------------------------------

func _apron_x() -> float:
	## Bordo sinistro della pedana di pietra: un po' prima della torre.
	var tower_left := origin.x + wall_x - TOWER_W
	return origin.x - ceilf((origin.x - tower_left + 8.0) / TILE) * TILE


## Prepara le posizioni (fisse per tutta la partita) di oggetti, muretto e animazioni.
func _setup_scenery() -> void:
	horizon = origin.y - 24.0
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	var spawn_x := origin.x + lane_len
	var bottom := origin.y + depth + FACE_H
	var ax := _apron_x()
	var tower_rect := Rect2(origin + Vector2(wall_x - TOWER_W - 4, tower_base_y - TOWER_H - 30), Vector2(TOWER_W + 18, TOWER_H + 36))
	# muretto in rovina sul bordo dietro il campo
	wall_tiles.clear()
	var x := ax
	var i := 0
	while x < spawn_x:
		var r: Rect2 = R_WALL_OK
		var h := (i * 37 + 11) % 10
		if i % 4 == 2:
			r = R_WALL_TORCH
		elif h < 2:
			r = R_WALL_BROKEN
		elif h == 5:
			r = R_WALL_SKULL
		wall_tiles.append({"r": r, "x": x})
		x += TILE
		i += 1
	# oggetti: dietro il muretto, a sinistra della torre, davanti al campo, oltre il portale
	props.clear()
	var tries := 0
	while props.size() < 34 and tries < 600:
		tries += 1
		var p := Vector2(rnd.randi_range(-4, int(art_size.x) - 12), rnd.randi_range(int(horizon) + 10, int(art_size.y) + 8))
		var tall := rnd.randf() < 0.3
		var size := Vector2(16, 32 if tall else 16)
		var box := Rect2(p - Vector2(0, size.y), size)
		if box.intersects(Rect2(Vector2(ax - 2, origin.y - 12), Vector2(spawn_x + SPAWN_W - ax + 4, depth + FACE_H + 16))):
			continue  # niente sul campo (né sul muretto)
		if box.intersects(tower_rect):
			continue
		if p.y < origin.y and tall and rnd.randf() < 0.5:
			pass
		elif p.y < origin.y:
			tall = true  # dietro il muretto si vedono solo le cose alte
			size.y = 32
		var region: Rect2
		if tall:
			var k := rnd.randi_range(0, R_PROPS_TALL.size() - 1)
			if p.x > spawn_x - 40:
				k = 2  # stendardi degli eroi vicino al portale
			elif k == 2:
				k = rnd.randi_range(0, 1)
			region = R_PROPS_TALL[k]
		else:
			region = R_PROPS_SMALL[rnd.randi_range(0, R_PROPS_SMALL.size() - 1)]
		var ok := true
		for q in props:
			if absf(q["pos"].x - p.x) < 12 and absf(q["pos"].y - p.y) < 8:
				ok = false
				break
		if ok:
			props.append({"r": region, "pos": p, "flip": rnd.randf() < 0.5})
	props.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	# stelle solo dove nel panorama c'è cielo (non sulle montagne)
	stars.clear()
	var sky_img := tex_sky.get_image()
	var sky_top := horizon - tex_sky.get_height()
	for k in 200:
		if stars.size() >= 40:
			break
		var sp := Vector2(rnd.randi_range(0, int(art_size.x) - 1), rnd.randi_range(int(ceilf(float(UI_TOP) / px)), int(horizon) - 8))
		var ip := Vector2i(int(sp.x) % sky_img.get_width(), int(sp.y - sky_top))
		if ip.y < 0 or ip.y >= sky_img.get_height() or sky_img.get_pixelv(ip).v < 0.12:
			stars.append({"p": sp, "ph": rnd.randf() * TAU, "sp": rnd.randf_range(1.0, 3.0)})
	bats.clear()
	for k in 3:
		bats.append({"x": rnd.randf_range(0, art_size.x), "y": rnd.randf_range(horizon - 30, horizon - 10),
			"sp": rnd.randf_range(8, 15), "ph": rnd.randf() * TAU})
	marchers.clear()
	for k in 14:
		marchers.append(_new_marcher(rnd, true))


func _new_marcher(rnd: RandomNumberGenerator, anywhere: bool) -> Dictionary:
	var x := rnd.randf_range(-10, art_size.x) if anywhere else rnd.randf_range(-24, -4)
	return {"x": x, "y": rnd.randf_range(horizon + 3, origin.y - 13), "sp": rnd.randf_range(2.5, 5.0),
		"ph": rnd.randf() * TAU, "flag": rnd.randf() < 0.2}


func _update_ambient(delta: float) -> void:
	amb_t += delta
	_update_weather(delta)
	for b in bats:
		b["x"] += b["sp"] * delta
		if b["x"] > art_size.x + 8:
			b["x"] = -8.0
			b["y"] = randf_range(horizon - 30, horizon - 10)
	var gate := origin.x + lane_len + 4.0
	for m in marchers:
		m["x"] += m["sp"] * delta
		if m["x"] > gate:  # entra nel portale: ne arriva un altro da sinistra
			var rnd := RandomNumberGenerator.new()
			rnd.randomize()
			var n := _new_marcher(rnd, false)
			m.merge(n, true)
	# scintille che salgono dalle torce
	if randf() < delta * 4.0 and not wall_tiles.is_empty():
		var torches := _torch_points()
		var tp: Vector2 = torches[randi() % torches.size()]
		embers.append({"p": tp + Vector2(0, -2), "v": Vector2(randf_range(-2, 2), randf_range(-10, -5)), "life": randf_range(0.6, 1.2)})
	for e in embers:
		e["p"] += e["v"] * delta
		e["life"] -= delta
	embers = embers.filter(func(e): return e["life"] > 0.0)
	# fumo dalla torre danneggiata
	var dmg := tower_damage_level()
	if dmg >= 2 and randf() < delta * (5.0 if dmg == 2 else 12.0):
		var top := origin + Vector2(wall_x, tower_base_y) - Vector2(TOWER_W, TOWER_H)
		var life := randf_range(1.5, 2.8)
		smoke.append({"p": top + Vector2(randf_range(14, 34), randf_range(2, 8)), "v": Vector2(randf_range(1, 5), randf_range(-9, -5)),
			"life": life, "max": life, "size": randf_range(2.0, 4.0) if dmg == 2 else randf_range(3.0, 5.0)})
	for sm in smoke:
		sm["p"] += sm["v"] * delta
		sm["size"] = minf(7.0, sm["size"] + delta * 1.2)
		sm["life"] -= delta
	smoke = smoke.filter(func(sm): return sm["life"] > 0.0)


## Punte delle fiamme di tutte le torce (muretto + pilastro del portale).
func _torch_points() -> Array:
	var pts := []
	for w in wall_tiles:
		if w["r"] == R_WALL_TORCH:
			pts.append(Vector2(w["x"] + 8, origin.y + 1 - TILE + 3))
	pts.append(Vector2(origin.x + lane_len + 8, origin.y + 2 - TEX_PILLAR.get_height() + 31))
	return pts


## Smusso di una lastra: spigolo chiaro in alto a sinistra, ombra in basso a destra.
func _draw_bevel(ci: CanvasItem, r: Rect2, k: float = 1.0) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.2 * k))
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 2)), Color(1, 1, 1, 0.12 * k))
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 1, 1)), Color(0, 0, 0, 0.22 * k))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.5 * k))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 1), Vector2(1, r.size.y - 2)), Color(0, 0, 0, 0.42 * k))


func _draw_prop(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var pos: Vector2 = pr["pos"] - Vector2(0, r.size.y)
	var dst := Rect2(pos, r.size)
	if pr["flip"]:
		dst = Rect2(pos + Vector2(r.size.x, 0), Vector2(-r.size.x, r.size.y))
	# più lontano = più scuro (foschia)
	var k := clampf(0.55 + 0.45 * (pr["pos"].y - horizon) / maxf(1.0, origin.y + depth - horizon), 0.55, 1.0)
	ci.draw_texture_rect_region(tex_tiles, dst, r, Color(k, k, k))


## Cielo, terreno, oggetti, muretto e pedana di pietra (tutto dietro le unità).
func _draw_scenery() -> void:
	var w := art_size.x
	var sky_h := float(tex_sky.get_height())
	var sky_top := horizon - sky_h
	if sky_top > 0.0:
		draw_rect(Rect2(0, 0, w, sky_top + 1.0), C0)
	var x := 0.0
	while x < w:
		draw_texture(tex_sky, Vector2(x, sky_top))
		var gy := horizon
		draw_texture(tex_ground, Vector2(x, gy))
		gy += tex_ground.get_height()
		while gy < art_size.y:  # schermi molto alti: ripeti la parte davanti del terreno
			var hh := minf(120.0, art_size.y - gy)
			draw_texture_rect_region(tex_ground, Rect2(x, gy, tex_ground.get_width(), hh),
				Rect2(0, tex_ground.get_height() - 120, tex_ground.get_width(), hh))
			gy += hh
		x += tex_ground.get_width()
	# oggetti dietro il muretto
	for pr in props:
		if pr["pos"].y < origin.y:
			_draw_prop(self, pr)
	var ax := _apron_x()
	var spawn_end := origin.x + lane_len + SPAWN_W
	# ombra del campo rialzato sul terreno davanti
	for i in 4:
		draw_rect(Rect2(ax + 2 + i, origin.y + depth + FACE_H + i, spawn_end - ax, 1), Color(0, 0, 0, 0.45 - i * 0.1))
	# faccia frontale del campo (spessore della pedana)
	var fx := ax
	var fi := 0
	while fx < spawn_end:
		var r: Rect2 = R_FACE[fi % R_FACE.size()]
		var ww := minf(TILE, spawn_end - fx)
		draw_texture_rect_region(tex_tiles, Rect2(fx, origin.y + depth, ww, FACE_H), Rect2(r.position, Vector2(ww, FACE_H)))
		fx += TILE
		fi += 1
	# pedana di pietra sotto la torre (a sinistra della griglia)
	var py := 0.0
	while py < depth:
		var px2 := ax
		while px2 < origin.x:
			var h := absi(int(px2) * 13 + int(py) * 7) % R_SLABS.size()
			var hh := minf(TILE, depth - py)
			var ww := minf(TILE, origin.x - px2)
			draw_texture_rect_region(tex_tiles, Rect2(px2, origin.y + py, ww, hh), Rect2(R_SLABS[h].position, Vector2(ww, hh)), Color(0.72, 0.72, 0.72))
			_draw_bevel(self, Rect2(px2, origin.y + py, ww, hh), 0.7)
			px2 += TILE
		py += TILE
	draw_rect(Rect2(ax, origin.y, 1, depth), Color(C0, 0.6))
	# muretto in rovina dietro il campo
	for wt in wall_tiles:
		draw_texture_rect_region(tex_tiles, Rect2(wt["x"], origin.y + 1 - TILE, TILE, TILE), wt["r"])
	# pilastro del portale (dietro)
	draw_texture(TEX_PILLAR, Vector2(origin.x + lane_len, origin.y + 2 - TEX_PILLAR.get_height()))
	# oggetti davanti e ai lati
	for pr in props:
		if pr["pos"].y >= origin.y:
			_draw_prop(self, pr)
	# buio oltre il portale: da lì arrivano gli eroi
	var dark_x := spawn_end
	for y in range(int(horizon), int(art_size.y), 2):
		for xx in range(int(dark_x), int(w), 2):
			var k := (xx - dark_x) / maxf(1.0, w - dark_x)
			if fmod(xx * 0.5 + y * 0.75, 1.0) < 0.5 and k > 0.15:
				draw_rect(Rect2(xx, y, 2, 2), Color(0, 0, 0, 0.35 * k))


## Animazioni dello sfondo: stelle, pipistrelli, fuochi dell'accampamento, eroi
## lontani in marcia, torce, nebbia del portale.
func _draw_ambient() -> void:
	var n := ambient_node
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var t := amb_t
	if bioma == null or bioma.stelle:
		_draw_stars(n, t)
	_draw_weather_back(n, t)
	for b in (bats if (bioma == null or bioma.pipistrelli) else []):
		var flap := int(t * 10.0 + b["ph"]) % 2
		var p := Vector2(roundf(b["x"]), roundf(b["y"] + sin(t * 2.0 + b["ph"]) * 3.0))
		n.draw_rect(Rect2(p, Vector2(1, 1)), C0)
		n.draw_rect(Rect2(p + Vector2(-2, -flap), Vector2(2, 1)), C0)
		n.draw_rect(Rect2(p + Vector2(1, -flap), Vector2(2, 1)), C0)
	# fuochi dell'accampamento sulle colline
	for f in (SKY_FIRES if (bioma == null or bioma.eroi_lontani) else []):
		var fp := Vector2(f.x, horizon - f.y)
		if fp.x >= art_size.x:
			continue
		var hgt := 1.0 + roundf(absf(sin(t * 8.0 + f.x)))
		n.draw_rect(Rect2(fp - Vector2(0, hgt), Vector2(1, hgt)), C6)
		n.draw_rect(Rect2(fp - Vector2(2, 3), Vector2(5, 4)), Color(1, 1, 1, 0.07 + 0.05 * absf(sin(t * 5.0 + f.x))))
	# nebbia bassa che scorre sull'orizzonte
	for i in 4:
		var fw := 70.0 + i * 20.0
		var fxp := fmod(t * (3.0 + i) + i * 140.0, art_size.x + fw) - fw
		n.draw_rect(Rect2(roundf(fxp), horizon + 1 + i * 2, fw, 2), Color(1, 1, 1, 0.05))
	# eroi lontani che marciano verso il portale
	for m in (marchers if (bioma == null or bioma.eroi_lontani) else []):
		var mx := roundf(m["x"])
		var my := roundf(m["y"])
		var step := int(t * 6.0 + m["ph"]) % 2
		var col := Color(0.42, 0.42, 0.42)
		n.draw_rect(Rect2(mx, my - 3, 1, 2), col)
		n.draw_rect(Rect2(mx - (1 if step else 0), my - 1, 1, 1), col)
		n.draw_rect(Rect2(mx + (1 if step else 0), my - 1, 1, 1), col)
		n.draw_rect(Rect2(mx + 1, my - 5, 1, 4), Color(0.3, 0.3, 0.3))  # lancia
		if m["flag"]:
			n.draw_rect(Rect2(mx + 2, my - 5, 2, 2), Color(0.67, 0.67, 0.67))
	# torce
	for tp in _torch_points():
		var hgt := 2.0 + roundf(absf(sin(t * 9.0 + tp.x)) * 2.0)
		n.draw_rect(Rect2(tp.x, tp.y - hgt + 1, 1, hgt), C6)
		n.draw_rect(Rect2(tp.x - 1, tp.y, 3, 1), Color(1, 1, 1, 0.6))
		var k := 0.05 + 0.04 * absf(sin(t * 5.0 + tp.x))
		n.draw_rect(Rect2(tp.x - 5, tp.y - 5, 11, 11), Color(1, 1, 1, k))
		n.draw_rect(Rect2(tp.x - 3, tp.y - 3, 7, 7), Color(1, 1, 1, k))
	for e in embers:
		n.draw_rect(Rect2((e["p"] as Vector2).round(), Vector2.ONE), Color(1, 1, 1, clampf(e["life"], 0.0, 1.0)))
	# nubi di peste sul terreno
	for cl in clouds:
		var a: float = clampf(cl["t"], 0.0, 1.0)
		var cp: Vector2 = origin + (cl["p"] as Vector2).round()
		for yy in range(-6, 7, 2):
			for xx in range(-16, 17, 2):
				if Vector2(xx, yy * 2.4).length() > 16.0:
					continue
				var v := sin(xx * 0.5 + t * 3.0 + yy) * cos(yy * 0.7 - t * 2.0)
				if v > 0.1:
					n.draw_rect(Rect2(cp + Vector2(xx, yy), Vector2(2, 2)), Color(colore_nube_peste, 0.4 * a))
	# nebbia che vortica nel portale degli eroi
	var sx := origin.x + lane_len
	for y in range(0, int(depth), 2):
		for xx in range(-4, SPAWN_W + 20, 2):
			var v := sin(xx * 0.35 + t * 1.7 + y * 0.12) * sin(y * 0.21 - t * 1.1 + xx * 0.05)
			if v > 0.35:
				var a := (v - 0.35) * (0.5 if xx < SPAWN_W + 4 else 0.25)
				n.draw_rect(Rect2(sx + xx, origin.y + y, 2, 2), Color(0.8, 0.8, 0.8, a))


## Davanti alle unità: il pilastro crollato del portale (in basso).
func _draw_front() -> void:
	var n := front_node
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var stump := 24.0
	var ph := float(TEX_PILLAR.get_height())
	var base := Vector2(origin.x + lane_len, origin.y + depth + FACE_H)
	n.draw_texture_rect_region(TEX_PILLAR, Rect2(base - Vector2(0, stump), Vector2(16, stump)),
		Rect2(0, ph - stump, 16, stump))
	n.draw_rect(Rect2(base.x + 3, base.y - stump, 10, 1), Color("8a8a8c"))
	_draw_weather_front(n, amb_t)



# --- Biomi: file bloccate, ostacoli e meteo ----------------------------------------

## Una casella di una fila bloccata, disegnata secondo il bioma.
func _draw_barrier(r: Rect2, c: Vector2i) -> void:
	var base: Color = bioma.colore_barriera if bioma else Color("1a1c1e")
	var t := amb_t
	var h := absi(c.x * 37 + c.y * 11)
	match ambiente:
		Bioma.Ambiente.PALUDE:  # acqua ferma con le increspature e le canne sulle rive
			draw_rect(r, base)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), base.darkened(0.4))
			for k in 4:
				var yy := r.position.y + 5.0 + k * 7.0
				var off := fmod(t * (3.0 + k) + h * 3.0 + k * 9.0, r.size.x + 10.0) - 10.0
				draw_rect(Rect2(r.position.x + maxf(0.0, off), yy, minf(8.0, r.size.x - maxf(0.0, off)), 1), Color(base.lightened(0.35), 0.6))
			if h % 3 == 0:  # ninfea
				draw_rect(Rect2(r.position + Vector2(8 + h % 12, 12 + h % 9), Vector2(5, 2)), base.lightened(0.25))
			for k in 3:
				var rx := r.position.x + 4.0 + ((h * (k + 3)) % int(r.size.x - 6.0))
				var rh := 3.0 + (h + k) % 4
				draw_rect(Rect2(rx, r.position.y - rh + 2, 1, rh), Color(0.35, 0.4, 0.33))
				draw_rect(Rect2(rx, r.end.y - 2, 1, rh - 1), Color(0.3, 0.34, 0.28))
		Bioma.Ambiente.CATTEDRALE:  # pavimento sfondato: buio con i bordi spezzati
			draw_rect(r, base)
			for x in range(int(r.position.x), int(r.end.x), 2):
				var j := (x * 7 + h) % 5
				draw_rect(Rect2(x, r.position.y, 2, 2 + j % 3), Color(0.42, 0.39, 0.36))
				draw_rect(Rect2(x, r.end.y - 2 - (j % 2), 2, 2 + (j % 2)), Color(0.3, 0.28, 0.26))
			draw_rect(Rect2(r.position.x, r.position.y + 6, r.size.x, r.size.y - 12), base.darkened(0.5))
		Bioma.Ambiente.MONTAGNA:  # crepaccio: fondo blu scuro e labbra di ghiaccio
			draw_rect(r, base)
			draw_rect(Rect2(r.position.x, r.position.y + 7, r.size.x, r.size.y - 14), base.darkened(0.45))
			for x in range(int(r.position.x), int(r.end.x)):
				var j := (x * 13 + h) % 7
				draw_rect(Rect2(x, r.position.y, 1, 2 + j % 3), Color(0.86, 0.9, 0.98))
				draw_rect(Rect2(x, r.end.y - 1 - j % 2, 1, 1 + j % 2), Color(0.7, 0.76, 0.86))
		_:  # cimitero: fossa scavata
			draw_rect(r, base)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0.32, 0.3, 0.28))
			if h % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(10, 16), Vector2(6, 1)), Color(0.75, 0.75, 0.72))


## Gli ostacoli sono nodi separati per stare davanti o dietro alle unità a seconda della fila.
func _build_obstacles() -> void:
	for o in ostacoli:
		if o.x < 0 or o.x >= cols or o.y < 0 or o.y >= rows:
			continue
		var n := Node2D.new()
		var bottom := Vector2(o.x * cell + cell / 2.0, (o.y + 1) * cell - 2.0)
		n.position = to_screen(bottom)
		n.scale = Vector2.ONE * px
		n.z_index = int(n.position.y) - int(cell * 0.3 * px)
		var variant := absi(o.x * 7 + o.y * 3) % 4
		n.draw.connect(func() -> void:
			if tex_obst:
				n.draw_texture_rect_region(tex_obst, Rect2(-16, -30, 32, 32), Rect2(variant * 32, 0, 32, 32))
			else:
				n.draw_texture_rect_region(tex_tiles, Rect2(-8, -30, 16, 32), R_PROPS_TALL[1]))
		add_child(n)


func _draw_stars(n: CanvasItem, t: float) -> void:
	for st in stars:
		var a := 0.25 + 0.55 * absf(sin(t * st["sp"] + st["ph"]))
		n.draw_rect(Rect2(st["p"], Vector2.ONE), Color(1, 1, 1, a))


func _update_weather(delta: float) -> void:
	match ambiente:
		Bioma.Ambiente.MONTAGNA:  # neve
			while weather.size() < 90:
				weather.append({"p": Vector2(randf_range(-20, art_size.x), randf_range(-10, art_size.y)),
					"v": Vector2(randf_range(-6, -2), randf_range(8, 16)), "s": 1.0 if randf() < 0.8 else 2.0})
			for f in weather:
				f["p"] += f["v"] * delta
				if f["p"].y > art_size.y + 4 or f["p"].x < -24:
					f["p"] = Vector2(randf_range(0, art_size.x + 30), -4)
		Bioma.Ambiente.PALUDE:  # fuochi fatui che vagano sul campo
			while weather.size() < 7:
				weather.append({"p": origin + Vector2(randf_range(0, lane_len), randf_range(0, depth)), "ph": randf() * TAU})
			for f in weather:
				f["p"] += Vector2(sin(amb_t * 0.7 + f["ph"]) * 4.0, cos(amb_t * 0.9 + f["ph"] * 2.0) * 3.0) * delta
		Bioma.Ambiente.CATTEDRALE:  # polvere che scende nella luce
			while weather.size() < 40:
				weather.append({"p": Vector2(randf_range(0, art_size.x), randf_range(horizon, art_size.y)),
					"v": Vector2(randf_range(-1, 1), randf_range(1.5, 4.0)), "ph": randf() * TAU})
			for f in weather:
				f["p"] += f["v"] * delta
				if f["p"].y > art_size.y:
					f["p"] = Vector2(randf_range(0, art_size.x), horizon)


## Dietro alle unità: fuochi fatui, fiammelle delle candele.
func _draw_weather_back(n: CanvasItem, t: float) -> void:
	if ambiente == Bioma.Ambiente.PALUDE:
		for f in weather:
			var a := 0.45 + 0.35 * sin(t * 3.0 + f["ph"])
			var p: Vector2 = (f["p"] as Vector2).round()
			n.draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), Color(0.65, 1.0, 0.6, a * 0.18))
			n.draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 1.0, 0.8, a))
	elif ambiente == Bioma.Ambiente.CATTEDRALE:
		for pr in props:
			if pr["r"] == R_PROPS_SMALL[6]:  # candele
				var base: Vector2 = pr["pos"] - Vector2(0, 16)
				for cx: float in [4.0, 7.0, 10.0]:
					var fx: float = base.x + (16.0 - cx - 1.0 if pr["flip"] else cx)
					var hy: float = 6.0 if cx == 4.0 else (9.0 if cx == 7.0 else 5.0)
					var fl := 1.0 + roundf(absf(sin(t * 9.0 + cx + base.x)))
					n.draw_rect(Rect2(fx, base.y + 15.0 - hy - 1.0 - fl, 1, fl), Color(1.0, 0.85, 0.5))
					n.draw_rect(Rect2(fx - 2, base.y + 15.0 - hy - 4.0, 5, 5), Color(1.0, 0.8, 0.5, 0.08))


## Davanti a tutto: neve, banchi di nebbia, raggi di luce.
func _draw_weather_front(n: CanvasItem, t: float) -> void:
	match ambiente:
		Bioma.Ambiente.MONTAGNA:
			for f in weather:
				n.draw_rect(Rect2((f["p"] as Vector2).round(), Vector2.ONE * f["s"]), Color(0.93, 0.95, 1.0, 0.8))
		Bioma.Ambiente.PALUDE:
			for i in 5:  # banchi di nebbia bassa che scorrono sul campo
				var fw := 90.0 + i * 24.0
				var fy := origin.y + depth * (0.1 + i * 0.2)
				var fx := fmod(t * (2.0 + i * 0.7) + i * 97.0, art_size.x + fw) - fw
				for k in 3:
					n.draw_rect(Rect2(roundf(fx + k * 8), fy + k * 2 - 3, fw - k * 16, 3), Color(0.8, 0.9, 0.8, 0.05))
		Bioma.Ambiente.CATTEDRALE:
			for i in 3:  # raggi di luce dalle finestre rotte
				var x0 := 60.0 + i * 140.0 + sin(t * 0.2 + i) * 6.0
				for y in range(int(horizon), int(art_size.y), 2):
					var w := 14.0
					var x := x0 + (y - horizon) * 0.45
					n.draw_rect(Rect2(roundf(x), y, w, 2), Color(1.0, 0.92, 0.75, 0.035))
			for f in weather:
				var a := 0.25 + 0.25 * sin(t * 2.0 + f["ph"])
				n.draw_rect(Rect2((f["p"] as Vector2).round(), Vector2.ONE), Color(1.0, 0.95, 0.8, a))


# --- Campioni degli eroi ------------------------------------------------------------

## Ondata da Data.build_wave, con il campione dell'ondata al posto del primo boss.
func _coda_ondata(n: int) -> Array:
	var q := Data.build_wave(n)
	if not campioni_attivi or campioni == null or n % Data.BOSS_EVERY != 0:
		return q
	var c := campioni.per_ondata(n)
	if c == null:
		return q
	for i in q.size():
		if q[i]["boss"]:
			q[i] = {"kind": c.tipo_base, "boss": true, "campione": c}
			break
	return q


func _campione_in_coda(q: Array) -> Campione:
	for e in q:
		if e.get("campione") is Campione:
			return e["campione"]
	return null


## Evoca subito un campione (dev tool): con la forza dell'ondata attuale.
func evoca_campione(c: Campione) -> void:
	_spawn_enemy({"kind": c.tipo_base, "boss": true, "campione": c})


func _annuncia_campione(u) -> void:
	campione_attivo = u
	intro_campione = u.dati
	intro_t = 3.5
	Suoni.play("ondata", 0.6)
	shake(0.5, 1.5)
	spawn_ground_fx(u.ground, 24.0, u.accent(), 0.8)


func campione_mossa(u, m: MossaCampione) -> void:
	mossa_testo = tr(m.nome).to_upper()
	mossa_t = 1.8
	var suono := {MossaCampione.Tipo.GRIDO: "ondata", MossaCampione.Tipo.EVOCA: "ondata", MossaCampione.Tipo.METEORA: "palla_di_fuoco",
		MossaCampione.Tipo.ROGO: "palla_di_fuoco", MossaCampione.Tipo.COLONNE: "saetta", MossaCampione.Tipo.RAGGIO: "saetta",
		MossaCampione.Tipo.LUCE: "saetta", MossaCampione.Tipo.CURA: "area_curativa", MossaCampione.Tipo.RESURREZIONE: "area_curativa",
		MossaCampione.Tipo.SCHIANTO: "spada", MossaCampione.Tipo.CARICA: "spada"}
	Suoni.play(suono.get(m.tipo, "magia"), 0.75)
	if u != campione_attivo and is_instance_valid(u):
		campione_attivo = u


func campione_fase2(u) -> void:
	intro_campione = u.dati
	mossa_testo = tr(u.dati.frase_fase2) if u.dati.frase_fase2 != "" else tr("%s si infuria!") % tr(u.dati.nome)
	mossa_t = 3.0
	shake(0.4, 2.0)
	lampo_schermo(0.3)
	spawn_ground_fx(u.ground, 30.0, u.accent(), 0.8)
	Suoni.play("ondata", 0.5)


func on_campione_sconfitto(u) -> void:
	var c: Campione = u.dati
	if not c.id in campioni_battuti:
		campioni_battuti.append(c.id)
	shake(0.6, 3.0)
	lampo_schermo(0.4)
	spawn_ground_fx(u.ground, 40.0, u.accent(), 1.0)
	spawn_ground_fx(u.ground, 26.0, C6, 0.8)
	if c.monete > 0 and not autotest:
		Portafoglio.add_monete(c.monete)
	set_hint(tr("Campione sconfitto: %s!") % tr(c.nome) + ("  +%d %s" % [c.monete, tr("monete")] if c.monete > 0 else ""), 4.0)
	if campione_attivo == u:
		campione_attivo = null


## Un lampo bianco su tutto lo schermo (luce dei campioni).
func lampo_schermo(dur: float) -> void:
	lampo_t = maxf(lampo_t, dur)


## Un eroe in più in un punto del campo (EVOCA dei campioni).
func spawn_enemy_at(kind: String, g: Vector2, boss: bool = false):
	var u := UnitScript.new()
	u.game = self
	u.setup_enemy(kind, Data.enemy_hp_mult(wave) * mods["enemy_hp"], Data.enemy_dmg_mult(wave), boss)
	u.ground = Vector2(clampf(g.x, 20.0, lane_len + SPAWN_W), clampf(g.y, 2.0, depth - 2.0))
	u.ground = constrain(u.ground, u.radius)
	enemies_root.add_child(u)
	spawn_ground_fx(u.ground, 8.0, C6, 0.4)
	return u


## RESURREZIONE: rialza fino a `n` eroi caduti entro `r`. Restituisce quanti.
func resuscita_eroi(centro: Vector2, r: float, n: int) -> int:
	var fatti := 0
	for i in range(eroi_caduti.size() - 1, -1, -1):
		if fatti >= n:
			break
		var e: Dictionary = eroi_caduti[i]
		if (e["g"] as Vector2).distance_to(centro) > r:
			continue
		eroi_caduti.remove_at(i)
		var u = spawn_enemy_at(e["kind"], e["g"])
		u.hp = u.max_hp * 0.6
		spawn_ground_fx(e["g"], 10.0, C6, 0.6, "heal")
		fatti += 1
	return fatti


## ROGO: fuoco a terra che brucia gli scheletri che ci stanno sopra.
func add_zona_nemica(g: Vector2, r: float, dps: float, durata: float, col: Color) -> void:
	zone_nemiche.append({"p": g, "r": r, "t": durata, "dps": dps, "col": col, "fx": 0.0})


func _update_zone_nemiche(delta: float) -> void:
	for z in zone_nemiche:
		z["t"] -= delta
		z["fx"] -= delta
		if z["fx"] <= 0.0:
			z["fx"] = 0.35
			spawn_ground_fx(z["p"], z["r"], z["col"], 0.5, "fire")
		for c in allies_root.get_children():
			if not c.dead and c.visible and c.ground.distance_to(z["p"]) <= z["r"] + c.radius:
				c.poison(z["dps"] * delta)
	zone_nemiche = zone_nemiche.filter(func(z) -> bool: return z["t"] > 0.0)


## Presentazione del campione, barra della vita in alto e nome dell'ultima mossa.
func _draw_boss_hud() -> void:
	var n := boss_hud
	var vp := n.size
	if lampo_t > 0.0:
		n.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, clampf(lampo_t * 1.5, 0.0, 0.5)))
	var u = campione_attivo
	if u != null and (not is_instance_valid(u) or u.dead):
		campione_attivo = null
		u = null
	if u != null and state != State.GAME_OVER:
		var c: Campione = u.dati
		var r := Rect2(vp.x / 2.0 - 280, 56, 560, 46)
		Pietra.stone(n, r, C1)
		var nome := tr(c.nome).to_upper()
		Pietra.text(n, ui_font, r.position + Vector2(14, 5), nome, 16, C6)
		if u.fase2:
			Pietra.text(n, ui_font, r.position + Vector2(r.size.x - 118, 5), tr("FURIA"), 16, c.colore)
		var bar := Rect2(r.position + Vector2(14, 26), Vector2(r.size.x - 28, 10))
		n.draw_rect(bar.grow(2), C0)
		n.draw_rect(bar, C2)
		var k := clampf(u.hp / u.max_hp, 0.0, 1.0)
		n.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * k), bar.size.y)), c.colore)
		n.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * k), 2)), Color(1, 1, 1, 0.35))
		if c.soglia_fase2 > 0.0:  # tacca della seconda fase
			n.draw_rect(Rect2(bar.position + Vector2(roundf(bar.size.x * c.soglia_fase2), -3), Vector2(2, bar.size.y + 6)), C6)
		if u.scudo_t > 0.0:
			n.draw_rect(Rect2(bar.position, Vector2(bar.size.x, 2)), C6)
		if mossa_t > 0.0:
			var a := clampf(mossa_t, 0.0, 1.0)
			Pietra.text_c(n, ui_font, vp.x / 2.0, r.end.y + 8, mossa_testo, 16, Color(c.colore.lightened(0.3), a))
	if intro_t > 0.0 and intro_campione != null:
		var c2 := intro_campione
		var a := clampf(intro_t / 0.5, 0.0, 1.0) * clampf((3.5 - intro_t) / 0.3, 0.0, 1.0)
		var br := Rect2(vp.x / 2.0 - 330, 170, 660, 150)
		n.draw_rect(Rect2(0, br.position.y - 8, vp.x, br.size.y + 16), Color(0, 0, 0, 0.55 * a))
		if c2.sprite != null:
			var fs := c2.sprite.get_height()
			var big := float(fs) * (3.0 if fs <= 40 else 2.5)
			n.draw_texture_rect_region(c2.sprite, Rect2(Vector2(br.position.x + 160 - big, br.get_center().y - big / 2.0 + 4), Vector2(big, big)),
				Rect2(2 * fs, 0, fs, fs), Color(1, 1, 1, a))
		var tx := br.position.x + 180
		Pietra.text(n, ui_font, Vector2(tx, br.position.y + 14), tr("CAMPIONE DEGLI EROI · ONDATA %d") % wave, 16, Color(c2.colore, a), false)
		Pietra.text(n, ui_font, Vector2(tx, br.position.y + 38), tr(c2.nome).to_upper(), 32, Color(C6, a))
		Pietra.text(n, ui_font, Vector2(tx, br.position.y + 80), tr(c2.titolo), 16, Color(C5, a))
		if c2.frase != "":
			Pietra.text_block_left(n, ui_font, Vector2(tx, br.position.y + 106), br.size.x - 200, "\"" + tr(c2.frase) + "\"", 16, Color(C4.lightened(0.2), a))


# --- Fine partita: finale cinematico (scripts/fine_partita.gd) ------------------------

func _mostra_fine(won: bool, earned: int, total: int, coins: int, record_prima: int, nuovo_livello: String, posto: int) -> void:
	var segs: Array = []
	var ultimo: Campione = null
	for i in 10:
		var w_fine := int(round(ondate_totali * (i + 1) / 10.0))
		var c: Campione = null
		if campioni_attivi and campioni != null:
			c = campioni.per_ondata(w_fine)
		var battuto := c != null and (c.id in campioni_battuti or wave > w_fine or (won and wave >= w_fine))
		segs.append({"ondata": w_fine, "campione": c, "sconfitto": battuto})
		if c != null:
			ultimo = c
	var d := {
		"vinto": won, "infinita": infinita, "ondata": wave, "ondate_totali": ondate_totali,
		"uccisioni": kills, "record": maxi(record_prima, wave), "posto": posto,
		"punti": earned, "punti_totali": total, "monete": coins, "pergamene": scrolls_earned,
		"nuovo_livello": nuovo_livello, "campioni": segs, "campioni_battuti": campioni_battuti.size(),
		"squadra": unlocked_units.duplicate(), "ultimo": ultimo,
	}
	var prep := func() -> void: get_tree().change_scene_to_file("res://scenes/preparazione.tscn")
	var campo := func() -> void: get_tree().change_scene_to_file("res://scenes/selezione_livello.tscn")
	var bottoni: Array = []
	if won and not infinita:
		bottoni.append({"testo": tr("CONTINUA"), "icona": "infinito", "stile": "oro", "larghezza": 420,
			"azione": _continua_infinita, "tasti": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_C]})
		var prossimo := _livello_successivo()
		if prossimo != null:
			bottoni.append({"testo": tr("PROSSIMO CAMPO"), "sotto": tr(prossimo.nome), "stile": "argento", "larghezza": 270,
				"azione": func() -> void:
					Livelli.scegli(prossimo)
					prep.call(), "tasti": [KEY_P]})
		else:
			bottoni.append({"testo": tr("CAMPO"), "icona": "campo", "stile": "argento", "larghezza": 270, "azione": campo, "tasti": [KEY_L]})
		bottoni.append({"testo": tr("RIGIOCA"), "icona": "riprova", "larghezza": 190, "azione": _restart_game, "tasti": [KEY_R]})
	else:
		bottoni.append({"testo": tr("RIPROVA"), "icona": "riprova", "stile": "chiaro", "larghezza": 420,
			"azione": _restart_game, "tasti": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_R]})
		bottoni.append({"testo": tr("SQUADRA"), "icona": "squadra", "larghezza": 230, "azione": prep, "tasti": [KEY_S]})
		bottoni.append({"testo": tr("CAMPO"), "icona": "campo", "larghezza": 230, "azione": campo, "tasti": [KEY_L]})
	bottoni.append({"testo": "", "icona": "menu", "stile": "scuro", "larghezza": 120, "azione": _go_to_menu, "tasti": [KEY_ESCAPE, KEY_M]})
	fine_node = FinePartitaScript.new()
	fine_node.mostra(d, bottoni, ui_font)
	ui_root.add_child(fine_node)
	hint_label.text = ""


## Il livello dopo questo nell'elenco (null se è l'ultimo).
func _livello_successivo() -> InfoLivello:
	var lista := Livelli.elenco()
	for i in lista.size() - 1:
		if lista[i].id == id_livello:
			return lista[i + 1]
	return null
