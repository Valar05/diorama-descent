shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_tex : source_color, hint_default_black;

uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_noise_scale : hint_range(0.01, 8.0) = 1.0;
uniform sampler2D dissolve_noise_tex : hint_default_black;
uniform vec2 dissolve_noise_offset = vec2(0.0, 0.0);

uniform float glow_radius : hint_range(0.0, 64.0) = 6.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_gradient_remap = false;
uniform sampler2D gradient_tex : hint_default_white;

uniform float overall_size : hint_range(0.25, 3.0) = 1.0;
uniform float top_stretch : hint_range(-2.0, 2.0) = 0.0;
uniform float bottom_stretch : hint_range(-2.0, 2.0) = 0.0;
uniform float left_stretch : hint_range(-2.0, 2.0) = 0.0;
uniform float right_stretch : hint_range(-2.0, 2.0) = 0.0;
uniform float top_falloff : hint_range(0.01, 1.0) = 0.5;
uniform float bottom_falloff : hint_range(0.01, 1.0) = 0.5;
uniform float left_falloff : hint_range(0.01, 1.0) = 0.5;
uniform float right_falloff : hint_range(0.01, 1.0) = 0.5;
uniform float black_threshold : hint_range(0.0, 0.5) = 0.05;

vec2 deform_uv(vec2 uv) {
	vec2 center = vec2(0.5, 0.5);

	float top_infl = clamp((1.0 - uv.y) / max(0.0001, top_falloff), 0.0, 1.0);
	float bottom_infl = clamp(uv.y / max(0.0001, bottom_falloff), 0.0, 1.0);
	float left_infl = clamp((1.0 - uv.x) / max(0.0001, left_falloff), 0.0, 1.0);
	float right_infl = clamp(uv.x / max(0.0001, right_falloff), 0.0, 1.0);

	float sx = 1.0;
	sx += top_stretch * top_infl;
	sx += bottom_stretch * bottom_infl;

	float sy = 1.0;
	sy += left_stretch * left_infl;
	sy += right_stretch * right_infl;

	vec2 from_center = uv - center;
	from_center.x *= sx;
	from_center.y *= sy;
	vec2 out_uv = center + from_center;
	return clamp(out_uv, vec2(0.0), vec2(1.0));
}

void vertex() {
	VERTEX.xy *= overall_size;
}

void fragment() {
	vec2 uv = deform_uv(UV);
	vec4 base = texture(albedo_tex, uv);

	if (use_gradient_remap) {
		float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		if (luma < black_threshold) {
			base.a = 0.0;
		}

		vec3 grad_rgb = texture(gradient_tex, vec2(luma, 0.5)).rgb;
		if (grad_rgb != vec3(1.0)) {
			base.rgb = grad_rgb;
		}
	}

	float noise = texture(dissolve_noise_tex, uv / dissolve_noise_scale + dissolve_noise_offset).r;
	bool is_cut = (base.a > 0.1) && (noise < dissolve_progress);

	if (base.a <= 0.1 || is_cut) {
		float edge_sample = 0.0;
		if (glow_radius > 0.0) {
			vec2 px = vec2(1.0) / vec2(textureSize(albedo_tex, 0));
			float sample_offset = max(1.0, glow_radius * 0.5);
			for (int ix = -1; ix <= 1; ix++) {
				for (int iy = -1; iy <= 1; iy++) {
					if (ix == 0 && iy == 0) {
						continue;
					}
					vec2 offset_uv = clamp(uv + vec2(float(ix), float(iy)) * px * sample_offset, vec2(0.0), vec2(1.0));
					edge_sample = max(edge_sample, texture(albedo_tex, offset_uv).a);
				}
			}
		}

		if (edge_sample > 0.1) {
			ALBEDO = glow_color.rgb;
			ALPHA = glow_color.a * edge_sample;
			EMISSION = glow_color.rgb * clamp(glow_radius / 24.0, 0.0, 2.0);
		} else {
			ALPHA = 0.0;
		}
	} else {
		ALBEDO = base.rgb * modulate_color.rgb;
		ALPHA = base.a * modulate_color.a;
		EMISSION = glow_color.rgb * clamp(glow_radius / 64.0, 0.0, 1.0) * base.a;
	}
}
