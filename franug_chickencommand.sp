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

#define PLUGIN_VERSION "1.0"

new Handle:hPush;
new Handle:hHeight;
new Handle:SpeedGallina;

new VelocityOffset_0;
new VelocityOffset_1;
new BaseVelocityOffset;

bool _gallina[MAXPLAYERS + 1];

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
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_jump", PlayerJump);
	
	RegAdminCmd("sm_gallina", Command_GiveGallina, ADMFLAG_BAN);
	RegAdminCmd("sm_nogallina", Command_GiveNoGallina, ADMFLAG_BAN);

	hPush = CreateConVar("sm_c4chicken_push","0.5", "push in jump for chicken");
	hHeight = CreateConVar("sm_c4chicken_height","1.0", "height in jump for chicken");
	SpeedGallina = CreateConVar("sm_c4chicken_speed", "0.9", "speed of chicken");


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
		
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
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

	_gallina[client] = false;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action:OnWeaponCanUse(client, weapon)
{
	if(_gallina[client])
		return Plugin_Handled;
	
	return Plugin_Continue;
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

quitarGallina(int client)
{
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	
	CS_UpdateClientModel(client);
	
	_gallina[client] = false;
}

hacerGallina(int client)
{
	// soltar bomba
	int bomb = GetPlayerWeaponSlot(client, CS_SLOT_C4);
	
	if(bomb != -1)
		CS_DropWeapon(client, bomb, false);
	
	int weaponIndex;
	for (int i = 0; i <= 5; i++)
	{
		if ((weaponIndex = GetPlayerWeaponSlot(client, i)) != -1)
		{  
			RemovePlayerItem(client, weaponIndex);
			AcceptEntityInput(weaponIndex, "Kill");
		}
	}

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(SpeedGallina));
	
	GivePlayerItem(client, "weapon_knife");
	
	new Float:pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	EmitAmbientSound("knifefight/chicken.wav", pos, client, SNDLEVEL_NORMAL );
	
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
			quitarGallina(iClient);
			ReplyToCommand(client, "Jugador %N ha sido quitado de ser gallina", iClient);
		} 
	}

	if(count == 0)
		ReplyToCommand(client, "No valid clients");
	
	return Plugin_Handled;
}