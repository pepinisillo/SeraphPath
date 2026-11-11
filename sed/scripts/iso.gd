class_name Iso
## Conversión entre coordenadas de casilla (lógica) y píxeles de pantalla (dibujo).
## Una posición continua p está dentro de la casilla floor(p); el centro de la casilla (c, f) es (c + 0,5, f + 0,5).
## Coincide con TileMapLayer.map_to_local() para forma isométrica y disposición DIAMOND_DOWN.


static func a_pantalla(p: Vector2) -> Vector2:
	var medio_ancho := Config.ANCHO_CASILLA / 2.0
	var medio_alto := Config.ALTO_CASILLA / 2.0
	return Vector2((p.x - p.y) * medio_ancho + medio_ancho, (p.x + p.y) * medio_alto)


static func a_casilla(pantalla: Vector2) -> Vector2:
	var u := (pantalla.x - Config.ANCHO_CASILLA / 2.0) / (Config.ANCHO_CASILLA / 2.0) # x - y
	var v := pantalla.y / (Config.ALTO_CASILLA / 2.0) # x + y
	return Vector2((u + v) / 2.0, (v - u) / 2.0)


## Convierte una dirección de pantalla (la del teclado o el stick) en dirección de casilla.
## Es un giro de 45°: «derecha» va a (1, −1), «arriba» a (−1, −1), «arriba y derecha» a (0, −1),
## de modo que las diagonales del teclado siguen los ejes isométricos del mapa.
static func direccion_desde_pantalla(d: Vector2) -> Vector2:
	return Vector2(d.x + d.y, d.y - d.x) / sqrt(2.0)
