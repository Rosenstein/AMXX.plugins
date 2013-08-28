/*
//\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
//----------------------------\\
//| Super Slap |&&&&&&&&&&&&&|\\
//|------------|--------------\\     
//|&&&&&&&| by |&&&&&&&&&&&&&|\\
//|------------|--------------\\          
//|&&&&&&&&&&&&| MaximusBrood|\\
//----------------------------\\
////////////////////////////////


Will slap the victim multiple times with a given damage per slap
BUT, dieing is for the weak, it will slap to 1 hp, but it won't kill

Happy Slapping =)

---

Client Command:

* amx_superslap <name> [amount of slaps] [damage per slap]
      - Amount and damage can be omitted (will take defaults from the cvars)

Cvars:
* superslap_standardamount <integer>
      - If amount is omitted, this will be the amount of slaps
      
* superslap_standarddamage <integer>
      - If damage is omitted, this will be the damage per slap
      
* superslap_immunity <0/1>
      - 0 -> Don't obbey immunity /^\ 1 -> Obey immunity


*/

//******************************************************************************
//******************* Copyright (C) 2005  MaximusBrood *************************
//******************************************************************************
//     This script is free software; you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//                      the Free Software Foundation.
//      By compiling and/or executing this script you agree to this terms, found at:
//
//                   http://www.gnu.org/licenses/gpl.txt
//
//  If you find any bugs, please report them to me via mail, MSN or on the amxmodx.org forums
//                        Email: maximusbrood gmail com
//                        MSN  : maximus_brood123 hotmail com

#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Super Slap"
#define VERSION "0.2"
#define AUTHOR "MaximusBrood"

#define ADMINFLAG ADMIN_LEVEL_H //The flag needed for using SuperSlap
#define RANDOMSLAP 1            //If victim has to be trown in random direction, else the slap is controlable
#define SLAPINTERVAL 0.2        //How long to wait between slaps, no smaller value than 0.1


public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_concmd("amx_superslap","cmd_superslap", ADMINFLAG,"<name> [amount] [damage]") 
	
	register_cvar("superslap_standardamount", "10")
	register_cvar("superslap_standarddamage", "0")
	register_cvar("superslap_immunity", "1")
}

public cmd_superslap(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED
		
	new arg1[32], arg2[3], arg3[3]
	read_argv(1, arg1, 31)
	read_argv(2, arg2, 2)
	read_argv(3, arg3, 2)
	
	new amount, damage
	
	//Check if the amount of slaps is given, else, use the defaults
	if(arg2[0])
		amount = str_to_num(arg2)
	else
		amount = get_cvar_num("superslap_standardamount")
	
	//Check if the damage is given, else, use the defaults
	if(arg3[0])
		damage = str_to_num(arg3)
	else
		damage = get_cvar_num("superslap_standarddamage")
	
	new victim, playernum, a, players[32], slaparguments[3], team[32], adminname[32]
	
	get_user_name(id, adminname, 31)
	
	//Different args: @ALL @CT, @T and single name
	if(arg1[0] == '@')
	{
		if(equali(arg1, "@all"))
		{
			get_players(players, playernum, "ac")
			format(team, 31, "everyone")
		} else if(equali(arg1, "@ct"))
		{
			get_players(players, playernum, "ace", "CT")
			format(team, 31, "the Counter-Terrorists")
		} else if(equali(arg1, "@t"))
		{
			get_players(players, playernum, "ace", "TERRORIST")
			format(team, 31, "the Terrorists")
		} 
		
		//Do the slapping
		for(a = 0; a < playernum; a++)
		{
			if(!access(players[a], ADMIN_IMMUNITY) || get_cvar_num("superslap_immunity") == 0)
			{
				slaparguments[0] = players[a]
				slaparguments[1] = damage
				set_task(SLAPINTERVAL, "slap_task", 0, slaparguments, 2, "a", amount)
			}
		}
		
		//Inform Admin
		client_print(id, print_chat, "[AMXX] SuperSlapping %s %d times with %d damage", team, amount, damage)
		
		//Inform clients
		switch (get_cvar_num("amx_show_activity"))
		{
			case 1: client_print(0, print_chat, "[AMXX] The admin SuperSlaps %s %d times with %d damage", team, amount, damage)
			case 2: client_print(0, print_chat, "[AMXX] Admin %s SuperSlaps %s %d times with %d damage", adminname, team, amount, damage)
		}

		log_amx("[SUPERSLAP] Admin %s SuperSlaps %s %d times with %d damage", adminname, team, amount, damage);
	} else
	{
		//Check if immunity has to be obeyed
		switch(get_cvar_num("superslap_immunity"))
		{
			case 0: victim = cmd_target(id, arg1, 6)
			case 1: victim = cmd_target(id, arg1, 7)
		}
	
		//Check if victim is found
		if(!victim)
			return PLUGIN_HANDLED
	
		//Do the actual slapping
		slaparguments[0] = victim
		slaparguments[1] = damage
		set_task(SLAPINTERVAL, "slap_task", 0, slaparguments, 2, "a", amount)
	
		new victimname[32]
	
		//Inform the admin
		get_user_name(victim, victimname, 31)
		client_print(id, print_chat, "[AMXX] SuperSlapping client %s %d times with %d damage", victimname, amount, damage)
	
		//Inform the victim
		switch (get_cvar_num("amx_show_activity"))
		{
			case 1: client_print(victim, print_chat, "[AMXX] The admin SuperSlaps you %d times with %d damage", amount, damage)
			case 2: client_print(victim, print_chat, "[AMXX] Admin %s SuperSlaps you %d times with %d damage", adminname, amount, damage)
		}

		new username[64]
		get_user_name(victim, username, 63)		
		log_amx("[SUPERSLAP] Admin %s SuperSlaps %s %d times with %d damage", adminname, username, amount, damage);
	}
	return PLUGIN_HANDLED
} 

//Should spare a few cylces ^^
new health

public slap_task(args[], id) //args[0] = victim and args[1] = dmg
{
	//SLAP!!! MUHAHAHA! =p
	//We won't slap to death, death is for the weak, he must suffer ^^
	health = get_user_health(args[0])
	if((health - args[1]) > 1)
	{
		user_slap(args[0], args[1], RANDOMSLAP)
	} else
	{
		
		user_slap(args[0], (health - 1), RANDOMSLAP)
	}
}
