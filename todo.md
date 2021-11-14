# TODO 11/11/21
- [x] Basic input
- [x] Bounding boxes and collision detection
- [x] Gravity (mostly to play with collisions)


# TODO 11/13/21
- [x] Clean up last stream's work
- [x] Simple environment tiles
- [x] Switch to OpenGL 4.5
- [ ] Start on level editor
	- [x] draw lines (show cursor position) | Debug shader?
	- [x] draw cursor snapped to grid
	- [x] draw specific textures (tilesets)
	- [ ] select a tile
	- [ ] click and drag to "draw" tiles snapped to a grid
	- [ ] define bounding boxes for the environment
	- [ ] de/serialize level data
	- [ ] Save/load from file


# TODO 11/14/21
- [x] Review what we did last time
- [ ] Basic level editor
	- [x] select a tile
	- [x] click to add a tile
	- [x] drag to "draw" tiles snapped to a grid
	- [x] right click to delete
	- [x] break sprite -> bbox 1:1 relationship
	- [ ] define bounding boxes for the environment
	- [ ] de/serialize level data
	- [ ] Save/load from file
	- [ ] stretch goal: undo/redo


# TODO ?
- [ ] Create some openGL helpers around VAO/VBO/EBO since we're starting to create/manage them in different files
- [ ] Matrices!
- [ ] Orthographic projection matrix
- [ ] Load multiple textures


# TODO faaar in the future
- [ ] Metal renderer (thanks Apple)
- [ ] Vulkan renderer (replace OpenGL)?
