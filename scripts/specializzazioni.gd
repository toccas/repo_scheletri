extends RefCounted
## SPECIALIZZAZIONI DELLE UNITÀ: al rango 3 e al rango 5 ogni unità sceglie tra due rami.
## I rami stanno in specializzazioni/<unità>.tres (vedi rami_unita.gd e specializzazione.gd).
## Le scelte si salvano in user://progressi.cfg, sezione [specializzazioni]:
##   <unità>_3 = 0 / 1   (ramo scelto al rango 3; -1 o assente = non ancora scelto)
##   <unità>_5 = 0 / 1
## Si possono cambiare quando vuoi in preparazione, fuori dalla battaglia.

const Lingua := preload("res://scripts/lingua.gd")
const SAVE_PATH := "user://progressi.cfg"
const CARTELLA := "res://specializzazioni/"
const RANGHI: Array[int] = [3, 5]

static var _rami := {}
static var _base: Dictionary = {}


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg


## I rami di un'unità (null se non ha il file).
static func rami(kind: String) -> RamiUnita:
	if not _rami.has(kind):
		var path := CARTELLA + kind + ".tres"
		_rami[kind] = load(path) if ResourceLoader.exists(path) else null
	return _rami[kind]


static func opzioni(kind: String, rango: int) -> Array[Specializzazione]:
	var r := rami(kind)
	return r.opzioni(rango) if r != null else ([] as Array[Specializzazione])


## Ramo scelto (0 o 1) per quel rango, -1 se non ancora scelto.
static func scelta(kind: String, rango: int) -> int:
	return int(_cfg().get_value("specializzazioni", "%s_%d" % [kind, rango], -1))


static func scegli(kind: String, rango: int, idx: int) -> void:
	var cfg := _cfg()
	cfg.set_value("specializzazioni", "%s_%d" % [kind, rango], idx)
	cfg.save(SAVE_PATH)


static func azzera() -> void:
	var cfg := _cfg()
	if cfg.has_section("specializzazioni"):
		cfg.erase_section("specializzazioni")
	cfg.save(SAVE_PATH)


## Il primo rango già raggiunto in cui manca la scelta (0 = niente da scegliere).
static func da_scegliere(kind: String, rank: int) -> int:
	for r in RANGHI:
		if rank >= r and scelta(kind, r) < 0 and not opzioni(kind, r).is_empty():
			return r
	return 0


## Le specializzazioni attive. `forza` = {3: idx, 5: idx} per le prove (sostituisce il salvataggio).
static func attive(kind: String, rank: int, forza: Dictionary = {}) -> Array[Specializzazione]:
	var out: Array[Specializzazione] = []
	for r in RANGHI:
		if rank < r:
			continue
		var ops := opzioni(kind, r)
		var i: int = int(forza.get(r, scelta(kind, r)))
		if i >= 0 and i < ops.size():
			out.append(ops[i])
	return out


## Valori neutri di tutti gli effetti.
static func neutri() -> Dictionary:
	if _base.is_empty():
		var s := Specializzazione.new()
		for k in Specializzazione.MOLTIPLICA + Specializzazione.SOMMA + Specializzazione.MASSIMO:
			_base[k] = s.get(k)
		_base["colore"] = Color(0, 0, 0, 0)
	return _base.duplicate()


## Effetti totali delle specializzazioni attive di un'unità (usati da main.gd e unit.gd).
static func effetti(kind: String, rank: int, forza: Dictionary = {}) -> Dictionary:
	var e := neutri()
	var lista := attive(kind, rank, forza)
	e["attive"] = lista.size()
	for s in lista:
		for k in Specializzazione.MOLTIPLICA:
			e[k] = float(e[k]) * float(s.get(k))
		for k in Specializzazione.SOMMA:
			e[k] = e[k] + s.get(k)
		for k in Specializzazione.MASSIMO:
			e[k] = maxf(float(e[k]), float(s.get(k)))
		if s.colore.a > 0.0:
			e["colore"] = s.colore
	for k in Specializzazione.LIMITI:
		e[k] = minf(float(e[k]), float(Specializzazione.LIMITI[k]))
	return e


## "Arciere di fuoco + Occhio di falco" (vuoto se nessuna).
static func nomi_attivi(kind: String, rank: int) -> String:
	var nomi: Array[String] = []
	for s in attive(kind, rank):
		nomi.append(Lingua.t(s.nome))
	return " + ".join(nomi)


static func _pc(x: float) -> int:
	return int(round(x * 100.0))


static func _sec(x: float) -> String:
	return ("%d" % int(x)) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


## Righe che descrivono gli effetti di una specializzazione, scritte dai suoi numeri.
static func testo_effetti(s: Specializzazione) -> Array[String]:
	var t: Array[String] = []
	var pct := func(v: float, piu: String, meno: String) -> void:
		if not is_equal_approx(v, 1.0):
			t.append(Lingua.t(piu if v > 1.0 else meno) % absi(_pc(v - 1.0)))
	pct.call(s.vita, "+%d%% vita", "-%d%% vita")
	pct.call(s.danno, "+%d%% danno", "-%d%% danno")
	pct.call(s.cadenza, "attacca il %d%% più spesso", "attacca il %d%% più lentamente")
	pct.call(s.gittata, "+%d%% gittata", "-%d%% gittata")
	pct.call(s.velocita, "+%d%% velocità", "-%d%% velocità")
	pct.call(s.area, "+%d%% area", "-%d%% area")
	if s.unita_extra > 0:
		t.append(Lingua.t("+%d unità in ogni squadra") % s.unita_extra)
	if s.colpi_extra > 0:
		t.append(Lingua.t("colpisce anche altri %d nemici (%d%% del danno)") % [s.colpi_extra, _pc(s.danno_colpi_extra)])
	if s.catena > 0:
		t.append(Lingua.t("il colpo rimbalza su altri %d nemici (%d%%)") % [s.catena, _pc(s.danno_catena)])
	if s.critico > 0.0:
		t.append(Lingua.t("%d%% di colpo critico (danno x%s)") % [_pc(s.critico), _sec(s.danno_critico)])
	if s.danno_nel_tempo > 0.0:
		t.append(Lingua.t("danno continuo: %d%% del colpo al secondo per %s s") % [_pc(s.danno_nel_tempo), _sec(s.durata_danno_nel_tempo)])
	if s.rallenta > 0.0:
		t.append(Lingua.t("rallenta del %d%% per %s s") % [_pc(s.rallenta), _sec(s.durata_rallenta)])
	if s.stordisci > 0.0:
		t.append(Lingua.t("%d%% di stordire per %s s") % [_pc(s.stordisci), _sec(s.durata_stordisci)])
	if s.maledici > 0.0:
		t.append(Lingua.t("maledice per %s s (+30%% danni subiti)") % _sec(s.maledici))
	if s.rubavita > 0.0:
		t.append(Lingua.t("si cura del %d%% del danno inflitto") % _pc(s.rubavita))
	if s.esplosione > 0.0:
		t.append(Lingua.t("i colpi esplodono attorno al bersaglio (%d%% del danno)") % _pc(s.danno_esplosione))
	if not is_equal_approx(s.danno_campioni, 1.0):
		t.append(Lingua.t("+%d%% danno ai campioni") % _pc(s.danno_campioni - 1.0))
	if s.esecuzione > 0.0:
		t.append(Lingua.t("finisce i nemici sotto il %d%% di vita") % _pc(s.esecuzione))
	if s.respingi > 0.0:
		t.append(Lingua.t("respinge indietro i nemici colpiti"))
	if s.riduzione_danni > 0.0:
		t.append(Lingua.t("-%d%% danni subiti") % _pc(s.riduzione_danni))
	if s.spine > 0.0:
		t.append(Lingua.t("rimanda il %d%% dei danni corpo a corpo") % _pc(s.spine))
	if s.rigenera > 0.0:
		t.append(Lingua.t("rigenera il %s%% della vita al secondo") % _sec(s.rigenera * 100.0))
	if s.schiva > 0.0:
		t.append(Lingua.t("%d%% di schivare i colpi") % _pc(s.schiva))
	if s.esplode_alla_morte > 0.0:
		t.append(Lingua.t("esplode quando muore"))
	if not is_equal_approx(s.potenza_speciale, 1.0):
		t.append(Lingua.t("abilità speciale più forte (+%d%%)") % _pc(s.potenza_speciale - 1.0))
	if s.aura_cura > 0.0:
		t.append(Lingua.t("cura gli scheletri vicini del %s%% della vita al secondo") % _sec(s.aura_cura * 100.0))
	if s.aura_rallenta > 0.0:
		t.append(Lingua.t("rallenta del %d%% i nemici vicini") % _pc(s.aura_rallenta))
	if s.rianimati_extra > 0:
		t.append(Lingua.t("+%d scheletri rianimati alla volta") % s.rianimati_extra)
	if s.curati_extra > 0:
		t.append(Lingua.t("cura anche altri %d scheletri feriti (70%%)") % s.curati_extra)
	return t
