shader_type canvas_item;

void fragment() {
	float gray = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR.rgb = vec3(gray);
}
