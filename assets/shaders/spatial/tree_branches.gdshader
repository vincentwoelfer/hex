shader_type spatial;
//render_mode depth_draw_opaque, cull_disabled;
render_mode depth_prepass_alpha, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 backlight_color: source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D texture_backlight : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
// in my workflow, roughness is stored as an alpha channel in normalmap texture
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap_anisotropic,repeat_enable;
//uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap_anisotropic,repeat_enable;

uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset;

uniform float alpha_scissor_threshold = 0.5;
uniform float normal_scale : hint_range(-16,16) = 1.0;
uniform float roughness : hint_range(0,1) = 1.0;
uniform float specular = 0.5;
uniform float max_distance = 100.0; // max distance across which the alpha clip threshold would be set to lower value, gives more leaf density to distant trees
uniform bool wind_enabled = true;
uniform bool is_branch = false; // true if transparency is present, trunk and leaves tend to be split into separate materials to avoid transparency sorting issues

// how the wind sin/cos frequencies are scaled for each of the timers ex. vec4(5000, 1500, 500, 5)
// global uniform vec4 tree_wind_size;
uniform vec4 tree_wind_size = vec4(5000, 1500, 500, 5);
// how strong is the wind: x - trunk, y - branches, z - leaves/alpha card branches, ex. vec3(5.0, 3, 0.125)
// global uniform vec3 tree_wind_power;
uniform vec3 tree_wind_power = vec3(5.0, 3, 0.125);

varying float view_distance;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_camera = INV_VIEW_MATRIX[3].xyz;
	vec4 tree_wind_timer = vec4(TIME) + vec4(NODE_POSITION_WORLD, 1.0);
	view_distance = distance(world_position, world_camera);
	
	if (wind_enabled) {
		vec3 world_normals = MODEL_NORMAL_MATRIX * NORMAL;
		
		vec3 global_wind = (world_position.xyz / tree_wind_size.x) + tree_wind_timer.x;
		global_wind = vec3(cos(global_wind.x), 0, sin(global_wind.z));
		global_wind.y = 1.0 + abs(dot(global_wind.x, global_wind.z));
		
		vec3 wind_force = (world_position / tree_wind_size.x) + tree_wind_timer.y - global_wind;
		wind_force = vec3(cos(wind_force.x), 0, sin(wind_force.y));
		
		vec3 wind_animate = wind_force * tree_wind_power.x * (world_position.y / tree_wind_size.y);
		float wind_variant = tree_wind_timer.z + (COLOR.y * 10.0);
		
		wind_animate.xz += vec2(cos(wind_variant), sin(wind_variant)) * COLOR.z * tree_wind_power.y * 0.1;
		
		vec3 wind_flutter = (world_position.xyz / tree_wind_size.w) + tree_wind_timer.w + COLOR.y;
		wind_animate += abs(world_normals) * sin( dot(wind_flutter, vec3(1)) * tree_wind_size.w ) * COLOR.x * (tree_wind_power.z / tree_wind_size.w);
		
		world_position += wind_animate * global_wind.y;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
	}
}


void fragment() {
	vec4 diffuse_alpha_tex = texture(texture_albedo, UV);
	vec4 normal_rough_tex = texture(texture_normal, UV);
	//float threshold_dist_modifier = 1.0 - min(view_distance / max_distance, 1.0);
	
	ALBEDO = diffuse_alpha_tex.rgb * albedo.rgb;
	ROUGHNESS = normal_rough_tex.a * roughness;
	SPECULAR = specular;
	NORMAL_MAP = normal_rough_tex.rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	
	if (is_branch) {
		ALPHA *= albedo.a * diffuse_alpha_tex.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;// * threshold_dist_modifier;
		BACKLIGHT = texture(texture_backlight, UV).rgb * backlight_color.rgb;
	}
}



// shader_type spatial;
// render_mode depth_prepass_alpha, cull_disabled, world_vertex_coords;

// uniform vec4 albedo : source_color;
// uniform sampler2D texture_albedo : source_color;
// uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001);

// uniform float roughness : hint_range(0.0, 1.0);

// uniform float specular : hint_range(0.0, 1.0, 0.01);
// uniform float metallic : hint_range(0.0, 1.0, 0.01);

// uniform vec4 backlight : source_color;
// uniform sampler2D texture_backlight : hint_default_black, filter_linear_mipmap, repeat_enable;

// uniform vec3 uv1_scale;
// uniform vec3 uv1_offset;
// uniform vec3 uv2_scale;
// uniform vec3 uv2_offset;

// uniform float sway_speed = 1.0;
// uniform float sway_strength = 0.55;
// uniform float sway_phase_len = 8.0;

// void vertex() {
// 	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
// 	float strength = COLOR.r * sway_strength;
//     VERTEX.x += sin(VERTEX.x * sway_phase_len * 1.123 + TIME * sway_speed) * strength;
//     VERTEX.y += sin(VERTEX.y * sway_phase_len + TIME * sway_speed * 1.12412) * strength;
//     VERTEX.z += sin(VERTEX.z * sway_phase_len * 0.9123 + TIME * sway_speed * 1.3123) * strength;
// }

// void fragment() {
// 	vec4 albedo_tex = texture(texture_albedo, UV);
// 	ALBEDO = albedo.rgb * albedo_tex.rgb;

// 	METALLIC = metallic;
// 	SPECULAR = specular;
// 	ROUGHNESS = roughness;
	
// 	ALPHA *= albedo.a * albedo_tex.a;
// 	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;

// 	// Backlight: Enabled
// 	vec3 backlight_tex = texture(texture_backlight, UV).rgb;
// 	BACKLIGHT = (backlight.rgb + backlight_tex);
// }
