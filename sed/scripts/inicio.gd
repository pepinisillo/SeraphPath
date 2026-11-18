extends Pantalla
## Inicio: la escena del guion con Krul antes de la primera expedición, que se ve una sola vez
## (queda apuntado junto a los recuerdos). En las siguientes, la línea corta de la caja de Krul.
## Si no hay guion, la expedición empieza sin ella.

var dialogo: Dialogo


func construir() -> void:
	titulo("Sanguinem", Paleta.BLANCO_HUESO, 30)
	espacio()
	dialogo = Dialogo.new()
	columna.add_child(dialogo)
	dialogo.terminado.connect(_al_terminar)
	dialogo.empezar(expedicion.escena_de_inicio())


func _al_terminar() -> void:
	expedicion.marcar_inicio_visto()
	espacio()
	boton("Empezar la expedición", expedicion.ir_a_ruta).call_deferred("grab_focus")
