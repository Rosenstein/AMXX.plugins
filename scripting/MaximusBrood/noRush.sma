#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#pragma semicolon 1

#define PROTECTION_LENGTH 120
#define PUNISH_FREQUENCY 4

new g_baseOrigin[3] = { 1978, -768,  -31 };
new g_tOrigin[3]    = { -336,  339,  265 };
new g_ctOrigin[3]    = { -336, -1866, 265 };

new g_lastPunishment[33] = 0;
new bool:g_isBeingPunished[33] = false;

new g_screenfadeMessageId;

//----------------------------------------------------------------------------
//				Init
//----------------------------------------------------------------------------

public plugin_init()
{
	register_plugin("noRush", "0.1a", "MaximusBrood");
	register_cvar("norush_version", "0.1", FCVAR_SERVER);
	
	g_screenfadeMessageId = get_user_msgid("ScreenFade");

	//Enable only on aim_ak_colt
	new mapname[32];
	get_mapname(mapname, 31);
	
	if(equali(mapname, "aim_ak_colt") || equali(mapname, "aim_ak-colt"))
	{
		register_logevent("event_roundStart", 2, "1=Round_Start");
		register_logevent("event_roundEnd", 2, "1=Round_End");
		register_event("TextMsg", "event_roundEnd", "a", "2=#Game_will_restart_in");
	}
}

//----------------------------------------------------------------------------
//				Commands & Tasks
//----------------------------------------------------------------------------

new g_noRushTickCount;
new bool:g_stopRushTick = true;

public event_roundStart()
{
	//Reset the ticker
	g_noRushTickCount = 0;
	
	//Set hitboxes to normal for everyone who is being punished from the last round
	for(new a = 0; a < 33; ++a)
	{
		if(g_isBeingPunished[a] && is_user_connected(a) )
			set_user_hitzones(a, 0, 255);
	}
	
	//Start the taskloop
	g_stopRushTick = false;
	task_noRushTick();
	
	return PLUGIN_CONTINUE;
}

public event_roundEnd()
{
	//Stop the rushTick
	g_stopRushTick = true;
	
	return PLUGIN_CONTINUE;
}

public task_noRushTick()
{
	//If it is the second tick, show hudmessage + chatmessage
	if(g_noRushTickCount == 0)
	{
		set_hudmessage(255, 0, 0, -1.0, 0.4, 0, 6.0, 4.0);
		show_hudmessage(0, "Rush protection on: %d seconds", PROTECTION_LENGTH);
		
		client_print(0, print_chat, "Rush protection is on for %d seconds!", PROTECTION_LENGTH);
		client_print(0, print_chat, "You will fire blanks if you enter the other team's half of the map!");
	}
	
	//On the last tick
	if(g_noRushTickCount >= (PROTECTION_LENGTH - 1) )
	{
		//Notify the user of the ended rushprotection
		set_hudmessage(6, 219, 6, -1.0, 0.4, 0, 6.0, 4.0);
		show_hudmessage(0, "Rush protection has worn off");
		
		client_print(0, print_chat, "Rush protection has worn off. You can go to the other side now.");
		
		//Set hitboxes to normal for everyone who is being punished
		for(new a = 0; a < 33; ++a)
		{
			if(g_isBeingPunished[a] && is_user_connected(a))
				set_user_hitzones(a, 0, 255);
				
			g_isBeingPunished[a] = false;
		}
		
		//Cancel ourselfs
		return PLUGIN_CONTINUE;
	} else
	{
		//Check bounds
		checkBounds();
	}
		
	++g_noRushTickCount;
	
	//Set new task if not stopped
	if(!g_stopRushTick)
		set_task(1.0, "task_noRushTick");
	
	return PLUGIN_CONTINUE;
}

//----------------------------------------------------------------------------
//				Commands & Tasks
//----------------------------------------------------------------------------

checkBounds()
{
	//Collect all data
	static players[32], playerOrigin[3];
	new playersAmount, currentPlayer, currentTimestamp, punishTimestamp;
	new CsTeams:playerTeam;
	
	//All alive, non-bot players
	get_players(players, playersAmount, "ach");
	
	//Timestamps
	currentTimestamp = get_systime();
	punishTimestamp = currentTimestamp - PUNISH_FREQUENCY;
	
	for(new a = 0; a < playersAmount; ++a)
	{
		currentPlayer = players[a];
		playerTeam = cs_get_user_team(currentPlayer);
		
		//Check if the player is at the wrong half of the map
		//Moles may go anywhere
		get_user_origin(currentPlayer, playerOrigin);
		
		if       ( !isUserMole(currentPlayer, playerTeam) && 
				 ( (playerTeam == CS_TEAM_T  && isBetweenOrigin(g_baseOrigin, g_ctOrigin, playerOrigin) ) || 
				   (playerTeam == CS_TEAM_CT && isBetweenOrigin(g_baseOrigin, g_tOrigin,  playerOrigin) ) )
			)
		{
			//Record that the user is being punished
			g_isBeingPunished[currentPlayer] = true;
			
			set_user_hitzones(currentPlayer, 0, 0);
		} else
		{
			//Make the player ready to shoot again, and go to the next player
			if(g_isBeingPunished[currentPlayer])
				set_user_hitzones(currentPlayer, 0, 255);
				
			continue;
		}
		
		//Only people that are being punished get here
		//Make a red flash + HUD Message + sound every PUNISH_FREQUENCY seconds
		if( g_lastPunishment[currentPlayer] <= punishTimestamp)
		{
			//Red flash
			message_begin(MSG_ONE, g_screenfadeMessageId, {0, 0, 0}, currentPlayer);
			
			//Duration
			write_short(PUNISH_FREQUENCY * 1000);
			//Hold time
			write_short((PUNISH_FREQUENCY * 1000) / 3);
			//Fade type
			write_short(0);
			//Red
			write_byte(253);
			//Green
			write_byte(27);
			//Blue
			write_byte(27);
			//Alpha
			write_byte(200);
			
			message_end();
			
			//Hud Message
			set_hudmessage(0, 0, 255, -1.0, -1.0, 0, 6.0, float(PUNISH_FREQUENCY));
			show_hudmessage(currentPlayer, "Do NOT rush!^nYour shots won't do damage now.");
			
			//Sound
			client_cmd(currentPlayer, "spk vox/weapon.wav");
			set_task(1.2, "task_playMalfunctionSound", currentPlayer);
			
			//Set the last punish time
			g_lastPunishment[currentPlayer] = currentTimestamp;
		}
	}
}

public task_playMalfunctionSound(id)
{
	client_cmd(id, "spk vox/malfunction.wav");
}

//----------------------------------------------------------------------------
//				Helpers
//----------------------------------------------------------------------------

bool:isUserMole(id, CsTeams:userTeam)
{
	//T  Models: Arctic, Leet, Guerilla, Terror
	//CT Models: Sas, Gsg9, Urban, Gign
	
	//We do this by checking the first letter of the modelname
	//Guerilla and Gign share the same first letter. Just check the second letter
	new model[3];
	cs_get_user_model(id, model, 2);
	
	if( userTeam == CS_TEAM_CT && ( model[0] == 'a' || model[0] == 'l' || model[0] == 't' || (model[0] == 'g' && model[1] == 'u') ) )
		return true;
		
	if( userTeam == CS_TEAM_T  && (model[0] == 's' || model[0] == 'u' || (model[0] == 'g' && (model[1] == 's' || model[1] == 'i') )) )
		return true;
		
	return false;
}

bool:isBetweenOrigin(comparedOriginOne[3], comparedOriginTwo[3], playerOrigin[3])
{
	for(new a = 0; a < 3; a++)
	{
		if(comparedOriginOne[a] > comparedOriginTwo[a])
		{
			if( !(comparedOriginOne[a] >= playerOrigin[a] >= comparedOriginTwo[a]) )
				return false;
		} else
		{
			if( !(comparedOriginOne[a] <= playerOrigin[a] <= comparedOriginTwo[a]) )
				return false;
		}
	}
	
	return true;
}
