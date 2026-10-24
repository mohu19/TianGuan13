/*
 * Multitile vehicle hitbox tests.
 *
 * The unit test room is only a single row of tiles, so a 2x2 vehicle does not fit
 * in it. These tests therefore avoid relying on open ground and instead exercise
 * the parts this codebase actually adds:
 *   - the footprint geometry (does enlarging bound_width/height produce 4 locs?)
 *   - the leading edge resolution and the collision refusal
 *   - the damage relay from hitbox to vehicle
 *   - the hull rider bookkeeping and the follow-the-vehicle logic
 * The one-tile step() itself is engine behaviour and is not re-tested here.
 */

/datum/unit_test/multitile_vehicle_footprint

/datum/unit_test/multitile_vehicle_footprint/Run()
	var/obj/vehicle/sealed/multitile/hauler/hauler = allocate(/obj/vehicle/sealed/multitile/hauler)
	var/obj/hitbox/hitbox = hauler.hitbox

	TEST_ASSERT_NOTNULL(hitbox, "the hauler never created a hitbox in Initialize()")
	TEST_ASSERT_EQUAL(hitbox.root, hauler, "the hitbox does not point back at its vehicle")
	TEST_ASSERT_EQUAL(hitbox.loc, hauler.loc, "the hitbox must be anchored on the vehicle's own turf")

	var/list/footprint = hitbox.get_footprint()
	TEST_ASSERT_NOTNULL(footprint, "the hitbox has no footprint")
	TEST_ASSERT_EQUAL(length(footprint), 4, "a 2x2 hitbox must cover exactly 4 turfs, covered [length(footprint)]")

	var/min_x = 1e6
	var/max_x = -1e6
	var/min_y = 1e6
	var/max_y = -1e6
	for(var/turf/owned as anything in footprint)
		min_x = min(min_x, owned.x)
		max_x = max(max_x, owned.x)
		min_y = min(min_y, owned.y)
		max_y = max(max_y, owned.y)
	TEST_ASSERT_EQUAL(max_x - min_x, 1, "the footprint should be 2 tiles wide")
	TEST_ASSERT_EQUAL(max_y - min_y, 1, "the footprint should be 2 tiles long")
	for(var/turf/owned as anything in footprint)
		TEST_ASSERT_EQUAL(owned.z, hauler.z, "every footprint turf must be on the vehicle's z-level")

/datum/unit_test/multitile_vehicle_leading_edge

/datum/unit_test/multitile_vehicle_leading_edge/Run()
	var/obj/vehicle/sealed/multitile/hauler/hauler = allocate(/obj/vehicle/sealed/multitile/hauler)
	var/obj/hitbox/hitbox = hauler.hitbox
	TEST_ASSERT_NOTNULL(hitbox, "the hauler never created a hitbox in Initialize()")

	var/list/footprint = hitbox.get_footprint()
	// A square footprint always exposes two tiles per cardinal direction.
	for(var/direction in GLOB.cardinals)
		var/list/entering = hitbox.get_entering_turfs(direction)
		TEST_ASSERT_EQUAL(length(entering), 2, "a 2x2 footprint should expose 2 leading edge turfs toward [dir2text(direction)], got [length(entering)]")
		for(var/turf/ahead as anything in entering)
			TEST_ASSERT(!(ahead in footprint), "leading edge turf [ahead] is inside the current footprint")
			TEST_ASSERT_EQUAL(ahead.z, hauler.z, "leading edge turf [ahead] is on the wrong z-level")

	// Cardinal correctness: the northern edge must be the row past the footprint's northern row.
	var/north_edge_y = 0
	for(var/turf/owned as anything in footprint)
		north_edge_y = max(north_edge_y, owned.y)
	for(var/turf/ahead as anything in hitbox.get_entering_turfs(NORTH))
		TEST_ASSERT_EQUAL(ahead.y, north_edge_y + 1, "the northern leading edge should be one row past the footprint")

/datum/unit_test/multitile_vehicle_collision

/datum/unit_test/multitile_vehicle_collision/Run()
	var/obj/vehicle/sealed/multitile/hauler/hauler = allocate(/obj/vehicle/sealed/multitile/hauler)
	var/obj/hitbox/hitbox = hauler.hitbox
	TEST_ASSERT_NOTNULL(hitbox, "the hauler never created a hitbox in Initialize()")

	var/list/north_edge = hitbox.get_entering_turfs(NORTH)
	TEST_ASSERT_EQUAL(length(north_edge), 2, "expected a 2 turf northern leading edge")
	var/turf/leading = north_edge[1]
	TEST_ASSERT_NOTNULL(leading, "could not resolve a leading edge turf")

	// Make sure the leading edge starts clear, whatever the test room happens to contain.
	for(var/atom/movable/occupant as anything in leading.contents)
		qdel(occupant)
	TEST_ASSERT(hitbox.can_drive(NORTH), "a clear leading edge must permit driving")

	// A dense structure on the leading edge must refuse the drive.
	var/obj/structure/table/blocker = allocate(/obj/structure/table, leading)
	TEST_ASSERT_NOTNULL(blocker, "failed to allocate a blocking structure")
	TEST_ASSERT(!hitbox.can_drive(NORTH), "a dense structure on the leading edge must refuse the drive")

	// Remove it again and the way is clear once more.
	qdel(blocker)
	TEST_ASSERT(hitbox.can_drive(NORTH), "the leading edge should be clear again once the obstacle is gone")

/datum/unit_test/multitile_vehicle_damage_relay

/datum/unit_test/multitile_vehicle_damage_relay/Run()
	var/obj/vehicle/sealed/multitile/hauler/hauler = allocate(/obj/vehicle/sealed/multitile/hauler)
	var/obj/hitbox/hitbox = hauler.hitbox
	TEST_ASSERT_NOTNULL(hitbox, "the hauler never created a hitbox in Initialize()")

	var/integrity_before = hauler.atom_integrity
	TEST_ASSERT(integrity_before > 0, "the hauler should start with integrity")

	hitbox.take_damage(100, BRUTE, MELEE, FALSE)

	var/damage_taken = integrity_before - hauler.atom_integrity
	TEST_ASSERT(damage_taken > 0, "damage dealt to the hitbox was never relayed to the vehicle")
	TEST_ASSERT(damage_taken <= 100, "the vehicle took [damage_taken] damage from a 100 damage hit; the relay must not amplify")
	TEST_ASSERT_NOTNULL(hauler.hitbox, "the hitbox should survive taking damage on behalf of its vehicle")

/datum/unit_test/multitile_vehicle_hull_rider

/datum/unit_test/multitile_vehicle_hull_rider/Run()
	var/obj/vehicle/sealed/multitile/hauler/hauler = allocate(/obj/vehicle/sealed/multitile/hauler)
	var/obj/hitbox/hitbox = hauler.hitbox
	TEST_ASSERT_NOTNULL(hitbox, "the hauler never created a hitbox in Initialize()")

	var/list/footprint = hitbox.get_footprint()
	TEST_ASSERT_EQUAL(length(footprint), 4, "expected a 4 turf footprint")
	var/turf/anchor = hitbox.loc
	var/turf/off_anchor
	for(var/turf/candidate as anything in footprint)
		if(candidate != anchor)
			off_anchor = candidate
			break
	TEST_ASSERT_NOTNULL(off_anchor, "a 2x2 footprint must have tiles besides its anchor tile")

	// allocate() drops test mobs on the anchor tile, so stage them off the hull first:
	// forceMoving something onto the turf it already occupies raises no arrival signal.
	var/turf/staging = get_step(anchor, SOUTH)
	TEST_ASSERT_NOTNULL(staging, "there is no turf south of the vehicle to stage a rider on")
	TEST_ASSERT(!(staging in footprint), "the staging turf must sit outside the footprint")

	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	first.forceMove(staging)
	first.forceMove(off_anchor)
	TEST_ASSERT_EQUAL(LAZYLEN(hitbox.desants), 1, "stepping onto a non-anchor hull tile should register a hull rider, got [LAZYLEN(hitbox.desants)]")
	first.forceMove(staging)
	TEST_ASSERT_EQUAL(LAZYLEN(hitbox.desants), 0, "stepping off the hull should unregister the hull rider")

	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	second.forceMove(staging)
	second.forceMove(anchor)
	TEST_ASSERT_EQUAL(LAZYLEN(hitbox.desants), 1, "standing on the anchor tile should register a hull rider")

	// A mob inside the vehicle must never also count as a hull rider.
	hauler.mob_enter(second)
	TEST_ASSERT_EQUAL(LAZYLEN(hitbox.desants), 0, "a mob inside the vehicle must not also be a hull rider")
	TEST_ASSERT(hauler.is_driver(second), "the only occupant should have become the driver")

	// And while riding the hull, the rider must be carried along with the vehicle.
	hauler.mob_exit(second, silent = TRUE)
	second.forceMove(staging)
	second.forceMove(anchor)
	TEST_ASSERT_EQUAL(LAZYLEN(hitbox.desants), 1, "the rider was not re-registered on the hull")

	var/turf/rider_start = second.loc
	var/turf/destination = get_step(hauler, NORTH)
	TEST_ASSERT_NOTNULL(destination, "there is no turf north of the vehicle to move onto")
	hauler.forceMove(destination)

	TEST_ASSERT_EQUAL(hitbox.loc, hauler.loc, "the hitbox did not follow its vehicle")
	TEST_ASSERT_EQUAL(second.loc, get_step(rider_start, NORTH), "the hull rider was not carried along with the vehicle")

	hitbox.remove_desant(second)
	TEST_ASSERT_EQUAL(LAZYLEN(hitbox.desants), 0, "removing a hull rider left it registered")

/datum/unit_test/multitile_vehicle_debug_spawner

/datum/unit_test/multitile_vehicle_debug_spawner/Run()
	// The keybind must exist and default to Z, or the terminal has no hotkey at all.
	var/datum/keybinding/spawner_bind = GLOB.keybindings_by_name["multitile_debug_spawner"]
	TEST_ASSERT_NOTNULL(spawner_bind, "the debug spawner keybind is not registered under its expected name")
	TEST_ASSERT_EQUAL(length(spawner_bind.hotkey_keys), 1, "the debug spawner keybind should have exactly one default key")
	TEST_ASSERT_EQUAL(spawner_bind.hotkey_keys[1], "Z", "the debug spawner keybind should default to Z")

	// The chassis list is derived from the module's own types, so assert the contract
	// (every entry is a chassis) rather than a frozen count.
	var/obj/item/multitile_debug_spawner/terminal = allocate(__IMPLIED_TYPE__)
	var/list/options = terminal.menu_options()
	TEST_ASSERT(length(options) >= 2, "the terminal should offer at least the two shipped chassis, got [length(options)]")
	TEST_ASSERT(options["utility hauler"] == /obj/vehicle/sealed/multitile/hauler, "the utility hauler is missing from the terminal's list")
	for(var/label, chassis_type in options)
		TEST_ASSERT(ispath(chassis_type, /obj/vehicle/sealed/multitile), "[label] does not resolve to a multitile chassis")

	// The list input hands back the label from tgui and the typepath from the native
	// fallback, so both shapes must resolve. Handing the label to new() is what once
	// produced "Cannot create objects of type null".
	TEST_ASSERT_EQUAL(terminal.resolve_chassis("utility hauler"), /obj/vehicle/sealed/multitile/hauler, "a label must resolve to its chassis")
	TEST_ASSERT_EQUAL(terminal.resolve_chassis(/obj/vehicle/sealed/multitile/hauler/cargo), /obj/vehicle/sealed/multitile/hauler/cargo, "a bare typepath must resolve to itself")
	TEST_ASSERT_NULL(terminal.resolve_chassis("no such chassis"), "an unknown label must not resolve")
	TEST_ASSERT_NULL(terminal.resolve_chassis(null), "a null pick must not resolve")

	// The keybind must only fire while the terminal is actually held in hand.
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NULL(multitile_debug_terminal_in_hand(operator), "a barehanded mob must not count as holding the terminal")
	operator.put_in_active_hand(terminal)
	TEST_ASSERT_EQUAL(multitile_debug_terminal_in_hand(operator), terminal, "holding the terminal must satisfy the keybind gate")
	operator.dropItemToGround(terminal, force = TRUE)
	TEST_ASSERT_NULL(multitile_debug_terminal_in_hand(operator), "dropping the terminal must clear the keybind gate")

/datum/unit_test/multitile_vehicle_hull_move_guard

/datum/unit_test/multitile_vehicle_hull_move_guard/Run()
	// The hull is a dense movable, so every grab/drag/shove path can reach it. Only
	// its own vehicle may move it: a stray external move desyncs the hull from the
	// chassis and, because those paths skip density checks, drops it into a wall.
	var/obj/vehicle/sealed/multitile/hauler/car = allocate(__IMPLIED_TYPE__)
	var/turf/origin = get_turf(car.hitbox)
	TEST_ASSERT_NOTNULL(origin, "the hull should start on a turf")

	var/turf/elsewhere = get_step(origin, EAST) || get_step(origin, WEST)
	TEST_ASSERT_NOTNULL(elsewhere, "the test needs a neighbouring turf to shove the hull toward")

	TEST_ASSERT(!car.hitbox.doMove(elsewhere), "the hull must refuse an externally initiated move")
	TEST_ASSERT_EQUAL(get_turf(car.hitbox), origin, "a refused move must leave the hull on its own tile")

	// Moving on the vehicle's behalf must still work, or the hull could never follow.
	car.hitbox.syncing = TRUE
	TEST_ASSERT(car.hitbox.doMove(elsewhere), "the vehicle must be able to drag its own hull along")
	car.hitbox.syncing = FALSE
	TEST_ASSERT_EQUAL(get_turf(car.hitbox), elsewhere, "a move cleared by syncing must go through")

/datum/unit_test/multitile_vehicle_handling

/datum/unit_test/multitile_vehicle_handling/Run()
	// Handling lives on the base type on purpose: a chassis that pins its own value
	// silently defeats any later tuning of the base (a 1.5s override in a subtype is
	// exactly what made a three-fold speed-up look like it did nothing). Assert the
	// relationship, not the current numbers, so tuning stays a one-line change.
	var/obj/vehicle/sealed/multitile/base = allocate(/obj/vehicle/sealed/multitile)
	var/obj/vehicle/sealed/multitile/hauler/hauler = allocate(/obj/vehicle/sealed/multitile/hauler)
	var/obj/vehicle/sealed/multitile/hauler/cargo/cargo = allocate(/obj/vehicle/sealed/multitile/hauler/cargo)

	TEST_ASSERT_EQUAL(hauler.movedelay, base.movedelay,
		"the utility hauler must inherit the base step delay, not pin its own")
	TEST_ASSERT_EQUAL(hauler.turn_delay, base.turn_delay,
		"the utility hauler must inherit the base turn delay, not pin its own")

	// The heavier chassis is meant to be slower, so its override has to be a real one.
	TEST_ASSERT(cargo.movedelay > hauler.movedelay,
		"the cargo hauler should step slower than the utility one")
	TEST_ASSERT(cargo.turn_delay > hauler.turn_delay,
		"the cargo hauler should turn slower than the utility one")
