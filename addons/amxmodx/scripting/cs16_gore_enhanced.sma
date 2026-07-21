//==============================================================================
//
//  CS 1.6 — Gore Enhanced
//
//  A server-side AMX Mod X plugin that cranks up the blood & gore:
//
//    * Bigger blood bursts and directional blood streams on every hit
//    * Blood splat decals around wounded players
//    * Death = blood explosion + flying fleshy giblets (extra on grenades)
//    * Headshot kills pop extra skull chunks + an arterial gush
//    * Optional damage-based red screen flash for the victim
//    * "Extreme" mode that multiplies everything
//
//  No custom resources are required: it reuses the stock Half-Life
//  fleshgibs/hgibs models, the stock blood sprites and the stock blood
//  decals from decals.wad, so players need zero downloads.
//
//  Requires: AMX Mod X 1.8.3 or newer (1.9/1.10 recommended), fakemeta.
//
//  License: MIT
//
//==============================================================================

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#define PLUGIN_NAME    "CS16 Gore Enhanced"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "noobsaltaccs-commits"

/* Blood palette index (red) — from the HL SDK const.h */
#define BLOOD_COLOR_RED 247

/* TE_BREAKMODEL material flag for fleshy gibs */
#if !defined BREAK_FLESH
    #define BREAK_FLESH 4
#endif

/*
 * Decal indexes inside the stock decals.wad.
 *   190-197 = red blood splats, 198-204 = large blood pools.
 * If your server ships a custom decals.wad and the wrong decals show up,
 * tweak these arrays and recompile.
 */
new const SMALL_BLOOD_DECALS[] = { 190, 191, 192, 193, 195, 196, 197 };
new const BIG_BLOOD_DECALS[]   = { 198, 199, 200, 201, 202, 203, 204 };

/* CVars */
new g_pMode;        // amx_gore_mode        0 = off, 1 = normal, 2 = EXTREME
new g_pBlood;       // amx_gore_blood       extra blood streams/sprays
new g_pDecals;      // amx_gore_decals      blood splat/pool decals
new g_pGibs;        // amx_gore_gibs        gib bodies on death
new g_pGibCount;    // amx_gore_gibcount    base number of giblets
new g_pHeadshot;    // amx_gore_headshot    extra skull gibs on headshot kills
new g_pFlash;       // amx_gore_screenflash red flash for the victim

/* Precached stock resources (-1 = missing on this server, effect skipped) */
new g_iFleshGibModel = -1;
new g_iSkullGibModel = -1;
new g_iBloodSpraySpr = -1;
new g_iBloodDropSpr  = -1;

new g_msgScreenFade;

//------------------------------------------------------------------------------
// Precaching (must happen here, not in plugin_init)
//------------------------------------------------------------------------------
public plugin_precache()
{
    if (file_exists("models/fleshgibs.mdl"))
        g_iFleshGibModel = precache_model("models/fleshgibs.mdl");

    if (file_exists("models/hgibs.mdl"))
        g_iSkullGibModel = precache_model("models/hgibs.mdl");

    /* Fallback: if fleshgibs is missing but hgibs exists, gib with skulls. */
    if (g_iFleshGibModel < 0 && g_iSkullGibModel >= 0)
        g_iFleshGibModel = g_iSkullGibModel;

    if (file_exists("sprites/bloodspray.spr"))
        g_iBloodSpraySpr = precache_model("sprites/bloodspray.spr");

    if (file_exists("sprites/blood.spr"))
        g_iBloodDropSpr = precache_model("sprites/blood.spr");
}

//------------------------------------------------------------------------------
// Plugin init
//------------------------------------------------------------------------------
public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
    register_cvar("cs16_gore_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY);

    g_pMode     = register_cvar("amx_gore_mode",        "1");
    g_pBlood    = register_cvar("amx_gore_blood",       "1");
    g_pDecals   = register_cvar("amx_gore_decals",      "1");
    g_pGibs     = register_cvar("amx_gore_gibs",        "1");
    g_pGibCount = register_cvar("amx_gore_gibcount",    "6");
    g_pHeadshot = register_cvar("amx_gore_headshot",    "1");
    g_pFlash    = register_cvar("amx_gore_screenflash", "1");

    register_event("Damage",   "OnDamage",   "b", "2!0");
    register_event("DeathMsg", "OnDeathMsg", "a");

    register_concmd("amx_gore", "CmdGore", ADMIN_CVAR,
                    "<0|1|2> - set gore mode (0 off, 1 normal, 2 EXTREME)");

    g_msgScreenFade = get_user_msgid("ScreenFade");
}

//------------------------------------------------------------------------------
// Non-fatal hits: extra spurts, drops, decals, screen flash
//------------------------------------------------------------------------------
public OnDamage(id)
{
    new mode = get_pcvar_num(g_pMode);
    if (mode < 1 || !get_pcvar_num(g_pBlood))
        return;

    /* If this damage killed them, DeathMsg handles the big show. */
    if (!is_user_alive(id))
        return;

    new weapon, hitgroup;
    new attacker = get_user_attacker(id, weapon, hitgroup);
    new damage   = read_data(2);

    new Float:origin[3], Float:hit[3];
    pev(id, pev_origin, origin);
    hit = origin;
    hit[2] += (hitgroup == HIT_HEAD) ? 58.0 : 36.0;

    /* Blood exits away from the shooter (plus a bit of upward gush). */
    new Float:dir[3] = { 0.0, 0.0, 1.0 };
    if (attacker)
    {
        new Float:aorigin[3];
        pev(attacker, pev_origin, aorigin);

        dir[0] = origin[0] - aorigin[0];
        dir[1] = origin[1] - aorigin[1];
        dir[2] = 0.0;

        new Float:len = floatsqroot(dir[0] * dir[0] + dir[1] * dir[1]);
        if (len > 1.0)
        {
            dir[0] /= len;
            dir[1] /= len;
        }
        dir[2] = 0.6;
    }

    new mul = (mode >= 2) ? 2 : 1;
    new bool:bHeadshot = (hitgroup == HIT_HEAD);

    /* --- Blood streams, scaled by damage ------------------------------ */
    new streams = clamp(1 + damage / 25, 1, 4) * mul;
    if (bHeadshot)
        streams += mul;

    for (new i = 0; i < streams; i++)
    {
        new Float:d[3];
        d[0] = dir[0] + random_float(-0.5, 0.5);
        d[1] = dir[1] + random_float(-0.5, 0.5);
        d[2] = dir[2] + random_float(-0.2, 0.5);
        fx_blood_stream(hit, d, clamp(80 + damage * 2 + random_num(0, 80), 60, 250));
    }

    /* --- Droplet sprays ----------------------------------------------- */
    if (g_iBloodSpraySpr >= 0 && g_iBloodDropSpr >= 0)
    {
        new drops = (2 + (bHeadshot ? 1 : 0)) * mul;
        for (new i = 0; i < drops; i++)
        {
            new Float:p[3];
            p[0] = hit[0] + random_float(-16.0, 16.0);
            p[1] = hit[1] + random_float(-16.0, 16.0);
            p[2] = hit[2] + random_float(-8.0, 8.0);
            fx_blood_spray(p, random_num(3, 8));
        }
    }

    /* --- Splat decal on the floor nearby ------------------------------- */
    if (get_pcvar_num(g_pDecals) && (mode >= 2 || random_num(1, 100) <= 70))
    {
        new Float:p[3];
        p[0] = origin[0] + random_float(-60.0, 60.0);
        p[1] = origin[1] + random_float(-60.0, 60.0);
        p[2] = origin[2] - 30.0; /* near the floor */
        fx_world_decal(p, false);
    }

    /* --- Red flash for the victim -------------------------------------- */
    if (get_pcvar_num(g_pFlash))
        fx_screen_flash(id, damage);
}

//------------------------------------------------------------------------------
// Deaths: blood explosion, pools, giblets, skulls
//------------------------------------------------------------------------------
public OnDeathMsg()
{
    new mode = get_pcvar_num(g_pMode);
    if (mode < 1)
        return;

    new victim   = read_data(2);
    new headshot = read_data(3);
    new weapon[24];
    read_data(4, weapon, charsmax(weapon));

    if (victim < 1 || victim > get_maxplayers())
        return;

    new Float:origin[3], Float:mid[3];
    pev(victim, pev_origin, origin);
    mid = origin;
    mid[2] += 24.0;

    new mul = (mode >= 2) ? 2 : 1;
    new bool:bBlast = equali(weapon, "grenade") != 0;

    /* --- Radial blood explosion --------------------------------------- */
    if (get_pcvar_num(g_pBlood))
    {
        new n = 8 * mul;
        if (bBlast)
            n *= 2;

        for (new i = 0; i < n; i++)
        {
            new Float:d[3];
            d[0] = random_float(-1.0, 1.0);
            d[1] = random_float(-1.0, 1.0);
            d[2] = random_float(0.3, 1.2);
            fx_blood_stream(mid, d, random_num(120, 240));
        }

        if (g_iBloodSpraySpr >= 0 && g_iBloodDropSpr >= 0)
        {
            new drops = 6 * mul;
            for (new i = 0; i < drops; i++)
            {
                new Float:p[3];
                p[0] = mid[0] + random_float(-32.0, 32.0);
                p[1] = mid[1] + random_float(-32.0, 32.0);
                p[2] = mid[2] + random_float(-16.0, 24.0);
                fx_blood_spray(p, random_num(5, 10));
            }
        }
    }

    /* --- Blood pools under the corpse ---------------------------------- */
    if (get_pcvar_num(g_pDecals))
    {
        new pools = 2 + (headshot ? 1 : 0) + (mul - 1);
        if (bBlast)
            pools += 2;

        for (new i = 0; i < pools; i++)
        {
            new Float:p[3];
            p[0] = origin[0] + random_float(-80.0, 80.0);
            p[1] = origin[1] + random_float(-80.0, 80.0);
            p[2] = origin[2] - 30.0;
            fx_world_decal(p, true);
        }
    }

    /* --- Giblets --------------------------------------------------------- */
    if (get_pcvar_num(g_pGibs) && g_iFleshGibModel >= 0)
    {
        new count = clamp(get_pcvar_num(g_pGibCount), 1, 32) * mul;
        if (bBlast)
            count *= 2;

        fx_break_model(mid, g_iFleshGibModel, count);

        /* Headshot pop: skull chunks from the noggin. */
        if (headshot && get_pcvar_num(g_pHeadshot))
        {
            new Float:head[3];
            head = origin;
            head[2] += 58.0;

            new skullModel = (g_iSkullGibModel >= 0) ? g_iSkullGibModel
                                                     : g_iFleshGibModel;
            fx_break_model(head, skullModel, max(2, count / 2));

            for (new i = 0; i < 3 * mul; i++)
            {
                new Float:d[3];
                d[0] = random_float(-0.6, 0.6);
                d[1] = random_float(-0.6, 0.6);
                d[2] = random_float(0.8, 1.5);
                fx_blood_stream(head, d, random_num(160, 255));
            }
        }
    }
}

//------------------------------------------------------------------------------
// Admin command: amx_gore <0|1|2>
//------------------------------------------------------------------------------
public CmdGore(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    static const MODES[][] = { "OFF", "NORMAL", "EXTREME" };

    if (read_argc() < 2)
    {
        console_print(id, "[Gore] Current mode: %d (%s). Usage: amx_gore <0|1|2>",
                      get_pcvar_num(g_pMode),
                      MODES[clamp(get_pcvar_num(g_pMode), 0, 2)]);
        return PLUGIN_HANDLED;
    }

    new arg[4];
    read_argv(1, arg, charsmax(arg));
    new mode = clamp(str_to_num(arg), 0, 2);
    set_pcvar_num(g_pMode, mode);

    new name[32];
    get_user_name(id, name, charsmax(name));
    client_print(0, print_chat, "[Gore] %s set gore mode to %s", name, MODES[mode]);
    console_print(id, "[Gore] Mode set to %s", MODES[mode]);

    return PLUGIN_HANDLED;
}

//==============================================================================
// Effect helpers
//==============================================================================

/* Packs a float origin into plain cells for message_begin(). */
stock pack_origin(const Float:origin[3], out[3])
{
    out[0] = floatround(origin[0]);
    out[1] = floatround(origin[1]);
    out[2] = floatround(origin[2]);
}

/* Directional column of blood particles. */
stock fx_blood_stream(const Float:origin[3], const Float:dir[3], speed)
{
    new op[3];
    pack_origin(origin, op);
    message_begin(MSG_PVS, SVC_TEMPENTITY, op);
    write_byte(TE_BLOODSTREAM);
    write_coord(floatround(origin[0]));
    write_coord(floatround(origin[1]));
    write_coord(floatround(origin[2]));
    write_coord(floatround(dir[0] * 128.0));
    write_coord(floatround(dir[1] * 128.0));
    write_coord(floatround(dir[2] * 128.0));
    write_byte(BLOOD_COLOR_RED);
    write_byte(clamp(speed, 1, 255));
    message_end();
}

/* Bloodspray + droplet sprite burst. */
stock fx_blood_spray(const Float:origin[3], scale)
{
    new op[3];
    pack_origin(origin, op);
    message_begin(MSG_PVS, SVC_TEMPENTITY, op);
    write_byte(TE_BLOODSPRITE);
    write_coord(floatround(origin[0]));
    write_coord(floatround(origin[1]));
    write_coord(floatround(origin[2]));
    write_short(g_iBloodSpraySpr);
    write_short(g_iBloodDropSpr);
    write_byte(BLOOD_COLOR_RED);
    write_byte(clamp(scale, 1, 255));
    message_end();
}

/* Blood splat / pool decal on the nearest surface. */
stock fx_world_decal(const Float:origin[3], bool:bBig)
{
    new op[3];
    pack_origin(origin, op);
    message_begin(MSG_PVS, SVC_TEMPENTITY, op);
    write_byte(TE_WORLDDECAL);
    write_coord(floatround(origin[0]));
    write_coord(floatround(origin[1]));
    write_coord(floatround(origin[2]));

    if (bBig)
        write_byte(BIG_BLOOD_DECALS[random_num(0, charsmax(BIG_BLOOD_DECALS))]);
    else
        write_byte(SMALL_BLOOD_DECALS[random_num(0, charsmax(SMALL_BLOOD_DECALS))]);

    message_end();
}

/* Flying fleshy giblets with physics. */
stock fx_break_model(const Float:origin[3], model, count)
{
    new op[3];
    pack_origin(origin, op);
    message_begin(MSG_PVS, SVC_TEMPENTITY, op);
    write_byte(TE_BREAKMODEL);
    write_coord(floatround(origin[0]));
    write_coord(floatround(origin[1]));
    write_coord(floatround(origin[2]));
    write_coord(16);   /* bbox size  */
    write_coord(16);
    write_coord(16);
    write_coord(random_num(-120, 120)); /* velocity */
    write_coord(random_num(-120, 120));
    write_coord(random_num(150, 300));
    write_byte(100);                    /* random velocity variance */
    write_short(model);
    write_byte(clamp(count, 1, 255));
    write_byte(80);                     /* lifetime: 8 seconds */
    write_byte(BREAK_FLESH);
    message_end();
}

/* Brief red flash, intensity scaled by the damage taken. */
stock fx_screen_flash(id, damage)
{
    if (!g_msgScreenFade)
        return;

    message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, {0, 0, 0}, id);
    write_short(1 << 10);  /* fade time  */
    write_short(1 << 10);  /* hold time  */
    write_short(0x0000);   /* fade in+out */
    write_byte(200);
    write_byte(0);
    write_byte(0);
    write_byte(clamp(60 + damage, 60, 190));
    message_end();
}
