shader_type canvas_item;
render_mode blend_mix;

uniform float time : hint_range(0.0, 3600.0) = 0.0;
uniform float curvature : hint_range(0.0, 0.15) = 0.06;
uniform float scanline_opacity : hint_range(0.0, 0.3) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float phosphor_bloom : hint_range(0.0, 0.08) = 0.035;
uniform vec2 viewport_size = vec2(720.0, 1280.0);

vec2 barrel_distort(vec2 uv, float strength) {
	vec2 centered = uv - 0.5;
	float dist = dot(centered, centered);
	return uv + centered * dist * strength;
}

void fragment() {
	vec2 uv = UV;

	vec2 distorted = barrel_distort(uv, curvature);

	if (distorted.x < 0.0 || distorted.x > 1.0 || distorted.y < 0.0 || distorted.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	vec4 screen_color = texture(SCREEN_TEXTURE, distorted);

	float scanline = sin((distorted.y * viewport_size.y) * 3.14159265 * 2.0 + time * 4.0) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_opacity);

	float vignette = 1.0 - length(uv - 0.5) * vignette_strength * 1.4;
	vignette = clamp(vignette, 0.0, 1.0);

	float brightness = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 bloom = screen_color.rgb * brightness * phosphor_bloom * 2.5;

	vec3 result = screen_color.rgb * scanline * vignette;
	result += bloom;
	result = mix(result, screen_color.rgb, 0.35);

	float rgb_shift = 0.8;
	result.r *= 0.96 + rgb_shift * 0.04;
	result.g *= 0.98;
	result.b *= 0.94 + rgb_shift * 0.06;

	COLOR = vec4(result, screen_color.a);
}