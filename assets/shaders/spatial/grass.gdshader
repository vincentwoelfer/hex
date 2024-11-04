shader_type spatial;
render_mode cull_disabled, ensure_correct_normals;

global uniform lowp float global_wind_direction;
global uniform lowp float global_wind_strength;
global uniform lowp float global_world_wetness;
global uniform lowp float global_camera_view_direction;
global uniform lowp vec3 global_player_position; // Only for crushing grass directly below player

group_uniforms GrassProperties;
uniform lowp float clumping_factor : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D clump_noise;
uniform lowp float wind_speed : hint_range(0.0, 5.0) = 2.0;
uniform sampler2D wind_noise;

group_uniforms GrassColor;
//instance uniform lowp vec3 base_color : source_color = lowp vec3(0.05,0.2,0.01);
instance uniform lowp vec3 base_color : source_color = vec3(0.05, 0.15, 0.05);
instance uniform lowp vec3 tip_color : source_color = vec3(0.5, 0.5, 0.1);

uniform lowp vec3 subsurface_scattering_color : source_color = vec3(1.0, 0.75, 0.1);

uniform lowp vec3 rand_color_variation_target : source_color = vec3(0.7, 0.45, 0.1);
varying lowp float rand_col_factor;

group_uniforms GrassSize;
instance uniform lowp float height_mod: hint_range(0.0, 5.0) = 1.0;

// Source: https://www.shadertoy.com/view/Xt3cDn
// -> [0,1]
lowp float hash12(vec2 x) {
	uvec2 p = floatBitsToUint(x);
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U*((p.x) ^ (p.y >> 3U));
    uint n = h32 ^ (h32 >> 16U);
    return float(n) * (1.0 / float(0xffffffffU));
}

mat3 rotate_x(lowp float angle) {
  lowp float s = sin(angle), c = cos(angle);
  return mat3(vec3(1, 0, 0), vec3(0, c, s), vec3(0, -s, c));
}

mat3 rotate_y(lowp float angle) {
  lowp float s = sin(angle), c = cos(angle);
  return mat3(vec3(c, 0, -s), vec3(0, 1, 0), vec3(s, 0, c));
}

mat4 modelview_inverse(mat4 modelview_matrix) {
	lowp mat3 rotation_inv = transpose(mat3(modelview_matrix));
	lowp mat4 modelview_inv = mat4(rotation_inv);
	modelview_inv[3] = vec4(-(rotation_inv * modelview_matrix[3].xyz), 1.0);
	return modelview_inv;
}

// 0.0 -> 0.0
// 0.5 -> 0.125
// 1.0 -> 1.0
lowp float ease_in_quartic(lowp float x) {
	lowp float a = x*x;
	return a*a;
}

// 0.0 -> 0.0
// 0.5 -> 0.875
// 1.0 -> 1.0
lowp float ease_out_quartic(lowp float x) {
	lowp float a = 1.0 - x;
	lowp float b = a*a;
	return 1.0 - b*b;
}

void vertex() {
	lowp float height_factor = 1.0 - UV.y;
	lowp float hash0 = hash12(NODE_POSITION_WORLD.xz);
	lowp float hash1 = hash12(-NODE_POSITION_WORLD.zx);
	// lowp float clump0 = texture(clump_noise, NODE_POSITION_WORLD.zx*0.01).x;   // -> rand_height_factor
	// lowp float clump1 = texture(clump_noise, NODE_POSITION_WORLD.zx*0.5).x;   // -> wind_strength_turbulence
	// lowp float clump2 = texture(clump_noise,-NODE_POSITION_WORLD.xz*0.035).x; // -> turn_angle_base
	// lowp float clump3 = texture(clump_noise,-NODE_POSITION_WORLD.xz*0.03).x;  // -> color

	lowp float clump0 = texture(clump_noise, NODE_POSITION_WORLD.zx*0.03).x;   // -> rand_height_factor
	lowp float clump1 = clump0;
	lowp float clump2 = clump0;
	lowp float clump3 = 1.0 - clump0;

	// Random color variation
	rand_col_factor = ease_in_quartic(smoothstep(0.4, 0.8, clump3)) * 0.15 * step(0.6, hash1);

	// --- GRASS BLADE HEIGHT/WIDTH ---
	lowp vec3 camera_offset = NODE_POSITION_WORLD - CAMERA_POSITION_WORLD;
	lowp float camera_distance = length(camera_offset);

	// Random height offset factor between 0.4 and 2.0
	// hash0 = pure random, clump = clump texture
	// the last value interpolates the random factor between hash0 and clump
	//lowp float rand_height_factor = mix(0.2, 2.0, mix(hash0, clump0, 0.5));
	lowp float rand_height_factor = mix(0.2, 2.0, clump0);

	// Offset width by random factor
	lowp float rand_width_factor = mix(0.5, 1.2, hash1);

	// The further the distance from the camera, the thicker the grass blade will
	// appear to account for decreasing density with LOD
	const lowp float max_dist_thicken_factor = 18.0;
	const lowp float thicken_dist_scaling = 0.028; // Higher -> thicker earlier. OG = 0.033
	VERTEX.x *= 1.0 + min(ease_in_quartic(thicken_dist_scaling * camera_distance), max_dist_thicken_factor);

	// Apply offsets and scale everything down by 0.5
	VERTEX.y *= 0.5 * height_mod * rand_height_factor;
	VERTEX.x *= 1.0 * rand_width_factor; // Thickness
	// Z should have no effect since grass is flat
	lowp vec3 vertex_model = VERTEX; // Vertex in model space before any rotations are applied

	// --- Player crushing grass --- -> DISABLED For now
	// crushed_factor = 1 -> on player, max crushed
	// lowp float player_distance = length(global_player_position.xz - NODE_POSITION_WORLD.xz);
	// lowp float crushed_factor = clamp(1.0 - player_distance*player_distance*0.5, 0.0, 1.0);
	lowp float crushed_factor = 0.0;

	// --- Random turning based on hash0 and clumping ---
	lowp float turn_angle_base = (mix(-0.15, 0.15, hash0) + clump2*clumping_factor)*TAU;

	// Modify base angle to not point at camera
	// lowp float angle_diff = turn_angle_base - global_camera_view_direction;
    // angle_diff = mod(angle_diff + PI, TAU) - PI; // Normalize the angle between -π and π
	// const lowp float threshold = PI / 6.0;
	// if (abs(angle_diff) < threshold) {
	// 	lowp float force = (threshold - abs(angle_diff)) * sign(hash1);
	// 	turn_angle_base += force;
	// 	crushed_factor = 0.25;
	// }

	// --- WIND ---
	lowp float wind_direction = texture(wind_noise, NODE_POSITION_WORLD.zx*0.005/wind_speed + TIME*0.005*wind_speed).x*TAU;
	//wind_direction = global_wind_direction;

	lowp float wind_strength = mix(0.1, 1.0, texture(wind_noise, NODE_POSITION_WORLD.xz*0.025/wind_speed + TIME*0.05).x);
	COLOR = vec4(1.0, 0.0, 0.0, 1.0);

	wind_strength *= wind_strength; // quadratic
	wind_strength *= mix(0.6, 0.95, hash1);
	wind_strength *= wind_speed * global_wind_strength; // weight by global wind strength

	// Rotate between base_angle and wind_direction based on wind strength
	lowp float final_rotation_dir = mix(turn_angle_base, wind_direction, wind_strength);
	lowp mat3 grass_rotate = rotate_y(final_rotation_dir);

	// TODO multiply this by "stiffness" to model more stable/weak grass variations
	lowp float bend_angle_base = mix(0.05, 0.25, hash1*0.5 + rand_height_factor*0.1) * PI * height_factor;
	bend_angle_base *= mix(1.0, 15.0, crushed_factor);

	// We sample wind noise identically to strength, but with a time offset based on
	// the height to simulate the turbulence as the grass blade shakes from the wind.
	lowp float wind_strength_turbulence = mix(0.25, 1.0, texture(wind_noise, NODE_POSITION_WORLD.xz*0.025/wind_speed + (TIME + height_factor*height_factor*0.25)*0.05).x);
	wind_strength_turbulence *= wind_strength_turbulence;
	wind_strength_turbulence *= mix(0.16, 0.25*hash0, clump1)*PI * min(wind_speed, 1.0);
	lowp mat3 grass_bend = rotate_x(mix(0.45*PI, bend_angle_base + wind_strength_turbulence, 1.0 - crushed_factor));

	// Apply rotations to the vertex and normal
	lowp mat3 grass_rotation_matrix = grass_rotate * grass_bend;
	VERTEX = grass_rotation_matrix * VERTEX;
	NORMAL = grass_rotation_matrix * NORMAL;

	// --- VIEW SPACE THICKENING ---
	// Grass blades perpendicular to the camera will appear very thin. We stretch
	// these blades horizontally in view space to make them appear more 'full'.
	lowp vec3 vertex_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lowp vec3 normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	lowp float dot_nv = dot(normalize(normal_world), normalize(camera_offset));

	// The direction of thickening in view space will be based on the x-coordinate
	// sign of the vertex position in model space. We multiply by a large factor
	// and round to correct for precision errors from positions at x=0.
	lowp float thicken_direction = sign(round((grass_rotate * vertex_model).x * 1e6));

	// TODO Use thicken-direction to thicken when grass is bending towards view aswell
	//  TOOD -> Maybe use for bending aswell???
	// 1  = Looking directly at it            -> 0
	// 0  = Perpendicular                     -> 1
	// -1 = Face is facing away from camera   -> 0.75
	lowp float dot_nv_fac = 1.0 - abs(dot_nv);
	lowp float thicken_factor = ease_in_quartic(dot_nv_fac) * abs(vertex_model.x) * 1.5;	// Custom factor to make it even thicker
	
	// TODO INclude bending (see above): lowp float thicken_factor = ease_in_quartic(1.0 - abs(dot_nv)) * abs(vertex_model.x) * 1.75;

	vertex_view.x += thicken_factor * thicken_direction;
	VERTEX = (modelview_inverse(MODELVIEW_MATRIX) * vec4(vertex_view, 1.0)).xyz;
}

void fragment() {
	lowp float fog_factor = exp(-length(VERTEX)*0.017);
	lowp mat3 normal_offset = rotate_y(mix(-0.12, 0.12, UV.x)*PI);
	NORMAL = normalize(normal_offset * NORMAL);

	// Blend grass normal with terrain normal based on distance (assumes up is 0,1,0!)
	NORMAL = mix(vec3(0,1,0), NORMAL, fog_factor);

	lowp float height_factor = 1.0 - UV.y;
	ALBEDO = mix(base_color, tip_color, ease_in_quartic(height_factor));
	ALBEDO = mix(ALBEDO, rand_color_variation_target, rand_col_factor); // Add random spots
	ALBEDO *= mix(0.1, 1.0, height_factor*height_factor); // Fake AO (darkening near base)

	// Color becomes more uniform as distance increases
	ALBEDO = mix(mix(base_color, tip_color, 0.5)*0.5, ALBEDO, fog_factor);
	// wetness
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.8), global_world_wetness);

	// --- ROUGHNESS --- Less rough for upper part, less if wet
	lowp float roughness_min = 0.7 * (1.0 - global_world_wetness * 0.3);

	ROUGHNESS = mix(1.0, roughness_min, ease_out_quartic(height_factor));

	// --- SPECULAR --- 
	SPECULAR = mix (0.5, 0.7, global_world_wetness);

	ANISOTROPY = 0.85;

	// TODO
	//https://github.com/godotengine/godot/issues/79859
}

void light() {
	lowp float sgn = 1.0;
    if (dot( NORMAL, LIGHT ) <= 0.0)
    {
		// reverse the normal if it's facing away from the light
		sgn = -1.0;
    }

	lowp float diffuse_factor = pow(4.0, dot(sgn*NORMAL, LIGHT)) / 4.0; // Diffuse never drops to 0 to simulate ambient bounces
	lowp float sss_factor = max(-dot(VIEW, LIGHT), 0.0) * 0.5;

	DIFFUSE_LIGHT += (diffuse_factor + sss_factor*subsurface_scattering_color) * ATTENUATION * LIGHT_COLOR;
	SPECULAR_LIGHT *= diffuse_factor;


}
