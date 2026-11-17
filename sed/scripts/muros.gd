class_name Muros
extends TileMapLayer
## Capa de muros. Los que tapan a Mika se dibujan semitransparentes para no perderlo de vista.
## Es solo dibujo: se decide en píxeles de pantalla, comparando la figura de Mika con la de cada bloque.

const ALFA_TRANSPARENTE := 0.35
const ALTO_BLOQUE := 32.0 # px que sube el bloque sobre su rombo (ver arte/casillas.svg)
const ALCANCE := 3 # casillas alrededor de Mika que se revisan

var transparentes: Dictionary = {} # Vector2i -> true


## Marca como transparentes los bloques que quedan delante de Mika y tapan parte de su figura.
func actualizar_transparencia(pos_mika: Vector2, alto: float, ancho: float) -> void:
	var pies := Iso.a_pantalla(pos_mika)
	var figura := PackedVector2Array([
		pies + Vector2(-ancho / 2.0, -alto), pies + Vector2(ancho / 2.0, -alto),
		pies + Vector2(ancho / 2.0, 0.0), pies + Vector2(-ancho / 2.0, 0.0)])
	var base := Vector2i(floori(pos_mika.x), floori(pos_mika.y))
	var nuevas := {}
	for dy in range(-ALCANCE, ALCANCE + 1):
		for dx in range(-ALCANCE, ALCANCE + 1):
			var celda := base + Vector2i(dx, dy)
			if get_cell_source_id(celda) == -1:
				continue
			var centro := map_to_local(celda)
			if centro.y <= pies.y:
				continue # está detrás de Mika: el Y-sort ya la dibuja delante
			if not Geometry2D.intersect_polygons(figura, _silueta_bloque(centro)).is_empty():
				nuevas[celda] = true
	if nuevas != transparentes:
		transparentes = nuevas
		notify_runtime_tile_data_update()


func _silueta_bloque(centro: Vector2) -> PackedVector2Array:
	var medio_ancho := Config.ANCHO_CASILLA / 2.0
	var medio_alto := Config.ALTO_CASILLA / 2.0
	return PackedVector2Array([
		centro + Vector2(-medio_ancho, -ALTO_BLOQUE),
		centro + Vector2(0, -medio_alto - ALTO_BLOQUE),
		centro + Vector2(medio_ancho, -ALTO_BLOQUE),
		centro + Vector2(medio_ancho, 0),
		centro + Vector2(0, medio_alto),
		centro + Vector2(-medio_ancho, 0)])


func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return transparentes.has(coords)


func _tile_data_runtime_update(_coords: Vector2i, tile_data: TileData) -> void:
	tile_data.modulate = Color(1, 1, 1, ALFA_TRANSPARENTE)
