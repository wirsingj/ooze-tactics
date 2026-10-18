extends RefCounted

# Index only hostile boundaries, so role assignment does not compare every
# living tile with every other tile as colonies fill the large board.
const CHUNK = 12
var buckets: Dictionary = {}
var hearts: Array[Vector2i] = []

func _init(state: GameState, owner: int) -> void:
	for block in state.blocks.values():
		if not state.are_hostile(owner,int(block.owner)):
			continue
		if block.core:
			hearts.append(block.pos)
		var boundary: bool = false
		for dir in BoardTopology.CARDINAL_STEPS:
			var neighbor: Dictionary = state.get_block_at(block.pos+dir)
			if neighbor.is_empty() or int(neighbor.owner)!=int(block.owner):
				boundary = true
				break
		if boundary:
			var key := Vector2i(block.pos.x/CHUNK,block.pos.y/CHUNK)
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(block)

func nearest(pos: Vector2i) -> Dictionary:
	var distance: int = 999999
	var target: Dictionary = {}
	var center := Vector2i(pos.x/CHUNK,pos.y/CHUNK)
	for y in range(-1,2):
		for x in range(-1,2):
			for block in buckets.get(center+Vector2i(x,y),[]):
				var d: int = absi(pos.x-block.pos.x)+absi(pos.y-block.pos.y)
				if d<distance:
					distance = d
					target = block
	if target.is_empty():
		for heart in hearts:
			distance = mini(distance,absi(pos.x-heart.x)+absi(pos.y-heart.y))
	return {"distance":distance,"block":target}
