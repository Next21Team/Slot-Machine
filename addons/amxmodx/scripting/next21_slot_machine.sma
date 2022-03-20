#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <json>
#include <reapi>
#include <xs>

new const PLUGIN[] =    "Slot Machine"
new const VERSION[] =   "0.3"
new const AUTHOR[] =    "Psycrow"

new const MODEL_SLOTMACHINE[] = "models/next21_crimetown/slot_machine.mdl"

new const CLASSNAME_BASE[] = "info_target"
new const CLASSNAME_SLOTMACHINE[] = "slot_machine"

new const SOUND_SLOTMACHINE_ROLL[] = "next21_crimetown/slot_machine_roll.wav"
new const SOUND_SLOTMACHINE_WIN[] = "next21_crimetown/slot_machine_win.wav"

#define SPIN_TIME           6.74
#define MAX_REELS           4
#define MAX_LINES           32

#define var_player  var_iuser2

enum MACHINE_SEQUENCE
{
    SEQ_IDLE,
    SEQ_ROLL
}

new g_iMachineMenu
new g_iReelsNum, g_iLinesNum
new g_matPattern[MAX_REELS][MAX_LINES]
new g_iPlayerUsingMachine[MAX_PLAYERS + 1]
new g_fwdWin, g_fwdSpin

public plugin_precache()
{
    precache_model(MODEL_SLOTMACHINE)
    precache_sound(SOUND_SLOTMACHINE_ROLL)
    precache_sound(SOUND_SLOTMACHINE_WIN)
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_dictionary("next21_slot_machine.txt")

    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
    RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Pre", false)
    RegisterHam(Ham_ObjectCaps, CLASSNAME_BASE, "CBase_ObjectCaps_Pre", false)

    AddMenuItem("Slot Machine Menu", "slot_machine", ADMIN_CFG, PLUGIN)
    register_clcmd("slot_machine", "clcmd_slot_machine", ADMIN_CFG, "- displays slot machine menu")

    g_iMachineMenu = menu_create("\rSlot Machine", "machine_menu_handler")
    menu_additem(g_iMachineMenu, "\wCreate")
    menu_additem(g_iMachineMenu, "\wRemove")
    menu_additem(g_iMachineMenu, "\wSave")
    menu_setprop(g_iMachineMenu, MPROP_EXIT, MEXIT_ALL)

    load_pattern()
    load_machines()

    g_fwdWin = CreateMultiForward("client_slot_machine_win", ET_IGNORE, FP_CELL, FP_CELL)
    g_fwdSpin = CreateMultiForward("client_slot_machine_spin", ET_STOP, FP_CELL)
}

public client_putinserver(iPlayer)
{
    g_iPlayerUsingMachine[iPlayer] = 0
}

public CBasePlayer_Spawn_Post(iPlayer)
{
    if (is_user_alive(iPlayer))
        reset_using_machine(iPlayer)
}

public CBasePlayer_Killed_Pre(iPlayer)
{
    reset_using_machine(iPlayer)
}

public CBase_ObjectCaps_Pre(iEnt)
{
    if (FClassnameIs(iEnt, CLASSNAME_SLOTMACHINE))
    {
        SetHamReturnInteger(FCAP_IMPULSE_USE)
        return HAM_OVERRIDE
    }

    return HAM_IGNORED
}

public clcmd_slot_machine(iPlayer, iLevel, iCid)
{
    if (!is_user_connected(iPlayer))
        return PLUGIN_HANDLED

    if (!cmd_access(iPlayer, iLevel, iCid, 1))
        return PLUGIN_HANDLED

    menu_display(iPlayer, g_iMachineMenu)
    return PLUGIN_HANDLED
}

public machine_menu_handler(iPlayer, iMenu, iItem)
{
    if (iItem == MENU_EXIT)
        return PLUGIN_HANDLED

    switch (iItem)
    {
        case 0:
        {
            new ivOrigin[3], Float:vOrigin[3], Float:vAngles[3]
            get_user_origin(iPlayer, ivOrigin, 3)
            IVecFVec(ivOrigin, vOrigin)

            get_entvar(iPlayer, var_v_angle, vAngles)
            vAngles[0] = vAngles[2] = 0.0
            vAngles[1] += 180.0

            create_machine(vOrigin, vAngles)
        }
        case 1:
        {
            new iEnt, iBody
            get_user_aiming(iPlayer, iEnt, iBody)

            if (FClassnameIs(iEnt, CLASSNAME_SLOTMACHINE))
                set_entvar(iEnt, var_flags, FL_KILLME)
        }
        case 2:
        {
            if (save_machines())
            {
                client_print(iPlayer, print_center, "Saved!")
                return PLUGIN_HANDLED
            }
        }
    }

    menu_display(iPlayer, iMenu)
    return PLUGIN_HANDLED
}

create_machine(const Float:vOrigin[3], const Float:vAngles[3])
{
    new iEnt = rg_create_entity(CLASSNAME_BASE, true)
    if (is_nullent(iEnt))
        return NULLENT

    engfunc(EngFunc_SetModel, iEnt, MODEL_SLOTMACHINE)
    engfunc(EngFunc_SetSize, iEnt, {-32.0, -32.0, 0.0 }, { 32.0, 32.0, 84.0 })

    set_entvar(iEnt, var_origin, vOrigin)
    set_entvar(iEnt, var_angles, vAngles)

    set_entvar(iEnt, var_solid, SOLID_BBOX)
    set_entvar(iEnt, var_movetype, MOVETYPE_PUSHSTEP)

    set_entvar(iEnt, var_animtime, get_gametime())
    set_entvar(iEnt, var_frame, 0)
    set_entvar(iEnt, var_framerate, 1.0)
    set_entvar(iEnt, var_sequence, SEQ_IDLE)

    set_entvar(iEnt, var_takedamage, DAMAGE_NO)
    set_entvar(iEnt, var_classname, CLASSNAME_SLOTMACHINE)

    SetThink(iEnt, "machine_think")
    SetUse(iEnt, "machine_use")

    return iEnt
}

public machine_think(iEnt)
{
    new iSeq = get_entvar(iEnt, var_sequence)
    switch (iSeq)
    {
        case SEQ_ROLL:
        {
            new iPlayer = get_entvar(iEnt, var_player)
            new iPrize = machine_calculate_prize(iEnt)

            if (is_user_connected(iPlayer))
            {
                if (iPrize >= 0)
                {
                    emit_sound(iEnt, CHAN_STATIC, SOUND_SLOTMACHINE_WIN, 1.0, ATTN_IDLE, 0, PITCH_NORM)
                    new iReturn
                    ExecuteForward(g_fwdWin, iReturn, iPlayer, iPrize)
                }
                g_iPlayerUsingMachine[iPlayer] = 0
            }

            set_entvar(iEnt, var_sequence, SEQ_IDLE)
        }
    }
}

public machine_use(iEnt, iActivator, iCaller, USE_TYPE:useType, Float:fValue)
{
    if (is_nullent(iActivator))
        return HC_CONTINUE

    if (!ExecuteHam(Ham_IsPlayer, iActivator))
        return HC_CONTINUE

    new Float:vUserDirection[3], Float:vMachineDirection[3]

    get_entvar(iActivator, var_v_angle, vUserDirection)
    angle_vector(vUserDirection, ANGLEVECTOR_FORWARD, vUserDirection)

    get_entvar(iEnt, var_angles, vMachineDirection)
    angle_vector(vMachineDirection, ANGLEVECTOR_FORWARD, vMachineDirection)

    if (-1.0 <= xs_vec_dot(vUserDirection, vMachineDirection) <= -0.8)
        spin(iActivator, iEnt)

    return HC_CONTINUE
}

machine_calculate_prize(iEnt)
{
    new s[MAX_REELS][MAX_REELS], i, j

    // Get current symbols
    new p, d = 256 / g_iLinesNum
    for (i = 0; i < g_iReelsNum; i++)
    {
        p = get_entvar(iEnt, var_controller, i) / d
        if (p > 0) p = g_iLinesNum - p
        s[0][i] = g_matPattern[i][p]

        for (j = 1; j < g_iReelsNum; j++)
        {
            p = (p + 1) % g_iLinesNum
            s[j][i] = g_matPattern[i][p]
        }
    }

    new iPrize, iTotal = -1

    // Check horizontal matches
    for (j = 0; j < g_iReelsNum; j++)
    {
        for (i = 1; i < g_iReelsNum && s[j][i] == s[j][i-1]; i++) {}
        if (i == g_iReelsNum)
        {
            iPrize = s[j][0]
            if (iPrize > iTotal)
            {
                set_entvar(iEnt, var_body, j + 1)
                iTotal = iPrize
            }
        }
    }

    // Check matches along the main diagonal
    for (i = 1; i < g_iReelsNum && s[i][i] == s[i-1][i-1]; i++) {}
    if (i == g_iReelsNum)
    {
        iPrize = s[0][0]
        if (iPrize > iTotal)
        {
            set_entvar(iEnt, var_body, g_iReelsNum + 1)
            iTotal = iPrize
        }
    }

    // Check matches along the secondary diagonal
    for (i = 1; i < g_iReelsNum && s[i][g_iReelsNum-1-i] == s[i-1][g_iReelsNum-i]; i++) {}
    if (i == g_iReelsNum)
    {
        iPrize = s[0][g_iReelsNum - 1]
        if (iPrize > iTotal)
        {
            set_entvar(iEnt, var_body, g_iReelsNum + 2)
            iTotal = iPrize
        }
    }

    return iTotal
}

spin(iPlayer, iEnt)
{
    if (get_entvar(iEnt, var_sequence) != SEQ_IDLE)
        return

    if (g_iPlayerUsingMachine[iPlayer])
    {
        client_print(iPlayer, print_center, "%L", iPlayer, "ALREADY_PLAYING")
        return
    }

    new iReturn = PLUGIN_CONTINUE
    ExecuteForward(g_fwdSpin, iReturn, iPlayer)

    if (iReturn == PLUGIN_CONTINUE)
    {
        set_entvar(iEnt, var_player, iPlayer)
        roll_slots(iEnt)
        g_iPlayerUsingMachine[iPlayer] = iEnt
    }
}

roll_slots(iEnt)
{
    for (new i; i < g_iReelsNum; i++)
        set_entvar(iEnt, var_controller, random(g_iLinesNum) * (256 / g_iLinesNum), i)

    new Float:fGameTime = get_gametime()

    set_entvar(iEnt, var_animtime, fGameTime)
    set_entvar(iEnt, var_frame, 0)
    set_entvar(iEnt, var_sequence, SEQ_ROLL)
    set_entvar(iEnt, var_body, 0)
    set_entvar(iEnt, var_nextthink, fGameTime + SPIN_TIME)

    emit_sound(iEnt, CHAN_STATIC, SOUND_SLOTMACHINE_ROLL, 1.0, ATTN_IDLE, 0, PITCH_NORM)
}

reset_using_machine(iPlayer)
{
    new iEnt = g_iPlayerUsingMachine[iPlayer]
    if (FClassnameIs(iEnt, CLASSNAME_SLOTMACHINE))
        set_entvar(iEnt, var_player, 0)
    g_iPlayerUsingMachine[iPlayer] = 0
}

get_spawns_filepath(szFilePath[], iFilePathLen)
{
    new szCfgDir[64], szMap[32]
    get_configsdir(szCfgDir, charsmax(szCfgDir))
    add(szCfgDir, charsmax(szCfgDir), "/slot_machine")
    if (!dir_exists(szCfgDir))
        mkdir(szCfgDir)

    get_mapname(szMap, charsmax(szMap))
    formatex(szFilePath, iFilePathLen, "%s/%s.json", szCfgDir, szMap)
}

load_pattern()
{
    new szFilePath[128]
    get_configsdir(szFilePath, charsmax(szFilePath))
    add(szFilePath, charsmax(szFilePath), "/slot_machine/_pattern.json")

    new JSON:jsonRoot = json_parse(szFilePath, true)
    if (jsonRoot == Invalid_JSON)
    {
        json_free(jsonRoot)
        set_fail_state("[%s] Slot machine pattern was not loaded (%s)", PLUGIN, szFilePath)
    }

    g_iReelsNum = json_array_get_count(jsonRoot)
    if (g_iReelsNum < 2 || g_iReelsNum >= MAX_REELS)
    {
        json_free(jsonRoot)
        set_fail_state("[%s] Invalid slot machine reels number: %d", PLUGIN, g_iReelsNum)
    }

    new JSON:jsonReel
    for (new i, j; i < g_iReelsNum; i++)
    {
        jsonReel = json_array_get_value(jsonRoot, i)
        g_iLinesNum = json_array_get_count(jsonReel)
        if (g_iLinesNum < 3 || g_iLinesNum >= MAX_LINES)
        {
            json_free(jsonReel)
            json_free(jsonRoot)
            set_fail_state("[%s] Invalid slot machine lines number: %d at %d", PLUGIN, g_iLinesNum, i)
        }

        for (j = 0; j < g_iLinesNum; j++)
            g_matPattern[i][j] = json_array_get_number(jsonReel, j)

        json_free(jsonReel)
    }

    json_free(jsonRoot)
}

load_machines()
{
    new szFilePath[128]
    get_spawns_filepath(szFilePath, charsmax(szFilePath))

    new JSON:jsonRoot = json_parse(szFilePath, true)

    if (jsonRoot == Invalid_JSON)
    {
        json_free(jsonRoot)
        log_amx("[%s] Slot machine spawns were not loaded", PLUGIN)
        return
    }

    new iVersion = json_object_get_number(jsonRoot, "version")
    switch (iVersion)
    {
        case 1:
        {
            new JSON:jsonSpawns = json_object_get_value(jsonRoot, "spawns")
            new iMachinesNum = json_array_get_count(jsonSpawns)
            new JSON:jsonTransform, JSON:jsonOrigin, JSON:jsonAngles
            new Float:vOrigin[3], Float:vAngles[3]

            for (new i, axis; i < iMachinesNum; i++)
            {
                jsonTransform = json_array_get_value(jsonSpawns, i)
                jsonOrigin = json_object_get_value(jsonTransform, "origin")
                jsonAngles = json_object_get_value(jsonTransform, "angles")

                for (axis = 0; axis < 3; axis++)
                {
                    vOrigin[axis] = json_array_get_real(jsonOrigin, axis)
                    vAngles[axis] = json_array_get_real(jsonAngles, axis)
                }

                create_machine(vOrigin, vAngles)
                json_free(jsonAngles)
                json_free(jsonOrigin)
                json_free(jsonTransform)
            }

            json_free(jsonSpawns)
        }
    }

    json_free(jsonRoot)
}

bool:save_machines()
{
    new szFilePath[128]
    get_spawns_filepath(szFilePath, charsmax(szFilePath))

    new JSON:jsonRoot = json_init_object()
    json_object_set_number(jsonRoot, "version", 1)

    new JSON:jsonSpawns = json_init_array()

    new JSON:jsonTransform, JSON:jsonOrigin, JSON:jsonAngles
    new Float:vOrigin[3], Float:vAngles[3]
    new iEnt, axis

    while ((iEnt = rg_find_ent_by_class(iEnt, CLASSNAME_SLOTMACHINE)))
    {
        jsonTransform = json_init_object()
        jsonOrigin = json_init_array()
        jsonAngles = json_init_array()

        get_entvar(iEnt, var_origin, vOrigin)
        get_entvar(iEnt, var_angles, vAngles)

        for (axis = 0; axis < 3; axis++)
        {
            json_array_append_real(jsonOrigin, vOrigin[axis])
            json_array_append_real(jsonAngles, vAngles[axis])
        }

        json_object_set_value(jsonTransform, "origin", jsonOrigin)
        json_object_set_value(jsonTransform, "angles", jsonAngles)
        json_array_append_value(jsonSpawns, jsonTransform)

        json_free(jsonAngles)
        json_free(jsonOrigin)
        json_free(jsonTransform)
    }

    json_object_set_value(jsonRoot, "spawns", jsonSpawns)
    json_free(jsonSpawns)

    new bool:result = json_serial_to_file(jsonRoot, szFilePath, true)
    json_free(jsonRoot)

    return result
}
