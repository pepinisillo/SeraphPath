class_name EstadoExpedicion
extends Node
## Expedición en curso (autoload «Expedicion»). Encadena las paradas de la zona y guarda lo que
## Mika arrastra de una a otra: vida, sed, Humanidad, viales y mejoras. Los recuerdos son
## permanentes: se guardan en disco y pasan a las siguientes partidas.
##
## Si no hay expedición activa (por ejemplo, al abrir un mapa suelto con F6), los mapas
## funcionan solos, como en los pasos anteriores.
##
## Los demás scripts la piden con EstadoExpedicion.actual() en vez de usar el nombre global
## del autoload: así compilan aunque se carguen antes de que exista (como en las pruebas).

const ESCENA_TITULO := "res://escenas/titulo.tscn"
const ESCENA_RUTA := "res://escenas/ruta.tscn"
const ESCENA_EVENTO := "res://escenas/evento.tscn"
const ESCENA_REFUGIO := "res://escenas/refugio.tscn"
const ESCENA_RECUERDO := "res://escenas/recuerdo.tscn"
const ESCENA_INICIO := "res://escenas/inicio.tscn"
const ESCENA_ESCENA := "res://escenas/escena.tscn"
const ESCENA_FINAL := "res://escenas/final.tscn"
const ESCENA_INFILTRACION := "res://escenas/mapa_puesto_control.tscn"
const ESCENA_TUNELES := "res://escenas/mapa_tuneles.tscn"
const ESCENA_PRUEBA := "res://escenas/mapa_prueba_sed.tscn"

## Zona 1: infiltración, dos rutas de dos paradas, Prueba de la sed y jefe.
const RUTAS := {
	"segura": ["refugio", "evento"],
	"arriesgada": ["emboscada", "infiltracion"],
}
const NOMBRES := {
	"infiltracion": "Infiltración", "emboscada": "Emboscada", "evento": "Evento",
	"refugio": "Refugio", "prueba": "Prueba de la sed", "jefe": "Jefe: Ferid Bathory",
}
const TOTAL_RECUERDOS := 7
const RECUERDO_CONFESION := 7 # solo se gana con Humanidad 1 o más (Mika necesita a quién decírselo)

## Archivo de los recuerdos ganados (y de si ya se vio el inicio). Las pruebas automáticas lo cambian para no tocar el real.
var archivo_recuerdos := "user://recuerdos.cfg"

var activa := false
var zona := 1
var ruta := "" # "", "segura" o "arriesgada"
var indice := 0 # parada actual dentro de paradas()

# Lo que Mika arrastra entre paradas.
var vida := Config.VIDA_MIKA
var vida_max := Config.VIDA_MIKA
var sed := Config.SED_INICIAL
var humanidad := Config.HUMANIDAD_INICIAL
var viales := 0
var mejoras: Array[String] = []
var salvacion_usada := false # recuerdo 4: una vez por expedición

# Lo que cambia el siguiente mapa (se consume al entrar en él).
var siguiente_empieza := "" # "", "sospecha" o "alarma"
var sed_congelada := false
# Lo que dura toda la zona.
var patrullas_visibles := false

var eventos_vistos: Array[String] = []
var evento_actual := ""
var recuerdo_nuevo := 0 # recuerdo ganado en la última parada (0 si ninguno)
var recuerdos: Array[int] = []
var inicio_visto := false
var fondos_vistos: Array[int] = [] # zonas cuya escena del fondo de la Prueba de la sed ya se vio entera
## Escena del guion en curso (ver mostrar_escena) y la que toca al salir de la parada actual.
var escena_titulo := ""
var escena_golpes: Array[Dictionary] = []
var escena_tras_parada: Array[Dictionary] = []
var _tras_escena: Callable
var rng := RandomNumberGenerator.new()


## La expedición en curso (el autoload), o null si no existe (por ejemplo, en el editor).
static func actual() -> EstadoExpedicion:
	var arbol := Engine.get_main_loop() as SceneTree
	return arbol.root.get_node_or_null("Expedicion") if arbol else null


## Hay una expedición activa: los mapas reciben su estado y la pantalla de resultado la continúa.
static func en_curso() -> bool:
	var e := actual()
	return e != null and e.activa


func _ready() -> void:
	cargar_recuerdos()


# --- Inicio y paradas ---

func nueva() -> void:
	activa = true
	zona = 1
	ruta = ""
	indice = 0
	vida = Config.VIDA_MIKA
	vida_max = Config.VIDA_MIKA
	sed = Config.SED_INICIAL
	humanidad = Config.HUMANIDAD_INICIAL
	viales = Config.VIALES_INICIALES + (Config.VIALES_RECUERDO_1 if tiene_recuerdo(1) else 0)
	mejoras = []
	salvacion_usada = false
	siguiente_empieza = ""
	sed_congelada = false
	patrullas_visibles = false
	eventos_vistos = []
	evento_actual = ""
	recuerdo_nuevo = 0
	escena_tras_parada = []
	rng.randomize()


## Paradas de la zona en orden. Antes de elegir ruta, las dos del medio son "?".
func paradas() -> Array:
	var medio: Array = RUTAS[ruta] if ruta != "" else ["?", "?"]
	return ["infiltracion"] + medio + ["prueba", "jefe"]


func parada_actual() -> String:
	return paradas()[indice]


## Hay que elegir ruta antes de seguir.
func toca_elegir_ruta() -> bool:
	return indice == 1 and ruta == ""


## Empieza una expedición nueva. Antes, la escena del inicio: la completa la primera vez y la
## línea corta de la caja de Krul las siguientes (si hay guion).
func empezar() -> void:
	nueva()
	if not escena_de_inicio().is_empty():
		_cambiar(ESCENA_INICIO)
	else:
		ir_a_ruta()


func escena_de_inicio() -> Array[Dictionary]:
	return Guion.cada_expedicion(viales) if inicio_visto else Guion.inicio()


func marcar_inicio_visto() -> void:
	inicio_visto = true
	guardar_recuerdos()


func elegir_ruta(p_ruta: String) -> void:
	ruta = p_ruta


func ir_a_ruta() -> void:
	_cambiar(ESCENA_RUTA)


## Entra en la parada actual.
func entrar() -> void:
	match parada_actual():
		"infiltracion":
			_cambiar(escena_infiltracion())
		"emboscada":
			siguiente_empieza = "alarma" # una emboscada empieza en Alarma
			_cambiar(ESCENA_INFILTRACION)
		"evento":
			evento_actual = elegir_evento()
			_cambiar(ESCENA_EVENTO)
		"refugio":
			_cambiar(ESCENA_REFUGIO)
		"prueba":
			if humanidad <= 0:
				# «Sin voz»: con Humanidad 0 el otro Yuu ya no existe y no hay prueba ni recuerdo.
				recuerdo_nuevo = 0
				mostrar_escena("Sin voz", Guion.prueba_sin_voz(), completar_parada)
			else:
				mostrar_escena("Prueba de la sed", Guion.prueba_entrada(zona), _cambiar.bind(ESCENA_PRUEBA))
		"jefe":
			_cambiar(ESCENA_FINAL)


## La primera infiltración de la zona es el puesto de control; la de la ruta arriesgada, los túneles.
func escena_infiltracion() -> String:
	return ESCENA_INFILTRACION if indice == 0 else ESCENA_TUNELES


## Pasa a la siguiente parada y vuelve al mapa de paradas (o enseña antes el recuerdo ganado).
func completar_parada() -> void:
	indice += 1
	var golpes := escena_tras_parada
	escena_tras_parada = []
	mostrar_escena("", golpes, _tras_parada)


func _tras_parada() -> void:
	if recuerdo_nuevo > 0:
		_cambiar(ESCENA_RECUERDO)
	else:
		ir_a_ruta()


## Enseña una escena del guion y después llama a `despues`. Sin texto (no hay guion), sigue directo.
func mostrar_escena(titulo: String, golpes: Array[Dictionary], despues: Callable) -> void:
	if golpes.is_empty():
		despues.call()
		return
	escena_titulo = titulo
	escena_golpes = golpes
	_tras_escena = despues
	_cambiar(ESCENA_ESCENA)


func terminar_escena() -> void:
	var despues := _tras_escena
	_tras_escena = Callable()
	despues.call()


## Mika cayó: la expedición termina. Los recuerdos ganados se conservan.
func caer() -> void:
	activa = false
	_cambiar(ESCENA_FINAL)


func volver_al_titulo() -> void:
	activa = false
	_cambiar(ESCENA_TITULO)


func _cambiar(escena: String) -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", escena)


# --- Eventos ---

## Uno al azar entre los de la zona que aún no han salido en esta expedición.
func elegir_evento() -> String:
	var posibles := Eventos.de_zona(zona).filter(func(e): return not e.id in eventos_vistos)
	if posibles.is_empty():
		posibles = Eventos.de_zona(zona)
	var evento: Dictionary = posibles[rng.randi_range(0, posibles.size() - 1)]
	eventos_vistos.append(evento.id)
	return evento.id


## Aplica los efectos de una opción. Devuelve las mejoras que hay que ofrecer (vacío si ninguna).
func aplicar_efectos(efectos: Dictionary) -> Array[String]:
	viales += efectos.get("viales", 0)
	if efectos.has("sed_a"):
		sed = efectos.sed_a
	sed = clampi(sed + efectos.get("sed", 0), 0, Config.SED_MAX)
	vida_max = maxi(1, vida_max + efectos.get("vida_max", 0))
	vida = clampi(vida + efectos.get("vida", 0), 1, vida_max)
	humanidad = clampi(humanidad + efectos.get("humanidad", 0), 0, Config.HUMANIDAD_INICIAL)
	if efectos.get("siguiente_empieza", "") != "":
		siguiente_empieza = efectos.siguiente_empieza
	if efectos.get("sed_congelada", false):
		sed_congelada = true
	if efectos.get("patrullas_visibles", false):
		patrullas_visibles = true
	if efectos.get("mejora", false):
		return opciones_de_mejora()
	return []


func opciones_de_mejora() -> Array[String]:
	var disponibles: Array[String] = []
	for id in Mejoras.TODAS:
		if not id in mejoras:
			disponibles.append(id)
	for i in range(disponibles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := disponibles[i]
		disponibles[i] = disponibles[j]
		disponibles[j] = tmp
	return disponibles.slice(0, 2)


func elegir_mejora(id: String) -> void:
	if id in mejoras:
		return
	mejoras.append(id)
	if id == Mejoras.VIGOR:
		vida_max += Config.MEJORA_VIGOR
		vida += Config.MEJORA_VIGOR


## Refugio: curar toda la vida.
func curar() -> void:
	vida = vida_max


# --- Mapas ---

## Lo llama cada mapa al empezar: pasa el estado a Mika y aplica lo que cambia este mapa.
func aplicar_a_mapa(mapa: Mapa) -> void:
	var mika := mapa.mika
	mika.vida = vida
	mika.vida_max = vida_max
	mika.sed = sed
	mika.humanidad = humanidad
	mika.viales = viales
	mika.mejoras.assign(mejoras)
	# Mejoras permanentes de los recuerdos.
	if tiene_recuerdo(2):
		mika.sed_por_golpe = 2
	if tiene_recuerdo(4) and not salvacion_usada:
		mika.salvacion_disponible = true
	if tiene_recuerdo(5):
		mika.tramo_lento = 70
	if tiene_recuerdo(6):
		mika.sed_impulso = 5
	# Lo que dejaron la parada o el evento anteriores.
	mika.sed_congelada = sed_congelada
	sed_congelada = false
	mapa.patrullas_visibles = patrullas_visibles
	if not mapa.prueba_de_la_sed:
		match siguiente_empieza:
			"alarma":
				mapa.alerta.dar_alarma(mika.pos)
			"sospecha":
				for soldado in mapa.soldados():
					soldado.oir(soldado.pos) # cada uno registra su zona
		siguiente_empieza = ""


## Lo llama el mapa al terminar, antes de enseñar el resultado: recoge el estado de Mika.
func al_terminar_mapa(mapa: Mapa, exito: bool, motivo: String) -> void:
	var mika := mapa.mika
	vida = maxi(1, mika.vida)
	vida_max = mika.vida_max
	sed = mika.sed
	humanidad = mika.humanidad
	viales = mika.viales
	mejoras.assign(mika.mejoras)
	if not mika.salvacion_disponible and tiene_recuerdo(4):
		salvacion_usada = true
	recuerdo_nuevo = 0
	if mapa.prueba_de_la_sed:
		var resultado := "superada" if exito else motivo
		if exito:
			recuerdo_nuevo = ganar_recuerdo()
		elif motivo == "fallida":
			siguiente_empieza = "alarma"
		escena_tras_parada = escena_salida_prueba(resultado)


## Lo que se ve al salir de la Prueba de la sed: si se superó, la escena del fondo (entera la
## primera vez en la zona, la versión corta después) y luego el texto de salida.
func escena_salida_prueba(resultado: String) -> Array[Dictionary]:
	var golpes: Array[Dictionary] = []
	if resultado == "superada":
		var larga := not zona in fondos_vistos
		var fondo := Guion.prueba_fondo(zona, larga)
		if larga and not fondo.is_empty():
			fondos_vistos.append(zona)
			guardar_recuerdos()
		golpes.append_array(fondo)
		if not fondo.is_empty():
			golpes.append({"tipo": "negro", "texto": ""})
	golpes.append_array(Guion.prueba_salida(zona, resultado))
	return golpes


# --- Recuerdos ---

func tiene_recuerdo(numero: int) -> bool:
	return numero in recuerdos


## Desbloquea el siguiente recuerdo, en orden. Devuelve su número (0 si ya estaban todos).
## El de la confesión no se gana con Humanidad 0.
func ganar_recuerdo() -> int:
	for n in range(1, TOTAL_RECUERDOS + 1):
		if n == RECUERDO_CONFESION and humanidad <= 0:
			return 0
		if not tiene_recuerdo(n):
			recuerdos.append(n)
			guardar_recuerdos()
			return n
	return 0


func guardar_recuerdos() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("recuerdos", "ganados", recuerdos)
	cfg.set_value("recuerdos", "inicio_visto", inicio_visto)
	cfg.set_value("recuerdos", "fondos_vistos", fondos_vistos)
	cfg.save(archivo_recuerdos)


func cargar_recuerdos() -> void:
	var cfg := ConfigFile.new()
	recuerdos = []
	inicio_visto = false
	fondos_vistos = []
	if cfg.load(archivo_recuerdos) == OK:
		fondos_vistos.assign(cfg.get_value("recuerdos", "fondos_vistos", []))
		recuerdos.assign(cfg.get_value("recuerdos", "ganados", []))
		inicio_visto = cfg.get_value("recuerdos", "inicio_visto", false)


static func datos_recuerdos() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://datos/recuerdos.json"))
