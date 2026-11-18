class_name Portador
extends Soldado
## Portador de arma maldita: un soldado de élite. Ve más lejos (cono largo), tiene más vida,
## pega más fuerte y, en Alarma, desde lejos (la espada maldita alcanza a distancia).
## El Golpe silencioso no lo derriba: solo lo aturde unos segundos, y al despertar sospecha.

const COLOR_ARMA := Color(0.05, 0.05, 0.07)

var aturdido := 0.0 # s que le quedan aturdido


func _ready() -> void:
	super()
	vida = Config.PORTADOR_VIDA
	alcance_vision = Config.PORTADOR_VISION
	dano = Config.PORTADOR_DANO
	distancia_golpe = Config.PORTADOR_DISTANCIA_GOLPE


func recibir_golpe_silencioso() -> void:
	aturdido = Config.PORTADOR_ATURDIDO
	medidor = 0.0
	estado = Estado.OCULTO
	cono.visible = false


func admite_golpe_silencioso() -> bool:
	return aturdido <= 0.0 and super()


func _physics_process(delta: float) -> void:
	if aturdido > 0.0 and not derribado:
		aturdido -= delta
		queue_redraw()
		if aturdido <= 0.0:
			cono.visible = true
			oir(pos) # al despertar, sospecha: mira alrededor de donde estaba
		return
	super(delta)


func _draw() -> void:
	super()
	if derribado:
		return
	# La espada maldita, negra, a la espalda.
	draw_line(Vector2(-ANCHO_CAPSULA * 0.6, -ALTO_CAPSULA * 0.9), Vector2(ANCHO_CAPSULA * 0.5, -ALTO_CAPSULA * 0.15), COLOR_ARMA, 7.0)
	if aturdido > 0.0:
		var fuente := ThemeDB.fallback_font
		draw_string(fuente, Vector2(-30, -ALTO_CAPSULA - 30), "aturdido", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Paleta.DETALLES)


func nombre_arte() -> String:
	return "portador"


func estado_animacion(se_mueve: bool) -> String:
	if aturdido > 0.0 and not derribado:
		return "aturdido"
	return super(se_mueve)
