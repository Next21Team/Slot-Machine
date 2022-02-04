# Slot Machine

_**English** | [Русский](README.ru.md)_

[![Slot Machine](https://img.youtube.com/vi/Y3zFFcCXAkc/0.jpg)](https://youtu.be/Y3zFFcCXAkc)

AMX Mod X plugin for Counter-Strike.

The plugin allows you to place slot machines on the map and play them. The player places a bet and waits for a winning combination of symbols to appear. A victory is counted when a whole row or main diagonal is filled with the same symbols. There is an API for adding your own prizes and a tool for customizing the slot machine model.

## Commands
* `slot_machine` — menu for placing slot machines on the map.

## Configuration
The plugin configuration is stored in the directory *addons/amxmodx/configs/slot_machine*. The file *_pattern.json* contains a 3 by 8 matrix with symbol markings for the reels of the slot machine. The symbol is defined by a number from 0 to 7. The symbol index is the same as the prize index. At the moment, it is not possible to change the dimension of the matrix. Example configuration file content:

```json
[
	[0, 1, 2, 0, 3, 2, 4, 5],
	[1, 0, 2, 4, 0, 2, 3, 5],
	[2, 0, 3, 4, 2, 0, 5, 1]
]
```

### Adding your own prizes and bets
The *next21_slot_machine.sma* source code file contains only the basic functionality of the plugin without issuing rewards. Prizes and bets must be implemented in a separate plugin using a dedicated API for this purpose:

```pawn
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
```

The file *addons/amxmodx/scripting/next21_slot_machine_money.sma* contains an example of the implementation of the money system for a slot machine:

```pawn
#include <slotmachine>

#define BET 100

new const GAME_PRIZES[] =
{
	200,
	300,
	500,
	800,
	1000,
	10000
}

public client_slot_machine_win(const iPlayer, const iPrize)
{
    new iAddMoney = GAME_PRIZES[iPrize]
    rg_add_account(iPlayer, iAddMoney)
}

public client_slot_machine_spin(const iPlayer)
{
    if (get_member(iPlayer, m_iAccount) < BET)
		return PLUGIN_HANDLED

    rg_add_account(iPlayer, -BET)
    return PLUGIN_CONTINUE
}
```

### Customization of the slot machine model
The script *slot_machine_texgen.py* allows you to relatively quickly generate the texture and UV-layout of the reels according to the specified parameters. For this you need:

1) Place *addons/amxmodx/configs/slot_machine/_pattern.json* file in *cfg* directory.
2) In the file *cfg/text.json* specify the names of bets and prizes, colors of text and shadows.
3) Place images of reel symbols into the *symbols* directory. File names must match the symbol numbers (from 0 to 7).
4) Run the script using the Python 3 interpreter. The [Pillow module](https://pillow.readthedocs.io/en/stable/) must be installed in the system.
5) Compile with studiomdl or any other compiler the slot machine model in the *dist* directory.

The quality of the generated textures may not be high enough. To solve this problem, it is proposed to re-save the resulting images with the png extension in any other raster editor (like GIMP).

## Requirements
- [Reapi](https://github.com/s1lentq/reapi)

## Authors
- [Psycrow](https://github.com/Psycrow101)
