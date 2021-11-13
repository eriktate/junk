- Quads
	- Describes what's actually rendered
	- Shipped to the GPU each frame
	- Needs to be contiguous
	- As small as possible
- Sprites
	- Describes visual element at a location
	- Mostly used to generate other things (quads, bounding boxes, etc.)
	- Could stand in as a general entity type? But that's probably a bad idea
	- Not sure if we'll be looping over sprites very often, except maybe to generate quads.
- Bounding Boxes
	- Describes the collision bounding boxes for every collidable in the game
	- Needs to store enough information to check for collisions
	- Needs to be small and contiguous, because we'll iterate over this a _lot_.
- Entities
	- Currently not described as a struct.
	- Really just an ID tying together sprites, bounding boxes, and quads.
	- _Could_ be described as a struct with pointers to the various components.
	- Could also just be bag of metadata that we can lookup in place of the sprite.
	- Might have to iterate over entities in order to run per-frame code (e.g. for AI)

We need some kind of entity manager to keep all of this straight. Even though these will be
represented as separate arrays, it would be cool if we could generally think about them as
singular entities most of the time. And then use the separate components during cache-heavy
workloads (like generating quads, or checking for collisions).
