shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float global_world_wetness;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.225, 0.325, 0.55), global_world_wetness);
    SPECULAR = mix(0.3, 0.6, global_world_wetness);
    ROUGHNESS = mix(0.9, 0.5, global_world_wetness);
}
