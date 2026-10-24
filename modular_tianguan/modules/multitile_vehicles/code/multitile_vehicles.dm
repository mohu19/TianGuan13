/*
 * Example multitile vehicles
 * ==========================
 * Concrete chassis built on [/obj/vehicle/sealed/multitile]. These exist to
 * prove the footprint framework end to end: two tiles wide, two tiles long,
 * turn-in-place, full leading-edge collision, hull riding.
 *
 * To make a new one, all you need is:
 *   - a subtype of [/obj/vehicle/sealed/multitile]
 *   - hitbox = a footprint typepath (see _hitbox.dm)
 *   - footprint_width / footprint_length kept in sync with that typepath
 *   - a sprite that fills the footprint (see this module's icons/multitile_vehicles.dmi)
 *
 * A 3x3 chassis is the same recipe with hitbox = /obj/hitbox/three_by_three and
 * footprint_width = footprint_length = 3.
 */

/obj/vehicle/sealed/multitile/hauler
	name = "utility hauler"
	desc = "A boxy four-wheeled cargo platform. Two tiles wide and two tiles long, so it does not fit through doors."
	icon_state = "hauler"
	hitbox = /obj/hitbox/two_by_two
	max_integrity = 500
	// movedelay / turn_delay are deliberately NOT set here: they live on the base type
	// so a chassis cannot silently pin an old handling value. Override only to deviate.
	footprint_width = 2
	footprint_length = 2
	max_occupants = 2
	max_drivers = 1
	enter_delay = 1.5 SECONDS

/obj/vehicle/sealed/multitile/hauler/cargo
	name = "cargo hauler"
	desc = "A long flatbed hauler. Slower than the utility model, but it carries a whole crew."
	icon_state = "cargo"
	max_integrity = 750
	// Heavier than the utility model, so deliberately slower.
	movedelay = 0.8 SECONDS
	turn_delay = 0.4 SECONDS
	max_occupants = 3
