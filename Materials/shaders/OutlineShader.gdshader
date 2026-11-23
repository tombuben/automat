shader_type spatial;
// Inverted hull outline. Used as the material_overlay of item meshes (see item_outline.gd):
// the mesh is drawn a second time, back faces only, pushed outward in screen space.
// Because it is real geometry with a normal depth test, it hides behind walls and characters
// together with the item. The alpha of outline_color is ignored.
//
// Item materials write 1 into the stencil buffer (see item_outline.gd). The outline skips those
// pixels, so it only draws around the item and never across it where the shape curves inward.
// It is drawn in the transparent pass (ALPHA below) so every item has written the stencil first,
// and writes depth (depth_draw_always) so transparent sprites behind the item, like the automat's
// slot circles, can't paint over it when they happen to be sorted after it.

render_mode unshaded, cull_front, depth_draw_always, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Width in pixels on screen (the views are SubViewports sized in UI units).
// The automat camera is orthographic, the world view camera is perspective, so each view
// gets its own width: items in the hands are much bigger and need a thicker line to match.
// Width in the automat (orthographic cameras).
uniform float outline_size : hint_range(0.0, 40.0) = 10.0;
// Width in the world view (perspective cameras) for an item held in the hands. Further away
// the outline shrinks with the item, so a thrown item keeps the same look at any distance.
uniform float world_outline_size : hint_range(0.0, 40.0) = 16.0;
// Distance from the world camera at which world_outline_size applies: where items sit in the
// hands (WorldView/AimRotation/SpawnPosition). Closer than this it doesn't grow any further.
uniform float world_outline_distance : hint_range(0.05, 5.0) = 0.73;

void vertex() {
	// ItemOutline bakes a smoothed normal into CUSTOM0, shared by every split copy of a vertex,
	// so hard edges don't tear open. Fall back to the regular normal if a mesh wasn't baked.
	vec3 normal = length(CUSTOM0.xyz) > 0.5 ? CUSTOM0.xyz : NORMAL;
	vec3 view_normal = MODELVIEW_NORMAL_MATRIX * normal;

	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Run the normal through the projection too, so the direction matches the screen even when
	// the renderer flips Y (the Compatibility renderer does when drawing into a viewport).
	// Normalized, so the width doesn't depend on how much the surface faces the camera.
	// Normals pointing straight at or away from the camera are not pushed.
	vec2 screen_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy * VIEWPORT_SIZE;
	float len = length(screen_normal);
	vec2 dir = len > 0.0001 ? screen_normal / len : vec2(0.0);

	// Clip space spans 2 units across the screen, hence the 2.0.
	bool orthographic = PROJECTION_MATRIX[3][3] != 0.0;
	// clip_pos.w is the distance from a perspective camera.
	float size = orthographic ? outline_size
		: world_outline_size * min(1.0, world_outline_distance / max(clip_pos.w, 0.0001));
	clip_pos.xy += dir * size * 2.0 * clip_pos.w / VIEWPORT_SIZE;

	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = 1.0;
}
