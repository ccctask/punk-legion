shader_type spatial;
render_mode unshaded;
uniform bool cable_quay = false;
varying vec2 yard;
void vertex() {
	yard = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
float band(float value,float half_width) {
	float edge=max(fwidth(value),0.004);
	return 1.0-smoothstep(half_width,half_width+edge,abs(value));
}
void fragment() {
	vec2 p=yard;
	vec2 bay=abs(p);
	vec3 paint;
	float marks;
	if (cable_quay) {
		paint=vec3(0.31,0.46,0.48);
		// Inlaid cable trays make two quarter-turns between winders and the quay edges.
		vec2 corner=vec2(bay.x-5.6,bay.y-5.1);
		float turn=abs(length(corner)-1.28);
		float route=corner.x>=0.0 && corner.y<=0.0 ? turn : (corner.x<0.0 ? abs(corner.y+1.28) : abs(corner.x-1.28));
		marks=max(band(route,0.055),band(route-0.25,0.035))*step(3.5,bay.x);
		paint=mix(paint,vec3(0.54,0.68,0.64),marks*0.72);
		float grate=step(11.70,bay.x)*step(bay.x,12.5)*step(1.1,bay.y)*step(bay.y,6.4)*band(mod(p.y+0.20,0.40)-0.20,0.055);
		paint=mix(paint,vec3(0.22,0.35,0.37),grate);
	} else {
		paint=vec3(0.52,0.49,0.39);
		// Flush rail strips and sleepers follow the long axis of the loading bays.
		float section=step(3.2,bay.x)*step(bay.x,5.8)*step(2.55,bay.y)*step(bay.y,7.65);
		float ties=band(mod(p.y+0.32,0.64)-0.32,0.09)*section;
		float tracks=max(band(bay.x-3.85,0.055),band(bay.x-5.15,0.055))*section;
		paint=mix(paint,vec3(0.36,0.34,0.29),ties*0.85);
		paint=mix(paint,vec3(0.73,0.68,0.53),tracks);
		float striped=step(11.5,bay.x)*step(bay.x,12.15)*step(1.0,bay.y)*step(bay.y,6.15)*step(0.5,fract((p.x+p.y)*1.35));
		paint=mix(paint,vec3(0.83,0.69,0.37),striped*0.68);
	}
	// Fine stamped plates remain quieter than the central capture ring.
	vec2 edges=abs(mod(p+vec2(2.9,1.45),vec2(5.8,2.9))-vec2(2.9,1.45));
	float seam=max(band(edges.x-2.9,0.011),band(edges.y-1.45,0.011));
	paint=mix(paint,paint*0.83,seam);
	ALBEDO=OUTPUT_IS_SRGB ? paint : pow(paint,vec3(2.2));
}
