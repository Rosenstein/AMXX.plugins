#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#pragma semicolon 1

#define MAX_ADMINS 32

new cvar_mode;
new cvar_defaultAccess;
new cvar_table;

new g_adminAuthids[MAX_ADMINS][32];
new g_adminAccess[MAX_ADMINS];
new g_adminAmount;

new g_kickCommand[5];

//**
//   Init
//        **
public plugin_init()
{
	register_plugin("customAdmin", "0.1", "MaximusBrood");
	
	format(g_kickCommand, 4, "%c%c%c%c", random_num('A', 'Z'), random_num('A', 'Z'), random_num('A', 'Z'), random_num('A', 'Z'));
	register_clcmd(g_kickCommand, "cmd_kickMe");
	
	register_srvcmd("amx_loadadmins", "cmd_loadAdmins");
	
	//Cvars
	cvar_mode = register_cvar("amx_mode", "1");
	cvar_defaultAccess = register_cvar("amx_default_access", "z");
	
	register_cvar("amx_show_activity", "2");
	register_cvar("amx_vote_ratio", "0.02");
	register_cvar("amx_vote_time", "10");
	register_cvar("amx_vote_answers", "1");
	register_cvar("amx_vote_delay", "60");
	register_cvar("amx_last_voting", "0");
	register_cvar("amx_votekick_ratio", "0.40");
	register_cvar("amx_voteban_ratio", "0.40");
	register_cvar("amx_votemap_ratio", "0.40");
		
	register_cvar("amx_sql_host", "127.0.0.1");
	register_cvar("amx_sql_user", "gotjuice");
	register_cvar("amx_sql_pass", "");
	register_cvar("amx_sql_db", "gotjuice");
	register_cvar("amx_sql_type", "mysql");
	cvar_table = register_cvar("amx_sql_table", "admins");
	
	//Execute config files
	new configsdir[64];
	get_configsdir(configsdir, 63);
	
	server_cmd("exec %s/amxx.cfg", configsdir);
	server_cmd("exec %s/sql.cfg", configsdir);
	server_exec();
	
	//Load the admins once the server's ready loading
	server_cmd("amx_loadadmins");
}

public plugin_cfg()
{
	new configFile[64], curMap[32];

	get_configsdir(configFile, 31);
	get_mapname(curMap, 31);

	new len = format(configFile, 63, "%s/maps/%s.cfg", configFile, curMap);

	if (file_exists(configFile))
		set_task(6.1, "delayed_load", 0, configFile, len + 1);
}

public delayed_load(configFile[])
{
	server_cmd("exec %s", configFile);
}


//**
//   Main
//        **
public cmd_kickMe(id)
	server_cmd("kick #%d ^"This server is currently on admin-only mode^"", get_user_userid(id));

public cmd_loadAdmins()
{
	static errorNumber, errorMessage[256], adminsTable[32], databaseType[11];
	
	new Handle:connectionInfo = SQL_MakeStdTuple();
	new Handle:connection = SQL_Connect(connectionInfo, errorNumber, errorMessage, 255);
	
	//Fatally handle a database error
	if(connection == Empty_Handle)
	{
		format(errorMessage, 255, "Could not connect to database: %s (%d)", errorMessage, errorNumber);
		set_fail_state(errorMessage);
	}
	
	get_pcvar_string(cvar_table, adminsTable, 31);
	SQL_GetAffinity(databaseType, 10);
	
	//Create a new table if it doesn't exist, also prepare the next query
	new Handle:query;
	
	if(equali(databaseType, "sqlite"))
	{
		if(!sqlite_TableExists(connection, adminsTable))
			SQL_QueryAndIgnore(connection, "CREATE TABLE %s ( authid TEXT NOT NULL DEFAULT '', name TEXT NOT NULL DEFAULT '', access TEXT NOT NULL DEFAULT '' )", adminsTable);
			
		query = SQL_PrepareQuery(connection, "SELECT authid, access FROM %s;", adminsTable);
	} else
	{
		SQL_QueryAndIgnore(connection, "CREATE TABLE IF NOT EXISTS `%s` (`authid` varchar(32) NOT NULL default '', `name` varchar(32) NOT NULL default '', `access` varchar(32) NOT NULL default '')", adminsTable);
		
		query = SQL_PrepareQuery(connection, "SELECT `authid`, `access` FROM `%s`;", adminsTable);
	}
	
	//Execute the query, again, handle errors fatally
	if(!SQL_Execute(query))
	{
		SQL_QueryError(query, errorMessage, 255);
		format(errorMessage, 255, "Error while querying database: %s", errorMessage);
		
		set_fail_state(errorMessage);
	}
	
	if(SQL_NumResults(query) == 0)
	{
		server_print("No admins were found in the database.");
		return;
	}
	
	//And onto the loading...
	static accessString[32];
	g_adminAmount = 0;
	
	for(; g_adminAmount < MAX_ADMINS && SQL_MoreResults(query); ++g_adminAmount)
	{
		SQL_ReadResult(query, 1, accessString, 31);
		
		SQL_ReadResult(query, 0, g_adminAuthids[g_adminAmount], 31);
		g_adminAccess[g_adminAmount] = read_flags(accessString);
		
		SQL_NextRow(query);
	}
	
	server_print("Loaded %d %s.", g_adminAmount, (g_adminAmount == 1 ? "admin" : "admins"));
	
	SQL_FreeHandle(query);
	SQL_FreeHandle(connection);
	SQL_FreeHandle(connectionInfo);
}

public client_authorized(id)
{
	//Do nothing if amx_mode is on 0
	new modeValue = get_pcvar_num(cvar_mode);
	if(modeValue == 0)
		return PLUGIN_CONTINUE;
		
	remove_user_flags(id);
	
	//Loop to find his authid, assign access accordingly
	new bool:wasFound = false;
	
	static authid[32];
	get_user_authid(id, authid, 31);
	
	for(new a = 0; a < g_adminAmount; ++a)
	{
		if(equal(g_adminAuthids[a], authid))
		{
			set_user_flags(id, g_adminAccess[a]);
			
			//Log the entering admin
			static name[32], accessString[32];
			get_user_name(id, name, 31);
			get_flags(g_adminAccess[a], accessString, 31);
			
			log_amx("Login: ^"%s<%d><%s><>^" became an admin (access ^"%s^")", name, get_user_userid(id), authid, accessString);
			
			//And break since we already found the admin			
			wasFound = true;
			break;
		}
	}
	
	if(!wasFound)
	{
		if(modeValue == 3)
		{
			//Kick the user
			client_cmd(id, "%s", g_kickCommand);
			
			return PLUGIN_HANDLED;
		}
		
		static defaultAccess[32];
		get_pcvar_string(cvar_defaultAccess, defaultAccess, 31);
		
		if(strlen(defaultAccess) == 0)
			copy(defaultAccess, 31, "z");
			
		new integerDefaultAccess = read_flags(defaultAccess);
		set_user_flags(id, integerDefaultAccess);
	}
	
	return PLUGIN_CONTINUE;	
}
