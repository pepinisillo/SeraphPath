shader_type canvas_item;
// La sed se ve: la pantalla pierde color según sube la sed; en Frenesí solo queda el rojo.
// Los colores cálidos (ámbar de sospecha, rojo de sangre y alarma) no se apagan con la sed:
// el mundo frío se vuelve gris, pero las señales de peligro siguen leyéndose.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float desaturacion : hint_range(0.0, 1.0) = 0.0;
uniform float frenesi : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float gris = dot(c, vec3(0.299, 0.587, 0.114));
	float calidez = clamp((c.r - c.b) * 3.0, 0.0, 1.0);
	vec3 apagado = mix(c, vec3(gris), desaturacion * (1.0 - calidez));
	// En Frenesí, todo a gris salvo lo que ya es rojo.
	float rojez = clamp((c.r - max(c.g, c.b)) * 4.0, 0.0, 1.0);
	vec3 solo_rojo = mix(vec3(gris) * vec3(1.0, 0.82, 0.82), c, rojez);
	COLOR = vec4(mix(apagado, solo_rojo, frenesi), 1.0);
}
