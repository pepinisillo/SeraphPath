class_name Config
## Todos los números del juego en un solo sitio. Valores iniciales: se ajustan jugando.
## Distancias en casillas, tiempos en segundos.

# --- Vista ---
const ANCHO_CASILLA := 128.0 # px en pantalla
const ALTO_CASILLA := 64.0 # px en pantalla

# --- Mika ---
const VELOCIDAD_MIKA := 5.5 # casillas/s
const VELOCIDAD_MIKA_SEDIENTO := 3.5 # casillas/s, con sed >= SED_TRAMO_LENTO
const RADIO_MIKA := 0.3 # casillas, para chocar con muros
const VIDA_MIKA := 12

# --- Impulso ---
const IMPULSO_DISTANCIA := 4.0
const IMPULSO_DURACION := 0.15
const IMPULSO_ENFRIAMIENTO := 1.5
const IMPULSO_SED := 8

# --- Tajo ---
const TAJO_DANO := 4
const TAJO_ALCANCE := 1.25
const TAJO_ENFRIAMIENTO := 0.4
const ATAQUE_ANGULO := 120.0 # grados delante de Mika en los que alcanzan Tajo y Golpe silencioso

# --- Golpe silencioso ---
const GOLPE_SILENCIOSO_ALCANCE := 1.25
const GOLPE_SILENCIOSO_ENFRIAMIENTO := 0.5

# --- Sangre ---
const BEBER_DURACION := 2.0
const VIAL_SED := -40
const VIAL_DURACION := 0.5

# --- Sed ---
const SED_MAX := 100
const SED_INICIAL := 30
const SED_INTERVALO := 3.0 # +1 cada tanto
const SED_POR_GOLPE := 3
const SED_TRAMO_REGENERA := 29 # 0–29 regenera
const SED_TRAMO_LENTO := 60 # 60–89 más lento y sin Sentidos
const SED_TRAMO_FRENESI := 90
const REGENERACION_INTERVALO := 6.0 # +1 de vida
const FRENESI_DURACION := 4.0

# --- Humanidad ---
const HUMANIDAD_INICIAL := 3

# --- Visión y detección enemiga ---
const VISION_ANGULO := 90.0 # grados
const VISION_ALCANCE := 5.0
const VISION_ALCANCE_SOMBRA := 2.5
const VISION_RAYOS := 48 # solo para dibujar el cono
const DETECCION_LEJOS := 1.2 # s para llenar
const DETECCION_CERCA := 0.3 # s para llenar
const DETECCION_DISTANCIA_CERCA := 3.0
const DETECCION_SOSPECHA := 0.5 # fracción del medidor que dispara la Sospecha
const DETECCION_VACIADO := 3.0 # s para vaciarse del todo cuando deja de verla
const RUIDO_RADIO := 4.0
const RUIDO_ONDA_DURACION := 0.4 # s que dura la onda dibujada
const SOSPECHA_DURACION := 6.0
const ALARMA_REFUERZO_INTERVALO := 10.0
const ALARMA_REFUERZOS_MAX := 4
const ALARMA_OLVIDO := 10.0

# --- Soldado ---
const SOLDADO_VIDA := 4
const SOLDADO_DANO := 2
const SOLDADO_GOLPE_INTERVALO := 1.0
const SOLDADO_VELOCIDAD_PATRULLA := 2.8
const SOLDADO_VELOCIDAD_ALARMA := 4.4
const SOLDADO_PAUSA_RUTA := 0.6 # s quieto en cada punto de la ruta
const SOLDADO_GIRO := 6.0 # rad/s al girar la mirada
const RADIO_SOLDADO := 0.3
const SOLDADO_GIRO_BUSQUEDA := 1.6 # rad/s al mirar alrededor del punto investigado
const SOLDADO_DISTANCIA_GOLPE := 0.9 # en alarma se detiene a esta distancia de Mika

# --- Prueba de la sed ---
const PRUEBA_SED_INTERVALO := 1.5
const PRUEBA_ECO_DISTANCIA := 1.5
const PRUEBA_ECO_VELOCIDAD := 1.9
