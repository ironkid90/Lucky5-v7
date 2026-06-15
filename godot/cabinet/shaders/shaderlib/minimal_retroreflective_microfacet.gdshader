// ============================================
// Shader from godotshaders.com
// ============================================
// Title: Minimal Retroreflective Microfacet
// Author: tentabrobpy
// License: MIT
// URL: https://godotshaders.com/shader/minimal-retroreflective-microfacet/
// ============================================

/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */

shader_type spatial;

// --- Compile options ---

// Alpha scissor - Useful for road signs
// Texture repeat - Should be disabled on alpha clipped road signs to prevent artifacts
// Masking - Retroreflective mask texture, useful for pavement markings and safety vests
// PBR maps - Roughness and metallic textures, may be unnecessary for road signs

//#define ALPHA_SCISSOR
#define TEXTURE_REPEAT
#define MASKING
#define PBR_MAPS

// --- Uniforms ---

#ifdef TEXTURE_REPEAT
uniform sampler2D albedo_map : source_color, repeat_enable;
#else
uniform sampler2D albedo_map : source_color, repeat_disable;
#endif // TEXTURE_REPEAT

uniform vec3 tint : source_color = vec3(1.0);

#ifdef MASKING
group_uniforms Retroreflection;
#ifdef TEXTURE_REPEAT
uniform sampler2D retroreflective_map : hint_default_white, repeat_enable;
#else
uniform sampler2D retroreflective_map : hint_default_white, repeat_disable;
#endif // TEXTURE_REPEAT
uniform float mask_threshold : hint_range(0.0, 1.0) = 0.1;
group_uniforms;
#endif // MASKING

#ifdef PBR_MAPS
group_uniforms Roughness;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
#ifdef TEXTURE_REPEAT
uniform sampler2D roughness_map : hint_roughness_gray, repeat_enable;
#else
uniform sampler2D roughness_map : hint_roughness_gray, repeat_disable;
#endif  // TEXTURE_REPEAT
group_uniforms;
group_uniforms Metallic;
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
#ifdef TEXTURE_REPEAT
uniform sampler2D metallic_map : hint_default_white, repeat_enable;
#else
uniform sampler2D metallic_map : hint_default_white, repeat_disable;
#endif // TEXTURE_REPEAT
group_uniforms;
#else
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
#endif // PBR_MAPS

#ifdef ALPHA_SCISSOR
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
#endif // ALPHA_SCISSOR

group_uniforms NormalMap;
#ifdef TEXTURE_REPEAT
uniform sampler2D normal_map : hint_normal, repeat_enable;
#else
uniform sampler2D normal_map : hint_normal, repeat_disable;
#endif // TEXTURE_REPEAT
uniform float normal_map_depth = 1.0;
group_uniforms;

group_uniforms UV;
uniform vec2 tiling = vec2(1.0, 1.0);
uniform vec2 offset = vec2(0.0, 0.0);
group_uniforms;

// --- Vertex function ---

void vertex() {
	UV = UV * tiling + offset;
}

// --- Fragment function ---

#ifdef MASKING
varying float retroreflective_mask;
#endif // MASKING

void fragment() {
	NORMAL_MAP = texture(normal_map, UV).xyz;
	NORMAL_MAP_DEPTH = normal_map_depth;

	vec4 albedo_texture = texture(albedo_map, UV);
	ALBEDO = albedo_texture.rgb * tint;

#ifdef PBR_MAPS
	ROUGHNESS = texture(roughness_map, UV).r * roughness;
	METALLIC = texture(metallic_map, UV).r * metallic;
#else
	ROUGHNESS = roughness;
	METALLIC = metallic;
#endif // PBR_MAPS

#ifdef ALPHA_SCISSOR
	ALPHA = albedo_texture.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
#endif // ALPHA_SCISSOR

#ifdef MASKING
	retroreflective_mask = texture(retroreflective_map, UV).r;
#endif // MASKING
}

// --- Lighting ---

float D_GGX(float cos_theta_m, float alpha) {
	float a = cos_theta_m * alpha;
	float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
	return k * k * (1.0 / PI);
}

float V_GGX(float NdotL, float NdotV, float alpha) {
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

float SchlickFresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

vec3 F0(float metalness, float specular, vec3 albedo) {
	float dielectric = 0.16 * specular * specular;
	return mix(vec3(dielectric), albedo, vec3(metalness));
}

void light() {
	// Minimal Retroreflective Microfacet - Replace V with V'
	vec3 Vp = -VIEW + 2.0 * dot(VIEW, NORMAL) * NORMAL;

#ifdef MASKING
	vec3 V = retroreflective_mask > mask_threshold ? Vp : VIEW;
#else
	vec3 V = Vp;
#endif // MASKING

	vec3 f0 = F0(METALLIC, 0.5, ALBEDO);
	float NdotL = min(dot(NORMAL, LIGHT), 1.0);
	float cNdotL = max(NdotL, 0.0);
	float NdotV = dot(NORMAL, V);
	float cNdotV = max(NdotV, 1e-4);

	vec3 H = normalize(V + LIGHT);
	float cLdotH = clamp(dot(LIGHT, H), 0.0, 1.0);
	float cNdotH = clamp(dot(NORMAL, H), 0.0, 1.0);

	// Burley diffuse
	if (METALLIC < 1.0) {
		float diffuse_brdNL = 0.0;

		float FD90_minus_1 = 2.0 * cLdotH * cLdotH * ROUGHNESS - 0.5;
		float FdV = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotV);
		float FdL = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotL);

		diffuse_brdNL = (1.0 / PI) * FdV * FdL * cNdotL;
		DIFFUSE_LIGHT += LIGHT_COLOR * diffuse_brdNL * ATTENUATION;
	}

	// Schlick-GGX specular
	if (ROUGHNESS > 0.0) {
		vec3 specular_brdNL = vec3(0.0);

		float alpha_ggx = ROUGHNESS * ROUGHNESS;
		float D = D_GGX(cNdotH, alpha_ggx);
		float G = V_GGX(cNdotL, cNdotV, alpha_ggx);
		float cLdotH5 = SchlickFresnel(cLdotH);
		float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
		vec3 F = f0 + (f90 - f0) * cLdotH5;

		specular_brdNL = cNdotL * D * F * G;
		SPECULAR_LIGHT += specular_brdNL * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
	}
}