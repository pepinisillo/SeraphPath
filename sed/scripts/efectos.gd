class_name Efectos
extends Node
## Sensación tipo Hades: paradas breves al golpear, sacudidas de cámara, partículas,
## rastro del dash y la pantalla que pierde color con la sed.
## Solo toca el dibujo y el ritmo del tiempo: la lógica del juego no depende de nada de esto.

## Las pruebas automáticas avanzan el tiempo a mano y desactivan las paradas.
var permitir_paradas := true
var trauma := 0.0 # 0 a 1; la sacudida crece con su cuadrado
var frenesi := 0.0 # 0 a 1; cuánto del filtro «solo rojo» se aplica

var mapa: Mapa
var filtro: ColorRect
var _fin_parada := 0 # ms (reloj real) en que termina la parada más larga en curso
var _rng := RandomNumberGenerator.new()


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	var capa := CanvasLayer.new()
	capa.layer = 1 # por encima del mundo, por debajo del HUD
	add_child(capa)
	filtro = ColorRect.new()
	filtro.set_anchors_preset(Control.PRESET_FULL_RECT)
	filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://recursos/sed.gdshader")
	filtro.material = material
	capa.add_child(filtro)


func _process(delta: float) -> void:
	if mapa == null or mapa.mika == null:
		return
	trauma = maxf(0.0, trauma - Config.SACUDIDA_CALMA * delta)
	var camara: Camera2D = mapa.mika.get_node("Camara")
	var fuerza := Config.SACUDIDA_MAXIMA * trauma * trauma
	camara.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * fuerza
	var mat := filtro.material as ShaderMaterial
	mat.set_shader_parameter("desaturacion", desaturacion(mapa.mika.sed))
	frenesi = move_toward(frenesi, 1.0 if mapa.mika.sin_control() else 0.0, delta * 4.0)
	mat.set_shader_parameter("frenesi", frenesi)


## Cuánto color pierde la pantalla con esta sed: nada hasta SED_COLOR_INICIO,
## y SED_COLOR_PERDIDO justo antes del Frenesí.
static func desaturacion(sed: int) -> float:
	var tramo := float(Config.SED_TRAMO_FRENESI - Config.SED_COLOR_INICIO)
	return clampf((sed - Config.SED_COLOR_INICIO) / tramo, 0.0, 1.0) * Config.SED_COLOR_PERDIDO


# --- Peso de los golpes ---

## Congela el juego unos cuadros. Si ya hay una parada en curso, gana la más larga.
func parada(duracion: float) -> void:
	if not permitir_paradas or duracion <= 0.0:
		return
	var fin := Time.get_ticks_msec() + roundi(duracion * 1000.0)
	_fin_parada = maxi(_fin_parada, fin)
	Engine.time_scale = 0.0001
	get_tree().create_timer(duracion, true, false, true).timeout.connect(_quizas_reanudar.bind(fin))


## Cada temporizador conoce su propio fin: solo el de la parada más larga reanuda el juego.
func _quizas_reanudar(fin: int) -> void:
	if fin >= _fin_parada:
		Engine.time_scale = 1.0


func sacudir(cantidad: float) -> void:
	trauma = minf(1.0, trauma + cantidad)


func _exit_tree() -> void:
	Engine.time_scale = 1.0 # nunca dejar el juego congelado al cambiar de escena


# --- Partículas ---

## Estallido de partículas en una posición del mapa (casillas), a cierta altura sobre el suelo.
func salpicar(pos: Vector2, color: Color, cantidad: int, altura := 60.0, fuerza := 160.0) -> void:
	var p := CPUParticles2D.new()
	p.position = Iso.a_pantalla(pos) + Vector2(0, -altura)
	p.z_as_relative = false
	p.z_index = 40
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = cantidad
	p.lifetime = 0.45
	p.spread = 180.0
	p.initial_velocity_min = fuerza * 0.4
	p.initial_velocity_max = fuerza
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	p.color = color
	p.finished.connect(p.queue_free)
	mapa.add_child(p)
	p.emitting = true


## Silueta de Mika que se desvanece: el rastro del dash.
func silueta(pos: Vector2) -> void:
	var s := Silueta.new()
	s.position = Iso.a_pantalla(pos)
	mapa.add_child(s)


# --- Momentos ---

func tajo_conectado(pos_victima: Vector2) -> void:
	parada(Config.PARADA_TAJO)
	sacudir(Config.SACUDIDA_TAJO)
	salpicar(pos_victima, Paleta.ROJO, 18)


func derribo_silencioso(pos_victima: Vector2) -> void:
	parada(Config.PARADA_SILENCIOSO)
	salpicar(pos_victima, Paleta.ROJO.darkened(0.3), 6, 50.0, 80.0)


func golpe_recibido(pos_mika: Vector2) -> void:
	parada(Config.PARADA_RECIBIDO)
	sacudir(Config.SACUDIDA_RECIBIDO)
	salpicar(pos_mika, Paleta.ROJO, 12)


func caida() -> void:
	sacudir(Config.SACUDIDA_CAIDA)


func trago(pos_mika: Vector2, color: Color) -> void:
	salpicar(pos_mika, color, 24, 70.0, 120.0)
