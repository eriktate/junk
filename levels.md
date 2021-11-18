# Level Format

## Header
u32 - Tile Length (length of tiles not bytes)
u32 - Box Length (length of boxes not bytes)

## Tile (byte size = 20)
u32 - x coord
u32 - y coord
u32 - texture x coord
u32 - texture y coord
u32 - tileset ID

## Box (byte size = 16)
u32 - x coord
u32 - y coord
u32 - width
u32 - height
