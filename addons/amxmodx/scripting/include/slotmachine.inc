#if defined _slotmachine_included
	#endinput
#endif
#define _slotmachine_included

/**
 * Called when a client wins a slot machine
 *
 * @param 	iPlayer			- Client index
 * @param	iPrize			- Prize index
 */
forward client_slot_machine_win(const iPlayer, const iPrize)

/**
 * Called before the slot machine is activated by the client
 *
 * @param 	iPlayer			- Client index
 * @return					- Use PLUGIN_HANDLED if you want to disable slot machine activation
 */
forward client_slot_machine_spin(const iPlayer)
