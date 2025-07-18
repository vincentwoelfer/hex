@tool
class_name PhysicUtil

########################################################################
# Constants
########################################################################
const LARGE_DIST := 100.0


########################################################################
# Composite Helper Functions
########################################################################
## Performs a shape cast downwards to find the shapes height on the surface
static func get_shape_height_on_map_surface(pos: Vector3, shape: Shape3D, mask : int = Layers.PHY_TERRAIN_AND_STATIC) -> Vector3:
	pos.y = MapGeneration.get_hex_tile_height_at_map_pos(pos)
	
	var origin := pos + Vector3.UP * LARGE_DIST / 2.0
	var motion := Vector3.DOWN * LARGE_DIST
	var t := shape_motion_sweep(origin, motion, shape, mask)

	# Offset upwards by half the shape height
	var shape_height := get_shape_height(shape)
	return (origin + motion * t) - (Vector3.UP * shape_height / 2.0)


## Performs a raycast downwards to find the height on the surface
static func get_raycast_height_on_map_surface(pos: Vector3, mask : int = Layers.PHY_TERRAIN_AND_STATIC) -> Vector3:
	pos.y = MapGeneration.get_hex_tile_height_at_map_pos(pos)
	
	var origin := pos + Vector3.UP * LARGE_DIST / 2.0
	var motion := Vector3.DOWN * LARGE_DIST
	return raycast_first_hit_pos(origin, origin + motion, mask)


## Complex function to find a spawn position for the shape close to origin in a spiral pattern.
## The position is optionally matched to the navmesh and the height is adjusted to the map surface.
static func find_closest_valid_spawn_pos(origin: Vector3, shape: Shape3D,
										r_step: float, r_max: float,
										match_to_navmesh: bool = true,
										mask: int = Layers.PHY.ALL) -> Vector3:
	origin.y = MapGeneration.get_hex_tile_height_at_map_pos(origin)

	if match_to_navmesh:
		origin = NavigationServer3D.map_get_closest_point(Util.get_map(), origin)

	origin = get_shape_height_on_map_surface(origin, shape)

	# Offset upwards to avoid collision with the ground
	var shape_height := get_shape_height(shape)
	origin += Vector3.UP * shape_height / 2.0

	# Find a valid spawn position - this takes all collision layers into account
	var spawn_pos := find_closest_free_position_radial_pattern(origin, shape, r_step, r_max, mask)

	if match_to_navmesh:
		spawn_pos = NavigationServer3D.map_get_closest_point(Util.get_map(), spawn_pos)

	# Find final height	
	spawn_pos = get_shape_height_on_map_surface(spawn_pos, shape)
	return spawn_pos


## Performs shape collision tests in a planar radial pattern and returns closest found free position
# TODO maybe implement variants of this using raycasts or shape sweeps. This could also improve quality on slopes
static func find_closest_free_position_radial_pattern(origin: Vector3, shape: Shape3D,
													  r_step: float, r_max: float,
													  mask: int = Layers.PHY_TERRAIN_AND_STATIC) -> Vector3:
	# DebugVis3D.visualize_shape(origin, shape, Color.RED, 5.0)
	# Check if initial position is free
	if shape_collision_test(origin, shape, mask):
		return origin

	# Spiral Parameters
	var angular_step := deg_to_rad(60)

	var r := r_step
	var angle: float = 0.0

	while r <= r_max:
		while angle < TAU:
			var pos := origin + Util.vec3_from_radius_angle(r, angle)
			# DebugVis3D.visualize_shape(pos, shape, Color.RED, 5.0)
			if shape_collision_test(pos, shape, mask):
				return pos

			angle += angular_step
		r += r_step
		angle = 0.0

	# No valid position found
	return Vector3.INF


########################################################################
# Ray Collision Queries
########################################################################
static func raycast(from: Vector3, to: Vector3, mask: int = Layers.PHY.ALL) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.hit_from_inside = true
	var result := Util.get_space_state().intersect_ray(query)

	# Debug shape
	# var color := Color(1, 0, 0) if hit else Color(0, 0, 1)
	# DebugVis3D.spawn_mesh(Vector3.ZERO, DebugVis3D.line_mesh(from, to, DebugVis3D.material(color, true)), Util.get_scene_root())

	return result

static func raycast_test(from: Vector3, to: Vector3, mask: int = Layers.PHY.ALL) -> bool:
	return not raycast(from, to, mask).is_empty()

static func raycast_first_hit_pos(from: Vector3, to: Vector3, mask: int = Layers.PHY.ALL) -> Vector3:
	var result := raycast(from, to, mask)
	if result.is_empty():
		return Vector3.INF
	return result["position"]


static func raycast_from_camera(mask: int = Layers.PHY.ALL) -> Dictionary:
	var camera := Util.get_global_cam(Util.get_scene_root())
	var mouse_pos := camera.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * 1000.0
	var result := PhysicUtil.raycast(ray_origin, ray_end, mask)
	return result


########################################################################
# Point Collision Queries
########################################################################
## Perform a point collision test at the given position (in world space)
static func point_collision_test(pos: Vector3, mask: int = Layers.PHY.ALL) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.position = pos
	query.collision_mask = mask
	var hit := not Util.get_space_state().intersect_point(query, 1).is_empty()

	# Debug shape
	# var color := Color(1, 0, 0) if hit else Color(0, 0, 1)
	# DebugVis3D.spawn_mesh(pos, DebugVis3D.sphere_mesh(0.15, DebugVis3D.material(color, true)), Util.get_scene_root())

	return hit

########################################################################
# Shape Collision Queries
########################################################################
static func shape_collision_test(pos: Vector3, shape: Shape3D, mask: int = Layers.PHY.ALL) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.set_shape(shape)
	query.transform = Transform3D(Basis.IDENTITY, pos)
	query.collision_mask = mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := not Util.get_space_state().intersect_shape(query, 1).is_empty()

	# var sp_green := DebugVis3D.cylinder(check_radius, check_height, DebugVis3D.mat(Color(Color.GREEN, 0.5), false))
	# var sp_red := DebugVis3D.cylinder(check_radius, check_height, DebugVis3D.mat(Color(Color.RED, 0.5), false))
	# if is_free:
	# 	Util.delete_after(5.0, DebugVis3D.spawn(pos + check_height_offset * 2.0, sp_green))
	# else:
	# 	Util.delete_after(5.0, DebugVis3D.spawn(pos + check_height_offset, sp_red))

	return hit

## Perform shape motion sweep, returns t [0, 1] of the motion
static func shape_motion_sweep(origin: Vector3, motion: Vector3, shape: Shape3D, mask: int = Layers.PHY.ALL) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.set_shape(shape)
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = motion
	query.collision_mask = mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return Util.get_space_state().cast_motion(query)[0]


## Perform shape motion sweep, returns true/false if the motion is free
static func shape_motion_sweep_test(origin: Vector3, motion: Vector3, shape: Shape3D, mask: int = Layers.PHY.ALL) -> bool:
	return shape_motion_sweep(origin, motion, shape, mask) >= 1.0


## Perform shape motion sweep, returns the final free position
static func shape_motion_sweep_final_free_pos(origin: Vector3, motion: Vector3, shape: Shape3D, mask: int = Layers.PHY.ALL) -> Vector3:
	var t := shape_motion_sweep(origin, motion, shape, mask)
	return origin + motion * t


########################################################################
# SHAPE UTILITY STUFF
########################################################################

static func get_shape_height(shape: Shape3D) -> float:
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * 2.0
	elif shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height
	elif shape is CylinderShape3D:
		return (shape as CylinderShape3D).height
	elif shape is BoxShape3D:
		return (shape as BoxShape3D).size.y
	elif shape is ConcavePolygonShape3D:
		pass
	elif shape is ConvexPolygonShape3D:
		pass

	push_error("Shape type not supported!")
	return 0.0

static func get_shape_radius(shape: Shape3D) -> float:
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	elif shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	elif shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	elif shape is BoxShape3D:
		var box_shape: BoxShape3D = shape as BoxShape3D
		return 0.5 * sqrt(box_shape.size.x * box_shape.size.x + box_shape.size.z * box_shape.size.z)
	elif shape is ConcavePolygonShape3D:
		pass
	elif shape is ConvexPolygonShape3D:
		pass

	push_error("Shape type not supported!")
	return 0.0
