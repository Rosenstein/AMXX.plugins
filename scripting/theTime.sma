/* AMX Mod X
*   theTime Plugin
*
* by the AMX Mod X Development Team
*  originally developed by OLO
*
* This file is part of AMX Mod X.
*
*
*  This program is free software; you can redistribute it and/or modify it
*  under the terms of the GNU General Public License as published by the
*  Free Software Foundation; either version 2 of the License, or (at
*  your option) any later version.
*
*  This program is distributed in the hope that it will be useful, but
*  WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
*  General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program; if not, write to the Free Software Foundation,
*  Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*
*  In addition, as a special exception, the author gives permission to
*  link the code of this program with the Half-Life Game Engine ("HL
*  Engine") and Modified Game Libraries ("MODs") developed by Valve,
*  L.L.C ("Valve"). You must obey the GNU General Public License in all
*  respects for all of the code used other than the HL Engine and MODs
*  from Valve. If you modify this file, you may extend this exception
*  to your version of the file, but you are not obligated to do so. If
*  you do not wish to do so, delete this exception statement from your
*  version.
*/

#include <amxmodx>

public plugin_init()
{
	register_plugin("theTime", "1.8.2", "AMXX Dev Team/Meister")
	register_dictionary("timeleft.txt")
	register_cvar("amx_time_voice", "1")
	register_clcmd("say thetime", "sayTheTime", 0, "- displays current time")
	register_clcmd("say /thetime", "sayTheTime", 0, "- displays current time")

}

public sayTheTime(id)
{
	if (get_cvar_num("amx_time_voice"))
	{
		new mhours[6], mmins[6], whours[32], wmins[32], wpm[6]
		
		get_time("%H", mhours, 5)
		get_time("%M", mmins, 5)
		
		new mins = str_to_num(mmins)
		new hrs = str_to_num(mhours)
		
		if (mins)
			num_to_word(mins, wmins, 31)
		else
			wmins[0] = 0
		
		if (hrs < 12)
			wpm = "am "
		else
		{
			if (hrs > 12) hrs -= 12
			wpm = "pm "
		}

		if (hrs) 
			num_to_word(hrs, whours, 31)
		else
			whours = "twelve "
		
		client_cmd(id, "spk ^"fvox/time_is_now %s_period %s%s^"", whours, wmins, wpm)
	}
	
	new ctime[64]
	
	get_time("%d/%m/%Y - %H:%M:%S", ctime, 63)
	client_print(0, print_chat, "%L:   %s", LANG_PLAYER, "THE_TIME", ctime)
	
	return PLUGIN_CONTINUE
}
