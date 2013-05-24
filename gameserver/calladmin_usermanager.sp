/**
 * -----------------------------------------------------
 * File        calladmin_usermanager.sp
 * Authors     David <popoklopsi> Ordnung, Impact
 * License     GPLv3
 * Web         http://popoklopsi.de, http://gugyclan.eu
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013 David <popoklopsi> Ordnung, Impact
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */
 

#include <sourcemod>
#include <autoexecconfig>
#include <basecomm>
#include "calladmin"

#undef REQUIRE_PLUGIN
#include <updater>

#pragma semicolon 1



// Cvar to blacklist muted players
new Handle:g_hBlacklistMuted;
new bool:g_bBlacklistMuted;

// Cvar to blacklist gagged players
new Handle:g_hBlacklistGagged;
new bool:g_bBlacklistGagged;

// Cvar to show information
new Handle:g_hShowInformation;
new bool:g_bShowInformation;



// Is immune or on blacklist?
new bool:g_bClientOnBlacklist[MAXPLAYERS + 1];
new bool:g_bClientImmune[MAXPLAYERS + 1];



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_usermanager.txt"



public Plugin:myinfo = 
{
	name = "CallAdmin UserManager",
	author = "Popoklopsi, Impact",
	description = "A UserManager for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://popoklopsi.de"
}






/*

Sourcemod

*/


// Register the library
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("calladmin_usermanager");
	
	
	// Api
	CreateNative("CallAdmin_SetClientOnBlacklist", Native_SetClientOnBlacklist);
	CreateNative("CallAdmin_SetClientImmune", Native_SetClientImmune);
	CreateNative("CallAdmin_IsClientOnBlacklist", Native_IsClientOnBlacklist);
	CreateNative("CallAdmin_IsClientImmune", Native_IsClientImmune);
	
	
	return APLRes_Success;
}


// Plugin Started
public OnPluginStart()
{
	// Create config and load it
	AutoExecConfig_SetFile("plugin.calladmin_usermanager");


	AutoExecConfig_CreateConVar("sm_calladmin_usermanager_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hBlacklistMuted = AutoExecConfig_CreateConVar("sm_calladmin_blacklist_muted", "1",  "Disallow muted players to report a player", FCVAR_PLUGIN);
	g_hBlacklistGagged = AutoExecConfig_CreateConVar("sm_calladmin_blacklist_gagged", "1",  "Disallow gagged players to report a player", FCVAR_PLUGIN);
	g_hShowInformation = AutoExecConfig_CreateConVar("sm_calladmin_show_information", "1",  "Show status to player on mute/gag", FCVAR_PLUGIN);


	AutoExecConfig(true, "plugin.calladmin_usermanager");
	AutoExecConfig_CleanFile();


	// Load translation
	LoadTranslations("calladmin_usermanager.phrases");


	// Read Config
	g_bBlacklistMuted = GetConVarBool(g_hBlacklistMuted);
	g_bBlacklistGagged = GetConVarBool(g_hBlacklistGagged);
	g_bShowInformation = GetConVarBool(g_hShowInformation);

	// Hook changes
	HookConVarChange(g_hBlacklistMuted, OnCvarChanged);
	HookConVarChange(g_hBlacklistGagged, OnCvarChanged);
	HookConVarChange(g_hShowInformation, OnCvarChanged);
}


// Convar Changed
public OnCvarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if (cvar == g_hBlacklistMuted)
	{
		g_bBlacklistMuted = GetConVarBool(g_hBlacklistMuted);
	}

	else if (cvar == g_hBlacklistGagged)
	{
		g_bBlacklistGagged = GetConVarBool(g_hBlacklistGagged);
	}
	else if (cvar == g_hShowInformation)
	{
		g_bShowInformation = GetConVarBool(g_hShowInformation);
	}
}


// Updater
public OnAllPluginsLoaded()
{
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATER_URL);
	}
}


// Updater
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATER_URL);
	}
}






/*

NATIVES

*/


// Set client on blacklist
public Native_SetClientOnBlacklist(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (IsClientValid(client))
	{
		g_bClientOnBlacklist[client] = GetNativeCell(2);
	}
}


// Set Client immune
public Native_SetClientImmune(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (IsClientValid(client))
	{
		g_bClientImmune[client] = GetNativeCell(2);
	}
}


// Checks if the client is on the blacklist
public Native_IsClientOnBlacklist(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (IsClientValid(client))
	{
		return g_bClientOnBlacklist[client];
	}

	return false;
}


// Checks if the client is immune
public Native_IsClientImmune(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (IsClientValid(client))
	{
		return g_bClientImmune[client];
	}

	return false;
}





/*

CallAdmin

*/


// Client will drawn to menu
public Action:CallAdmin_OnDrawTarget(client, target)
{
	// Target is immune, so don't draw it
	if (IsClientValid(target) && g_bClientImmune[target])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}


// Client will report
public Action:CallAdmin_OnReportPre(client, target, const String:reason[])
{
	// Target is immune, so don't report
	if (IsClientValid(target) && g_bClientImmune[target])
	{
		// Info text
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_TargetImmune", target);

		return Plugin_Handled;
	}

	// Client is on blacklist so don't allow report
	if (IsClientValid(client) && g_bClientOnBlacklist[client])
	{
		// Info text
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_ClientOnBlacklist");

		return Plugin_Handled;
	}

	return Plugin_Continue;
}





/*

Basecomm

*/


// Client get muted
public BaseComm_OnClientMute(client, bool:muteState)
{
	if (g_bBlacklistMuted && IsClientValid(client))
	{
		// Set client on blacklist
		g_bClientOnBlacklist[client] = muteState;

		// Show information
		if (g_bShowInformation)
		{
			if (muteState)
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_ClientBlacklistMute");
			}
			else
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_ClientBlacklistRemove");
			}
		}
	}
}


// Client get gagged
public BaseComm_OnClientGag(client, bool:muteState)
{
	if (g_bBlacklistGagged && IsClientValid(client))
	{
		// Set client on blacklist
		g_bClientOnBlacklist[client] = muteState;

		// Show information
		if (g_bShowInformation)
		{
			if (muteState)
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_ClientBlacklistGag");
			}
			else
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_ClientBlacklistRemove");
			}
		}
	}
}




/*

STOCKS

*/


// Is Client valid
stock bool:IsClientValid(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	
	return false;
}