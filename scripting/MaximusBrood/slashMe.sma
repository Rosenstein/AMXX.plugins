/* Idea from `Emp's plugin, but totally rewritten */

#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1

//#define USE_COLOR

new g_userMessageSayText;

public plugin_init()
{
	register_plugin("slashMe", "0.2", "MaximusBrood");
	register_cvar("slashme_version", "0.2", FCVAR_SERVER);
	
	register_clcmd("say", "cmd_say");
	register_clcmd("say_team", "cmd_sayTeam");
	
	g_userMessageSayText = get_user_msgid("SayText");
}

public cmd_say(id)
	return readMessage(id, false);
	
public cmd_sayTeam(id)
	return readMessage(id, true);

//---

readMessage(id, bool:isTeamMessage)
{
	static message[128];
	
	read_args(message, 127);
	remove_quotes(message);
	
	//If the message is very long, somehow the trailing " is omitted, so remove_quotes() doesn't remove the preceding "
	//Therefore we check for "/me too
	if( equali(message, "/me", 3) || equali(message, "^"/me", 4 ) )
	{
		doEmote(id, message, isTeamMessage);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

doEmote(id, message[], bool:isTeamMessage)
{
	static finalMessage[128], name[32];
	
	get_user_name(id, name, 31);
	
#if defined USE_COLOR	
	format(finalMessage, 127, "^x04* %s %s", name, message[4]);
#else
	format(finalMessage, 127, "* %s %s", name, message[4]);
#endif

	static players[32], playerAmount;
	new flags[3];
	
	//If the user is dead, we want to send to dead only
	if( !is_user_alive(id) )
		flags[0] = 'b';
		
	//If the message is a team only, send to the appropriate team
	if( isTeamMessage )
	{
		new userTeam = get_user_team(id);
		
		//We don't care about spectators or unassigned people sending messages to their 'team'
		if(userTeam != 0 && userTeam != 3)
		{
			flags[(flags[0] == 0 ? 0 : 1)] = 'e';
			get_players( players, playerAmount, flags, (userTeam == 1 ? "TERRORIST" : "CT") );
		} else
			get_players(players, playerAmount, flags);
			
	} else
		get_players(players, playerAmount, flags);
		
	//Loop the selected players, and finally send the message
	new currentPlayer;
	for(new a = 0; a < playerAmount; ++a)
	{
		currentPlayer = players[a];
		
		message_begin(MSG_ONE, g_userMessageSayText, {0, 0, 0}, currentPlayer);
		write_byte(currentPlayer);
		write_string(finalMessage);
		message_end();
	}
}
