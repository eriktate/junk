# Level Editor
1. Click tile
2. Click grid
3. Place tile

- Intercept mouse click
- Are we in the tileset?
	- Yes
		- Grab cursor_pos (_NOT_ the mouse_pos)
		- Convert to Vec2(u32) to get tex_coord
		- Save that away as selected_tile
	- No
		- Create a new sprite with the cursor_pos and selected_tile tex_coord

const LevelEditor = struct {
	selected_tile: Vec2(u32),
}
