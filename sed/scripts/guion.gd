class_name Guion
## Lee el guion de la historia, escrito en Markdown, y lo convierte en «golpes»: los párrafos
## que una escena con diálogo enseña uno a uno.
##
## El guion es provisional y no se sube a git: vive en `historia/guion/`, junto a `sed/`, o en
## `res://datos/guion/` si algún día se copia dentro del juego. Si no está en ninguno de los dos,
## las escenas salen vacías: el inicio no se enseña y los recuerdos solo dicen su mejora.
## `datos/recuerdos.json` guarda solo lo que no es texto: momento y mejora de cada recuerdo.
##
## Cada golpe es un diccionario con `tipo` y `texto`:
## - "narracion": párrafo sin raya.
## - "dialogo": párrafo que empieza con raya (—).
## - "ahora": la línea de «Mika, ahora».
## - "otro_yuu": comentario del otro Yuu; lleva además `variante` ("hambriento" o "lleno").
## - "negro": pantalla en negro (sale de una acotación que lo pide).
## - "silencio": pausa sin texto (Humanidad 0, donde el otro Yuu ya no comenta).
## Las demás acotaciones *(…)* son notas para el juego y no se enseñan.

const CARPETA_INTERNA := "res://datos/guion"
const CARPETA_EXTERNA := "../historia/guion" # relativa a la carpeta del proyecto (sed/)
const ARCHIVO_INICIO := "0_inicio_y_recuerdos.md"

static var _cache := {}
## Las pruebas automáticas ponen aquí una carpeta con un guion de muestra.
static var carpeta_pruebas := ""


## Carpeta del guion, o "" si no hay guion.
static func carpeta() -> String:
	if carpeta_pruebas != "":
		return carpeta_pruebas
	if DirAccess.dir_exists_absolute(CARPETA_INTERNA):
		return CARPETA_INTERNA
	var proyecto := ProjectSettings.globalize_path("res://")
	if proyecto != "":
		var externa := proyecto.path_join(CARPETA_EXTERNA).simplify_path()
		if DirAccess.dir_exists_absolute(externa):
			return externa
	return ""


static func hay_guion() -> bool:
	return carpeta() != ""


## Golpes de la sección cuyo encabezado empieza por `encabezado` (sin las #), hasta el siguiente
## encabezado del mismo nivel o superior, o hasta una línea «---». Vacío si no existe.
static func seccion(archivo: String, encabezado: String) -> Array[Dictionary]:
	var lineas := _lineas(archivo)
	var golpes: Array[Dictionary] = []
	var nivel := 0
	var parrafo := PackedStringArray()
	for linea in lineas:
		var es_encabezado := linea.begins_with("#")
		var n := linea.length() - linea.lstrip("#").length() if es_encabezado else 0
		if nivel == 0:
			if es_encabezado and linea.lstrip("#").strip_edges().begins_with(encabezado):
				nivel = n
			continue
		if (es_encabezado and n <= nivel) or linea.strip_edges() == "---":
			break
		if linea.strip_edges() == "" or es_encabezado:
			_cerrar_parrafo(parrafo, golpes)
		else:
			parrafo.append(linea.strip_edges())
	_cerrar_parrafo(parrafo, golpes)
	return golpes


static func inicio() -> Array[Dictionary]:
	return seccion(ARCHIVO_INICIO, "Inicio")


## Título del recuerdo `n` según el guion ("" si no hay guion).
static func titulo_recuerdo(n: int) -> String:
	for linea in _lineas(ARCHIVO_INICIO):
		if linea.begins_with("### %d. " % n):
			return linea.trim_prefix("### %d. " % n).strip_edges()
	return ""


## Golpes del recuerdo `n` (vacío si no hay guion).
static func recuerdo(n: int) -> Array[Dictionary]:
	return seccion(ARCHIVO_INICIO, "%d. " % n)


## Deja solo lo que corresponde a la Humanidad: el comentario «hambriento» con 3, «lleno» con
## 2 o 1, y con 0 un silencio en su lugar.
static func segun_humanidad(golpes: Array[Dictionary], humanidad: int) -> Array[Dictionary]:
	var variante := "hambriento" if humanidad >= Config.HUMANIDAD_INICIAL else "lleno"
	var resultado: Array[Dictionary] = []
	var silencio_puesto := false
	for g in golpes:
		if g.tipo != "otro_yuu":
			resultado.append(g)
		elif humanidad <= 0:
			if not silencio_puesto:
				resultado.append({"tipo": "silencio", "texto": ""})
				silencio_puesto = true
		elif g.variante == variante:
			resultado.append(g)
	return resultado


## Vuelve a leer el guion del disco (por si se cambió con el juego abierto).
static func olvidar() -> void:
	_cache.clear()


# --- Lectura ---

static func _lineas(archivo: String) -> PackedStringArray:
	if _cache.has(archivo):
		return _cache[archivo]
	var lineas := PackedStringArray()
	var c := carpeta()
	if c != "":
		var ruta := c.path_join(archivo)
		if FileAccess.file_exists(ruta):
			lineas = FileAccess.get_file_as_string(ruta).split("\n")
	_cache[archivo] = lineas
	return lineas


static func _cerrar_parrafo(parrafo: PackedStringArray, golpes: Array[Dictionary]) -> void:
	if parrafo.is_empty():
		return
	var g := _golpe(" ".join(parrafo))
	parrafo.clear()
	if not g.is_empty():
		golpes.append(g)


static func _golpe(texto: String) -> Dictionary:
	# Acotación para el juego: *(…)*
	if texto.begins_with("*(") and texto.ends_with(")*"):
		if texto.to_lower().contains("pantalla en negro"):
			return {"tipo": "negro", "texto": ""}
		return {}
	if texto.begins_with("**Mika, ahora:**"):
		return {"tipo": "ahora", "texto": texto.trim_prefix("**Mika, ahora:**").strip_edges()}
	if texto.begins_with("**El otro Yuu, "):
		var resto := texto.trim_prefix("**El otro Yuu, ")
		var variante := resto.get_slice(":", 0)
		return {"tipo": "otro_yuu", "variante": variante, "texto": resto.trim_prefix(variante + ":**").strip_edges()}
	var limpio := texto.replace("**", "")
	return {"tipo": "dialogo" if limpio.begins_with("—") else "narracion", "texto": limpio}

