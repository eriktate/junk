# TODO next stream
- [ ] Look at switching to orphanage serializer
- [ ] Use multiple textures
- [ ] Matrices!
- [ ] Orthographic projection matrix

# TODO 11/18/21
- [x] Basic level editor
	- [x] de/serialize level data
	- [x] Save/load from file

# TODO 11/16/21
- [ ] Basic level editor
	- [x] extend manager to create individual components
	- [x] toggle between tile mode and bbox mode
	- [x] remove bounding boxes
	- [x] clean up level editing stuff
	- [ ] de/serialize level data
	- [ ] Save/load from file


# TODO 11/15/21
- [ ] Basic level editor
	- [x] Fix panic from last stream
	- [x] define bounding boxes for the environment
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
	- [x] manager can debug-draw bounding boxes
	- [ ] define bounding boxes for the environment
	- [ ] de/serialize level data
	- [ ] Save/load from file


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


# TODO 11/11/21
- [x] Basic input
- [x] Bounding boxes and collision detection
- [x] Gravity (mostly to play with collisions)


# TODO ?
- [ ] Create some openGL helpers around VAO/VBO/EBO since we're starting to create/manage them in different files
- [ ] Level editor: undo/redo


# TODO faaar in the future
- [ ] Metal renderer (thanks Apple)
- [ ] Vulkan renderer (replace OpenGL)?
