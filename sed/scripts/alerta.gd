class_name Alerta
extends Node
## Alarma compartida por todo el mapa. Mientras está activa, todos los soldados persiguen
## la última posición donde alguien vio a Mika, y cada cierto tiempo llega un refuerzo.

var activa := false
var ultima_posicion := Vector2.ZERO # casillas
var refuerzos := 0 # llamados en este mapa

var _sin_ver := 0.0
var _hasta_refuerzo := 0.0


func dar_alarma(posicion: Vector2) -> void:
	if not activa:
		activa = true
		_hasta_refuerzo = Config.ALARMA_REFUERZO_INTERVALO
	vista(posicion)


## Algún soldado ve a Mika: actualiza la última posición y reinicia el olvido.
func vista(posicion: Vector2) -> void:
	ultima_posicion = posicion
	_sin_ver = 0.0


func _physics_process(delta: float) -> void:
	if not activa:
		return
	_sin_ver += delta
	if _sin_ver >= Config.ALARMA_OLVIDO:
		activa = false # cada soldado baja a Sospecha por su cuenta
		return
	_hasta_refuerzo -= delta
	if _hasta_refuerzo <= 0.0:
		_hasta_refuerzo += Config.ALARMA_REFUERZO_INTERVALO
		if refuerzos < Config.ALARMA_REFUERZOS_MAX:
			refuerzos += 1
			get_parent().crear_refuerzo(refuerzos)
