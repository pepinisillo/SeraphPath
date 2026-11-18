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
const ESCENA_FILO := "res://escenas/filo.tscn"
const ESCENA_FINAL := "res://escenas/final.tscn"
const ESCENA_INFILTRACION := "res://escenas/mapa_puesto_control.tscn"
const ESCENA_TUNELES := "res://escenas/mapa_tuneles.tscn"
const ESCENA_PRUEBA := "res://escenas/mapa_prueba_sed.tscn"
const ESCENA_JEFE := "res://escenas/mapa_hangar.tscn"

## Las zonas de la expedición, en orden: nombre, mapas (la primera infiltración, la de la ruta
## arriesgada y el del jefe) y cómo se describen en el mapa de paradas. Al escapar del jefe de
## una zona se pasa a la siguiente; tras la última, el final.
const ZONAS := {
	1: {
		"nombre": "Sanguinem", "jefe": "Ferid Bathory",
		"infiltracion": ESCENA_INFILTRACION, "arriesgada": ESCENA_TUNELES, "mapa_jefe": ESCENA_JEFE,
		"prueba": ESCENA_PRUEBA, # el orfanato
		"texto_infiltracion": "Cruza el puesto de control hasta la salida.",
		"texto_arriesgada": "Cruza los túneles de abastecimiento hasta la salida.",
		"texto_jefe": "No se le vence: se le escapa. Llega a la rampa del avión mientras te persigue.",
	},
	2: {
		"nombre": "Ruinas de Shinjuku", "jefe": "Crowley Eusford",
		"infiltracion": "res://escenas/mapa_shinjuku.tscn", "arriesgada": "res://escenas/mapa_estacion.tscn",
		"mapa_jefe": "res://escenas/mapa_cruce.tscn",
		"prueba": "res://escenas/mapa_prueba_calle.tscn", # la calle intacta, con las ventanas encendidas
		"texto_infiltracion": "Cruza las ruinas de Shinjuku, entre soldados y Jinetes.",
		"texto_arriesgada": "Cruza la estación hundida hasta la salida.",
		"texto_jefe": "Combate abierto. Aguanta hasta que se rinda.",
	},
	3: {
		"nombre": "Shibuya", "jefe": "Guren Ichinose",
		"infiltracion": "res://escenas/mapa_shibuya.tscn", "arriesgada": "res://escenas/mapa_rio.tscn",
		"mapa_jefe": "res://escenas/mapa_patio.tscn",
		"prueba": "res://escenas/mapa_prueba_cuarto.tscn", # el cuarto blanco, sin puertas
		"texto_infiltracion": "Cruza la base del ejército dentro de la muralla. Cuidado con los talismanes.",
		"texto_arriesgada": "Entra por el hueco de la muralla, del lado del río.",
		"texto_jefe": "Combate contra un arma maldita. Al final está Yuu.",
	},
}

## Los finales de la expedición entera (tras el jefe de la última zona), según cómo llegue Mika.
const FINAL_SANGRE := "La sangre de Yuu" # Humanidad 3 y los siete recuerdos
const FINAL_LIMITE := "En el límite" # el resto, con Humanidad 1 o más
const FINAL_VAMPIRO := "Vampiro completo" # Humanidad 0

## Cada zona: infiltración, dos rutas de dos paradas, Prueba de la sed y jefe.
const RUTAS := {
	"segura": ["refugio", "evento"],
	"arriesgada": ["emboscada", "infiltracion"],
}
const NOMBRES := {
	"infiltracion": "Infiltración", "emboscada": "Emboscada", "evento": "Evento",
	"refugio": "Refugio", "prueba": "Prueba de la sed", "jefe": "Jefe",
}
const TOTAL_RECUERDOS := 7
const RECUERDO_CONFESION := 7 # solo se gana con Humanidad 1 o más (Mika necesita a quién decírselo)

## Archivo de los recuerdos ganados (y de si ya se vio el inicio). Las pruebas automáticas lo cambian para no tocar el real.
var archivo_recuerdos := "user://recuerdos.cfg"
## Archivo de la expedición a medias. Se guarda en el mapa de paradas y al terminar cada parada;
## si el juego se cierra dentro de una parada, al volver la expedición cuenta como caída (así
## no se puede deshacer un mal mapa cerrando el juego).
var archivo_partida := "user://expedicion.cfg"
## Índice de los mapas generados que pasaron la validación (lo escribe pruebas/generar_mapas.gd).
var archivo_generados := "res://datos/mapas_generados.json"
## Lo que se guarda de la expedición.
const GUARDADO := ["zona", "ruta", "indice", "vida", "vida_max", "sed", "humanidad", "viales", "mejoras",
	"filos", "salvacion_usada", "siguiente_empieza", "sed_congelada", "patrullas_visibles", "eventos_vistos",
	"filo_pendiente", "saltar_siguiente", "siguiente_vampiro_extra", "siguiente_vampiros_callados",
	"siguiente_jinete_suelto", "siguiente_prueba_cerca", "mapa_arriesgado"]

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
var caidas := 0 # veces que Mika ha caído, en todas las partidas (el final «Caído» cambia tras la primera)
## Escena del guion en curso (ver mostrar_escena) y la que toca al salir de la parada actual.
var escena_titulo := ""
var escena_golpes: Array[Dictionary] = []
var escena_tras_parada: Array[Dictionary] = []
var siguiente_vampiro_extra := false # evento «La doncella de Krul»
var siguiente_vampiros_callados := false # evento «Lacus y René»
var siguiente_jinete_suelto := false # evento «El Jinete dormido»
var saltar_siguiente := false # evento «El desertor» (confiar)
var siguiente_prueba_cerca := false # evento «El escuadrón de Yuu»
var finales_vistos: Array[String] = []
var filos: Array[String] = [] # filos de la espada que lleva Mika en esta expedición
var filo_pendiente := false # superó una emboscada: al salir, elige un filo
var filos_ofrecidos: Array[String] = []
var mapa_arriesgado := "" # el mapa de la infiltración arriesgada de esta zona (se sortea una vez)
var _tras_filo: Callable
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
	# Desde una prueba automática (godot -s), nunca se tocan los archivos de verdad.
	var bucle := Engine.get_main_loop()
	if bucle != null and bucle.get_script() != null:
		archivo_recuerdos = "user://prueba_recuerdos_auto.cfg"
		archivo_partida = "user://prueba_expedicion.cfg"
	else:
		Opciones.cargar()
	cargar_recuerdos()


## Nunca se ha jugado: ni recuerdos, ni caídas, ni finales (para los avisos de controles).
func primera_vez() -> bool:
	return recuerdos.is_empty() and caidas == 0 and finales_vistos.is_empty()


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
	siguiente_vampiro_extra = false
	siguiente_vampiros_callados = false
	siguiente_jinete_suelto = false
	saltar_siguiente = false
	siguiente_prueba_cerca = false
	filos = []
	filo_pendiente = false
	mapa_arriesgado = ""
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


## Al mapa de paradas; tras la última parada de la zona (el jefe), a la zona siguiente o, si
## era la última, al final.
func ir_a_ruta() -> void:
	if zona_terminada() and ZONAS.has(zona + 1):
		pasar_de_zona()
	if zona_terminada():
		borrar_partida() # la expedición terminó: el final
		_cambiar(ESCENA_FINAL)
		return
	guardar_partida(false)
	_cambiar(ESCENA_RUTA)


## Ya se pasó la última parada de la zona.
func zona_terminada() -> bool:
	return indice >= paradas().size()


## Empieza la zona siguiente: paradas nuevas; lo que duraba toda la zona se acaba.
func pasar_de_zona() -> void:
	zona += 1
	ruta = ""
	indice = 0
	mapa_arriesgado = ""
	patrullas_visibles = false


## Datos de la zona actual (ver ZONAS).
func datos_zona() -> Dictionary:
	return ZONAS[zona]


## Nombre de una parada para enseñarlo («Jefe: Ferid Bathory»).
func nombre_parada(parada: String) -> String:
	if parada == "jefe":
		return "Jefe: " + datos_zona().jefe
	return NOMBRES[parada]


## Entra en la parada actual.
func entrar() -> void:
	guardar_partida(true) # si se cierra el juego dentro de la parada, cuenta como caída
	match parada_actual():
		"infiltracion":
			_cambiar(escena_infiltracion())
		"emboscada":
			siguiente_empieza = "alarma" # una emboscada empieza en Alarma
			_cambiar(escena_emboscada())
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
				mostrar_escena("Prueba de la sed", Guion.prueba_entrada(zona), _cambiar.bind(datos_zona().prueba))
		"jefe":
			_cambiar(datos_zona().mapa_jefe)


## La emboscada: uno de los mapas generados de la zona, al azar (siempre distinto de una
## expedición a otra); si no hay ninguno, la primera infiltración de la zona.
func escena_emboscada() -> String:
	var generados := mapas_generados(zona)
	if generados.is_empty():
		return datos_zona().infiltracion
	return generados[rng.randi_range(0, generados.size() - 1)]


## Las escenas de los mapas generados y validados para una zona.
func mapas_generados(de_zona: int) -> Array:
	if not FileAccess.file_exists(archivo_generados):
		return []
	var indice = JSON.parse_string(FileAccess.get_file_as_string(archivo_generados))
	if not indice is Dictionary:
		return []
	return indice.get(str(de_zona), []).map(func(m): return m.escena).filter(func(e): return ResourceLoader.exists(e))


## La primera infiltración de la zona y la de la ruta arriesgada (en la zona 1, el puesto de
## control y los túneles).
## En la ruta arriesgada, la mitad de las veces sale uno de los mapas generados de la zona.
func escena_infiltracion() -> String:
	if indice == 0:
		return datos_zona().infiltracion
	if not mapa_arriesgado.is_empty():
		return mapa_arriesgado
	mapa_arriesgado = datos_zona().arriesgada
	var generados := mapas_generados(zona)
	if not generados.is_empty() and rng.randf() < 0.5:
		mapa_arriesgado = generados[rng.randi_range(0, generados.size() - 1)]
	return mapa_arriesgado


## Pasa a la siguiente parada y vuelve al mapa de paradas (o enseña antes el recuerdo ganado).
func completar_parada() -> void:
	indice += 1
	if saltar_siguiente and indice < paradas().size() and paradas()[indice] != "jefe":
		indice += 1 # «El desertor»: se salta la parada siguiente y su recompensa
	saltar_siguiente = false
	if not zona_terminada():
		guardar_partida(false) # la parada ya está hecha
	var golpes := escena_tras_parada
	escena_tras_parada = []
	if filo_pendiente:
		filo_pendiente = false
		ofrecer_filo(mostrar_escena.bind("", golpes, _tras_parada))
		return
	mostrar_escena("", golpes, _tras_parada)


## Ofrece dos filos al azar (entre los que no lleva) y después llama a `despues`.
func ofrecer_filo(despues: Callable) -> void:
	filos_ofrecidos = Filos.dos_al_azar(filos, rng)
	if filos_ofrecidos.is_empty():
		despues.call()
		return
	_tras_filo = despues
	_cambiar(ESCENA_FILO)


## Se queda con `nuevo` (y, si ya lleva FILOS_MAX, deja `dejar`). Con `nuevo` vacío, no coge ninguno.
func elegir_filo(nuevo: String, dejar := "") -> void:
	if nuevo != "":
		if dejar != "":
			filos.erase(dejar)
		if filos.size() < Config.FILOS_MAX and not nuevo in filos:
			filos.append(nuevo)
	filos_ofrecidos = []
	var despues := _tras_filo
	_tras_filo = Callable()
	despues.call()


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
	borrar_partida()
	_cambiar(ESCENA_FINAL)


## La escena del final «Caído» (del guion). Cuenta la caída: la primera vez se ve entera.
func escena_caido() -> Array[Dictionary]:
	var golpes := Guion.caido(humanidad, caidas == 0, rng)
	caidas += 1
	guardar_recuerdos()
	return golpes


func volver_al_titulo() -> void:
	activa = false
	borrar_partida()
	_cambiar(ESCENA_TITULO)


# --- Guardar a mitad de expedición ---

func guardar_partida(en_parada: bool) -> void:
	if not activa:
		return
	var cfg := ConfigFile.new()
	for clave in GUARDADO:
		cfg.set_value("expedicion", clave, get(clave))
	cfg.set_value("expedicion", "en_parada", en_parada)
	cfg.save(archivo_partida)


func borrar_partida() -> void:
	if FileAccess.file_exists(archivo_partida):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archivo_partida))


## Hay una expedición guardada para continuar.
func hay_partida() -> bool:
	return FileAccess.file_exists(archivo_partida)


## Sigue la expedición guardada. Si se cerró el juego dentro de una parada, cuenta como caída.
func continuar_partida() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(archivo_partida) != OK:
		return
	nueva()
	for clave in GUARDADO:
		var valor = cfg.get_value("expedicion", clave, get(clave))
		if get(clave) is Array:
			get(clave).assign(valor)
		else:
			set(clave, valor)
	if cfg.get_value("expedicion", "en_parada", false):
		caer()
	else:
		ir_a_ruta()


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
	if efectos.get("vampiro_extra", false):
		siguiente_vampiro_extra = true
	if efectos.get("vampiros_callados", false):
		siguiente_vampiros_callados = true
	if efectos.get("jinete_suelto", false):
		siguiente_jinete_suelto = true
	if efectos.get("saltar_parada", false):
		saltar_siguiente = true
	if efectos.get("prueba_cerca", false):
		siguiente_prueba_cerca = true
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
	mika.filos.assign(filos)
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
	if mapa.prueba_de_la_sed and siguiente_prueba_cerca:
		siguiente_prueba_cerca = false
		if mapa.inicio_cerca.x >= 0:
			mika.pos = Vector2(mapa.inicio_cerca) + Vector2(0.5, 0.5)
			mika.position = Iso.a_pantalla(mika.pos)
	if not mapa.prueba_de_la_sed:
		if siguiente_vampiro_extra:
			mapa.poner_vampiro_extra()
		if siguiente_jinete_suelto:
			mapa.soltar_jinete()
		siguiente_jinete_suelto = false
		mapa.vampiros_callados = siguiente_vampiros_callados
		siguiente_vampiro_extra = false
		siguiente_vampiros_callados = false
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
	if exito and parada_actual() == "emboscada":
		filo_pendiente = true # la recompensa de la emboscada
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
	elif mapa.jefe != "" and exito:
		recuerdo_nuevo = ganar_recuerdo() # cada jefe superado da un recuerdo
		escena_tras_parada = Guion.segun_humanidad(Guion.jefe_despues(mapa.jefe), humanidad)


## En la escena del fondo (zona 3) Mika bebió del otro Yuu: la prueba queda cedida. Pierde el
## recuerdo que acababa de ganar y 1 de Humanidad, la sed baja a 0 y gana una mejora al azar.
func ceder_en_fondo() -> void:
	if recuerdo_nuevo > 0:
		recuerdos.erase(recuerdo_nuevo)
		guardar_recuerdos()
		recuerdo_nuevo = 0
	humanidad = maxi(0, humanidad - 1)
	sed = 0
	var opciones := opciones_de_mejora()
	if not opciones.is_empty():
		elegir_mejora(opciones[0])


## El final de la expedición: el de la sangre de Yuu con Humanidad 3 y los siete recuerdos,
## vampiro completo con Humanidad 0 y, si no, en el límite.
func final_alcanzado() -> String:
	if humanidad >= Config.HUMANIDAD_INICIAL and recuerdos.size() >= TOTAL_RECUERDOS:
		return FINAL_SANGRE
	if humanidad <= 0:
		return FINAL_VAMPIRO
	return FINAL_LIMITE


## Apunta que se vio un final (queda en disco con los recuerdos).
func marcar_final(nombre: String) -> void:
	if not nombre in finales_vistos:
		finales_vistos.append(nombre)
		guardar_recuerdos()


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
	cfg.set_value("recuerdos", "caidas", caidas)
	cfg.set_value("recuerdos", "finales", finales_vistos)
	cfg.save(archivo_recuerdos)


func cargar_recuerdos() -> void:
	var cfg := ConfigFile.new()
	recuerdos = []
	inicio_visto = false
	fondos_vistos = []
	caidas = 0
	finales_vistos = []
	if cfg.load(archivo_recuerdos) == OK:
		finales_vistos.assign(cfg.get_value("recuerdos", "finales", []))
		caidas = cfg.get_value("recuerdos", "caidas", 0)
		fondos_vistos.assign(cfg.get_value("recuerdos", "fondos_vistos", []))
		recuerdos.assign(cfg.get_value("recuerdos", "ganados", []))
		inicio_visto = cfg.get_value("recuerdos", "inicio_visto", false)


static func datos_recuerdos() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://datos/recuerdos.json"))
