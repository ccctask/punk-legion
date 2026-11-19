shader_type spatial;
render_mode unshaded;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// The GLB stores its painted palette in linear RGB.
	vec3 light_direction = normalize(vec3(-0.45, 0.90, -0.32));
	float facing = dot(normalize(world_normal), light_direction);
	float shade = mix(0.78, 1.02, smoothstep(-0.25, 0.75, facing));
	vec3 palette = pow(max(COLOR.rgb, vec3(0.0)), vec3(1.0 / 2.2));
	vec3 paint = mix(palette, vec3(1.0, 0.94, 0.85), 0.075) * shade;
	ALBEDO = OUTPUT_IS_SRGB ? paint : pow(paint, vec3(2.2));
}
