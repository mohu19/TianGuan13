/*
 * Multitile vehicle debug spawner
 * ===============================
 * A hand-held terminal for eyeballing the multitile chassis in game: hold it,
 * press Z, pick a chassis from the list, and it spawns under you. The same menu
 * is reachable by using the item in hand, so the tool still works for anyone
 * whose client has not picked up the new keybind yet.
 *
 * This file uses module-local defines only, so they are #undef'd again at the
 * bottom of the file (see modular_tianguan/readme.md -> "Defines").
 */

/// Fired by the multitile spawner keybind.
#define COMSIG_KB_TIANGUAN_MULTITILE_SPAWN_DOWN "tianguan_kb_multitile_spawn_down"

/// The debug terminal [holder] is holding in their active hand, if any.
/// Single source of truth for the keybind gate and the keybind handler.
/proc/multitile_debug_terminal_in_hand(mob/holder)
	var/obj/item/multitile_debug_spawner/held = holder?.get_active_held_item()
	if(!istype(held))
		return null
	return held

/datum/keybinding/multitile_debug_spawner
	hotkey_keys = list("Z")
	name = "multitile_debug_spawner"
	full_name = "召唤多格载具（调试）"
	description = "手持载具调试终端时：按此键弹出多格载具选择列表"
	keybind_signal = COMSIG_KB_TIANGUAN_MULTITILE_SPAWN_DOWN

/// Only bound while the terminal is actually in the active hand, so Z stays free otherwise.
/datum/keybinding/multitile_debug_spawner/can_use(client/user)
	return !isnull(multitile_debug_terminal_in_hand(user?.mob))

/datum/keybinding/multitile_debug_spawner/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	var/mob/holder = user.mob
	var/obj/item/multitile_debug_spawner/terminal = multitile_debug_terminal_in_hand(holder)
	if(!terminal)
		return
	terminal.open_spawn_menu(holder)
	return TRUE

/obj/item/multitile_debug_spawner
	name = "载具调试终端"
	desc = "一把小小的调试终端，用来现场召唤多格载具框体。手持时按 Z 选择要召唤的载具，直接使用也可以打开列表。"
	icon = 'modular_tianguan/modules/multitile_vehicles/icons/debug_spawner.dmi'
	icon_state = "spawner"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT

/obj/item/multitile_debug_spawner/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	open_spawn_menu(user)

/// Every concrete chassis in this module, keyed by display name. Grows automatically
/// with the module: add a /obj/vehicle/sealed/multitile subtype and it shows up here.
/obj/item/multitile_debug_spawner/proc/menu_options()
	var/list/options = list()
	for(var/obj/vehicle/sealed/multitile/chassis as anything in subtypesof(/obj/vehicle/sealed/multitile))
		var/chassis_name = initial(chassis.name)
		if(chassis_name)
			options[chassis_name] = chassis
	return options

/// Resolves whatever a list-input hands back into a chassis typepath, or null.
///
/// The two input backends disagree, and both reaches have to be covered:
///   - tgui_input_list returns the assoc list's *key* (the display label),
///     because /datum/tgui_list_input builds items_map[display] = key and then
///     set_choice()s the key.
///   - The native input() fallback in this codebase (see the I18N block in
///     tgui_input/list.dm) explicitly localises the label and hands back the
///     *value* instead.
/// Handing a label straight to new() is what produced "Cannot create objects of
/// type null", so never trust the shape of this return value.
/obj/item/multitile_debug_spawner/proc/resolve_chassis(pick)
	var/list/options = menu_options()
	if(ispath(pick))
		for(var/label in options)
			if(options[label] == pick)
				return pick
		return null
	if(istext(pick))
		return options[pick]
	return null

/// Offers the chassis list and spawns the chosen one on the user's tile.
/obj/item/multitile_debug_spawner/proc/open_spawn_menu(mob/user)
	if(!isliving(user))
		return
	var/list/options = menu_options()
	if(!length(options))
		to_chat(user, span_warning("这个模块里没有已注册的多格载具。"))
		return
	var/picked = tgui_input_list(user, "要召唤哪一种多格载具？", "载具调试终端", options)
	var/chassis_type = resolve_chassis(picked)
	if(!chassis_type)
		return
	if(!isliving(user))
		return
	var/turf/landing = get_turf(user)
	var/obj/vehicle/sealed/multitile/spawned = new chassis_type(landing)
	to_chat(user, span_notice("已召唤 [spawned]。它占据 [spawned.footprint_width]x[spawned.footprint_length] 格；拖拽自己上去可以进入车内，点击车体可以爬到车顶。"))
	message_admins("[key_name_admin(user)] 通过载具调试终端在 [ADMIN_VERBOSEJMP(landing)] 召唤了 [spawned.type]。")
	log_admin("[key_name(user)] spawned [spawned.type] via the multitile debug spawner at [AREACOORD(landing)].")

#undef COMSIG_KB_TIANGUAN_MULTITILE_SPAWN_DOWN
