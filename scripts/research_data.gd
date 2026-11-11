@tool
extends RefCounted
## Albero delle ricerche: dati dei nodi e salvataggio dei progressi.
##
## Per aggiungere o cambiare una ricerca modifica NODES:
##   name      nome mostrato
##   desc      descrizione (l'effetto per livello)
##   branch    ramo: 0 Necromante, 1 Evocazioni, 2 Arcano
##   pos       posizione nella griglia della schermata (colonna, riga)
##   costs     costo in punti di ogni livello (il numero di livelli è la lunghezza)
##   requires  [id, livello minimo] della ricerca da sbloccare prima (o [] se nessuna)
##   effect    tipo di bonus (vedi bonuses() e main.gd: _apply_research)
##   value     valore del bonus per ogni livello
##   icon      angolo in alto a sinistra dell'icona 16x16 in assets/sprites.png
##   tex       (facoltativo) "necro" = l'icona è in assets/necromanti/necromanti.png
##   tree      (facoltativo) a quale necromante appartiene: "ossa" (se manca),
##             "strega" o "lich". Ogni necromante ha il suo albero; i punti sono in comune.
##   infinito  (facoltativo) ricerca senza livello massimo: costa costs[0] + COSTO_PASSO_INFINITO
##             punti in più a ogni livello. Si sblocca quando tutto il resto dell'albero è al massimo.
##
## I costi crescono a ogni livello: chi vuole completare un albero ci mette parecchie partite,
## e i punti che avanzano finiscono nella ricerca senza fine (ramo ASCESA).
##
## Le unità NON si sbloccano più da qui: si trovano aprendo le pergamene nel
## portale (vedi collezione.gd). Qui ci sono solo potenziamenti, anche per ruolo
## (corpo a corpo, a distanza, magia), e le tre abilità del necromante.
## Effetti per ruolo: "hp_<ruolo>" e "dmg_<ruolo>" (vedi main.gd: role_mult).

const SAVE_PATH := "user://progressi.cfg"
## Ricerche senza fine: ogni livello costa questi punti in più del precedente.
const COSTO_PASSO_INFINITO := 20
## Livello massimo "di sicurezza" delle ricerche senza fine (praticamente irraggiungibile).
const MAX_INFINITO := 999

const BRANCHES := [
	{"name": "NECROMANTE", "cols": [0, 1]},
	{"name": "EVOCAZIONI", "cols": [3, 4]},
	{"name": "ARCANO", "cols": [6, 7]},
	{"name": "ASCESA", "cols": [8]},
]

## Rami di ogni albero (id del necromante -> rami). Le colonne sono quelle della griglia.
const TREES := {
	"ossa": BRANCHES,
	"strega": [
		{"name": "STREGA", "cols": [0, 1]},
		{"name": "EVOCAZIONI", "cols": [3, 4]},
		{"name": "MALEFICI", "cols": [6, 7]},
		{"name": "ASCESA", "cols": [8]},
	],
	"lich": [
		{"name": "LICH", "cols": [0, 1]},
		{"name": "EVOCAZIONI", "cols": [3, 4]},
		{"name": "INVERNO", "cols": [6, 7]},
		{"name": "ASCESA", "cols": [8]},
	],
}

const NODES := {
	# --- Necromante ---------------------------------------------------------
	"mura": {
		"name": "Mura rinforzate", "desc": "Vita della torre +20 per livello.",
		"branch": 0, "pos": Vector2i(0, 0), "costs": [4, 8, 16, 26, 42], "requires": [],
		"effect": "tower_hp", "value": 20.0, "icon": Vector2(16, 48),
	},
	"furia": {
		"name": "Furia oscura", "desc": "Danno del necromante +10% per livello.",
		"branch": 0, "pos": Vector2i(1, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "necro_dmg", "value": 0.10, "icon": Vector2(64, 32),
	},
	"occhio": {
		"name": "Occhio della notte", "desc": "Gittata del necromante +20% per livello: si schiera anche più lontano dalla torre.",
		"branch": 0, "pos": Vector2i(0, 1), "costs": [6, 14, 27, 41, 57, 66], "requires": ["mura", 1],
		"effect": "necro_range", "value": 0.20, "icon": Vector2(48, 64),
	},
	"rito": {
		"name": "Rito rapido", "desc": "Velocità d'attacco del necromante +8% per livello.",
		"branch": 0, "pos": Vector2i(1, 1), "costs": [8, 17, 32], "requires": ["furia", 1],
		"effect": "necro_rate", "value": 0.08, "icon": Vector2(48, 80),
	},
	"saggezza": {
		"name": "Saggezza proibita", "desc": "Esperienza guadagnata +10% per livello: sali di livello prima.",
		"branch": 0, "pos": Vector2i(1, 2), "costs": [6, 14, 27], "requires": ["rito", 1],
		"effect": "xp", "value": 0.10, "icon": Vector2(64, 64),
	},
	# --- Evocazioni ---------------------------------------------------------
	"lame": {
		"name": "Lame d'osso", "desc": "Danno delle unità scheletro +10% per livello.",
		"branch": 1, "pos": Vector2i(3, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "ally_dmg", "value": 0.10, "icon": Vector2(96, 64),
	},
	"ossa": {
		"name": "Ossa robuste", "desc": "Vita delle unità scheletro +10% per livello.",
		"branch": 1, "pos": Vector2i(4, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "ally_hp", "value": 0.10, "icon": Vector2(80, 64),
	},
	"disciplina": {
		"name": "Disciplina d'osso", "desc": "Vita delle unità corpo a corpo +12% per livello.",
		"branch": 1, "pos": Vector2i(3, 1), "costs": [6, 14, 27], "requires": ["lame", 1],
		"effect": "hp_corpo", "value": 0.12, "icon": Vector2(0, 0),
	},
	"mira": {
		"name": "Mira spettrale", "desc": "Danno delle unità a distanza +12% per livello.",
		"branch": 1, "pos": Vector2i(3, 2), "costs": [8, 17, 32], "requires": ["disciplina", 1],
		"effect": "dmg_distanza", "value": 0.12, "icon": Vector2(32, 0),
	},
	"occulto": {
		"name": "Arti occulte", "desc": "Danno delle unità magiche +12% per livello.",
		"branch": 1, "pos": Vector2i(4, 1), "costs": [8, 17, 32], "requires": ["ossa", 1],
		"effect": "dmg_magia", "value": 0.12, "icon": Vector2(64, 0),
	},
	"legione": {
		"name": "Legione", "desc": "Squadre schierabili a inizio partita +1 per livello.",
		"branch": 1, "pos": Vector2i(4, 2), "costs": [25, 56], "requires": ["occulto", 1],
		"effect": "deploy", "value": 1.0, "icon": Vector2(112, 64),
	},
	# --- Arcano -------------------------------------------------------------
	"palla": {
		"name": "Palla di fuoco", "desc": "Sblocca l'abilità Palla di fuoco: danni alti in un'area media.",
		"branch": 2, "pos": Vector2i(6, 0), "costs": [8], "requires": [],
		"effect": "unlock_palla_di_fuoco", "value": 1.0, "icon": Vector2(48, 48),
	},
	"cura": {
		"name": "Area curativa", "desc": "Sblocca l'abilità Area curativa: cura gli scheletri in un'area ampia.",
		"branch": 2, "pos": Vector2i(7, 0), "costs": [8], "requires": [],
		"effect": "unlock_area_curativa", "value": 1.0, "icon": Vector2(80, 48),
	},
	"saetta": {
		"name": "Saetta", "desc": "Sblocca l'abilità Saetta: danni altissimi in un'area piccola.",
		"branch": 2, "pos": Vector2i(6, 1), "costs": [14], "requires": ["palla", 1],
		"effect": "unlock_saetta", "value": 1.0, "icon": Vector2(64, 48),
	},
	"potere": {
		"name": "Potere arcano", "desc": "Potenza delle abilità +15% per livello.",
		"branch": 2, "pos": Vector2i(6, 2), "costs": [10, 22, 43], "requires": ["saetta", 1],
		"effect": "ability_power", "value": 0.15, "icon": Vector2(112, 48),
	},
	"concentrazione": {
		"name": "Concentrazione", "desc": "Tempo di ricarica delle abilità -10% per livello.",
		"branch": 2, "pos": Vector2i(7, 1), "costs": [10, 22, 43], "requires": ["cura", 1],
		"effect": "ability_cd", "value": 0.10, "icon": Vector2(96, 48),
	},
	# --- Signore delle Ossa: ricerca in più nel ramo Necromante ---------------
	"raccolto": {
		"tree": "ossa", "name": "Raccolto d'ossa", "desc": "Probabilità che un nemico ucciso si rialzi come scheletro +5% per livello.",
		"branch": 0, "pos": Vector2i(0, 2), "costs": [8, 17, 32], "requires": ["occhio", 1],
		"effect": "rialza", "value": 0.05, "icon": Vector2(96, 32), "tex": "necro",
	},
	# --- Strega Pestilenziale ---------------------------------------------------
	"s_veleno": {
		"tree": "strega", "name": "Veleno potente", "desc": "Veleno dei colpi della torre +20% per livello.",
		"branch": 0, "pos": Vector2i(0, 0), "costs": [4, 8, 16, 26, 42], "requires": [],
		"effect": "veleno_torre", "value": 0.20, "icon": Vector2(0, 32), "tex": "necro",
	},
	"s_ira": {
		"tree": "strega", "name": "Ira della strega", "desc": "Danno della torre +10% per livello.",
		"branch": 0, "pos": Vector2i(1, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "necro_dmg", "value": 0.10, "icon": Vector2(112, 48),
	},
	"s_tossine": {
		"tree": "strega", "name": "Tossine lente", "desc": "Il veleno della torre dura 1 secondo in più per livello.",
		"branch": 0, "pos": Vector2i(0, 1), "costs": [6, 14, 27], "requires": ["s_veleno", 1],
		"effect": "veleno_durata", "value": 1.0, "icon": Vector2(16, 32), "tex": "necro",
	},
	"s_malocchio": {
		"tree": "strega", "name": "Malocchio", "desc": "I colpi della torre maledicono 1 secondo in più per livello.",
		"branch": 0, "pos": Vector2i(1, 1), "costs": [6, 14, 27], "requires": ["s_ira", 1],
		"effect": "maledizione_torre", "value": 1.0, "icon": Vector2(32, 32), "tex": "necro",
	},
	"s_rovi": {
		"tree": "strega", "name": "Mura di rovi", "desc": "Vita della torre +20 per livello.",
		"branch": 0, "pos": Vector2i(0, 2), "costs": [4, 8, 16, 26, 42], "requires": ["s_tossine", 1],
		"effect": "tower_hp", "value": 20.0, "icon": Vector2(80, 64),
	},
	"s_rito": {
		"tree": "strega", "name": "Rito del calderone", "desc": "Velocità d'attacco della torre +8% per livello.",
		"branch": 0, "pos": Vector2i(1, 2), "costs": [8, 17, 32], "requires": ["s_malocchio", 1],
		"effect": "necro_rate", "value": 0.08, "icon": Vector2(96, 48),
	},
	"s_lame": {
		"tree": "strega", "name": "Lame avvelenate", "desc": "I colpi degli scheletri avvelenano: 10% del danno al secondo per livello.",
		"branch": 1, "pos": Vector2i(3, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "ally_veleno", "value": 0.10, "icon": Vector2(96, 64),
	},
	"s_ossa": {
		"tree": "strega", "name": "Ossa marce", "desc": "Vita delle unità scheletro +10% per livello.",
		"branch": 1, "pos": Vector2i(4, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "ally_hp", "value": 0.10, "icon": Vector2(80, 48),
	},
	"s_contagio": {
		"tree": "strega", "name": "Contagio", "desc": "Quando un nemico avvelenato muore, 20% per livello di contagiare chi gli sta vicino.",
		"branch": 1, "pos": Vector2i(3, 1), "costs": [6, 14, 27], "requires": ["s_lame", 1],
		"effect": "contagio", "value": 0.20, "icon": Vector2(48, 32), "tex": "necro",
	},
	"s_streghe": {
		"tree": "strega", "name": "Arti della congrega", "desc": "Danno delle unità magiche +12% per livello.",
		"branch": 1, "pos": Vector2i(4, 1), "costs": [8, 17, 32], "requires": ["s_ossa", 1],
		"effect": "dmg_magia", "value": 0.12, "icon": Vector2(64, 0),
	},
	"s_legione": {
		"tree": "strega", "name": "Esercito appestato", "desc": "Squadre schierabili a inizio partita +1 per livello.",
		"branch": 1, "pos": Vector2i(3, 2), "costs": [25, 56], "requires": ["s_contagio", 1],
		"effect": "deploy", "value": 1.0, "icon": Vector2(112, 64),
	},
	"s_mira": {
		"tree": "strega", "name": "Frecce intinte", "desc": "Danno delle unità a distanza +12% per livello.",
		"branch": 1, "pos": Vector2i(4, 2), "costs": [8, 17, 32], "requires": ["s_streghe", 1],
		"effect": "dmg_distanza", "value": 0.12, "icon": Vector2(32, 0),
	},
	"s_nube": {
		"tree": "strega", "name": "Nube di peste", "desc": "Sblocca la magia Nube di peste: una nube che avvelena, rallenta e maledice.",
		"branch": 2, "pos": Vector2i(6, 0), "costs": [8], "requires": [],
		"effect": "unlock_nube_di_peste", "value": 1.0, "icon": Vector2(0, 16), "tex": "necro",
	},
	"s_maledizione": {
		"tree": "strega", "name": "Maledizione", "desc": "Sblocca la magia Maledizione: i nemici nell'area subiscono il 50% di danni in più.",
		"branch": 2, "pos": Vector2i(7, 0), "costs": [8], "requires": [],
		"effect": "unlock_maledizione", "value": 1.0, "icon": Vector2(16, 16), "tex": "necro",
	},
	"s_sciame": {
		"tree": "strega", "name": "Sciame", "desc": "Sblocca la magia Sciame: insetti velenosi su tanti nemici vicini.",
		"branch": 2, "pos": Vector2i(6, 1), "costs": [14], "requires": ["s_nube", 1],
		"effect": "unlock_sciame", "value": 1.0, "icon": Vector2(32, 16), "tex": "necro",
	},
	"s_potere": {
		"tree": "strega", "name": "Potere del sabba", "desc": "Potenza delle magie +15% per livello.",
		"branch": 2, "pos": Vector2i(6, 2), "costs": [10, 22, 43], "requires": ["s_sciame", 1],
		"effect": "ability_power", "value": 0.15, "icon": Vector2(64, 64),
	},
	"s_luna": {
		"tree": "strega", "name": "Luna nera", "desc": "Tempo di ricarica delle magie -10% per livello.",
		"branch": 2, "pos": Vector2i(7, 1), "costs": [10, 22, 43], "requires": ["s_maledizione", 1],
		"effect": "ability_cd", "value": 0.10, "icon": Vector2(96, 48),
	},
	"s_anatema": {
		"tree": "strega", "name": "Anatema", "desc": "I maledetti subiscono il 10% di danni in più per livello.",
		"branch": 2, "pos": Vector2i(7, 2), "costs": [10, 22, 43], "requires": ["s_luna", 1],
		"effect": "maledizione_forza", "value": 0.10, "icon": Vector2(48, 64),
	},
	# --- Lich del Ghiaccio -------------------------------------------------------
	"l_gelo": {
		"tree": "lich", "name": "Tocco gelido", "desc": "Rallentamento dei colpi della torre +8% per livello.",
		"branch": 0, "pos": Vector2i(0, 0), "costs": [4, 8, 16, 26, 42], "requires": [],
		"effect": "rallenta_torre", "value": 0.08, "icon": Vector2(64, 32), "tex": "necro",
	},
	"l_furia": {
		"tree": "lich", "name": "Furia del lich", "desc": "Danno della torre +10% per livello.",
		"branch": 0, "pos": Vector2i(1, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "necro_dmg", "value": 0.10, "icon": Vector2(112, 48),
	},
	"l_inverno": {
		"tree": "lich", "name": "Inverno lungo", "desc": "Il rallentamento della torre dura mezzo secondo in più per livello.",
		"branch": 0, "pos": Vector2i(0, 1), "costs": [6, 14, 27], "requires": ["l_gelo", 1],
		"effect": "rallenta_durata", "value": 0.5, "icon": Vector2(96, 48),
	},
	"l_congela": {
		"tree": "lich", "name": "Morsa di ghiaccio", "desc": "Probabilità di congelare a ogni colpo della torre +4% per livello.",
		"branch": 0, "pos": Vector2i(1, 1), "costs": [6, 14, 27], "requires": ["l_furia", 1],
		"effect": "congela", "value": 0.04, "icon": Vector2(64, 16), "tex": "necro",
	},
	"l_mura": {
		"tree": "lich", "name": "Mura di ghiaccio", "desc": "Vita della torre +20 per livello.",
		"branch": 0, "pos": Vector2i(0, 2), "costs": [4, 8, 16, 26, 42], "requires": ["l_inverno", 1],
		"effect": "tower_hp", "value": 20.0, "icon": Vector2(80, 64),
	},
	"l_cuore": {
		"tree": "lich", "name": "Cuore gelido", "desc": "Il congelamento dura 0,3 secondi in più per livello.",
		"branch": 0, "pos": Vector2i(1, 2), "costs": [8, 17, 32], "requires": ["l_congela", 1],
		"effect": "congela_durata", "value": 0.3, "icon": Vector2(48, 64),
	},
	"l_lame": {
		"tree": "lich", "name": "Lame di brina", "desc": "I colpi degli scheletri rallentano i nemici dell'8% per livello.",
		"branch": 1, "pos": Vector2i(3, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "ally_gelo", "value": 0.08, "icon": Vector2(96, 64),
	},
	"l_ossa": {
		"tree": "lich", "name": "Ossa di ghiaccio", "desc": "Vita delle unità scheletro +10% per livello.",
		"branch": 1, "pos": Vector2i(4, 0), "costs": [5, 11, 22, 35, 57], "requires": [],
		"effect": "ally_hp", "value": 0.10, "icon": Vector2(80, 48),
	},
	"l_guardia": {
		"tree": "lich", "name": "Guardia d'inverno", "desc": "Vita delle unità corpo a corpo +12% per livello.",
		"branch": 1, "pos": Vector2i(3, 1), "costs": [6, 14, 27], "requires": ["l_lame", 1],
		"effect": "hp_corpo", "value": 0.12, "icon": Vector2(0, 0),
	},
	"l_mira": {
		"tree": "lich", "name": "Frecce di ghiaccio", "desc": "Danno delle unità a distanza +12% per livello.",
		"branch": 1, "pos": Vector2i(4, 1), "costs": [8, 17, 32], "requires": ["l_ossa", 1],
		"effect": "dmg_distanza", "value": 0.12, "icon": Vector2(32, 0),
	},
	"l_legione": {
		"tree": "lich", "name": "Legione gelata", "desc": "Squadre schierabili a inizio partita +1 per livello.",
		"branch": 1, "pos": Vector2i(3, 2), "costs": [25, 56], "requires": ["l_guardia", 1],
		"effect": "deploy", "value": 1.0, "icon": Vector2(112, 64),
	},
	"l_schegge": {
		"tree": "lich", "name": "Schegge", "desc": "I nemici congelati subiscono il 20% di danni in più per livello.",
		"branch": 1, "pos": Vector2i(4, 2), "costs": [8, 17, 32], "requires": ["l_mira", 1],
		"effect": "schegge", "value": 0.20, "icon": Vector2(80, 32), "tex": "necro",
	},
	"l_bufera": {
		"tree": "lich", "name": "Bufera", "desc": "Sblocca la magia Bufera: una tempesta di neve che rallenta e ferisce.",
		"branch": 2, "pos": Vector2i(6, 0), "costs": [8], "requires": [],
		"effect": "unlock_bufera", "value": 1.0, "icon": Vector2(48, 16), "tex": "necro",
	},
	"l_prigione": {
		"tree": "lich", "name": "Prigione gelida", "desc": "Sblocca la magia Prigione gelida: congela i nemici in una piccola area.",
		"branch": 2, "pos": Vector2i(7, 0), "costs": [8], "requires": [],
		"effect": "unlock_prigione_di_ghiaccio", "value": 1.0, "icon": Vector2(64, 16), "tex": "necro",
	},
	"l_cometa": {
		"tree": "lich", "name": "Cometa gelata", "desc": "Sblocca la magia Cometa gelata: danni altissimi e gelo dove cade.",
		"branch": 2, "pos": Vector2i(6, 1), "costs": [14], "requires": ["l_bufera", 1],
		"effect": "unlock_cometa_gelata", "value": 1.0, "icon": Vector2(80, 16), "tex": "necro",
	},
	"l_potere": {
		"tree": "lich", "name": "Potere del gelo", "desc": "Potenza delle magie +15% per livello.",
		"branch": 2, "pos": Vector2i(6, 2), "costs": [10, 22, 43], "requires": ["l_cometa", 1],
		"effect": "ability_power", "value": 0.15, "icon": Vector2(64, 64),
	},
	"l_luna": {
		"tree": "lich", "name": "Notte polare", "desc": "Tempo di ricarica delle magie -10% per livello.",
		"branch": 2, "pos": Vector2i(7, 1), "costs": [10, 22, 43], "requires": ["l_prigione", 1],
		"effect": "ability_cd", "value": 0.10, "icon": Vector2(96, 48),
	},
	"l_eterno": {
		"tree": "lich", "name": "Inverno eterno", "desc": "Gli effetti delle magie (gelo, bufera) durano il 20% in più per livello.",
		"branch": 2, "pos": Vector2i(7, 2), "costs": [10, 22, 43], "requires": ["l_luna", 1],
		"effect": "durata_magie", "value": 0.20, "icon": Vector2(64, 32), "tex": "necro",
	},
	# --- Ascesa: una ricerca senza fine per albero, dove finiscono i punti che avanzano ---
	"patto_immortale": {
		"name": "Patto immortale", "desc": "Danni e vita di torre e scheletri +2% per livello. Senza limite: ogni livello costa 20 punti in più. Si sblocca completando tutto l'albero.",
		"branch": 3, "pos": Vector2i(8, 1), "costs": [40], "requires": [], "infinito": true,
		"effect": "ascesa", "value": 0.02, "icon": Vector2(112, 48),
	},
	"s_pestilenza": {
		"tree": "strega", "name": "Pestilenza senza fine", "desc": "Danni e vita di torre e scheletri +2% per livello. Senza limite: ogni livello costa 20 punti in più. Si sblocca completando tutto l'albero.",
		"branch": 3, "pos": Vector2i(8, 1), "costs": [40], "requires": [], "infinito": true,
		"effect": "ascesa", "value": 0.02, "icon": Vector2(112, 48),
	},
	"l_glaciale": {
		"tree": "lich", "name": "Era glaciale", "desc": "Danni e vita di torre e scheletri +2% per livello. Senza limite: ogni livello costa 20 punti in più. Si sblocca completando tutto l'albero.",
		"branch": 3, "pos": Vector2i(8, 1), "costs": [40], "requires": [], "infinito": true,
		"effect": "ascesa", "value": 0.02, "icon": Vector2(112, 48),
	},
}


# --- Salvataggio -------------------------------------------------------------

## Ricerche tolte (sblocco delle unità) e il loro costo, per rimborsare i vecchi salvataggi.
const OLD_UNLOCKS := {"arcieri": 6, "maghi": 12, "giganti": 14}

## Stato salvato: {"points": int, "best": int, "levels": {id: livello}}
static func load_state() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # se il file non esiste ancora parte tutto da zero
	var levels := {}
	for id in NODES:
		levels[id] = int(cfg.get_value("ricerche", id, 0))
	# vecchi salvataggi: gli sblocchi delle unità non esistono più, restituisco i punti
	var refund := 0
	for old in OLD_UNLOCKS:
		if int(cfg.get_value("ricerche", old, 0)) > 0:
			refund += OLD_UNLOCKS[old]
			cfg.set_value("ricerche", old, 0)
	if refund > 0:
		cfg.set_value("progressi", "punti", int(cfg.get_value("progressi", "punti", 0)) + refund)
		cfg.save(SAVE_PATH)
	return {
		"points": int(cfg.get_value("progressi", "punti", 0)),
		"best": int(cfg.get_value("progressi", "record_ondata", 0)),
		"levels": levels,
	}


static func save_state(st: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # conserva le altre voci (record, ecc.)
	cfg.set_value("progressi", "punti", st["points"])
	for id in st["levels"]:
		cfg.set_value("ricerche", id, st["levels"][id])
	cfg.save(SAVE_PATH)


# --- Regole ------------------------------------------------------------------

static func level(st: Dictionary, id: String) -> int:
	return st["levels"].get(id, 0)


static func max_level(id: String) -> int:
	return MAX_INFINITO if infinito(id) else NODES[id]["costs"].size()


## Ricerca senza livello massimo (ramo ASCESA)?
static func infinito(id: String) -> bool:
	return bool(NODES[id].get("infinito", false))


## Costo del livello `lv` (il primo è 0).
static func cost_of(id: String, lv: int) -> int:
	var costs: Array = NODES[id]["costs"]
	if infinito(id):
		return int(costs[0]) + COSTO_PASSO_INFINITO * lv
	return int(costs[lv])


## Costo del prossimo livello, oppure -1 se la ricerca è al massimo.
static func next_cost(st: Dictionary, id: String) -> int:
	var lv := level(st, id)
	return cost_of(id, lv) if lv < max_level(id) else -1


static func requirements_met(st: Dictionary, id: String) -> bool:
	if infinito(id):  # tutto il resto dell'albero al massimo
		for other: String in tree_nodes(tree_of(id)):
			if other != id and not infinito(other) and level(st, other) < max_level(other):
				return false
		return true
	var req: Array = NODES[id]["requires"]
	return req.is_empty() or level(st, req[0]) >= req[1]


static func can_buy(st: Dictionary, id: String) -> bool:
	var cost := next_cost(st, id)
	return cost >= 0 and requirements_met(st, id) and st["points"] >= cost


static func buy(st: Dictionary, id: String) -> bool:
	if not can_buy(st, id):
		return false
	st["points"] -= next_cost(st, id)
	st["levels"][id] = level(st, id) + 1
	save_state(st)
	return true


## Albero a cui appartiene la ricerca ("ossa" se non è indicato).
static func tree_of(id: String) -> String:
	return String(NODES[id].get("tree", "ossa"))


## Id delle ricerche di un albero.
static func tree_nodes(tree: String) -> Array:
	var out: Array = []
	for id in NODES:
		if tree_of(id) == tree:
			out.append(id)
	return out


static func branches(tree: String) -> Array:
	return TREES.get(tree, BRANCHES)


## Restituisce i punti spesi e azzera le ricerche (di un solo albero se `tree` non è vuoto).
static func refund_all(st: Dictionary, tree: String = "") -> void:
	for id in NODES:
		if tree != "" and tree_of(id) != tree:
			continue
		for i in level(st, id):
			st["points"] += cost_of(id, i)
		st["levels"][id] = 0
	save_state(st)


## Somma dei bonus delle ricerche fatte: {effect: valore totale}.
## Con `tree` conta solo l'albero di quel necromante (quello in partita).
static func bonuses(levels: Dictionary, tree: String = "") -> Dictionary:
	var b := {}
	for id in NODES:
		if tree != "" and tree_of(id) != tree:
			continue
		var lv: int = levels.get(id, 0)
		if lv > 0:
			var n: Dictionary = NODES[id]
			b[n["effect"]] = b.get(n["effect"], 0.0) + n["value"] * lv
	return b
