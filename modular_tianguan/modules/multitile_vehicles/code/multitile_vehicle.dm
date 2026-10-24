/*
 * Multitile vehicles
 * ==================
 * A [/obj/vehicle/sealed] whose body is bigger than one turf. All of the
 * footprint bookkeeping lives in [/obj/hitbox] (see _hitbox.dm); this subtype is
 * the part you actually drive:
 *
 *   - a sealed vehicle is driven through relaymove(), because it has no riding
 *     component, so movement is handled explicitly here
 *   - a multitile vehicle always turns to face the direction it wants to travel
 *     and pays a full tick for the turn; it never strafes
 *   - its speed is capped by [movedelay], and the leading edge of its whole
 *     footprint is collision-checked before every step
 *
 * Nothing in here touches damage, armour or any combat subsystem: a multitile
 * vehicle takes damage exactly like any other [/obj/vehicle].
 */

/obj/vehicle/sealed/multitile
	name = "multitile vehicle"
	desc = "An oversized vehicle that occupies more than one tile. Yell at coderbus."
	icon = 'modular_tianguan/modules/multitile_vehicles/icons/multitile_vehicles.dmi'
	icon_state = "hauler"
	layer = ABOVE_MOB_LAYER
	max_integrity = 500
	movedelay = 0.5 SECONDS
	/// How long a 90 degree turn in place takes. A direction change costs this plus
	/// one [movedelay] step, so keep it well below movedelay.
	var/turn_delay = 0.25 SECONDS
	/// Footprint dimensions in tiles. Keep these in sync with the hitbox typepath.
	var/footprint_width = 2
	var/footprint_length = 2
	/// A vehicle is not a loose crate: you cannot shove it or walk off with it. Both
	/// gates below are the idiomatic ones -- /atom/movable/Move_Pulled() compares
	/// move_resist against the puller's force, and can_be_pulled() is the explicit
	/// veto. (Mouse dragging is already refused by /obj/vehicle/sealed/AllowDrop.)
	/// Do NOT guard Move()/doMove() here: those also carry system moves (admin
	/// teleports, z-changes, shuttles), and refusing them strands the vehicle.
	move_resist = MOVE_FORCE_OVERPOWERING
	/// Temporary speed probe: logs the real interval between steps so the handling
	/// can be measured in game rather than guessed. Flip to FALSE to silence it.
	var/log_step_timing = TRUE

/// We are a vehicle, not a crate: you cannot grab us and walk off with us.
/obj/vehicle/sealed/multitile/can_be_pulled(user, force)
	return FALSE

/obj/vehicle/sealed/multitile/Initialize(mapload)
	. = ..()
	if(hitbox)
		hitbox = new hitbox(get_turf(src), src)

/obj/vehicle/sealed/multitile/Destroy()
	if(hitbox)
		var/obj/hitbox/dying = hitbox
		hitbox = null
		qdel(dying, force = TRUE)
	return ..()

/obj/vehicle/sealed/multitile/generate_actions()
	. = ..()
	initialize_passenger_action_type(/datum/action/vehicle/sealed/climb_out)

/obj/vehicle/sealed/multitile/examine(mob/user)
	. = ..()
	if(hitbox)
		. += span_notice("It occupies a [footprint_width]x[footprint_length] area. Click it to climb onto the hull, drag yourself onto it to get inside.")

/// Only a driver may move us (the base sealed proc lets any occupant relay movement keys).
/obj/vehicle/sealed/multitile/relaymove(mob/living/user, direction)
	if(!canmove || !is_driver(user))
		return FALSE
	vehicle_move(direction)
	return TRUE

/// Movement entry point for sealed vehicles. Called from [/obj/vehicle/sealed/relaymove].
/obj/vehicle/sealed/multitile/vehicle_move(direction)
	if(!COOLDOWN_FINISHED(src, cooldown_vehicle_move))
		return FALSE
	if(!direction || ISDIAGONALDIR(direction))
		return FALSE
	if(!Process_Spacemove(direction))
		return FALSE
	// An oversized vehicle cannot strafe: it turns to face where it is going, and that costs a tick.
	if(dir != direction && dir != REVERSE_DIR(direction))
		setDir(direction)
		COOLDOWN_START(src, cooldown_vehicle_move, turn_delay)
		if(log_step_timing)
			log_world("MTVSPEED [world.time] TURN dir=[direction] cd_ends=[cooldown_vehicle_move] turn_delay=[turn_delay]")
		after_move(direction)
		return TRUE
	if(!hitbox?.can_drive(direction))
		return FALSE
	COOLDOWN_START(src, cooldown_vehicle_move, movedelay)
	var/moved = step(src, direction)
	if(log_step_timing)
		log_world("MTVSPEED [world.time] STEP dir=[direction] moved=[moved] cd_ends=[cooldown_vehicle_move] movedelay=[movedelay] turn_delay=[turn_delay]")
	if(!moved)
		return FALSE
	after_move(direction)
	return TRUE

/// Leaving must never put an occupant back inside our own footprint.
/obj/vehicle/sealed/multitile/exit_location(mob/M)
	return find_exit_turf(M) || drop_location()

/// Returns a clear turf just outside our footprint, preferring one behind us.
/obj/vehicle/sealed/multitile/proc/find_exit_turf(mob/M)
	var/list/footprint = get_footprint()
	var/list/turf/candidates = list()
	for(var/turf/owned as anything in footprint)
		for(var/step_dir in GLOB.alldirs)
			var/turf/adjacent = get_step(owned, step_dir)
			if(!adjacent || (adjacent in footprint) || adjacent.density)
				continue
			var/blocked = FALSE
			for(var/atom/movable/obstacle as anything in adjacent.contents)
				if(obstacle.density && !obstacle.CanPass(M, adjacent))
					blocked = TRUE
					break
			if(blocked)
				continue
			candidates += adjacent
	if(!length(candidates))
		return null
	var/turf/behind = get_step(src, REVERSE_DIR(dir))
	if(behind && (behind in candidates))
		return behind
	return pick(candidates)

/// Our own tiles. Falls back to our turf if the hitbox is somehow missing.
/obj/vehicle/sealed/multitile/proc/get_footprint()
	if(hitbox)
		return hitbox.get_footprint()
	return list(get_turf(src))

/// Click the hull to climb on top of it; click it again to get back down.
/obj/vehicle/sealed/multitile/attack_hand(mob/user, list/modifiers)
	if(!isliving(user) || !hitbox)
		return ..()
	if(is_occupant(user))
		return ..()
	if(user.loc in get_footprint())
		var/turf/get_off = find_exit_turf(user)
		hitbox.remove_desant(user)
		if(get_off)
			user.forceMove(get_off)
		user.visible_message(
			span_notice("[user] climbs down from \the [src]."),
			span_notice("You climb down from \the [src]."),
		)
		return TRUE
	if(!user.Adjacent(src))
		return ..()
	var/turf/hull = get_turf(hitbox)
	if(!hull || !hitbox.add_desant(user))
		return ..()
	user.forceMove(hull)
	user.visible_message(
		span_notice("[user] climbs onto \the [src]."),
		span_notice("You climb onto \the [src]. Use your movement keys to walk around on it, or click it to get down."),
	)
	return TRUE

// ----------------------------------------------------------------------------
// Hull rider bookkeeping for this vehicle. Riders are owned by the hitbox; these
// hooks let a subtype react (sounds, effects, equipment restrictions, ...) and
// make sure a rider cannot also be an occupant.
// ----------------------------------------------------------------------------

/obj/vehicle/sealed/multitile/after_add_occupant(mob/M)
	. = ..()
	hitbox?.remove_desant(M)

/obj/vehicle/sealed/multitile/after_remove_occupant(mob/M)
	. = ..()
	// Occupants are dumped just outside the footprint, so they must not become riders.
	hitbox?.remove_desant(M)
