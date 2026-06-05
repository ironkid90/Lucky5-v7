shader_type canvas_item;
render_mode blend_mix;

uniform float flip_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	vec2 uv = UV;
	float center_dist = abs(uv.x - 0.5) * 2.0;

	float flip_curve = sin(flip_progress * 3.14159265);
	float shadow = center_dist * flip_curve * shadow_intensity;

	vec4 tex_color = texture(TEXTURE, uv);
	vec4 shadow_color = mix(vec4(1.0), edge_color, shadow);

	COLOR = tex_color * shadow_color;

	float highlight = (1.0 - center_dist) * flip_curve * 0.12;
	COLOR.rgb += highlight * vec3(1.0, 0.95, 0.7);
}