class_name Hechicero
extends Soldado
## Hechicero de talismanes: un soldado más débil (pega menos) que ha dejado talismanes en el
## suelo. Si Mika pisa uno, el talismán lo revela: alarma en ese punto. Derribar al hechicero
## apaga todos sus talismanes.

const COLOR_PAPEL := Paleta.BLANCO_HUESO

## Casillas donde están sus talismanes.
@export var talismanes: Array[Vector2i] = []

var _nodos: Array[Talisman] = []


func _ready() -> void:
	super()
	dano = Config.HECHICERO_DANO


func iniciar(p_mapa: Mapa) -> void:
	super(p_mapa)
	for celda in talismanes:
		var t := Talisman.new()
		t.name = "Talisman_%s_%d_%d" % [name, celda.x, celda.y]
		mapa.add_child.call_deferred(t)
		t.iniciar(mapa, self, celda)
		_nodos.append(t)


## Talismanes que aún pueden revelar a Mika.
func talismanes_activos() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	if derribado:
		return lista
	for t in _nodos:
		if is_instance_valid(t) and t.activo:
			lista.append(t.celda)
	return lista


func _draw() -> void:
	super()
	if derribado:
		return
	# Un fajo de talismanes en la mano.
	draw_rect(Rect2(ANCHO_CAPSULA * 0.35, -ALTO_CAPSULA * 0.55, 10, 16), COLOR_PAPEL)


func nombre_arte() -> String:
	return "hechicero"
