class_name Sonido
extends Node
## Sonido provisional, generado por código (como las cápsulas son arte provisional): efectos
## cortos y una música por capas que cambia con el estado del mapa.
##
## Capas (se mezclan subiendo o bajando su volumen):
## - fondo: un acorde grave, siempre;
## - tension: un pulso lento, mientras algún enemigo sospecha;
## - alarma: un pulso rápido y agudo, durante la Alarma;
## - sed: un latido que crece con la sed (y manda en el Frenesí).
## Para poner música de verdad basta con cambiar cada capa por un AudioStream (ver `capas`).

const FRECUENCIA := 22050
const VOLUMEN_MIN := -60.0 # dB: capa apagada
const SUAVIDAD := 3.0 # lo rápido que sube o baja cada capa

static var silencio := false # las pruebas lo apagan
static var _capas_hechas := {} # nombre -> AudioStreamWAV (se generan una sola vez)
static var _efectos_hechos := {}

var mapa: Mapa
var capas := {} # nombre -> AudioStreamPlayer
var _objetivo := {} # nombre -> volumen (0..1) al que va
var _efectos: Array[AudioStreamPlayer] = []


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if silencio:
		set_process(false)
		return
	for nombre in ["fondo", "tension", "alarma", "sed"]:
		var p := AudioStreamPlayer.new()
		p.stream = _capa(nombre)
		p.volume_db = VOLUMEN_MIN
		p.autoplay = false
		add_child(p)
		capas[nombre] = p
		_objetivo[nombre] = 0.0
		if not silencio:
			p.play()
	for i in 6:
		var e := AudioStreamPlayer.new()
		add_child(e)
		_efectos.append(e)


func _process(delta: float) -> void:
	if mapa == null or mapa.mika == null:
		return
	var mika := mapa.mika
	var sospecha := false
	for s in mapa.soldados():
		if s.estado == Soldado.Estado.SOSPECHA:
			sospecha = true
	for v in mapa.vampiros():
		if v.estado == Vampiro.Estado.TESTIGO:
			sospecha = true
	var alarma := mapa.alerta != null and mapa.alerta.activa
	_objetivo.fondo = 0.0 if mika.sin_control() else 0.55
	_objetivo.tension = 0.5 if sospecha and not alarma else 0.0
	_objetivo.alarma = 0.6 if alarma else 0.0
	_objetivo.sed = 1.0 if mika.sin_control() else clampf((mika.sed - 40.0) / 60.0, 0.0, 0.7)
	for nombre in capas:
		var p: AudioStreamPlayer = capas[nombre]
		var actual := db_to_linear(p.volume_db)
		var nuevo := move_toward(actual, _objetivo[nombre], delta * SUAVIDAD * 0.5)
		p.volume_db = linear_to_db(maxf(nuevo, 0.001)) if nuevo > 0.001 else VOLUMEN_MIN


## Suena un efecto: "tajo", "silencioso", "impulso", "golpe", "alarma", "sospecha", "beber",
## "vial", "talisman".
func efecto(nombre: String) -> void:
	if silencio:
		return
	for e in _efectos:
		if not e.playing:
			e.stream = _efecto(nombre)
			e.play()
			return


# --- Síntesis ---

func _efecto(nombre: String) -> AudioStreamWAV:
	if _efectos_hechos.has(nombre):
		return _efectos_hechos[nombre]
	var muestras := PackedFloat32Array()
	match nombre:
		"tajo": muestras = _ruido(0.18, 3.0, 0.6) # un silbido que se apaga
		"silencioso": muestras = _tono(70.0, 0.15, 8.0, 0.7)
		"impulso": muestras = _ruido(0.25, 6.0, 0.35)
		"golpe": muestras = _mezcla(_tono(110.0, 0.2, 10.0, 0.6), _ruido(0.12, 12.0, 0.4))
		"alarma": muestras = _mezcla(_tono(660.0, 0.5, 1.5, 0.35), _tono(880.0, 0.5, 1.5, 0.25))
		"sospecha": muestras = _tono(520.0, 0.12, 6.0, 0.3)
		"beber": muestras = _tono(55.0, 0.3, 5.0, 0.8)
		"vial": muestras = _mezcla(_tono(1320.0, 0.5, 4.0, 0.25), _tono(1980.0, 0.4, 5.0, 0.15))
		"talisman": muestras = _mezcla(_tono(990.0, 0.8, 2.0, 0.3), _tono(1485.0, 0.8, 2.5, 0.2))
		_: muestras = _tono(440.0, 0.1, 10.0, 0.2)
	var flujo := _wav(muestras, false)
	_efectos_hechos[nombre] = flujo
	return flujo


func _capa(nombre: String) -> AudioStreamWAV:
	if _capas_hechas.has(nombre):
		return _capas_hechas[nombre]
	var segundos := 4.0
	var n := int(FRECUENCIA * segundos)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / FRECUENCIA
		var v := 0.0
		match nombre:
			"fondo": # acorde frío y grave (la, mi, la menor), que respira despacio
				v = (sin(TAU * 55.0 * t) + 0.6 * sin(TAU * 82.4 * t) + 0.4 * sin(TAU * 110.0 * t)) * (0.6 + 0.4 * sin(TAU * 0.25 * t)) * 0.2
			"tension": # pulso lento
				v = sin(TAU * 146.8 * t) * pow(maxf(0.0, sin(TAU * 1.0 * t)), 6.0) * 0.3
			"alarma": # pulso rápido y agudo
				v = sin(TAU * 293.7 * t) * pow(maxf(0.0, sin(TAU * 3.0 * t)), 4.0) * 0.25
			"sed": # latido: dos golpes graves por segundo y pico
				var fase := fmod(t * 1.25, 1.0)
				var golpe := exp(-fase * 18.0) + 0.6 * exp(-maxf(0.0, fase - 0.18) * 18.0) * float(fase > 0.18)
				v = sin(TAU * 48.0 * t) * golpe * 0.5
		m[i] = v
	_capas_hechas[nombre] = _wav(m, true)
	return _capas_hechas[nombre]


func _tono(hz: float, segundos: float, caida: float, volumen: float) -> PackedFloat32Array:
	var n := int(FRECUENCIA * segundos)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / FRECUENCIA
		m[i] = sin(TAU * hz * t) * exp(-t * caida) * volumen
	return m


func _ruido(segundos: float, caida: float, volumen: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(FRECUENCIA * segundos)
	var m := PackedFloat32Array()
	m.resize(n)
	var anterior := 0.0
	for i in n:
		var t := float(i) / FRECUENCIA
		anterior = lerpf(anterior, rng.randf_range(-1.0, 1.0), 0.35) # algo suavizado
		m[i] = anterior * exp(-t * caida) * volumen
	return m


func _mezcla(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var m := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var otra := b if a.size() >= b.size() else a
	for i in otra.size():
		m[i] = clampf(m[i] + otra[i], -1.0, 1.0)
	return m


func _wav(muestras: PackedFloat32Array, en_bucle: bool) -> AudioStreamWAV:
	var datos := PackedByteArray()
	datos.resize(muestras.size() * 2)
	for i in muestras.size():
		datos.encode_s16(i * 2, int(clampf(muestras[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = FRECUENCIA
	w.stereo = false
	w.data = datos
	if en_bucle:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = muestras.size()
	return w
