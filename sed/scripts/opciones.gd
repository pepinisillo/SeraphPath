class_name Opciones
## Opciones del jugador: volumen y pantalla completa. Se guardan en user://opciones.cfg y se
## aplican al arrancar (lo hace la expedición, el autoload).

const ARCHIVO := "user://opciones.cfg"
static var archivo := ARCHIVO # las pruebas usan otro
const PASO_VOLUMEN := 10

static var volumen := 80 # %
static var pantalla_completa := false


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(archivo) == OK:
		volumen = cfg.get_value("opciones", "volumen", volumen)
		pantalla_completa = cfg.get_value("opciones", "pantalla_completa", pantalla_completa)
	aplicar()


static func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("opciones", "volumen", volumen)
	cfg.set_value("opciones", "pantalla_completa", pantalla_completa)
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
