extends Pantalla
## Refugio: al entrar, una línea del guion según la Humanidad (y la sed) de Mika, como escena
## con diálogo; después, el descanso.

var dialogo: Dialogo
var descansado := false
var _escena_vista := false


func construir() -> void:
	titulo("Refugio")
	if not _escena_vista:
		_escena_vista = true
		var golpes := Guion.refugio(expedicion.humanidad, expedicion.sed, expedicion.rng)
		if not golpes.is_empty():
			dialogo = Dialogo.new()
			add_child(dialogo)
			dialogo.terminado.connect(rehacer)
			dialogo.empezar(golpes)
			return
	if dialogo != null and not dialogo.acabado:
		return
	espacio()
	estado_expedicion()
	espacio()
	if descansado:
		texto("Descansaste. La vida vuelve a estar completa.", Paleta.TURQUESA)
		boton("Continuar", expedicion.completar_parada)
		return
	texto("Una cosa u otra: descansar o cuidar la espada.", Paleta.DETALLES, 16)
	boton("Curar toda la vida", _curar)
	boton("Mejorar la espada: elegir un filo", expedicion.ofrecer_filo.bind(expedicion.completar_parada))


func _curar() -> void:
	expedicion.curar()
	descansado = true
	rehacer()
