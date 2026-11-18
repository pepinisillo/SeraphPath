class_name Ferid
extends Node2D
## Ferid Bathory, jefe de la zona 1. No se le vence: persigue a Mika por el hangar y Mika tiene
## que llegar a la rampa del avión. Cada cierto tiempo embiste: primero marca en el suelo la
## línea por donde va a pasar (aviso) y luego la recorre muy deprisa. En la segunda fase (a
## partir del punto de control `fase2_desde` del mapa) embiste dos veces seguidas.
## Si atrapa a Mika, le quita vida y lo devuelve al último punto de control.
## Su posición vive en casillas; los ataques de Mika no le hacen nada.

enum Estado { PERSIGUE, AVISA, EMBISTE, RECUPERA, ESPERA }

const COLOR_CUERPO := Paleta.VAMPIROS
const COLOR_CONTORNO := Paleta.BLANCO_HUESO
const COLOR_AVISO := Paleta.ROJO
const ALTO_CAPSULA := 112.0
const ANCHO_CAPSULA := 42.0

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var inicio := Vector2.ZERO
var mirada := Vector2(1, 0)
var estado := Estado.ESPERA
var fase := 1
var atrapadas := 0
var frase := "" # lo que dice ahora (bocadillo)
var frases := {} # del guion: persigue, atrapa, otro_yuu

var _tiempo := 0.0 # s en el estado actual
var _enfriamiento := 0.0
var _embestidas_pendientes := 0 # en la segunda fase, la segunda embestida
var _desde := Vector2.ZERO # embestida: de dónde sale
var _hasta := Vector2.ZERO # y adónde llega
var _frase_restante := 0.0
var _hasta_frase := 0.0
var _hasta_otro_yuu := 0.0
var _numero_frase := 0
var _segunda := false # la embestida en curso es la segunda de la pareja (aviso más corto)
var _mika_antes := Vector2.ZERO
var velocidad_mika := Vector2.ZERO # casillas/s, medida por Ferid fotograma a fotograma


var animador: Animador # el arte en 8 direcciones, cuando exista (ver animador.gd)


func iniciar(p_mapa: Mapa, celda: Vector2i) -> void:
	mapa = p_mapa
	if animador == null:
		animador = Animador.crear(self, "ferid")
	pos = Vector2(celda) + Vector2(0.5, 0.5)
	inicio = pos
	frases = Guion.jefe_durante("Ferid Bathory")
	_tiempo = Config.FERID_ESPERA - Config.FERID_ESPERA_INICIAL
	estado = Estado.ESPERA
	_hasta_frase = 1.0
	_hasta_otro_yuu = Config.FERID_FRASE_OTRO_YUU
	position = Iso.a_pantalla(pos)


func _physics_process(delta: float) -> void:
	if mapa == null or mapa.mika == null or mapa.terminado:
		return
	var mika := mapa.mika
	if delta > 0.0 and _mika_antes != Vector2.ZERO:
		var v := (mika.pos - _mika_antes) / delta
		velocidad_mika = velocidad_mika.lerp(v, 0.3) if v.length() < 20.0 else Vector2.ZERO # un salto (punto de control) no cuenta
	_mika_antes = mika.pos
	_tiempo += delta
	_enfriamiento -= delta
	fase = 2 if mapa.punto_de_control >= mapa.fase2_desde else 1
	match estado:
		Estado.ESPERA:
			if _tiempo >= Config.FERID_ESPERA:
				_cambiar(Estado.PERSIGUE)
		Estado.RECUPERA:
			if _tiempo >= Config.FERID_RECUPERACION:
				_cambiar(Estado.PERSIGUE)
		Estado.PERSIGUE:
			_perseguir(delta)
			if _puede_embestir():
				_avisar()
		Estado.AVISA:
			if _tiempo >= (Config.FERID_FASE2_PAUSA if _segunda else Config.FERID_EMBESTIDA_AVISO):
				_cambiar(Estado.EMBISTE)
		Estado.EMBISTE:
			var f := clampf(_tiempo / Config.FERID_EMBESTIDA_DURACION, 0.0, 1.0)
			pos = _desde.lerp(_hasta, f)
			if f >= 1.0:
				if _embestidas_pendientes > 0:
					_embestidas_pendientes -= 1
					_avisar(true)
				else:
					_enfriamiento = Config.FERID_EMBESTIDA_ENFRIAMIENTO
					_cambiar(Estado.RECUPERA)
	if estado != Estado.ESPERA and estado != Estado.RECUPERA and not mika.caida and pos.distance_to(mika.pos) <= Config.FERID_ATRAPA:
		atrapar()
	_hablar(delta)
	position = Iso.a_pantalla(pos)
	queue_redraw()


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_tiempo = 0.0


func _perseguir(delta: float) -> void:
	var mika := mapa.mika
	var camino := mapa.camino(pos, mika.pos)
	if camino.is_empty():
		return
	var hacia := camino[0] - pos
	var avance := Config.FERID_VELOCIDAD * delta
	if hacia.length() <= avance:
		pos = camino[0]
	else:
		pos += hacia.normalized() * avance
	if hacia.length() > 0.001:
		mirada = hacia.normalized()


## Cerca, viéndolo, y con el camino libre hasta donde va a estar Mika (no embiste contra una caja).
func _puede_embestir() -> bool:
	var mika := mapa.mika
	if _enfriamiento > 0.0 or mika.caida or pos.distance_to(mika.pos) > Config.FERID_EMBESTIDA_ALCANCE:
		return false
	if not mapa.hay_linea_de_vision(pos, mika.pos):
		return false
	return mapa.hay_linea_de_vision(pos, _previsto(Config.FERID_EMBESTIDA_AVISO))


## Dónde va a estar Mika dentro de `aviso` s (más media embestida), si sigue moviéndose igual.
func _previsto(aviso: float) -> Vector2:
	return mapa.mika.pos + velocidad_mika * (aviso + Config.FERID_EMBESTIDA_DURACION * 0.5)


## Fija la línea de la embestida hacia donde va a estar Mika al acabar el aviso, si sigue
## moviéndose igual. Después no la corrige: correr recto no salva; apartarse de la línea, sí.
## `segunda`: la que va justo después de otra, en la segunda fase (aviso más corto).
func _avisar(segunda := false) -> void:
	var aviso := Config.FERID_FASE2_PAUSA if segunda else Config.FERID_EMBESTIDA_AVISO
	var hacia := _previsto(aviso) - pos
	if hacia.length() < 0.001:
		hacia = mirada
	mirada = hacia.normalized()
	_desde = pos
	var deseado := minf(hacia.length() + Config.FERID_EMBESTIDA_DE_MAS, Config.FERID_EMBESTIDA_DISTANCIA)
	var largo := mapa.distancia_hasta_muro(pos, mirada, deseado)
	_hasta = pos + mirada * maxf(0.0, (largo - 0.35) if largo < deseado else largo)
	_segunda = segunda
	if not segunda:
		_embestidas_pendientes = 1 if fase == 2 else 0
	_cambiar(Estado.AVISA)


## Atrapa a Mika: le quita vida, lo devuelve al último punto de control y espera un momento.
func atrapar() -> void:
	var mika := mapa.mika
	atrapadas += 1
	mika.recibir_golpe(Config.FERID_DANO)
	_decir_de("atrapa", 0)
	if mika.caida:
		_cambiar(Estado.ESPERA)
		return
	mapa.volver_al_punto_de_control()
	pos = mapa.casilla_libre_cerca(mapa.mika.pos - Vector2(Config.FERID_REINICIO, 0))
	_embestidas_pendientes = 0
	_enfriamiento = Config.FERID_EMBESTIDA_ENFRIAMIENTO
	_cambiar(Estado.ESPERA)


## La línea de la embestida marcada en el suelo: dónde no hay que estar.
func linea_de_embestida() -> Array:
	return [_desde, _hasta] if estado == Estado.AVISA else []


func _hablar(delta: float) -> void:
	_frase_restante -= delta
	if _frase_restante <= 0.0:
		frase = ""
	_hasta_frase -= delta
	if _hasta_frase <= 0.0 and estado == Estado.PERSIGUE:
		_hasta_frase = Config.FERID_FRASE
		_decir_de("persigue", _numero_frase)
		_numero_frase += 1
	_hasta_otro_yuu -= delta
	if _hasta_otro_yuu <= 0.0:
		_hasta_otro_yuu = Config.FERID_FRASE_OTRO_YUU
		var del_otro: PackedStringArray = frases.get("otro_yuu", PackedStringArray())
		var hud := mapa.get_node_or_null("HUD")
		if mapa.mika.humanidad >= 1 and not del_otro.is_empty() and hud:
			hud.decir(del_otro[randi() % del_otro.size()])


func _decir_de(clave: String, numero: int) -> void:
	var lista: PackedStringArray = frases.get(clave, PackedStringArray())
	if lista.is_empty():
		return
	frase = lista[numero % lista.size()]
	_frase_restante = Config.FERID_FRASE - 0.5


func _draw() -> void:
	if animador:
		animador.poner(estado_animacion(animador.se_mueve()), Formas.direccion_8(mirada))
	# La línea de la embestida, en el suelo (coordenadas del mapa, relativas a Ferid).
	var linea := linea_de_embestida()
	if not linea.is_empty():
		var a := Iso.a_pantalla(linea[0]) - position
		var b := Iso.a_pantalla(linea[1]) - position
		var f := clampf(_tiempo / (Config.FERID_FASE2_PAUSA if _segunda else Config.FERID_EMBESTIDA_AVISO), 0.0, 1.0)
		draw_line(a, b, Color(COLOR_AVISO, 0.3 + 0.5 * f), 10.0 + 8.0 * f)
		draw_circle(b, 14.0 + 10.0 * f, Color(COLOR_AVISO, 0.4 + 0.4 * f))
	if not (animador and animador.activo):
		Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)
	if frase != "":
		var fuente := ThemeDB.fallback_font
		var ancho := fuente.get_string_size(frase, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
		draw_rect(Rect2(-ancho / 2.0, -ALTO_CAPSULA - 58, ancho, 26), Color(0.04, 0.05, 0.08, 0.85))
		draw_string(fuente, Vector2(-ancho / 2.0, -ALTO_CAPSULA - 40), frase, HORIZONTAL_ALIGNMENT_CENTER, ancho, 16, Paleta.BLANCO_HUESO)


## Estado para el arte: quieto (espera), correr, avisar o embestir.
func estado_animacion(_se_mueve: bool) -> String:
	match estado:
		Estado.PERSIGUE:
			return "correr"
		Estado.AVISA:
			return "avisar"
		Estado.EMBISTE:
			return "embestir"
	return "quieto"
