shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;

// Body candidate for the static Character.shd rule:
// blendmode == "none" selects diffuseopaque.
uniform sampler2D diffuse_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D material_texture : filter_linear_mipmap, repeat_enable;


void fragment() {
    vec4 diffuse_sample = texture(diffuse_texture, UV);
    vec3 normal_object = texture(normal_texture, UV).rgb * 2.0 - 1.0;
    vec4 material_sample = texture(material_texture, UV);

    ALBEDO = diffuse_sample.rgb;
    METALLIC = 0.0;
    SPECULAR = material_sample.r;
    // The source uses Mtl.a as a gloss input. The inverse roughness mapping is
    // a Godot lighting approximation, not a claim of bit-identical rendering.
    ROUGHNESS = clamp(1.0 - material_sample.a, 0.0, 1.0);
    // Diffuse.program samples an object-space normal and rotates the light
    // direction into object space; it does not build a tangent-space TBN.
    // Godot's fragment NORMAL is view-space, so transform explicitly.
    NORMAL = normalize(
        (VIEW_MATRIX * MODEL_MATRIX * vec4(normal_object, 0.0)).xyz
    );
}
