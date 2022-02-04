#include <amxmodx>
#include <slotmachine>
#include <reapi>

new const PLUGIN[] =    "Slot Machine Money"
new const VERSION[] =   "0.1"
new const AUTHOR[] =    "Psycrow"

#define BET						100

new const GAME_PRIZES[] =
{
	200,
	300,
	500,
	800,
	1000,
	10000
}

new g_msgBlinkAcct


public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_dictionary("next21_slot_machine.txt")
    g_msgBlinkAcct = get_user_msgid("BlinkAcct")
}

public client_slot_machine_win(const iPlayer, const iPrize)
{
    new iAddMoney = GAME_PRIZES[iPrize]
    rg_add_account(iPlayer, iAddMoney)
    client_print_color(iPlayer, print_team_default, "^4[%s] %L",
        PLUGIN, iPlayer, "WIN_MONEY", iAddMoney)
}

public client_slot_machine_spin(const iPlayer)
{
    if (get_member(iPlayer, m_iAccount) < BET)
    {
		message_begin(MSG_ONE, g_msgBlinkAcct, .player = iPlayer)
		write_byte(2)
		message_end()

		client_print_color(iPlayer, print_team_default, "^4[%s] %L",
            PLUGIN, iPlayer, "NOT_ENOUGH_MONEY")

		return PLUGIN_HANDLED
    }

    rg_add_account(iPlayer, -BET)
    return PLUGIN_CONTINUE
}
