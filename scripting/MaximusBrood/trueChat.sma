#include <amxmodx>
#include <amxmisc>
#include <engine>

#pragma semicolon 1
#define DEBUG 0

new bool:g_heardCounter[33][33];
new messageIDSayText;

#if DEBUG == 1 || DEBUG == 2
new filepath[64];
#endif

public plugin_init() 
{
	register_plugin("Truechat", "0.1", "MaximusBrood");
	register_cvar("truechat_version", "0.1", FCVAR_SERVER);
	
	register_event("SayText", "catchSay", "b");
	
	messageIDSayText = get_user_msgid("SayText");
	
#if DEBUG == 1 || DEBUG == 2
	get_basedir(filepath, 63);
	format(filepath, 63, "%s/logs/trueLog.txt", filepath);
	
	new mapname[32];
	get_mapname(mapname, 31);
	log_to_file(filepath, "--------Mapchange: %s", mapname);
#endif
}

/*
With the SayText event, the message is sent to the person who sent it last.
It's sent to everyone else before the sender recieves it.
We want to catch the last one because we have had everyone that was supposed to hear it 
Now we will pass the message through to dead people/admins who are originally not supposed to see it.
*/
new gtmp_message[64], gtmp_channel[32], gtmp_senderName[32];

#if DEBUG == 2
new bool:isAdmin = false;
#endif

public catchSay(id)
{
	new reciever = read_data(0);
	new sender = read_data(1);
	
	//Register that the current person heard the message
	g_heardCounter[sender][reciever] = true;
	
	//Don't continue if it isn't the last message
	if(sender != reciever)
		return PLUGIN_CONTINUE;
		
	//Get info about message
	read_data(4, gtmp_message, 63);
	read_data(2, gtmp_channel, 31);
	get_user_name(sender, gtmp_senderName, 31);
		
	//Get players
	new players[32], playerNum, currPlayer;
	get_players(players, playerNum, "c");
	
	//Loop through all players
	for(new a = 0; a < playerNum; a++)
	{
		currPlayer = players[a];
		
		//If the player already got the message, don't check anything at all
		if(g_heardCounter[sender][currPlayer])
		{
			g_heardCounter[sender][currPlayer] = false;
			continue;
		}
		
		//For normal players: See alive chat when dead
		//You need to not have recieved the message and be dead
		//Also, check if it isn't team chat.
		//We do this by looking if there is a _T or CT in the channel name
		// (#CSTRIKE_CHAT_CT[_DEAD] and #CSTRIKE_CHAT_T[_DEAD]
		if(!is_user_alive(currPlayer) && contain(gtmp_channel, "_T") == -1 && contain(gtmp_channel, "CT") == -1)
		{
			displayMessage(currPlayer, sender, gtmp_channel, gtmp_senderName, gtmp_message);
			g_heardCounter[sender][currPlayer] = false;
			continue;
		}
		
		//For admins only. See all chat including team chat
		//You won't see anything double from previous query (the loop was continue'ed)
		if(get_user_flags(currPlayer) & ADMIN_LEVEL_A)
		{
#if DEBUG == 2
			isAdmin = true;
#endif
			displayMessage(currPlayer, sender, gtmp_channel, gtmp_senderName, gtmp_message);
			g_heardCounter[sender][currPlayer] = false;
		}
	}
	
	return PLUGIN_CONTINUE;
}

new gtmp_authid[33];

displayMessage(target, sender, channel[], senderName[], message[])
{
	get_user_authid(target, gtmp_authid, 32);
	
	//Check for fakeclients or users not connected
	if(!is_user_connected(target) || !is_user_connected(sender) || equal(gtmp_authid, "BOT"))
	{
#if DEBUG == 1 || DEBUG == 2
		log_to_file(filepath, "***: Fakeclient or disconnected user detected. Authid: ", gtmp_authid);
#endif		
		return;
	}
	
#if DEBUG == 2	
	log_to_file(filepath, "%s, %d, %d, %s, %s, %s", isAdmin ? "Admin" : "Normal", target, sender, channel, senderName, message);
	isAdmin = false;
#endif
	
	message_begin(MSG_ONE, messageIDSayText, {0, 0, 0}, target);
	write_byte(sender);
	write_string(channel);
	write_string(senderName);
	write_string(message);
	message_end();
}
