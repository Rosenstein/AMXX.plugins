#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#pragma semicolon 1

#define MAX_MAPS 200
#define TIMEBETWEENMAPS 3600

new g_mapNameHolder[4][32];

new g_fourVoteResults[4];

new g_twoNominatedMaps[2];
new g_twoVoteResults[2];

new bool:g_votingDone = false;
new bool:g_inFourVote = false;
new bool:g_inTwoVote = false;

new Handle:g_loginData;
new Handle:g_connection;

//**
//   Init
//        **
public plugin_init()
{
	register_plugin("advancedMapchooser", "0.5", "MaximusBrood");
	register_cvar("advancedmapchooser_version", "0.5", FCVAR_SERVER);
	
	//Dictionary
	register_dictionary("mapchooser.txt");
	register_dictionary("common.txt");
	
	//Commands
	register_clcmd("amx_setnextmap", "cmd_setNextmap", ADMIN_MAP, "- [map]");
	register_concmd("amx_testmaps", "cmd_testMaps", ADMIN_LEVEL_A, "- test all the maps in the database for validity");
	register_concmd("amx_checkmap", "cmd_checkMap", ADMIN_LEVEL_A, "- [mapname]");
	register_concmd("amx_addmap", "cmd_addMap", ADMIN_LEVEL_A, "- [mapname] [minplayers] [maxplayers]");
	register_concmd("amx_removemap", "cmd_removeMap", ADMIN_LEVEL_A, "- [mapname]");
	
	//Database 
	g_loginData = SQL_MakeStdTuple();
	
	if(connectDatabase())
		set_task(15.0, "taskStartVote", 987456, "", 0, "b");
		
	testMaps(-1);
}

public plugin_end()
{
	//Update the record of the current map
	//Only update it if the map has been completed
	if(g_connection != Empty_Handle)
	{
		if(g_votingDone)
		{
			new mapname[32];
			get_mapname(mapname, 31);
			server_print("Updating map %s (%d)!", mapname, get_timeleft());
			
			SQL_QueryAndIgnore(g_connection, "UPDATE `maps` SET `playCount` = `playCount` + 1, `lastPlayed` = %d WHERE `mapname` = '%s';", get_systime(), mapname);
		}
		
		SQL_FreeHandle(g_connection);
	}
}

//**
//   Maplist Loading Functions
//                             **
bool:connectDatabase()
{
	//This plugin is mysql only, exit fatally out if we aren't on mysql
	new databaseType[11];
	SQL_GetAffinity(databaseType, 10);
	
	if(!equali(databaseType, "mysql"))
	{
		log_amx("This plugin does not work with SQLite! Plugin will be disabled.");
		
		g_connection = Empty_Handle;
		return false;
	}
	
	//Try to connect to the database
	new errorCode, errorMessage[256];
	g_connection = SQL_Connect(g_loginData, errorCode, errorMessage, 255);
	
	if(g_connection == Empty_Handle)
	{
		log_amx("Error while connecting to database. %s (%d)", errorMessage, errorCode);
		return false;
	}	
	
	SQL_QueryAndIgnore(g_connection, "CREATE TABLE IF NOT EXISTS `maps` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY ,`mapname` VARCHAR( 32 ) NOT NULL ,`minPlayers` TINYINT NOT NULL ,`maxPlayers` TINYINT NOT NULL ,`playCount` INT NOT NULL ,`lastPlayed` BIGINT NOT NULL ,UNIQUE (`mapname`));");
	
	return true;
}

handleExecuteQuery(Handle:query, errorNumber)
{
	if(!SQL_Execute(query))
	{
		static errorMessage[256];
		SQL_QueryError(query, errorMessage, 255);
				
		log_amx("Error while attempting to query maps database. %s (%d)", errorMessage, errorNumber);
		SQL_FreeHandle(query);
		return 0;
	}
	
	return 1;
}

invertedRouletteSelection(collection[], collectionSize, results[])
{
	//Check if less then 4 numbers are given
	if (collectionSize < 4)
	{
		log_amx("Too small collection for rouletteSelection (%d)", collectionSize);
		return 0;
	}

	//Get the total
	//Also increment the collection
	new Float:total = 0.0;
	for (new a = 0; a < collectionSize; ++a)
	{
		++collection[a];
		total += 1.0 / (collection[a] == 0 ? 1.0 : float(collection[a]) );
	}

	new Float:currentSum;
	new Float:targetNumber;
	
	new infiniteCheck = 0;				
	for (new a = 0; a < 4; ++a)
	{
		//Reset the sum            
		currentSum = 0.0;

		//Get the random target number
		targetNumber = random_float(0.0, 1.0) * total;

		//Start the wheel
		for (new b = 0; b < collectionSize; ++b)
		{
			currentSum += 1.0 / (collection[b] == 0 ? 1.0 : float(collection[b]) );

			if (currentSum >= targetNumber)
			{
				results[a] = b;
				break;
			}
		}

		//Make sure the result is not duplicate
		for (new b = 0; b < a; ++b)
		{
			if (results[a] == results[b])
			{
				--a;
				break;
			}
		}
		
		//Make sure we're not in an infinite loop
		//This function isn't very expensive, so we set a big limit
		if(++infiniteCheck > 1000)
		{
			log_amx("rouletteSelection got into an infinite loop. (%d maps) (%d check)", collectionSize, infiniteCheck);
			return 0;
		}

	}

	//Decrement back
	for (new a = 0; a < collectionSize; ++a)
		--collection[a];

	return 1;
}

public getMapsFromSQL(output[][], outputLenght)
{
	if(g_connection == Empty_Handle)
	{
		log_amx("getMapsFromSQL didn't have a database connection");
		return 0;
	}
	
	//Get the number of players minus HLTV or bots
	new currPlayers, temp[32];
	get_players(temp, currPlayers, "ch");
	
	//Query handle which is used for almost everything
	new Handle:query;
	
	//Get all the maps which:
	// - Are suited for the current amount of players
	// - Hasn't been into play for the last hour
	// - Isn't the current map
	new currentMap[32];
	get_mapname(currentMap, 31);
	
	query = SQL_PrepareQuery(g_connection, "SELECT `id`, `playCount` FROM `maps` WHERE `minPlayers` <= %d AND (`maxPlayers` >= %d OR `maxplayers` = 0) AND `lastPlayed` <= %d AND `mapname` != '%s';", currPlayers, currPlayers, (get_systime() - TIMEBETWEENMAPS), currentMap);
	
	if(!handleExecuteQuery(query, 0))
	{
		log_amx("Error while executing first query");
		return 0;
	}
	
	//Collect all playtimes into an array for inverted roulette selection
	new mapAmount = SQL_NumResults(query);
	
	if(mapAmount < 4)
	{
		log_amx("Less than 4 maps were found");
		return 0;
	}
	
	static idCollection[MAX_MAPS];
	static playCountCollection[MAX_MAPS];
		
	for(new a = 0; a < mapAmount && a < MAX_MAPS; ++a)
	{
		idCollection[a] = SQL_ReadResult(query, 0);
		playCountCollection[a] = SQL_ReadResult(query, 1);
		
		SQL_NextRow(query);
	}
	
	SQL_FreeHandle(query);	
	
	//Do the inverted roulette selection
	new rouletteResults[4];
	if(!invertedRouletteSelection(playCountCollection, mapAmount, rouletteResults))
	{
		log_amx("Error while doing roulette selection");
		return 0;
	}
	
	//Get the names of the four nominated maps
	query = SQL_PrepareQuery(g_connection, "SELECT `mapname` FROM `maps` WHERE `id` = %d OR `id` = %d OR `id` = %d OR `id` = %d;", idCollection[rouletteResults[0]], idCollection[rouletteResults[1]], idCollection[rouletteResults[2]], idCollection[rouletteResults[3]] );
	
	if(!handleExecuteQuery(query, 1))
	{
		log_amx("Error while retrieving mapnames");
		return 0;
	}
	
	mapAmount = SQL_NumResults(query);
	
	//Check if a map dissappeared magically
	if(mapAmount != 4)
	{
		log_amx("Magic occured (gaspian gasp)");
		return 0;
	}
			
	for(new a = 0; a < 4; ++a)
	{
		SQL_ReadResult(query, 0, output[a], outputLenght - 1);
		
		SQL_NextRow(query);
	}
	
	//Pickle Surprise!
	return 1;
}

//**
//   Commands
//            **

//Two errormessages
new g_errorNoConnection[]	= "Cannot perform action; no database connection.";
new g_errorQuery[]			= "Error occured while trying to query maps database.";

//Small helper
concmdPrint(id, message[], ...)
{
	static textToPrint[128];
	
	//Format the line
	vformat(textToPrint, 127, message, 3);
	
	if(id == 0)
		server_print("%s", textToPrint);
	else
		client_print(id, print_console, "%s", textToPrint);
}

public cmd_setNextmap(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
		
	static arg1[32];
	read_argv(1, arg1, 31);
	
	if(!is_map_valid(arg1))
	{
		client_print(id, print_console, "The map you specified couldn't be found.");
		return PLUGIN_CONTINUE;
	}
	
	g_votingDone = true;
	set_cvar_string("amx_nextmap", arg1);
	
	client_print(id, print_console, "Nextmap was successfully set to %s", arg1);
	client_print(0, print_chat, "The nextmap was set to %s", arg1);
	
	static username[32];
	get_user_name(id, username, 31);
	log_amx("ADMIN %s set the nextmap to %s", username, arg1);
	
	return PLUGIN_CONTINUE;
}

public cmd_testMaps(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	testMaps(id);
	
	return PLUGIN_CONTINUE;
}

testMaps(id)
{
	//Check the database connection
	if(g_connection == Empty_Handle)
	{
		if(id != -1)
			concmdPrint(id, g_errorNoConnection);
		
		return;
	}	
	
	//Prepare and execute query
	new Handle:query;
	query = SQL_PrepareQuery(g_connection, "SELECT `mapname` FROM `maps`");
	
	//Errormessage on query error
	if(!handleExecuteQuery(query, 2))
	{
		if(id == -1)
			log_amx(g_errorQuery);
		else
			concmdPrint(id, g_errorQuery);
		
		return;
	}
	
	static currMapname[32];
	new resultAmount = SQL_NumResults(query);
	
	//Loop the results
	new bool:foundInvalidMap = false;
	
	for(new a = 0; a < resultAmount; ++a)
	{
		SQL_ReadResult(query, 0, currMapname, 31);
		
		if(!is_map_valid(currMapname))
		{
			foundInvalidMap = true;
			
			if(id == -1)
				log_amx("Map %s is _not_ valid! Please correct.", currMapname);
			else
				concmdPrint(id, "Map %s is _not_ valid! Please correct.", currMapname);
		}
		
		SQL_NextRow(query);
	}
	
	if(!foundInvalidMap && id != -1)
		concmdPrint(id, "No invalid maps were found");
	
	SQL_FreeHandle(query);
}

/*public cmd_forceVote()
{
	startVote(true);
	return PLUGIN_CONTINUE;
}*/

public cmd_checkMap(id, level, cid)
{
	//Arguments: mapname
	
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
		
	//Check the database connection
	if(g_connection == Empty_Handle)
	{
		concmdPrint(id, g_errorNoConnection);
		return PLUGIN_CONTINUE;
	}	
	
	//Check for enough arguments
	if(read_argc() < 2)
	{
		concmdPrint(id, "Syntax: amx_checkmap [mapname]");
		return PLUGIN_CONTINUE;
	}
	
	//Get the mapname
	static mapname[32];
	read_argv(1, mapname, 31);
	
	//Prepare and execute query
	new Handle:query;
	query = SQL_PrepareQuery(g_connection, "SELECT `mapname`, `minPlayers`, `maxPlayers`, `playCount` FROM `maps` WHERE `mapname` LIKE '%%%s%%';", mapname);
	
	//Errormessage on query error
	if(!handleExecuteQuery(query, 3))
	{
		concmdPrint(id, g_errorQuery);
		return PLUGIN_CONTINUE;
	}
	
	new resultAmount = SQL_NumResults(query);
	
	//Check if the map was found
	if(resultAmount < 1)
	{
		concmdPrint(id, "No maps were found in the database with the (partial) name %s.", mapname);
	}
	
	static currMapname[32];
	
	//Loop the results
	for(new a = 0; a < resultAmount; ++a)
	{
		SQL_ReadResult(query, 0, currMapname, 31);
		concmdPrint(id, "Found map in database: %s. (minPlayers %d, maxPlayers %d, playcount %d)", currMapname, SQL_ReadResult(query, 1), SQL_ReadResult(query, 2), SQL_ReadResult(query, 3));
		
		SQL_NextRow(query);
	}
	
	SQL_FreeHandle(query);
	
	return PLUGIN_CONTINUE;
}

public cmd_addMap(id, level, cid)
{
	//Arguments: mapname, minPlayers, maxPlayers
	
	if (!cmd_access(id, level, cid, 4))
		return PLUGIN_HANDLED;
		
	//Check the database connection
	if(g_connection == Empty_Handle)
	{
		concmdPrint(id, g_errorNoConnection);
		return PLUGIN_CONTINUE;
	}	
	
	//Check for enough arguments
	if(read_argc() < 4)
	{
		concmdPrint(id, "Syntax: amx_checkmap [mapname] [minplayers] [maxplayers]");
		return PLUGIN_CONTINUE;
	}
	
	//Read the arguments
	new mapname[32], temp[5], minPlayers, maxPlayers;
	
	read_argv(1, mapname, 31);
	
	read_argv(2, temp, 4);
	minPlayers = str_to_num(temp);
	
	read_argv(3, temp, 4);
	maxPlayers = str_to_num(temp);
	
	//Check if the arguments are in the correct range
	if( !( (0 <= minPlayers < 33) && (0 <= maxPlayers <= 33) ) )
	{
		concmdPrint(id, "Min- and or maxplayers or not in the correct range. (0 - 32)");
		return PLUGIN_CONTINUE;
	}
	
	//Remove the map from the database
	new Handle:query;
	query = SQL_PrepareQuery(g_connection, "DELETE FROM maps WHERE mapname = '%s';", mapname);
	
	if(!handleExecuteQuery(query, 4))
	{
		concmdPrint(id, g_errorQuery);
		return PLUGIN_CONTINUE;
	}
	
	//Notify the user if the map already existed
	if(SQL_AffectedRows(query) > 0)
		concmdPrint(id, "Map %s was already in the database. It will be replaced now.", mapname);
		
	SQL_FreeHandle(query);
	
	//Add the map
	query = SQL_PrepareQuery(g_connection, "INSERT INTO `maps` (`mapname`, `minPlayers`, `maxPlayers`) VALUES ('%s', %d, %d);", mapname, minPlayers, maxPlayers);
	
	if(!handleExecuteQuery(query, 5))
	{
		concmdPrint(id, g_errorQuery);
		return PLUGIN_CONTINUE;
	}
	
	SQL_FreeHandle(query);
	
	concmdPrint(id, "Map %s was successfully added to the database.", mapname);
	return PLUGIN_CONTINUE;
}

public cmd_removeMap(id, level, cid)
{
	//Arguments: mapname
	
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
		
	//Check the database connection
	if(g_connection == Empty_Handle)
	{
		concmdPrint(id, g_errorNoConnection);
		return PLUGIN_CONTINUE;
	}	
	
	//Check for enough arguments
	if(read_argc() < 2)
	{
		concmdPrint(id, "Syntax: amx_removemap [mapname]");
		return PLUGIN_CONTINUE;
	}
	
	//Read the arguments
	new mapname[32];
	read_argv(1, mapname, 31);
	
	//Remove the map
	new Handle:query;
	query = SQL_PrepareQuery(g_connection, "DELETE FROM `maps` WHERE `mapname` = '%s';", mapname);
	
	if(!handleExecuteQuery(query, 6))
	{
		concmdPrint(id, g_errorQuery);
		return PLUGIN_CONTINUE;
	}
	
	if(SQL_AffectedRows(query) > 0)
		concmdPrint(id, "Map %s was successfully deleted from the database.", mapname);
	else
		concmdPrint(id, "Map %s is not in the database and therefore couldn't be deleted.", mapname);
		
	SQL_FreeHandle(query);
	
	return PLUGIN_CONTINUE;
}

//**
//   Helper Functions
//                    **
closeAllMenus(exitbutton)
{
	new players[32], playerNum;
	new menu1, menu2;
	
	get_players(players, playerNum, "ch");
	
	for(new a = 0; a < playerNum; ++a)
	{
		if(player_menu_info(players[a], menu1, menu2) && menu2 != -1)
		{
			//Close the menu
			client_cmd(players[a], "slot%d", exitbutton);
			
			//Invalidate the menu
			menu_cancel(players[a]);
		}
	}
}

getHighestKey(array[], limit)
{
	new b = 0;
	
	for (new a = 0; a < limit; ++a)
		if (array[b] < array[a])
			b = a;
			
	return b;
}

setNextmap(nextmap[])
{
	client_print(0, print_chat, "Choosing finished. The nextmap will be %s.", nextmap);
	log_amx("Vote: Voting for the nextmap finished. The nextmap will be %s.", nextmap);
	
	set_cvar_string("amx_nextmap", nextmap);
}

//**
//   Main Plugin Functions
//                         **
public taskStartVote()
	startVote();
	
startVote(bool:forceVote = false)
{
	//Check if we need to put up vote (3 minutes)
	if( !forceVote && ( !(0 < get_timeleft() < 179) || g_votingDone) )
		return;

	g_votingDone = true;
	
	//Create a new menu
	new fourMenu = menu_create("Gotjuice nextmap voting: (stage one)", "menuHandler_fourMenu");
	
	//Get maps to vote on via SQL. Return errormessage on error. (DOH!)
	if(!getMapsFromSQL(g_mapNameHolder, 32))
	{
		log_amx("Error while trying to collect maps");
		return;
	}
	
	//Add all the maps to the menu
	menu_additem(fourMenu, g_mapNameHolder[0], "0");
	menu_additem(fourMenu, g_mapNameHolder[1], "1");
	menu_additem(fourMenu, g_mapNameHolder[2], "2");
	menu_additem(fourMenu, g_mapNameHolder[3], "3");
		
	//Blank item and exit button name
	menu_addblank(fourMenu, 0);
	menu_setprop(fourMenu, MPROP_EXITNAME, "None");
	
	//Empty the vote results
	for(new a = 0; a < 4; ++a)
		g_fourVoteResults[a] = 0;
		
	//Show menu to all players
	new players[32], playernum;
	get_players(players, playernum, "ch");
	
	for(new a = 0; a < playernum; ++a)
		menu_display(players[a], fourMenu, 0);
		
	//Notify the user the vote started in different ways
	client_print(0, print_chat, "It's time to choose the nextmap...");
	client_cmd(0, "spk Gman/Gman_Choose2");
	
	log_amx("Vote: Voting for the nextmap started");
	
	//Set a 15 second timer to exit the vote and get the results
	set_task(15.0, "fourMenuEnd");
	
	g_inFourVote = true;
}

public menuHandler_fourMenu(id, menu, item) 
{
	//Check if the user has hit none
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED;
	
	new access, callback, strCommand[4], itemName[32];
	menu_item_getinfo(menu, item, access, strCommand, 3, itemName, 31, callback);
	
	//If a map was chosen
	if('0' <= strCommand[0] <= '3')
	{
		//If we are allowed to show votes, display them
		if (get_cvar_float("amx_vote_answers"))
		{
			static username[32];
			get_user_name(id, username, 31);
		
			client_print(0, print_chat, "%s chose %s", username, itemName);
		}
		
		//Register the vote
		++g_fourVoteResults[item];
	}
			
	return PLUGIN_HANDLED;
}

public fourMenuEnd()
{
	g_inFourVote = false;
	
	//Before proceeding, check if the vote has been made
	if(!g_votingDone || g_inTwoVote)
		return;
	
	//Quit all votes
	closeAllMenus(5);
	
	new firstMap, secondMap;
	
	//Get the highest key
	firstMap = getHighestKey(g_fourVoteResults, 4);
	
	//Check if somebody actually voted
	if(g_fourVoteResults[firstMap] == 0)
	{
		client_print(0, print_chat, "Nobody voted. The nextmap was not set.");
		return;
	}
	
	//Get the second highest key
	g_fourVoteResults[firstMap] = 0;
	secondMap = getHighestKey(g_fourVoteResults, 4);
	
	//Check if it was a unanime vote, if it was, set the nextmap to that map
	if(g_fourVoteResults[secondMap] == 0)
	{
		setNextmap(g_mapNameHolder[firstMap]);
		return;
	}
	
	client_print(0, print_chat, "The two most chosen maps are now revoted!");
	
	//We now have the two most chosen maps, make a new vote
	new twoMenu = menu_create("Gotjuice nextmap voting: (final stage)", "menuHandler_twoMenu");
	
	g_twoNominatedMaps[0] = firstMap;
	g_twoNominatedMaps[1] = secondMap;
	
	menu_additem(twoMenu, g_mapNameHolder[firstMap], "0");
	menu_additem(twoMenu, g_mapNameHolder[secondMap], "1");
	menu_addblank(twoMenu);
	menu_setprop(twoMenu, MPROP_EXITNAME, "None");
	
	//Empty the vote results
	for(new a = 0; a < 2; ++a)
		g_twoVoteResults[a] = 0;
		
	//Show menu to all players
	new players[32], playernum;
	get_players(players, playernum, "ch");
	
	for(new a = 0; a < playernum; ++a)
		menu_display(players[a], twoMenu, 0);
		
	//Notify user
	client_cmd(0, "spk Gman/Gman_Choose2");
	
	//Set a 15 second timer to exit the vote and get the results
	set_task(15.0, "twoMenuEnd");
	
	g_inTwoVote = true;
}

public menuHandler_twoMenu(id, menu, item) 
{
	//Check if the user has hit none
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED;
	
	new access, callback, strCommand[4], itemName[32];
	menu_item_getinfo(menu, item, access, strCommand, 3, itemName, 31, callback);
	
	//If a map was chosen
	if('0' <= strCommand[0] <= '1')
	{
		//If we are allowed to show votes, display them
		if (get_cvar_float("amx_vote_answers"))
		{
			static username[32];
			get_user_name(id, username, 31);
		
			client_print(0, print_chat, "%s chose %s", username, itemName);
		}
		
		//Register the vote
		++g_twoVoteResults[item];
	}
			
	return PLUGIN_HANDLED;
}

public twoMenuEnd()
{
	g_inTwoVote = false;
	
	//Before proceeding, check if the vote has been made
	if(!g_votingDone || g_inFourVote)
		return PLUGIN_HANDLED;
	
	//Quit all votes
	closeAllMenus(3);
	
	//Get the winner
	new winningMap = getHighestKey(g_twoVoteResults, 2);
	
	if(g_twoVoteResults[winningMap] == 0)
		return PLUGIN_HANDLED;
		
	//Set the nextmap to the winning map
	setNextmap(g_mapNameHolder[g_twoNominatedMaps[winningMap]]);
	
	return PLUGIN_HANDLED;
}
