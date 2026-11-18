class_name Animador
extends AnimatedSprite2D
## Conecta un personaje con su arte en 8 direcciones, cuando exista.
##
## Busca `res://arte/personajes/<personaje>.tres` (un SpriteFrames). Si no está, no hace nada y
## el personaje sigue dibujándose con su forma provisional (la cápsula). Si está, el personaje
## deja de dibujar la cápsula y aquí se reproduce la animación de su estado y su dirección:
##
##   <estado>_<dirección>   por ejemplo «correr_se», «tajo_n», «derribado_o»
##
## Direcciones de pantalla (las 8 de Formas.direccion_8): e, se, s, so, o, no, n, ne.
## Si falta la de esa dirección, prueba «<estado>» a secas, «quieto_<dirección>», «quieto» y, por
## último, el mismo estado en otra dirección o cualquier «quieto_…».
## El origen del sprite está en los pies del personaje (el punto que se ordena con Y-sort).

const CARPETA := "res://arte/personajes"
const DIRECCIONES := ["e", "se", "s", "so", "o", "no", "n", "ne"]

## Las pruebas la cambian para usar un arte de muestra.
static var carpeta := CARPETA

var activo := false
var personaje := ""
var estado := ""
var _antes := Vector2.INF


## Crea el animador de `dueno` y lo prepara para `p_personaje`.
static func crear(dueno: Node2D, p_personaje: String) -> Animador:
	var a := Animador.new()
	a.name = "Animador"
	dueno.add_child(a)
	a.preparar(p_personaje)
	return a


## ¿El dueño se movió desde la última vez? (para elegir entre «quieto» y «andar»/«correr»)
func se_mueve() -> bool:
	var ahora := (get_parent() as Node2D).position
	var movio := _antes != Vector2.INF and ahora.distance_to(_antes) > 0.5
	_antes = ahora
	return movio


## Prepara el animador para `p_personaje` («mika», «soldado», «vampiro»…). Devuelve si hay arte.
func preparar(p_personaje: String) -> bool:
	personaje = p_personaje
	var ruta := "%s/%s.tres" % [carpeta, personaje]
	if not ResourceLoader.exists(ruta):
		activo = false
		visible = false
		return false
	sprite_frames = load(ruta)
	centered = true
	activo = sprite_frames != null
	visible = activo
	return activo


## Pone la animación del estado y la dirección (0 = derecha, en sentido horario).
func poner(p_estado: String, direccion: int) -> void:
	if not activo:
		return
	estado = p_estado
	var nombre := nombre_animacion(p_estado, direccion)
	if nombre != "" and animation != nombre:
		play(nombre)


## La animación que se usará para ese estado y dirección ("" si no hay ninguna que sirva).
func nombre_animacion(p_estado: String, direccion: int) -> String:
	if sprite_frames == null:
		return ""
	var dir: String = DIRECCIONES[posmod(direccion, 8)]
	for candidato in ["%s_%s" % [p_estado, dir], p_estado, "quieto_%s" % dir, "quieto"]:
		if sprite_frames.has_animation(candidato):
			return candidato
	# Lo más parecido que haya: el mismo estado en otra dirección y, si no, cualquier «quieto».
	for prefijo in [p_estado + "_", "quieto_"]:
		for nombre in sprite_frames.get_animation_names():
			if nombre.begins_with(prefijo):
				return nombre
	return ""
