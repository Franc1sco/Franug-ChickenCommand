/*  SM Chicken Command
 *
 *  Copyright (C) 2020 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <sdkhooks>
#include <cstrike>

#define PLUGIN_VERSION "1.1"

new Handle:hPush;
new Handle:hHeight;
new Handle:SpeedGallina;

new VelocityOffset_0;
new VelocityOffset_1;
new BaseVelocityOffset;

bool _gallina[MAXPLAYERS + 1];

ConVar cv_rr;

public Plugin:myinfo =
{
	name = "SM Chicken Command",
	author = "Franc1sco Steam: franug",
	description = "Be a chicken",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	HookEvent("player_spawn", Event_Player_Spawn, EventHookMode_Pre);
	HookEvent("player_jump", PlayerJump);
	
	HookEvent("player_death",PlayerDeath, EventHookMode_Pre);
	
	HookEvent("round_end", RoundEnd);
	
	RegAdminCmd("sm_gallina", Command_GiveGallina, ADMFLAG_BAN);
	RegAdminCmd("sm_nogallina", Command_GiveNoGallina, ADMFLAG_BAN);

	hPush = CreateConVar("sm_c4chicken_push","0.5", "push in jump for chicken");
	hHeight = CreateConVar("sm_c4chicken_height","1.0", "height in jump for chicken");
	SpeedGallina = CreateConVar("sm_c4chicken_speed", "1.0", "speed of chicken");

	cv_rr = FindConVar("mp_restartgame");
	
	HookConVarChange(cv_rr, OnCvarChange);

	// FIND OFFSET
	VelocityOffset_0=FindSendPropInfo("CBasePlayer","m_vecVelocity[0]");
	if (VelocityOffset_0==-1)
		SetFailState("[BunnyHop] Error: Failed to find Velocity[0] offset, aborting");
	VelocityOffset_1=FindSendPropInfo("CBasePlayer","m_vecVelocity[1]");
	if (VelocityOffset_1==-1)
		SetFailState("[BunnyHop] Error: Failed to find Velocity[1] offset, aborting");
	BaseVelocityOffset=FindSendPropInfo("CBasePlayer","m_vecBaseVelocity");
	if (BaseVelocityOffset==-1)
		SetFailState("[BunnyHop] Error: Failed to find the BaseVelocity offset, aborting");
		
}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!_gallina[client])return;
	
	quitarGallina(client, false);
	
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll<0)
	{
		return;
	}
	
	AcceptEntityInput(ragdoll, "Kill");
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if(StringToInt(newValue) == 0)
		return;
		
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && _gallina[i])
		{
			quitarGallina(i, IsPlayerAlive(i));
		}
	}
}

public void OnMapStart()
{
	AddFileToDownloadsTable("materials/models/lduke/chicken/chicken2.vmt");
	AddFileToDownloadsTable("materials/models/lduke/chicken/chicken2.vtf");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.dx80.vtx");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.dx90.vtx");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.mdl");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.phy");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.sw.vtx");
	AddFileToDownloadsTable("models/lduke/chicken/chicken2.vvd");
	PrecacheModel("models/lduke/chicken/chicken2.mdl");

	AddFileToDownloadsTable("sound/lduke/chicken/chicken.wav");
	PrecacheSound("lduke/chicken/chicken.wav");

	AddFileToDownloadsTable("sound/knifefight/chicken.wav");
	PrecacheSound("knifefight/chicken.wav");
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(_gallina[client])
	{
		quitarGallina(client, IsPlayerAlive(client));
	}
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && _gallina[i])
		{
			quitarGallina(i, IsPlayerAlive(i));
		}
	}
}

public Action:OnWeaponCanUse(client, weapon)
{
	if(weapon > 0 && IsValidEntity(weapon))
	{
		char sWeapon[32]; 
		if(!GetEdictClassname(weapon, sWeapon, sizeof(sWeapon)))
			return Plugin_Continue;
			
		if(StrEqual(sWeapon, "weapon_knife") || StrEqual(sWeapon, "weapon_c4"))
			return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) 
{
	damage *= 5.0;
	
	return Plugin_Changed;
}

public PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (_gallina[client]) SaltoGallina(client);
}

SaltoGallina(client)
{
	new Float:finalvec[3];
	finalvec[0]=GetEntDataFloat(client,VelocityOffset_0)*GetConVarFloat(hPush)/2.0;
	finalvec[1]=GetEntDataFloat(client,VelocityOffset_1)*GetConVarFloat(hPush)/2.0;
	finalvec[2]=GetConVarFloat(hHeight)*50.0;
	SetEntDataVector(client,BaseVelocityOffset,finalvec,true);
	
	new Float:pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	EmitAmbientSound("lduke/chicken/chicken.wav", pos, client, SNDLEVEL_NORMAL );
}

quitarGallina(int client, bool alive)
{
	if(alive)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255, 255, 255, 255);
		
		CS_UpdateClientModel(client);
	}
	
	SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	_gallina[client] = false;
}

hacerGallina(int client)
{
	// soltar bomba
	/*
	int bomb = GetPlayerWeaponSlot(client, CS_SLOT_C4);
	
	if(bomb != -1)
		CS_DropWeapon(client, bomb, false);
	*/
	
	FakeClientCommand(client, "use weapon_knife");
	
	int weaponIndex;
	for (int i = 0; i <= 5; i++)
	{
		if (i == CS_SLOT_C4 || i == CS_SLOT_KNIFE)continue;
		
		while ((weaponIndex = GetPlayerWeaponSlot(client, i)) != -1)
		{  
			RemovePlayerItem(client, weaponIndex);
			AcceptEntityInput(weaponIndex, "Kill");
		}
	}

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(SpeedGallina));
	
	//GivePlayerItem(client, "weapon_knife");
	
	SetEntityModel(client, "models/lduke/chicken/chicken2.mdl");
	
	new Float:pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	EmitAmbientSound("knifefight/chicken.wav", pos, client, SNDLEVEL_NORMAL );
	
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	if(GetClientTeam(client) == CS_TEAM_CT)
		SetEntityRenderColor(client, 0, 0, 255, 255);
	else
		SetEntityRenderColor(client, 255, 0, 0, 255);
	
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	_gallina[client] = true;
}

public Action Command_GiveGallina(int client, int args)
{
	if(args != 1)
	{
		ReplyToCommand(client, "Use: sm_gallina <name>");
		return Plugin_Handled;
	}
	char strTarget[32]; 
	GetCmdArg(1, strTarget, sizeof(strTarget)); 

	// Progress the targets 
	char strTargetName[MAX_TARGET_LENGTH]; 
	int TargetList[MAXPLAYERS];
	int TargetCount; 
	bool TargetTranslate; 

	if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
					strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{ 
		ReplyToCommand(client, "client not found");
		return Plugin_Handled; 
	} 

	// Apply to all targets 
	int count;
	for (int i = 0; i < TargetCount; i++) 
	{ 
		int iClient = TargetList[i]; 
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && !_gallina[iClient]) 
		{
			count++;
			hacerGallina(iClient);
			ReplyToCommand(client, "Jugador %N ha sido convertido en gallina", iClient);
		} 
	}

	if(count == 0)
		ReplyToCommand(client, "No valid clients");
	
	return Plugin_Handled;
}

public Action Command_GiveNoGallina(int client, int args)
{
	if(args != 1)
	{
		ReplyToCommand(client, "Use: sm_nogallina <name>");
		return Plugin_Handled;
	}
	char strTarget[32]; 
	GetCmdArg(1, strTarget, sizeof(strTarget)); 

	// Progress the targets 
	char strTargetName[MAX_TARGET_LENGTH]; 
	int TargetList[MAXPLAYERS];
	int TargetCount; 
	bool TargetTranslate; 

	if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
					strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{ 
		ReplyToCommand(client, "client not found");
		return Plugin_Handled; 
	} 

	// Apply to all targets 
	int count;
	for (int i = 0; i < TargetCount; i++) 
	{ 
		int iClient = TargetList[i]; 
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && _gallina[iClient]) 
		{
			count++;
			quitarGallina(iClient, true);
			ReplyToCommand(client, "Jugador %N ha sido quitado de ser gallina", iClient);
		} 
	}

	if(count == 0)
		ReplyToCommand(client, "No valid clients");
	
	return Plugin_Handled;
}