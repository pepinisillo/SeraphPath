class_name Opciones
## Opciones del jugador: volumen, pantalla completa y teclas. Se guardan en user://opciones.cfg
## y se aplican al arrancar (lo hace la expedición, el autoload).
## Teclas: se cambia la tecla principal de cada acción (la primera del teclado); las flechas y el
## mando no se tocan. Si la nueva ya la usa otra acción, las dos se intercambian.

const ARCHIVO := "user://opciones.cfg"
static var archivo := ARCHIVO # las pruebas usan otro
const PASO_VOLUMEN := 10

static var volumen := 80 # %
static var pantalla_completa := false
static var teclas := {} # acción -> physical_keycode elegido por el jugador

## Las acciones que se pueden cambiar, con su nombre para enseñarlo.
const ACCIONES := [
	["mover_arriba", "Arriba"], ["mover_abajo", "Abajo"], ["mover_izquierda", "Izquierda"], ["mover_derecha", "Derecha"],
	["tajo", "Tajo"], ["golpe_silencioso", "Golpe silencioso"], ["impulso", "Impulso"], ["beber", "Beber"],
	["vial", "Vial de Krul"], ["sentidos", "Sentidos"], ["espada", "Espada, bebe mi sangre"], ["pausa", "Pausa"],
]


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(archivo) == OK:
		volumen = cfg.get_value("opciones", "volumen", volumen)
		pantalla_completa = cfg.get_value("opciones", "pantalla_completa", pantalla_completa)
		teclas = cfg.get_value("opciones", "teclas", {})
	aplicar()
	for accion in teclas:
		_poner_tecla(accion, teclas[accion])


static func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("opciones", "volumen", volumen)
	cfg.set_value("opciones", "pantalla_completa", pantalla_completa)
	cfg.set_value("opciones", "teclas", teclas)
	cfg.save(archivo)


static func aplicar() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen, 0.001) / 100.0) if volumen > 0 else -80.0)
	AudioServer.set_bus_mute(bus, volumen <= 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED)


static func cambiar_volumen(cuanto: int) -> void:
	volumen = clampi(volumen + cuanto, 0, 100)
	aplicar()
	guardar()


static func cambiar_pantalla_completa() -> void:
	pantalla_completa = not pantalla_completa
	aplicar()
	guardar()



# --- Teclas ---

## La tecla principal de una acción (su primer evento de teclado), o 0.
static func tecla(accion: String) -> int:
	for evento in InputMap.action_get_events(accion):
		if evento is InputEventKey:
			return evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	return 0


## El nombre de la tecla principal de una acción, como se ve en el teclado («J», «Espacio»…).
static func nombre_tecla(accion: String) -> String:
	var codigo := tecla(accion)
	if codigo == 0:
		return "—"
	var visible := DisplayServer.keyboard_get_keycode_from_physical(codigo) if DisplayServer.get_name() != "headless" else codigo
	var nombre := OS.get_keycode_string(visible)
	match nombre:
		"Space": return "Espacio"
		"Escape": return "Esc"
		"Up": return "↑"
		"Down": return "↓"
		"Left": return "←"
		"Right": return "→"
		"Enter": return "Intro"
		"Shift": return "Mayús"
	return nombre


## Pone `codigo` como tecla principal de `accion`. Si ya la usaba otra acción, le da la vieja.
static func cambiar_tecla(accion: String, codigo: int) -> void:
	var vieja := tecla(accion)
	for par in ACCIONES:
		var otra: String = par[0]
		if otra != accion and tecla(otra) == codigo:
			_poner_tecla(otra, vieja)
			teclas[otra] = vieja
	_poner_tecla(accion, codigo)
	teclas[accion] = codigo
	guardar()


## Vuelve a las teclas de siempre.
static func restaurar_teclas() -> void:
	InputMap.load_from_project_settings()
	teclas = {}
	guardar()


static func _poner_tecla(accion: String, codigo: int) -> void:
	if not InputMap.has_action(accion):
		return
	var nueva := InputEventKey.new()
	nueva.physical_keycode = codigo
	var eventos := InputMap.action_get_events(accion)
	var cambiada := false
	InputMap.action_erase_events(accion)
	for evento in eventos:
		if evento is InputEventKey and not cambiada:
			InputMap.action_add_event(accion, nueva)
			cambiada = true
		else:
			InputMap.action_add_event(accion, evento)
	if not cambiada:
		InputMap.action_add_event(accion, nueva)
