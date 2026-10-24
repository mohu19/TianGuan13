/*
 * Multitile vehicle hitbox
 * ========================
 * An oversized vehicle (one that is longer and/or wider than a single turf)
 * cannot express its collision, its "is the way ahead clear?" test and its
 * damage intake on one turf. [/obj/hitbox] is the unit that owns all three:
 * an invisible, dense, indestructible object whose bounding box is enlarged to
 * cover the vehicle's whole footprint. Everything that happens to it is relayed
 * to the [/obj/vehicle] that created it, and it drags anyone standing on the
 * hull along when that vehicle moves or turns.
 *
 * Design adapted from TGMC's multitile hitbox (which is itself the descendant of
 * the original CM tank hitbox), rewritten against this codebase's APIs:
 *   - modern integrity (atom_integrity / uses_integrity) instead of obj_integrity
 *   - pass_flags_self instead of allow_pass_flags
 *   - flags_1 / resistance_flags instead of the old atom_flags grab-bag
 *   - no combat layer: no soft_armor, no xeno hooks, no projectile interception
 *
 * Two notes earned the hard way on this codebase, both measured rather than guessed:
 *
 *  1. The footprint is derived arithmetically (anchor tile + body size) and cached,
 *     rather than read from BYOND's `locs` each time. Measurement showed `locs`
 *     works fine at every point including inside Initialize, so this is about
 *     having one authoritative, cheap list rather than about `locs` being broken.
 *  2. Never `+=` onto a null typed list. `var/list/turf/tracked_turfs` starting out
 *     null and then doing `tracked_turfs += owned` raised "bad pixloc" for every
 *     single element, while the identical append onto a list already initialised
 *     with `list()` was fine. Initialise the list first.
 */

/// Sent to a non-square hitbox's root when the footprint rotates. Args: (source, new_dir, old_dir)
#define COMSIG_MULTITILE_VEHICLE_ROTATED "multitile_vehicle_rotated"

/// Vehicles may link a multitile hitbox. Assign a typepath on a subtype to enable it.
/obj/vehicle
	/// Multitile hitbox linked to this vehicle, if any. Set a typepath on a subtype to make the vehicle multitile.
	var/obj/hitbox/hitbox

	/// Called when [new_desant] climbs onto this vehicle's hull. Override for sounds/effects/restrictions.
	proc/add_desant(mob/living/new_desant)
		return

	/// Called when [old_desant] leaves this vehicle's hull. Override for sounds/effects/restrictions.
	proc/remove_desant(mob/living/old_desant)
		return

/obj/hitbox
	name = "vehicle chassis"
	desc = "A structural element of an oversized vehicle. You shouldn't be able to see this."
	// A real (if never rendered) icon, so the enlarged bounding box always has a
	// well defined pixel extent.
	icon = 'icons/effects/effects.dmi'
	icon_state = "nothing"
	invisibility = INVISIBILITY_MAXIMUM
	anchored = TRUE
	density = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The vehicle carries the integrity, we only relay damage to it.
	uses_integrity = FALSE
	resistance_flags = INDESTRUCTIBLE
	move_resist = MOVE_FORCE_OVERPOWERING
	// NOTE: explosion_block deliberately stays at its default of 0 in the type
	// definition. /atom/movable/Initialize asserts that anything with a non-zero
	// explosion_block already carries TRAIT_BLOCKING_EXPLOSIVES, and that parent
	// init runs before we can apply the element, so we set it afterwards instead.
	/// Footprint length along the vehicle's facing, in pixels.
	var/vehicle_length = 64
	/// Footprint width, in pixels.
	var/vehicle_width = 64
	/// Cached turfs of our footprint. Rebuilt by [proc/refresh_footprint] whenever the hull moves.
	var/list/turf/footprint
	/// Footprint turfs whose ENTERED/EXITED signals we are currently listening to.
	var/list/turf/tracked_turfs
	/// Movables standing on top of the hull, which travel with the vehicle.
	var/list/atom/movable/desants
	/// The vehicle this hitbox belongs to. Movement and damage are relayed to it.
	var/obj/vehicle/root
	/// Only set while [proc/root_moved] is dragging us along, which is the one move
	/// we are allowed to make. Every other movement path in the codebase (drag,
	/// shove, pull) funnels through [proc/doMove] and would desync us from the
	/// vehicle -- and since those paths skip density checks, a stray shove drops
	/// the hull straight through a wall.
	var/syncing = FALSE

/// The hull may only ever be moved by its own vehicle. Drag, shove, pull and
/// forceMove all funnel through doMove, so one guard here covers every one of
/// them. A null destination is still allowed through: qdel needs it to work.
/obj/hitbox/doMove(atom/destination)
	if(destination && !syncing)
		return FALSE
	return ..()

/obj/hitbox/Initialize(mapload, obj/vehicle/new_root)
	. = ..()
	if(!new_root)
		return INITIALIZE_HINT_QDEL
	root = new_root
	bound_width = vehicle_width
	bound_height = vehicle_length
	RegisterSignal(root, COMSIG_MOVABLE_MOVED, PROC_REF(root_moved))
	RegisterSignal(root, COMSIG_QDELETING, PROC_REF(root_deleted))
	RegisterSignal(root, COMSIG_ATOM_DIR_CHANGE, PROC_REF(root_turned))
	refresh_footprint()
	// The hull is a solid body, so it should absorb blasts across every covered
	// tile. The element inspects `locs`, so it cannot be applied from inside our
	// own Initialize (see the file header); one tick later is plenty.
	addtimer(CALLBACK(src, PROC_REF(setup_explosion_blocking)), 0)

/// APPLIES the explosion-block element once our bounds have settled.
/obj/hitbox/proc/setup_explosion_blocking()
	if(QDELETED(src) || !loc)
		return
	AddElement(/datum/element/blocks_explosives)
	set_explosion_block(1)

/// Recomputes [var/footprint] from our anchor tile and re-hooks every tile's
/// arrival/departure signals. Must be called whenever the hull's tiles change.
/obj/hitbox/proc/refresh_footprint()
	if(tracked_turfs)
		for(var/turf/watched as anything in tracked_turfs)
			UnregisterSignal(watched, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED))
	footprint = calculate_footprint()
	tracked_turfs = list()
	if(!length(footprint))
		return
	for(var/turf/owned as anything in footprint)
		// override = TRUE: these turfs are shared, and anything else (connect_loc
		// users, the transport system, ...) may already be hooked to the same
		// signal. Without it the registration is refused and a warning is raised.
		RegisterSignal(owned, COMSIG_ATOM_ENTERED, PROC_REF(on_footprint_entered), override = TRUE)
		RegisterSignal(owned, COMSIG_ATOM_EXITED, PROC_REF(on_footprint_exited), override = TRUE)
		tracked_turfs += owned

/// Derives the covered turfs from the anchor tile plus the body size. Our bounding
/// box starts at the anchor with no `bound_x`/`bound_y` offset, so the covered
/// block is simply (anchor .. anchor + tiles - 1). Doing the arithmetic ourselves
/// keeps this off BYOND's `locs` machinery entirely.
/obj/hitbox/proc/calculate_footprint()
	. = list()
	var/turf/anchor = get_turf(src)
	if(!anchor)
		return
	var/tiles_x = max(1, ROUND_UP(vehicle_width / ICON_SIZE_X))
	var/tiles_y = max(1, ROUND_UP(vehicle_length / ICON_SIZE_Y))
	for(var/offset_x in 0 to tiles_x - 1)
		for(var/offset_y in 0 to tiles_y - 1)
			var/turf/found = locate(anchor.x + offset_x, anchor.y + offset_y, anchor.z)
			if(found)
				. += found

/// The turfs this hull covers. Callers use it for membership tests and geometry.
/obj/hitbox/proc/get_footprint()
	if(!footprint)
		footprint = calculate_footprint()
	return footprint

/// Is [mover] standing on top of the hull?
/obj/hitbox/proc/is_on_hull(atom/movable/mover)
	if(!mover)
		return FALSE
	return get_turf(mover) in get_footprint()

/obj/hitbox/Destroy(force)
	// Anything other than our own vehicle deleting us is refused; we outlive stray qdels.
	if(!force)
		return QDEL_HINT_LETMELIVE
	if(root)
		root.hitbox = null
	for(var/atom/movable/desant as anything in desants)
		remove_desant(desant)
	if(tracked_turfs)
		for(var/turf/watched as anything in tracked_turfs)
			UnregisterSignal(watched, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED))
		tracked_turfs = null
	footprint = null
	root = null
	return ..()

// ----------------------------------------------------------------------------
// Damage relaying. Everything that can hurt an atom is forwarded to the vehicle
// so that all the usual vehicle behaviour (destruction, armour, riding along)
// keeps working without duplicating any of it here.
// ----------------------------------------------------------------------------

/obj/hitbox/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	if(!root)
		return FALSE
	return root.take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)

/obj/hitbox/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE, blocked = 0)
	SHOULD_CALL_PARENT(FALSE) //This is an abstract relay; running /atom/bullet_act on it would be wrong.
	if(!root)
		return BULLET_ACT_HIT
	SEND_SIGNAL(src, COMSIG_ATOM_BULLET_ACT, hitting_projectile)
	return root.bullet_act(hitting_projectile, def_zone, piercing_hit, blocked)

/obj/hitbox/ex_act(severity, target)
	if(root)
		root.ex_act(severity, target)

// ----------------------------------------------------------------------------
// Footprint entry/exit
// ----------------------------------------------------------------------------

/obj/hitbox/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(.)
		return
	// Anyone already standing on the hull may move around on top of it (and step off it).
	if(is_on_hull(mover))
		return TRUE

/// Something arrived on one of our tiles: if it is standing on us, it is now riding the hull.
/obj/hitbox/proc/on_footprint_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(arrived == src || arrived == root)
		return
	if(!is_on_hull(arrived)) //It moved straight back off; EXITED will have handled it.
		return
	add_desant(arrived)

/obj/hitbox/proc/on_footprint_exited(datum/source, atom/movable/gone, direction)
	SIGNAL_HANDLER
	if(!gone || !(gone in desants))
		return
	if(is_on_hull(gone))
		return
	remove_desant(gone)

// ----------------------------------------------------------------------------
// Hull riders ("desants" in TGMC terms)
// ----------------------------------------------------------------------------

/// Puts [new_desant] on top of the hull so it travels with the vehicle. Called by the vehicle too.
/obj/hitbox/proc/add_desant(atom/movable/new_desant)
	if(!new_desant || new_desant == root || new_desant == src)
		return FALSE
	if(is_on_hull(new_desant) && (new_desant in desants))
		return FALSE
	LAZYSET(desants, new_desant, TRUE)
	RegisterSignal(new_desant, COMSIG_QDELETING, PROC_REF(on_desant_deleted))
	if(root)
		root.add_desant(new_desant)
	return TRUE

/// Removes [desant] from the hull.
/obj/hitbox/proc/remove_desant(atom/movable/desant)
	if(!desant)
		return FALSE
	LAZYREMOVE(desants, desant)
	UnregisterSignal(desant, COMSIG_QDELETING)
	if(root)
		root.remove_desant(desant)
	return TRUE

/obj/hitbox/proc/on_desant_deleted(datum/source)
	SIGNAL_HANDLER
	LAZYREMOVE(desants, source)

// ----------------------------------------------------------------------------
// Following the vehicle
// ----------------------------------------------------------------------------

/// The vehicle moved: bring the hitbox (and its riders) along with it.
/obj/hitbox/proc/root_moved(atom/movable/mover, turf/old_loc, movement_dir, forced, list/turf/old_locs)
	SIGNAL_HANDLER
	if(!mover.loc) //The vehicle was sent to nullspace or deleted.
		for(var/atom/movable/desant as anything in desants)
			remove_desant(desant)
		return
	var/delta_x = root.x - old_loc.x
	var/delta_y = root.y - old_loc.y
	var/z_changed = root.z != old_loc.z
	var/glide = root.glide_size
	syncing = TRUE
	forceMove(get_turf(root))
	syncing = FALSE

	for(var/atom/movable/desant as anything in desants)
		if(QDELETED(desant))
			remove_desant(desant)
			continue
		desant.set_glide_size(glide)
		if(z_changed)
			//A z-change has no meaningful "step" to preserve, so just land them on the hull.
			desant.abstract_move(loc)
			continue
		var/turf/target = locate(desant.x + delta_x, desant.y + delta_y, desant.z)
		if(!target)
			continue
		desant.forceMove(target)

	// Our footprint just moved, so the tiles we watch for arrivals/departures did too.
	refresh_footprint()

/// The vehicle turned: for a square footprint the bounds do not change, so we just
/// rotate the riders around the footprint centre. Non-square footprints (subtypes
/// that set differing vehicle_length/vehicle_width) handle their own bounds.
/obj/hitbox/proc/root_turned(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(!new_dir || new_dir == old_dir)
		return FALSE
	if(vehicle_length != vehicle_width)
		SEND_SIGNAL(src, COMSIG_MULTITILE_VEHICLE_ROTATED, new_dir, old_dir)
		return TRUE
	if(!LAZYLEN(desants))
		return FALSE
	var/clockwise
	if(turn(old_dir, 90) == new_dir)
		clockwise = TRUE
	else if(turn(old_dir, -90) == new_dir)
		clockwise = FALSE
	for(var/atom/movable/desant as anything in desants)
		if(QDELETED(desant) || desant.loc == root.loc)
			continue
		var/delta_x = desant.x - root.x
		var/delta_y = desant.y - root.y
		var/new_x
		var/new_y
		switch(clockwise)
			if(TRUE) //clockwise: north -> east
				new_x = delta_y
				new_y = -delta_x
			if(FALSE) //anticlockwise: north -> west
				new_x = -delta_y
				new_y = delta_x
			else //half turn
				new_x = -delta_x
				new_y = -delta_y
		var/turf/target = locate(root.x + new_x, root.y + new_y, root.z)
		if(target)
			desant.set_glide_size(root.glide_size)
			desant.forceMove(target)
	return FALSE

/// The vehicle is being deleted: take us with it.
/obj/hitbox/proc/root_deleted(datum/source)
	SIGNAL_HANDLER
	root = null
	qdel(src, force = TRUE)

// ----------------------------------------------------------------------------
// Driving
// ----------------------------------------------------------------------------

/// Is the way ahead clear for a one-step move in [direction]? Never moves anything:
/// [obj/vehicle/sealed/multitile] does the actual stepping so its own cooldowns apply.
/obj/hitbox/proc/can_drive(direction)
	if(!root || !direction || ISDIAGONALDIR(direction))
		return FALSE
	var/can_step = TRUE
	for(var/turf/entering as anything in get_entering_turfs(direction))
		if(!entering.Enter(root))
			can_step = FALSE
		for(var/atom/movable/obstacle as anything in entering.contents)
			if(obstacle == root || obstacle == src || (obstacle in desants))
				continue
			if(obstacle.CanPass(root, entering))
				continue
			root.Bump(obstacle)
			can_step = FALSE
	return can_step

/// The turfs on the leading edge of our footprint for a move in [direction].
/// Generic: any footprint turf whose neighbour in [direction] is outside the footprint.
/obj/hitbox/proc/get_entering_turfs(direction)
	. = list()
	var/list/covered = get_footprint()
	if(!length(covered))
		return
	for(var/turf/owned as anything in covered)
		var/turf/ahead = get_step(owned, direction)
		if(!ahead || (ahead in covered))
			continue
		. += ahead

// ----------------------------------------------------------------------------
// Footprint variants. All of these are square-or-rectangular and anchored with
// their lower-left (south-west) tile on the vehicle, so `bound_x`/`bound_y`
// stay at zero and the icon is drawn from the same origin.
// ----------------------------------------------------------------------------

/// 2x2 (64x64 pixels).
/obj/hitbox/two_by_two
	vehicle_length = 64
	vehicle_width = 64

/// 3x3 (96x96 pixels).
/obj/hitbox/three_by_three
	vehicle_length = 96
	vehicle_width = 96

/// 2x3 (64 wide, 96 long).
/obj/hitbox/two_by_three
	vehicle_length = 96
	vehicle_width = 64

/// 3x4 (96 wide, 128 long). Non-square, so it recalculates its bounds on rotation.
/obj/hitbox/three_by_four
	vehicle_length = 128
	vehicle_width = 96

/obj/hitbox/three_by_four/root_turned(datum/source, old_dir, new_dir)
	. = ..()
	if(!.)
		return FALSE
	switch(new_dir)
		if(NORTH, SOUTH)
			bound_width = vehicle_width
			bound_height = vehicle_length
		if(EAST, WEST)
			bound_width = vehicle_length
			bound_height = vehicle_width
	switch(new_dir) //Keep the vehicle's own origin on the south-west tile of the footprint.
		if(NORTH)
			root.pixel_x = -32
			root.pixel_y = 0
		if(SOUTH)
			root.pixel_x = 0
			root.pixel_y = 0
		if(EAST)
			root.pixel_x = 0
			root.pixel_y = -32
		if(WEST)
			root.pixel_x = 0
			root.pixel_y = 0
	// The covered block just changed shape, so re-derive it and re-hook its tiles.
	footprint = null
	refresh_footprint()
	return FALSE

#undef COMSIG_MULTITILE_VEHICLE_ROTATED
