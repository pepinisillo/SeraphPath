class_name Eventos
## Los diez eventos de docs/contenido.md, como datos. Cada opción lleva sus efectos:
##   viales, sed (suma), sed_a (fija), vida (cura), vida_max (suma), humanidad (suma), mejora (elige una),
##   siguiente_empieza ("sospecha" o "alarma"), sed_congelada, patrullas_visibles,
##   pendiente (texto de un efecto que depende de un sistema que aún no existe).
## `zona` 0 = cualquiera. `requiere` deja fuera eventos cuyo sistema principal aún no existe.

const TODOS := [
	{
		"id": "doncella", "titulo": "La doncella de Krul", "zona": 1,
		"situacion": "Una sirvienta de la reina te ofrece un vial de su reserva a cambio de un favor.",
		"opciones": [
			{"texto": "Aceptar", "efectos": {"viales": 1, "pendiente": "el siguiente mapa tendrá un vampiro más"}},
			{"texto": "Rechazar", "efectos": {}},
		],
	},
	{
		"id": "lacus_rene", "titulo": "Lacus y René", "zona": 1,
		"situacion": "Tus compañeros de escuadrón te invitan a cazar humanos con ellos.",
		"opciones": [
			{"texto": "Ir y fingir", "efectos": {"sed": 15, "pendiente": "los vampiros del siguiente mapa no te delatarán"}},
			{"texto": "Negarse", "efectos": {"siguiente_empieza": "sospecha"}},
		],
	},
	{
		"id": "copa_ferid", "titulo": "La copa de Ferid", "zona": 1,
		"situacion": "Ferid te espera con una copa de sangre humana y las rutas de todas las patrullas de la zona.",
		"opciones": [
			{"texto": "Beber", "efectos": {"sed_a": 0, "humanidad": -1, "patrullas_visibles": true}},
			{"texto": "Rechazar", "efectos": {}},
		],
	},
	{
		"id": "soldado_atrapado", "titulo": "El soldado atrapado", "zona": 2,
		"situacion": "Un soldado solo, con la pierna atrapada bajo los escombros.",
		"opciones": [
			{"texto": "Beber", "efectos": {"sed_a": 0, "mejora": true, "humanidad": -1}},
			{"texto": "Liberarlo", "efectos": {"siguiente_empieza": "sospecha"}},
			{"texto": "Seguir de largo", "efectos": {}},
		],
	},
	{
		"id": "jinete_dormido", "titulo": "El Jinete dormido", "zona": 2, "requiere": "jinetes",
		"situacion": "Un Jinete del Apocalipsis duerme bloqueando el camino corto.",
		"opciones": [
			{"texto": "Rodearlo", "efectos": {"sed": 10}},
			{"texto": "Atraerlo al puesto humano", "efectos": {"pendiente": "el siguiente mapa tendrá 2 soldados menos y un Jinete suelto"}},
		],
	},
	{
		"id": "clinica", "titulo": "La clínica", "zona": 2,
		"situacion": "Bolsas de sangre de transfusión, intactas, en una clínica en ruinas.",
		"opciones": [
			{"texto": "Beber", "efectos": {"sed": -60, "humanidad": -1}},
			{"texto": "Dejarlas", "efectos": {}},
		],
	},
	{
		"id": "carta", "titulo": "La carta sin enviar", "zona": 0,
		"situacion": "Papel y lápiz en una escuela vacía.",
		"opciones": [
			{"texto": "Escribirle a Yuu", "efectos": {"sed_congelada": true}},
			{"texto": "Descansar", "efectos": {"vida": 3}},
		],
	},
	{
		"id": "filo_exigente", "titulo": "El filo exigente", "zona": 0, "requiere": "filos",
		"situacion": "La espada pide más sangre de la habitual.",
		"opciones": [
			{"texto": "Dársela", "efectos": {"vida_max": -3, "pendiente": "elegir un filo entre dos"}},
			{"texto": "Negarse", "efectos": {}},
		],
	},
	{
		"id": "desertor", "titulo": "El desertor", "zona": 3,
		"situacion": "Un soldado joven, harto del ejército, se ofrece a guiarte por las alcantarillas.",
		"opciones": [
			{"texto": "Confiar", "efectos": {"pendiente": "saltar la siguiente parada y perder su recompensa"}},
			{"texto": "Beber de él", "efectos": {"sed_a": 0, "mejora": true, "humanidad": -1}},
			{"texto": "Dejarlo ir", "efectos": {}},
		],
	},
	{
		"id": "escuadron_yuu", "titulo": "El escuadrón de Yuu", "zona": 3,
		"situacion": "Desde una azotea ves a Yuu reír con su escuadrón.",
		"opciones": [
			{"texto": "Quedarse mirando", "efectos": {"sed": 10, "pendiente": "la siguiente prueba de la sed empezará más cerca de la salida"}},
			{"texto": "Seguir", "efectos": {}},
		],
	},
]


## Eventos que pueden salir en una zona (los de esa zona y los de cualquiera).
static func de_zona(zona: int) -> Array:
	return TODOS.filter(func(e): return (e.zona == zona or e.zona == 0) and not e.has("requiere"))


static func por_id(id: String) -> Dictionary:
	for e in TODOS:
		if e.id == id:
			return e
	return {}


## Texto breve de lo que hace una opción, para mostrarlo junto al botón y después de elegir.
static func describir(efectos: Dictionary) -> String:
	var partes := PackedStringArray()
	if efectos.has("viales"):
		partes.append("+%d vial" % efectos.viales)
	if efectos.has("sed"):
		partes.append("sed %+d" % efectos.sed)
	if efectos.has("sed_a"):
		partes.append("sed a %d" % efectos.sed_a)
	if efectos.has("vida"):
		partes.append("cura %d de vida" % efectos.vida)
	if efectos.has("vida_max"):
		partes.append("%+d de vida máxima" % efectos.vida_max)
	if efectos.has("mejora"):
		partes.append("una mejora de sangre")
	if efectos.has("humanidad"):
		partes.append("%+d de Humanidad" % efectos.humanidad)
	if efectos.get("siguiente_empieza", "") == "sospecha":
		partes.append("el siguiente mapa empieza en Sospecha")
	if efectos.has("sed_congelada"):
		partes.append("la sed no sube durante el siguiente mapa")
	if efectos.has("patrullas_visibles"):
		partes.append("ves todas las patrullas de la zona")
	if efectos.has("pendiente"):
		partes.append("(aún sin efecto: %s)" % efectos.pendiente)
	return " · ".join(partes) if not partes.is_empty() else "Nada"
