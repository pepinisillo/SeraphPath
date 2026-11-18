shader_type canvas_item;
// Quita color a lo que hay debajo (escenas del guion: «la pantalla casi no tiene color»).
uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float gris : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(pantalla, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(l), gris), 1.0);
}
