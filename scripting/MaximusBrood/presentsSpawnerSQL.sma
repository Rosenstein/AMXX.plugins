#include <amxmodx>
#include <amxmisc>
#include <engine>

#pragma semicolon 1

/* Configuration */

//-----------------------------------
//Only activate one of these two.

#define XMAS
//#define EASTER

//-----------------------------------
//Comment this if you are not using cstrike (there won't be rewards for picking up a present)

#define USING_CTRIKE

#if defined USING_CTRIKE
	#include <cstrike>
#endif

//-----------------------------------
//Database Info

//Comment this to not use a database
//#define USING_DATABASE

#define DATABASE_HOST ""
#define DATABASE_USERNAME ""
#define DATABASE_PASSWORD ""
#define DATABASE_DATABASE ""
#define WEBSITE_ROOT ""

#if defined USING_DATABASE
	#include <sqlx>
#endif

//Maximums

#define MAP_MAX 3800.0
#define TRIES_PER_RANDOM_PRESENT 5

#define MAX_SPAWNLOCATIONS 64

#define TOTAL_COLORS 10
#define EASTER_MAX_MODELS 5
#define XMAS_MAX_MODELS 2
//-----------------------------------

/* End configuration */

new gcvar_removePresents;
new gcvar_presentsPerSpawnpoint;
new gcvar_randomPresentAmount;

new g_orginFilePath[256];
new g_spawnOrigins[MAX_SPAWNLOCATIONS][3];
new g_totalOrigins;

//new g_rRectangleHolder[R_RECTANGLE_ARRAY_SIZE][R_RECTANGLE_ARRAY_SIZE];

#if defined USING_DATABASE
	new Handle:g_loginData;
	new Handle:g_connection;
	
	new g_queryHolder[512];
#endif

new Float:colors[TOTAL_COLORS][3] = 
{
	{95.0, 200.0, 255.0},
	{0.0, 150.0, 255.0},
	{180.0, 255.0, 175.0},
	{0.0, 155.0, 0.0},
	{255.0, 255.0, 255.0},
	{255.0, 190.0, 90.0},
	{222.0, 110.0, 0.0},
	{192.0, 192.0, 192.0},
	{190.0, 100.0, 10.0},
	{0.0, 0.0, 0.0}
};

//----------------------------------------------------------------------------
//							Init
//----------------------------------------------------------------------------
public plugin_init()
{
#if defined USING_DATABASE
	register_plugin("presentsSpawner", "1.5_SQL", "MaximusBrood");
#else
	register_plugin("presentsSpawner", "1.5", "MaximusBrood");
#endif
	register_dictionary("presentsspawner.txt");

	//Commands
	register_clcmd("amx_addspawnpoint", "cmd_addSpawn", ADMIN_RCON, "- add a spawnpoint at your current location");
	register_clcmd("amx_spawnpresent", "cmd_spawnPresent", ADMIN_RCON, "- Spawns an present at your current location");
	register_clcmd("amx_removepresents", "cmd_removePresents", ADMIN_RCON, "- Removes all presents from the map");

#if defined USING_DATABASE
	register_clcmd("say", "cmd_say");
#endif
	
	//Cvars
	gcvar_removePresents = register_cvar("sv_removepresents", "1");
	gcvar_presentsPerSpawnpoint = register_cvar("sv_presentsperspawnpoint", "0");
	gcvar_randomPresentAmount = register_cvar("sv_randompresentamount", "20");
	
	//Events
	register_logevent("event_roundStart", 2, "1=Round_Start");
	register_touch("presentsSpawnerPresent", "player", "event_presentTouch");
		
	//Get the path to the origin file
	new filepath[256];
	get_datadir(filepath, 255);
	
	new mapname[32];
	get_mapname(mapname, 31);
	
	format(g_orginFilePath, 255, "%s/presents/%s.ini", filepath, mapname);
	
	//Load the locations
	loadData();
	
#if defined USING_DATABASE
	SQL_SetAffinity("mysql");

	//Create login tuple
	g_loginData = SQL_MakeDbTuple(DATABASE_HOST, DATABASE_USERNAME, DATABASE_PASSWORD, DATABASE_DATABASE);
	
	//Connect for the simple query
	database_connect();
#endif
}

#if defined USING_DATABASE
public plugin_end()
{
	if(g_connection && g_connection != Empty_Handle)
		SQL_FreeHandle(g_connection);
}
#endif

public plugin_precache()
{
#if defined EASTER
	for(new a = 1; a <= EASTER_MAX_MODELS; ++a)
		formatPrecache_model("models/easteregg%d.mdl", a);
#endif

#if defined XMAS
	for(new a = 1; a <= XMAS_MAX_MODELS; ++a)
		formatPrecache_model("models/xmaspresent%d.mdl", a);
#endif

	return PLUGIN_CONTINUE;
}


//----------------------------------------------------------------------------
//								File reading
//----------------------------------------------------------------------------

loadData()
{
	g_totalOrigins = 0;
	
	//Note that we won't throw any errormessages when no presents are found
	new buffer[128];
	new strX[12], strY[12], strZ[12];
	if( file_exists(g_orginFilePath) )  
	{
		new readPointer = fopen(g_orginFilePath, "rt");
		
		if(!readPointer)
			return;
			
		while( !feof(readPointer) )
		{
			fgets(readPointer, buffer, 127);
			
			if(buffer[0] == ';' || !buffer[0])
				continue;
				
			parse(buffer, strX, 11, strY, 11, strZ, 11);
			
			g_spawnOrigins[g_totalOrigins][0] = str_to_num(strX);
			g_spawnOrigins[g_totalOrigins][1] = str_to_num(strY);
			g_spawnOrigins[g_totalOrigins][2] = str_to_num(strZ);
			
			++g_totalOrigins;
		}
		
		fclose(readPointer);
	}
}

//----------------------------------------------------------------------------
//								Commands
//----------------------------------------------------------------------------

public cmd_addSpawn(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
		
	//Check for too many spawns
	if(g_totalOrigins >= MAX_SPAWNLOCATIONS)
	{
		printChatAndConsole(id, "[presentsSpawner] %L", id, "MAXSPAWNS_REACHED", MAX_SPAWNLOCATIONS);
		return PLUGIN_CONTINUE;
	}
	
	//Get the current origin
	new Float:currentOrigin[3];
	entity_get_vector(id, EV_VEC_origin, currentOrigin);
	
	//Open the file for writing, write the origin and close up
	new writePointer = fopen(g_orginFilePath, "at");
	
	if(writePointer)
	{
		fprintf(writePointer, "%d %d %d^n", floatround(currentOrigin[0]), floatround(currentOrigin[1]), floatround(currentOrigin[2]) );
	
		fclose(writePointer);
		
		//Notify the user
		printChatAndConsole(id, "[presentsSpawner] %L", id, "ADD_SUCCESS");
	
		//Reload spawnpoints
		loadData();
	} else
		printChatAndConsole(id, "Failed to add!");
	
	return PLUGIN_CONTINUE;
}

public cmd_spawnPresent(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
		
	//Get the player's origin
	new Float:playerOrigin[3];
	entity_get_vector(id, EV_VEC_origin, playerOrigin);
	
	//Pack the origin
	new packedOrigin[3];
	FVecIVec(playerOrigin, packedOrigin);
	
	set_task(2.5, "spawnPresentIV", _, packedOrigin, 3);
	
	//Don't display a message to the user, gets irritating	
	return PLUGIN_HANDLED;
}

public cmd_removePresents(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_CONTINUE;
		
	removePresents();
	
	printChatAndConsole(id, "[presentsSpawner] %L", id, "REMOVED_ALL");
	
	return PLUGIN_CONTINUE;
}

#if defined USING_DATABASE
public cmd_say(id)
{
	if(id < 1)
		return PLUGIN_CONTINUE;
	
	static chatMessage[191];
	read_args(chatMessage, 190);
	remove_quotes(chatMessage);
	
	static address[256];
	
#if defined EASTER
	if(equali(chatMessage, "/easterrank"))
		database_showRank(id);
	else if(equali(chatMessage, "/eastertop10") || equali(chatMessage, "/eastertop") || equali(chatMessage, "/easterwinner"))
	{
		formatex(address, 255, "%s/presentStats.php", WEBSITE_ROOT);
		show_motd(id, address, "Easter Top 10");
	} else if(equali(chatMessage, "/easterinfo"))
	{
		formatex(address, 255, "%s/easterInfo.php", WEBSITE_ROOT);
		show_motd(id, address, "Easter Contest Info");
	} else if(equali(chatMessage, "/easternextrank"))
		database_showNextRank(id);
	
#endif

#if defined XMAS	
	if(equali(chatMessage, "/xmasrank"))
		database_showRank(id);
	else if(equali(chatMessage, "/xmastop10") || equali(chatMessage, "/xmastop") || equali(chatMessage, "/xmaswinner"))
	{
		formatex(address, 255, "%s/presentStats.php", WEBSITE_ROOT);
		show_motd(id, address, "Xmas Top 10");
	} else if(equali(chatMessage, "/xmasinfo"))
	{
		formatex(address, 255, "%s/xmasInfo.php", WEBSITE_ROOT);
		show_motd(id, address, "Xmas Contest Info");
	}
	else if(equali(chatMessage, "/xmasnextrank"))
		database_showNextRank(id);

#endif

	return PLUGIN_CONTINUE;
}
#endif

//----------------------------------------------------------------------------
//								Events
//----------------------------------------------------------------------------

public event_roundStart()
{
	//Check if there are spawnlocations to drop to
	if(g_totalOrigins < 0)
		return PLUGIN_CONTINUE;
		
	//Get the number of players minus HLTV or bots
	//Only spawn presents with 2 or more real players
	new currPlayers, temp[32];
	get_players(temp, currPlayers, "ch");
	
	if(currPlayers < 2)
		return PLUGIN_CONTINUE;
		
	//Remove all presents if requested
	if(get_pcvar_num(gcvar_removePresents) == 1)
		removePresents();
		
	//Get the amount of presents to drop per spawnpoint
	new presentsPerSpawnpoint = get_pcvar_num(gcvar_presentsPerSpawnpoint);
		
	//If we have presents to drop, drop them with the right amount per spawnpoint
	if(presentsPerSpawnpoint > 0 && g_totalOrigins > 0)
	{
		for(new a = 0; a < g_totalOrigins; ++a)
		{
			for(new b = 0; b < presentsPerSpawnpoint; ++b)
				spawnPresentIV(g_spawnOrigins[a]);
		}
	}
				
	//Random position present spawning
	spawnPresentsRandomLocation(get_pcvar_num(gcvar_randomPresentAmount));
		
	return PLUGIN_CONTINUE;
}

public event_presentTouch(pTouched, pToucher)
{
	//Error checking
	if(!is_valid_ent(pToucher) || !is_valid_ent(pTouched) || !is_user_connected(pToucher))
		return PLUGIN_HANDLED;
		
#if defined USING_CTRIKE
	
	//Money handling for CS
	new randomMoney = random_num(50, 500);
	
	cs_set_user_money(pToucher, (cs_get_user_money(pToucher) + randomMoney), 1);
	
	#if defined EASTER
		client_print(pToucher, print_chat, "[presentsSpawner] %L", pToucher, "EASTEREGG_TOUCH_CSTRIKE", randomMoney);
	#endif
		
	#if defined XMAS
		client_print(pToucher, print_chat, "[presentsSpawner] %L", pToucher, "XMASPRESENT_TOUCH_CSTRIKE", randomMoney);
	#endif
		
	#if defined USING_DATABASE	
		database_updateRecord(pToucher, randomMoney);
	#endif
	
#else

	#if defined EASTER
		client_print(pToucher, print_chat, "[presentsSpawner] %L", pToucher, "EASTEREGG_TOUCH");
	#endif
		
	#if defined XMAS
		client_print(pToucher, print_chat, "[presentsSpawner] %L", pToucher, "XMASPRESENT_TOUCH");
	#endif
	
#endif

	//Remove the egg
	remove_entity(pTouched);
	
	return PLUGIN_HANDLED;
}

//----------------------------------------------------------------------------
//								Main Functions
//----------------------------------------------------------------------------


//x and y are the actual coordinates in the game, not the rectangle coordinates
bool:findRandomLocation(Float:origin[3], maxTries, &tryCount = 0)
{
	//Limit the amount of checks we do to the specified limit
	if(tryCount++ >= maxTries)
		return false;
		
	static topToBottom, spotContent;
	topToBottom = random_num(0, 1);
	
	origin[0] = random_float(-MAP_MAX, MAP_MAX);
	origin[1] = random_float(-MAP_MAX, MAP_MAX);
	origin[2] = (topToBottom == 1 ? MAP_MAX : -MAP_MAX);
	
	//Go up or down trough the current coords to find an empty spot
	do
	{
		//Stop when we're too high or too low
		if(origin[2] > MAP_MAX || origin[2] < -MAP_MAX)
			return findRandomLocation(origin, maxTries, tryCount);
			
		//Change height and get the contents of that spot
		origin[2] += (topToBottom == 1 ? -10.0 : 10.0);
		spotContent = PointContents(origin);
		
	} while(spotContent != CONTENTS_EMPTY);
	
	//Maybe we should check if another present is in the neighbourhood.
	//Maybe not. I feel sleepy today.
	
	return true;
}

bool:spawnPresentsRandomLocation(presentAmount)
{
	static Float:origin[3];
	new infiniteCheck = 0, maxTries = (presentAmount * TRIES_PER_RANDOM_PRESENT);
		
	for(new a = 0; a < presentAmount; ++a)
	{
		//Get a valid random location
		//If it returns false, it couldn't find a spot within the alotted amount of tries
		if( findRandomLocation(origin, maxTries, infiniteCheck) )
			spawnPresent(origin);
		else
			return false;
	}
	
	return true;
}

///---

//IV -> Integer Vector
spawnPresentIV(IVOrigin[3])
{
	//Unpack the origin and feed it to the real function
	static Float:FVOrigin[3];
	IVecFVec(IVOrigin, FVOrigin);
	
	spawnPresent(FVOrigin);
}

spawnPresent(Float:origin[3])
{
	//Create entity and set origin and velocity
	new entity;
	entity = create_entity("info_target");
	
	entity_set_origin(entity, origin);
	
	new Float:velocity[3];
	velocity[0] = (random_float(0.0, 256.0) - 128.0);
	velocity[1] = (random_float(0.0, 256.0) - 128.0);
	velocity[2] = (random_float(0.0, 300.0) + 75.0);
		
	entity_set_vector(entity, EV_VEC_velocity, velocity );
	
	//Set a random model
	static modelName[64];
	
#if defined EASTER
	formatex(modelName, 63, "models/easteregg%d.mdl", random_num(1, EASTER_MAX_MODELS));
#endif

#if defined XMAS
	formatex(modelName, 63, "models/xmaspresent%d.mdl", random_num(1, XMAS_MAX_MODELS));
#endif

	entity_set_model(entity, modelName);
	
	//Color (75% chance)
	if(random_num(1, 4) > 2)
	{
		//Special effect (25% chance)
		if(random_num(1, 4) == 1)
			entity_set_int(entity, EV_INT_renderfx, kRenderFxHologram);
			
		entity_set_vector(entity, EV_VEC_rendercolor, colors[random(TOTAL_COLORS)] );
			
		entity_set_int(entity, EV_INT_renderfx, kRenderFxGlowShell);
		entity_set_float(entity, EV_FL_renderamt, 1000.0);
		entity_set_int(entity, EV_INT_rendermode, kRenderTransAlpha);
	}
	
	//The rest of the properties
	entity_set_string(entity, EV_SZ_classname, "presentsSpawnerPresent");
	entity_set_int(entity, EV_INT_effects, 32);
	entity_set_int(entity, EV_INT_solid, SOLID_TRIGGER);
	entity_set_int(entity, EV_INT_movetype, MOVETYPE_TOSS);
}

removePresents()
{
	new currentEntity;

	while ( (currentEntity = find_ent_by_class(currentEntity, "presentsSpawnerPresent")) != 0)
	{
		remove_entity(currentEntity);
	}
}

//----------------------------------------------------------------------------
//							Database Functions
//----------------------------------------------------------------------------
#if defined USING_DATABASE

stock database_connect()
{
	new errorCode, strError[128];
	
	//Make the actual connection
	g_connection = SQL_Connect(g_loginData, errorCode, strError, 127);
	
	//Check for errors
	if(g_connection == Empty_Handle)
	{
		//Log the error to file
		log_amx("Error while connecting to MySQL host %s with user %s", DATABASE_HOST, DATABASE_USERNAME);
		log_amx("Errorcode %d: %s", errorCode, strError);
	}
}

//%%% Command showRank %%%
stock database_showRank(id)
{
	static authid[32];
	get_user_authid(id, authid, 31);
	
	//Long query that will get the rank, presentAmount and moneyAmount from the player who issued the command
	formatex(g_queryHolder, 511, "SELECT (SELECT COUNT(*) + 1 FROM presentStats WHERE presentAmount > (SELECT presentAmount FROM presentStats WHERE authid = '%s')) AS rank, presentAmount, moneyAmount FROM presentStats WHERE authid = '%s';", authid, authid);
	
	//Send the playerid with the query
	new data[1];
	data[0] = id;
	
	SQL_ThreadQuery(g_loginData, "database_rankCallback", g_queryHolder, data, 1);
}

public database_rankCallback(failstate, Handle:query, error[], errnum, data[], size)
{
	//new queryerror[256];
	//SQL_QueryError (query, queryerror, 255);
	//server_print("Data is -> id: %d [*] queryerror: %s", data[0], queryerror);
	
	//Check if the user is still ingame
	if(!is_user_connected(data[0]))
		return PLUGIN_HANDLED;
		
	new rank, presents, money;
	
	if(failstate)
	{
		client_print(data[0], print_chat, "The presents statistics are currently offline.");		
	} else
	{
		//Check if the query did match a row
		if(SQL_NumResults(query) != 0)
		{
			//We only need to get 3 columns, next row is impossible and undesirable
			rank   = SQL_ReadResult(query, 0);
			presents  = SQL_ReadResult(query, 1);
			money = SQL_ReadResult(query, 2);
			
#if defined EASTER
			client_print(data[0], print_chat, "Your rank is #%d with %d presents containing %d dollars. Happy Easter!", rank, presents, money);
#endif

#if defined XMAS
			client_print(data[0], print_chat, "Your rank is #%d with %d presents containing %d dollars. Happy Xmas!", rank, presents, money);
#endif
		} else
		{
			client_print(data[0], print_chat, "Your rank hasn't been calculated yet or you didn't pickup any presents.");
		}
	}
	
	return PLUGIN_HANDLED;
}

//%%% Show Next Rank %%%
stock database_showNextRank(id)
{
	static authid[32];
	get_user_authid(id, authid, 31);
	
	//Very long query, it returns the presentAmount of the player specified, the presentAmount of the next ranking player and the rank of the specified player
	formatex(g_queryHolder, 511, "SELECT presentAmount AS currentAmount, ( SELECT MIN( presentAmount ) FROM presentStats WHERE presentAmount > currentAmount) AS nextAmount, (SELECT COUNT( * ) +1 FROM presentStats WHERE presentAmount > ( SELECT presentAmount FROM presentStats WHERE authid = '%s' ) ) AS rank FROM presentStats WHERE authid = '%s';", authid, authid);
	
	//Send the playerid with the query
	new data[1];
	data[0] = id;
	
	SQL_ThreadQuery(g_loginData, "database_nextRankCallbackOne", g_queryHolder, data, 1);
}

public database_nextRankCallbackOne(failstate, Handle:query, error[], errnum, data[], size)
{
	//new queryerror[256];
	//SQL_QueryError (query, queryerror, 255);
	//server_print("Data is -> id: %d [*] queryerror: %s", data[0], queryerror);
	
	//Check if the user is still ingame
	if(!is_user_connected(data[0]))
		return PLUGIN_HANDLED;
		
	if(failstate)
	{
		client_print(data[0], print_chat, "The presents statistics are currently offline.");
	} else
	{
		//Check if the query did match a row
		if(SQL_NumResults(query) != 0)
		{
			//We only need to get the 3 values from the current row
			new currentPresents = SQL_ReadResult(query, 0);
			new nextRankPresents = SQL_ReadResult(query, 1);
			new rank = SQL_ReadResult(query, 2);
			
			if(rank <= 0)
			{
				client_print(data[0], print_chat, "There was an error handling your request, please try again later.");
				return PLUGIN_HANDLED;
			}
						
			//You can't be better than #1
			if(rank == 1)
			{
				client_print(data[0], print_chat, "You are #1. There isn't anyone above you!");
				return PLUGIN_HANDLED;
			}
			
			//Output the final message to the client
			client_print(data[0], print_chat, "You need %d more presents to go to #%d.", ((nextRankPresents - currentPresents) + 1), (rank - 1) );
							
		} else
		{
			client_print(data[0], print_chat, "Your rank hasn't been calculated yet or you didn't pickup any presents.");
		}
	}
	
	return PLUGIN_HANDLED;
}

//%%% Update player record %%%
stock database_updateRecord(id, money)
{
	//Check for database connection
	if(g_connection == Empty_Handle)
		return;
	
	static authid[32], errorMessage[2], errorNum;
	
	get_user_authid(id, authid, 31);
	
	formatex(g_queryHolder, 511, "INSERT INTO presentStats VALUES('%s', 0, 1, %d) ON DUPLICATE KEY UPDATE presentAmount=presentAmount+1, moneyAmount=moneyAmount+%d;", authid, money, money);	
	
	//We discard the successfullness
	SQL_SimpleQuery(g_connection, g_queryHolder, errorMessage, 1, errorNum);
}

#endif
//----------------------------------------------------------------------------
//								Helpers
//----------------------------------------------------------------------------

stock printChatAndConsole(id, text[], ...)
{
	static buffer[128];
	
	vformat(buffer, 127, text, 3);
	
	client_print(id, print_chat, "%s", buffer);
	client_print(id, print_console, "%s", buffer);
}

stock formatPrecache_model(name[], ...)
{
	static buffer[256];
	
	vformat(buffer, 255, name, 2);
	
	precache_model(buffer);
}
