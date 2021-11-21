# TODO next steam
- [ ] Load tileset on level load (so we can edit levels)


# TODO 11/21/21
- [ ] Cleanup/Refactor stream!
	- [x] Make debug flag part of Debug struct.
	- [x] Remove unnecessary prints
	- [x] Make a 'global' Window to be used during callback fns.
	- [x] Leverage top level imports throughout
	- [x] Refactor checkCollision and checkCollisionRelative to return an optional entity ID instead of a bool.
	- [x] Make active texture IDs predictable (maybe define them as enums?)
	- [x] Add Atlas struct that can be derived from Texture (e.g. tex.makeAtlas()). Refactor Animations to use Atlases
	- [x] Fix duplicate naming in texture.zig
	- [x] Look into naming of texture fields (id vs name)
	- [ ] Move VAO generation and updating to the entity manager.
	- [ ] Look at switching to orphanage serializer.
	- [ ] Make a Player struct?
	- [ ] Handle animation state management in player struct.


# TODO 11/20/21
- [x] Telly walk/run animation
- [x] Telly jump/fall animation
- [x] Improve animation definitions
- [x] Basic animation state management
- [x] Use multiple textures
- [ ] Look at switching to orphanage serializer
- [ ] Matrices!
- [ ] Orthographic projection matrix
- [ ] Create the concept of an Atlas
- [ ] Refactor animations to use an atlas


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
