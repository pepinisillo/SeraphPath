class_name Guion
## Lee el guion de la historia, escrito en Markdown, y lo convierte en «golpes»: las líneas que
## una escena con diálogo enseña una a una.
##
## El guion es provisional y no se sube a git: vive en `historia/guion/`, junto a `sed/`, o en
## `res://datos/guion/` si algún día se copia dentro del juego. Si no está en ninguno de los dos,
## las escenas salen vacías: el inicio no se enseña, los recuerdos solo dicen su mejora, etc.
##
## Formato: cada línea no vacía es un golpe (la línea en blanco entre párrafos no hace falta,
## pero se puede poner). Cada golpe es un diccionario con `tipo` y `texto`:
## - "narracion": línea sin raya.
## - "dialogo": línea que empieza con raya (—).
## - "ahora": la línea de «Mika, ahora».
## - "otro_yuu": comentario del otro Yuu; lleva `variante` ("hambriento", "lleno" o "rombo",
##   el ◆ de los eventos, que solo sale con Humanidad 1 o más).
## - "opcion": «**Aceptar** *(…)*» en un evento; lleva `nombre`.
## - "final": el «**Texto final.**» de un final.
## Desde una línea que empieza por «**◆ El otro Yuu**» (sin dos puntos) hasta el final de la
## sección, cada golpe lleva `rombo`: solo sale con Humanidad 1 o más.
## - "negro": pantalla en negro (sale de una acotación que lo pide).
## - "beber": «aparece el botón Beber»: espera a que el jugador lo mantenga. Lleva `obligatorio`
##   («no hay otra opción»); si no, se puede seguir sin beber.
## - "sin_color": «la pantalla casi no tiene color»; "color": «el color vuelve a la pantalla».
## - "silencio": pausa sin texto (Humanidad 0, donde el otro Yuu ya no comenta).
## - "nota": las demás acotaciones *(…)*, notas para el juego que no se enseñan.
## Quién habla lo deduce asignar_hablantes(); se puede forzar con «[Krul]» al principio de la línea.

const CARPETA_INTERNA := "res://datos/guion"
const CARPETA_EXTERNA := "../historia/guion" # relativa a la carpeta del proyecto (sed/)
const ARCHIVO_INICIO := "0_inicio_y_recuerdos.md"
const ARCHIVO_PRUEBAS := "1_pruebas_de_la_sed.md"
const ARCHIVO_EVENTOS := "2_eventos_y_refugios.md"
const ARCHIVO_JEFES := "3_jefes.md"
const ARCHIVO_FINALES := "4_finales.md"
const TIPOS_VISIBLES := ["narracion", "dialogo", "ahora", "otro_yuu", "final", "negro", "silencio", "beber", "sin_color", "color"]

## Personajes que se reconocen al deducir quién habla, con los nombres con que aparecen en el texto.
const PERSONAJES := {
	"El otro Yuu": ["el otro Yuu", "El otro Yuu", "el otro", "El otro"],
	"Mika": ["Mika"], "Yuu": ["Yuu"], "Krul": ["Krul"], "Ferid": ["Ferid"],
	"Crowley": ["Crowley"], "Lacus": ["Lacus"], "René": ["René"], "Akane": ["Akane"],
	"Guren": ["Guren"], "Shinoa": ["Shinoa"], "Mahiru": ["Mahiru"],
	"La doncella": ["la doncella", "La doncella"],
}
const VERBOS := ["dijo", "preguntó", "contestó", "respondió", "murmuró", "gritó", "susurró", "añadió", "insistió", "repitió"]

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


## Líneas de la sección cuyo encabezado empieza por `encabezado` (sin las #), hasta el siguiente
## encabezado del mismo nivel o superior, o hasta una línea «---». Con `dentro`, la busca solo
## después del encabezado `dentro` (por ejemplo, «Entrada» dentro de «Zona 1»). Vacío si no existe.
static func lineas_de(archivo: String, encabezado: String, dentro := "") -> PackedStringArray:
	var resultado := PackedStringArray()
	var nivel := 0
	var buscando := dentro == ""
	for linea in _lineas(archivo):
		var es_encabezado := linea.begins_with("#")
		var n := linea.length() - linea.lstrip("#").length() if es_encabezado else 0
		var titulo := linea.lstrip("#").strip_edges()
		if not buscando:
			buscando = es_encabezado and titulo.begins_with(dentro)
			continue
		if nivel == 0:
			if es_encabezado and titulo.begins_with(encabezado):
				nivel = n
			continue
		if (es_encabezado and n <= nivel) or linea.strip_edges() == "---":
			break
		if not es_encabezado:
			resultado.append(linea)
	return resultado


## Golpes de una sección (con las notas; ver sin_notas).
static func seccion(archivo: String, encabezado: String, dentro := "") -> Array[Dictionary]:
	var golpes: Array[Dictionary] = []
	var en_rombo := false
	for linea in lineas_de(archivo, encabezado, dentro):
		var g := _golpe(linea.strip_edges())
		if g.is_empty():
			continue
		if g.get("abre_rombo", false):
			en_rombo = true
		if en_rombo:
			g.rombo = true
		golpes.append(g)
	return golpes


static func sin_notas(golpes: Array[Dictionary]) -> Array[Dictionary]:
	return golpes.filter(func(g): return g.tipo != "nota")


## Elementos de una lista numerada («1. …»), cada uno con sus líneas de continuación (las que
## van sangradas debajo). Cada elemento: {condicion, golpes}. `condicion` es el texto de una
## acotación al principio, como «Sed 60 o más.», o "".
static func lista(archivo: String, encabezado: String, dentro := "") -> Array[Dictionary]:
	var elementos: Array[Dictionary] = []
	var numero := RegEx.create_from_string("^\\d+\\.\\s+")
	for linea in lineas_de(archivo, encabezado, dentro):
		var limpia := linea.strip_edges()
		if limpia == "":
			continue
		var m := numero.search(linea)
		if m != null:
			limpia = linea.substr(m.get_end()).strip_edges()
			var condicion := ""
			if limpia.begins_with("*(") and limpia.contains(")*"):
				condicion = limpia.substr(2, limpia.find(")*") - 2).strip_edges()
				limpia = limpia.substr(limpia.find(")*") + 2).strip_edges()
			var nuevos: Array[Dictionary] = []
			elementos.append({"condicion": condicion, "golpes": nuevos})
		elif elementos.is_empty() or not linea.begins_with(" "):
			continue
		var g := _golpe(limpia)
		if not g.is_empty() and g.tipo != "nota":
			elementos[-1].golpes.append(g)
	return elementos


## Listas de una sección separadas por notas: [{nota, elementos}], donde cada elemento es
## {condicion, golpes} como en lista(). Admite «1. …» y «- …». Lo que va antes de la primera
## nota queda en un grupo con nota "".
static func grupos(archivo: String, encabezado: String, dentro := "") -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var numero := RegEx.create_from_string("^(\\d+\\.|-)\\s+")
	var actual := {"nota": "", "elementos": []}
	for linea in lineas_de(archivo, encabezado, dentro):
		var limpia := linea.strip_edges()
		if limpia == "":
			continue
		if limpia.begins_with("*(") and limpia.ends_with(")*"):
			if not actual.elementos.is_empty() or actual.nota != "":
				resultado.append(actual)
			actual = {"nota": limpia.substr(2, limpia.length() - 4), "elementos": []}
			continue
		var m := numero.search(linea)
		if m != null:
			limpia = linea.substr(m.get_end()).strip_edges()
			var condicion := ""
			if limpia.begins_with("*(") and limpia.contains(")*"):
				condicion = limpia.substr(2, limpia.find(")*") - 2).strip_edges()
				limpia = limpia.substr(limpia.find(")*") + 2).strip_edges()
			var nuevos: Array[Dictionary] = []
			actual.elementos.append({"condicion": condicion, "golpes": nuevos})
		elif actual.elementos.is_empty() or not linea.begins_with(" "):
			continue
		var g := _golpe(limpia)
		if not g.is_empty() and g.tipo != "nota":
			actual.elementos[-1].golpes.append(g)
	if not actual.elementos.is_empty() or actual.nota != "":
		resultado.append(actual)
	return resultado


## Los textos sueltos de una lista (para frases cortas, como las de los ecos), sin las comillas «».
## Deja fuera los elementos con condición.
static func frases(archivo: String, encabezado: String, dentro := "") -> PackedStringArray:
	var resultado := PackedStringArray()
	for e in lista(archivo, encabezado, dentro):
		if e.condicion == "" and not e.golpes.is_empty():
			resultado.append(sin_comillas(e.golpes[0].texto))
	return resultado


static func sin_comillas(texto: String) -> String:
	return texto.trim_prefix("«").trim_suffix("»")


static func inicio() -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_INICIO, "Inicio"))


## La línea corta del inicio de las demás expediciones, con {viales} cambiado por el número en letra.
static func cada_expedicion(viales: int) -> Array[Dictionary]:
	var golpes := sin_notas(seccion(ARCHIVO_INICIO, "Cada expedición"))
	for g in golpes:
		g.texto = g.texto.replace("{viales}", en_letra(viales))
	return golpes


static func en_letra(n: int) -> String:
	const NUMEROS := ["ningún", "un", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez"]
	return NUMEROS[n] if n >= 0 and n < NUMEROS.size() else str(n)


## Título del recuerdo `n` según el guion ("" si no hay guion).
static func titulo_recuerdo(n: int) -> String:
	for linea in _lineas(ARCHIVO_INICIO):
		if linea.begins_with("### %d. " % n):
			return linea.trim_prefix("### %d. " % n).strip_edges()
	return ""


## Golpes del recuerdo `n` (vacío si no hay guion).
static func recuerdo(n: int) -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_INICIO, "%d. " % n))


# --- Prueba de la sed ---

const ESTADO_ECOS := {3: "Hambriento", 2: "Satisfecho", 1: "Cariñoso"}


static func prueba_entrada(zona: int) -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_PRUEBAS, "Entrada", "Zona %d" % zona))


## La escena del fondo de la zona: la completa (`larga`) o la versión corta.
static func prueba_fondo(zona: int, larga: bool) -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_PRUEBAS, "Escena del fondo" if larga else "Versión corta", "Zona %d" % zona))


## Texto de salida según el resultado ("superada", "cedida" o "fallida").
static func prueba_salida(zona: int, resultado: String) -> Array[Dictionary]:
	var golpes: Array[Dictionary] = []
	match resultado:
		"superada":
			var marca := "**Zona %d.**" % zona
			for linea in lineas_de(ARCHIVO_PRUEBAS, "Superada", "Salidas"):
				if linea.strip_edges().begins_with(marca):
					golpes.append(_golpe(linea.strip_edges().trim_prefix(marca).strip_edges()))
			return golpes
		"cedida":
			# Hasta la acotación de la variante; en la zona 3, lo que va después de ella.
			var despues: Array[Dictionary] = []
			var en_variante := false
			for g in seccion(ARCHIVO_PRUEBAS, "Cedida", "Salidas"):
				if g.tipo == "nota" and g.texto.begins_with("Variante"):
					en_variante = true
				elif g.tipo != "nota":
					if en_variante:
						despues.append(g)
					else:
						golpes.append(g)
			return despues if zona == 3 and not despues.is_empty() else golpes
		_:
			return sin_notas(seccion(ARCHIVO_PRUEBAS, "Fallida", "Salidas"))


## «Sin voz»: sustituye a la prueba con Humanidad 0.
static func prueba_sin_voz() -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_PRUEBAS, "«Sin voz»"))


static func frases_ecos(humanidad: int) -> PackedStringArray:
	if not ESTADO_ECOS.has(humanidad):
		return PackedStringArray()
	return frases(ARCHIVO_PRUEBAS, ESTADO_ECOS[humanidad], "Frases de los ecos")


## Frases de la voz en el Frenesí: las de siempre y la de cuando pasa sin que beba.
static func voz_frenesi() -> Dictionary:
	var normales := PackedStringArray()
	var sin_beber := PackedStringArray()
	for e in lista(ARCHIVO_PRUEBAS, "Voz en el Frenesí"):
		if e.golpes.is_empty():
			continue
		var t := sin_comillas(e.golpes[0].texto)
		if e.condicion.contains("sin que beba"):
			sin_beber.append(t)
		else:
			normales.append(t)
	return {"normales": normales, "sin_beber": sin_beber}


# --- Jefes ---

static func jefe_antes(jefe: String) -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_JEFES, "Antes", jefe))


static func jefe_despues(jefe: String) -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_JEFES, "Después", jefe))


## Frases de un jefe durante el combate: {persigue, atrapa, otro_yuu, fase2, poca_vida}, cada una
## una lista de textos («persigue»: las de siempre; «poca_vida»: las marcadas «Con poca vida»).
static func jefe_durante(jefe: String) -> Dictionary:
	var frases_de := {"persigue": PackedStringArray(), "atrapa": PackedStringArray(), "otro_yuu": PackedStringArray(), "fase2": PackedStringArray(), "poca_vida": PackedStringArray()}
	for grupo in grupos(ARCHIVO_JEFES, "Durante", jefe):
		var nota: String = grupo.nota.to_lower()
		var clave := "persigue"
		if nota.contains("otro yuu"):
			clave = "otro_yuu"
		elif nota.contains("atrapa") or nota.contains("lo derriba") or nota.contains("lo alcanza"):
			clave = "atrapa"
		elif nota.contains("segunda fase"):
			clave = "fase2"
		for e in grupo.elementos:
			if not e.golpes.is_empty():
				var de: String = "poca_vida" if e.condicion.to_lower().contains("poca vida") else clave
				frases_de[de].append(sin_comillas(e.golpes[0].texto))
	return frases_de


# --- Finales ---

## La escena de un final («La sangre de Yuu», «En el límite», «Vampiro completo»).
static func final(nombre: String) -> Array[Dictionary]:
	return sin_notas(seccion(ARCHIVO_FINALES, nombre))

## Final «Caído»: la primera vez, entero; después, una línea de Krul al azar y otra del otro Yuu
## (Humanidad 1 o más), con el mismo texto final; con Humanidad 0, su versión.
static func caido(humanidad: int, primera_vez: bool, rng: RandomNumberGenerator) -> Array[Dictionary]:
	if humanidad <= 0:
		var sin_humanidad := sin_notas(seccion(ARCHIVO_FINALES, "Caído con Humanidad 0", "Caído"))
		if not sin_humanidad.is_empty():
			return sin_humanidad
	var primera := sin_notas(seccion(ARCHIVO_FINALES, "La primera vez", "Caído"))
	if primera_vez or primera.is_empty():
		return primera
	var golpes: Array[Dictionary] = []
	var listas := grupos(ARCHIVO_FINALES, "Las siguientes veces", "Caído")
	for i in listas.size():
		var es_otro_yuu: bool = listas[i].nota.contains("otro Yuu")
		if listas[i].elementos.is_empty() or (es_otro_yuu and humanidad < 1):
			continue
		var elegido: Dictionary = listas[i].elementos[rng.randi_range(0, listas[i].elementos.size() - 1)]
		for g: Dictionary in elegido.golpes:
			var copia := g.duplicate()
			if es_otro_yuu:
				copia = {"tipo": "otro_yuu", "variante": "rombo", "texto": g.texto}
			golpes.append(copia)
	for g in primera:
		if g.tipo == "final":
			golpes.append(g)
	return golpes


# --- Eventos y refugios ---

## Texto de un evento por su título: {intro, opciones: {nombre de la opción: golpes}}.
## La intro llega hasta la primera opción; cada opción, hasta la siguiente.
static func evento(titulo: String) -> Dictionary:
	var encabezado := ""
	for linea in _lineas(ARCHIVO_EVENTOS):
		if linea.begins_with("### ") and linea.contains(titulo):
			encabezado = linea.lstrip("#").strip_edges()
			break
	var intro: Array[Dictionary] = []
	var opciones := {}
	if encabezado == "":
		return {"intro": intro, "opciones": opciones}
	var actual := ""
	for g in seccion(ARCHIVO_EVENTOS, encabezado, "Eventos"):
		if g.tipo == "opcion":
			actual = g.nombre
			var golpes: Array[Dictionary] = []
			opciones[actual] = golpes
		elif g.tipo != "nota":
			if actual == "":
				intro.append(g)
			else:
				opciones[actual].append(g)
	return {"intro": intro, "opciones": opciones}


## Una línea de refugio al azar para esa Humanidad, entre las que se cumplen (algunas piden
## «Sed 60 o más»). Vacío si no hay guion.
static func refugio(humanidad: int, sed: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var posibles: Array = []
	for e in lista(ARCHIVO_EVENTOS, "Humanidad %d" % humanidad, "Refugios"):
		var condicion: String = e.condicion
		if condicion == "" or (condicion.begins_with("Sed 60") and sed >= 60):
			posibles.append(e.golpes)
	var golpes: Array[Dictionary] = []
	if not posibles.is_empty():
		for g: Dictionary in posibles[rng.randi_range(0, posibles.size() - 1)]:
			var copia := g.duplicate()
			if copia.texto.begins_with("«"): # pensamiento de Mika
				copia.habla_forzada = "Mika"
			golpes.append(copia)
	return golpes


## Deja solo lo que corresponde a la Humanidad: el comentario «hambriento» con 3, «lleno» con
## 2 o 1, y con 0 un silencio en su lugar. Las líneas ◆ («rombo») solo con 1 o más.
static func segun_humanidad(golpes: Array[Dictionary], humanidad: int) -> Array[Dictionary]:
	var variante := "hambriento" if humanidad >= Config.HUMANIDAD_INICIAL else "lleno"
	var resultado: Array[Dictionary] = []
	var silencio_puesto := false
	for g in golpes:
		if g.get("rombo", false) and humanidad < 1:
			continue
		if g.tipo != "otro_yuu":
			resultado.append(g)
		elif g.variante == "rombo":
			if humanidad >= 1:
				resultado.append(g)
		elif humanidad <= 0:
			if not silencio_puesto:
				resultado.append({"tipo": "silencio", "texto": ""})
				silencio_puesto = true
		elif g.variante == variante:
			resultado.append(g)
	return resultado


## Pone en cada golpe `habla`, el personaje que dice la línea ("" si es narración o no se sabe):
## 1. «[Nombre]» al principio de la línea (y se quita del texto).
## 2. La línea lo dice: «—dijo Krul», «preguntó el otro Yuu».
## 3. La narración justo anterior empieza por un personaje: «Krul se sentó.»
## 4. Si no, se alternan los dos últimos que hablaron, como en una novela.
static func asignar_hablantes(golpes: Array) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var ultimos: Array[String] = [] # los dos últimos que hablaron, el más reciente al final
	var sujeto := "" # personaje con que empieza la narración anterior
	for original in golpes:
		var g: Dictionary = original.duplicate()
		var forzado: String = g.get("habla_forzada", "")
		var habla := forzado
		match g.tipo:
			"ahora":
				habla = "Mika, ahora"
			"otro_yuu":
				habla = "El otro Yuu"
			"dialogo":
				if habla == "":
					habla = _por_verbo(g.texto)
				if habla == "" and sujeto != "":
					habla = sujeto
				if habla == "" and ultimos.size() == 2:
					habla = ultimos[0]
			"narracion":
				if forzado == "":
					sujeto = _sujeto(g.texto)
		if g.tipo == "dialogo":
			sujeto = ""
			if habla != "":
				ultimos.erase(habla)
				ultimos.append(habla)
				if ultimos.size() > 2:
					ultimos.pop_front()
		g.habla = habla
		resultado.append(g)
	return resultado


## «—Sí —dijo una voz.» → ""; «—Sí —dijo Krul.» → "Krul"; «preguntó el otro» → "El otro Yuu".
static func _por_verbo(texto: String) -> String:
	for verbo in VERBOS:
		var i := texto.find(verbo + " ")
		while i >= 0:
			var nombre := _empieza_por_personaje(texto.substr(i + verbo.length() + 1))
			if nombre != "":
				return nombre
			i = texto.find(verbo + " ", i + 1)
	return ""


static func _sujeto(texto: String) -> String:
	return _empieza_por_personaje(texto)


static func _empieza_por_personaje(texto: String) -> String:
	for nombre in PERSONAJES:
		for alias in PERSONAJES[nombre]:
			if texto.begins_with(alias) and (texto.length() == alias.length() or not (texto[alias.length()].is_valid_identifier() or texto[alias.length()] in "áéíóúñ")):
				return nombre
	return ""


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


static func _golpe(texto: String) -> Dictionary:
	if texto == "":
		return {}
	# «[Krul] —…»: quién habla, forzado a mano.
	if texto.begins_with("[") and texto.contains("]"):
		var forzado := texto.substr(1, texto.find("]") - 1).strip_edges()
		var g := _golpe(texto.substr(texto.find("]") + 1).strip_edges())
		if not g.is_empty():
			g.habla_forzada = forzado
		return g
	# Acotación para el juego: *(…)*
	if texto.begins_with("*(") and texto.ends_with(")*"):
		var nota := texto.to_lower()
		if nota.contains("pantalla en negro"):
			return {"tipo": "negro", "texto": ""}
		if nota.contains("botón beber"):
			return {"tipo": "beber", "texto": "", "obligatorio": nota.contains("no hay otra opción")}
		if nota.contains("color vuelve"):
			return {"tipo": "color", "texto": ""}
		if nota.contains("casi no tiene color"):
			return {"tipo": "sin_color", "texto": ""}
		return {"tipo": "nota", "texto": texto.substr(2, texto.length() - 4)}
	if texto.begins_with("**Mika, ahora:**"):
		return {"tipo": "ahora", "texto": texto.trim_prefix("**Mika, ahora:**").strip_edges()}
	if texto.begins_with("**Texto final.**"):
		return {"tipo": "final", "texto": texto.trim_prefix("**Texto final.**").strip_edges()}
	if texto.begins_with("**◆ El otro Yuu** "):
		return {"tipo": "narracion", "abre_rombo": true, "texto": "El otro Yuu " + texto.trim_prefix("**◆ El otro Yuu** ")}
	if texto.begins_with("**◆ El otro Yuu:**"):
		return {"tipo": "otro_yuu", "variante": "rombo", "texto": texto.trim_prefix("**◆ El otro Yuu:**").strip_edges()}
	if texto.begins_with("**El otro Yuu, "):
		var resto := texto.trim_prefix("**El otro Yuu, ")
		var variante := resto.get_slice(":", 0)
		return {"tipo": "otro_yuu", "variante": variante, "texto": resto.trim_prefix(variante + ":**").strip_edges()}
	# Opción de un evento: «**Aceptar** *(efectos).*»
	if texto.begins_with("**") and texto.find("**", 2) > 2:
		var cierre := texto.find("**", 2)
		var resto := texto.substr(cierre + 2).strip_edges()
		if resto == "" or resto.begins_with("*("):
			return {"tipo": "opcion", "nombre": texto.substr(2, cierre - 2), "texto": resto}
	var limpio := texto.replace("**", "")
	return {"tipo": "dialogo" if limpio.begins_with("—") else "narracion", "texto": limpio}
