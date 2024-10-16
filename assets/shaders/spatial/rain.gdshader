shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 albedo : source_color;

void vertex() {    
    VERTEX.xz = normalize(INV_VIEW_MATRIX[0].xz) * VERTEX.x + normalize(INV_VIEW_MATRIX[2].xz) * VERTEX.z;    
}

void fragment() {
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
}

void light() {
    vec3 lightN = NORMAL;
    if (dot( lightN, LIGHT ) < 0.0)
    {
        // reverse the normal if it's facing away from the light
        lightN = -1.0 * lightN;
    }
    DIFFUSE_LIGHT += clamp(dot(lightN, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO;
}
