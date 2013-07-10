//--------------------------
// G L O B A L   S T U F F
//--------------------------
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <morecolors>

new g_DEERStarted = 0

#define STARTCFG  	"sourcemod/DEER_START.cfg"
#define SERVERCFG		"server.cfg"

#define terrorist 			2
#define counterTerrorist 	3

new Handle:AllowDeer = INVALID_HANDLE;

// Regenerate HP CVAR's
new Handle:HealthInterval = INVALID_HANDLE;
new Handle:RegenMaxHP = INVALID_HANDLE;
new Handle:HealthPerInterval = INVALID_HANDLE;

new Handle:g_hRegenTimer[MAXPLAYERS + 1];
new g_WeaponParent;

// CT Infinite Ammo
new Handle:InfiniteAmmo = INVALID_HANDLE;

//---------------------------------------
// P L U G I N   I N F O R M A T I O N 
//---------------------------------------
public Plugin:myinfo = 
{
    name = "DEER Plugin",
    author = "Mr. Freeman",
    description = "DEER Plugin - Custom made for Unhinged Clan (Counter-Strike: Source)",
    version = "1.0",
    url = ":)"
}

public OnPluginStart()
{
	g_WeaponParent = FindSendPropOffs("CBaseCombatWeapon", "m_hOwnerEntity");
	
	//-----------------------
	// Creating Our CVAR's
	//-----------------------
	AllowDeer = CreateConVar( "sm_deer_allow", "1", "Enables the DEER Plugin.", FCVAR_PLUGIN );
	HealthInterval = CreateConVar( "sm_deer_healthinterval", "1.0", "Number of Seconds for Terrorist Health Regeneration. (Default: 1.0)", FCVAR_PLUGIN );
	RegenMaxHP = CreateConVar( "sm_deer_regenmaxhp", "10000", "Max amount of health regenerated (Default: 10000.00)", FCVAR_PLUGIN );
	HealthPerInterval = CreateConVar( "sm_deer_healthperinterval", "5.0", "Amount of HP regenerated  per interval seconds (Default: 5.0)", FCVAR_PLUGIN );
	InfiniteAmmo = CreateConVar( "sm_deer_infiniteammo", "1.0", "Enable/Disable CT Infinite Ammo (1 = Enable | 0 = Disable)", FCVAR_PLUGIN );
	CreateConVar( "sm_deer_ratio", "10", "The ratio of Counter-Terrorists to Terrorists. (Default: 10 CT = 1 T)", FCVAR_PLUGIN );
	CreateConVar( "sm_deer_version", "1.0", "There is no need to change this value.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY );
	
	//-----------------------------------------
	// Generate config file
	//-----------------------------------------
	
	AutoExecConfig( true, "DEER" );
	
	//-----------------
	// Admin Commands 
	//-----------------
	
	RegAdminCmd( "sm_deer", CmdStart, ADMFLAG_KICK );
	RegAdminCmd( "sm_cancel", CmdCancel, ADMFLAG_KICK );
	
	RegConsoleCmd( "jointeam", DEERTeams );
	
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_hurt", HealthHookPlayerHurt);
	HookEvent("player_spawn", StartWeapons_Spawn);
	HookEvent("player_death", AnyoneDies);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}
/*
|===================================================================================|
|																					|
|					A D M I N   R E L A T E D   A C T I O N S						|
|																					|
|===================================================================================|
*/
//----------------------------------------------
// D E E R   C O M M A N D   A C T I V A T E D
//----------------------------------------------
public Action:CmdStart(client, args)
{
	new DEER_Enable = GetConVarInt(AllowDeer)
	if(DEER_Enable == 1)
	{
		ServerCommand("exec sourcemod/DEER_START.cfg");
		ServerCommand("mp_restartgame 1");
		CPrintToChatAll(" {green}ATTENTION:{default} {white}The round will now restart.");
		CreateTimer(5.0, DEERRounds);
		g_DEERStarted = 1
	}
}

//--------------------------------------------------
// C A N C E L   C O M M A N D   A C T I V A T E D
//--------------------------------------------------
public Action:CmdCancel(client, args)
{
	if(g_DEERStarted == 1)
	{
		ServerCommand("exec server.cfg");
		ServerCommand("mp_restartgame 1");
		CPrintToChatAll(" {green}ATTENTION:{default} {white}DEER has now been cancelled.");
		g_DEERStarted = 0
	}
	else if(g_DEERStarted == 0)
	{
		CPrintToChat(client, "Type {green}!deer{default} to activate the DEER plugin.")
	}
}

/*
|===============================================================================|
|																				|
|			G L O B A L   P L A Y E R   R E L A T E D   A C T I O N S			|
|																				|
|===============================================================================|
*/

//---------------------------
// P L A Y E R   S P A W N 
//---------------------------
public StartWeapons_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_DEERStarted == 1)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if ( GetClientTeam( client ) == terrorist )
		{
			StripAllTWeapons(client);
			TSetHealth(client);
			SetEntityRenderColor(client, 0, 0, 0, 255);
			CPrintToChat(client, "{darkred}RUN AND HIDE! There hunting you!");
		}
		else if ( GetClientTeam( client ) == counterTerrorist )
		{
			GiveCTWeapons(client);
			PerformBlind(client, 0);
			CreateTimer(30.0, UnBlindCT);
			CPrintToChat(client, "{darkred}Work together to cleanse the map of the illusive DEER");
		}
	}
}

/*
|=======================================================================================|
|																						|
|			C O U N T E R - T E R R O R I S T   R E L A T E D   A C T I O N S			|
|																						|
|=======================================================================================|
*/
//----------------------------
// I N F I N I T E   A M M O 
//----------------------------
public Event_WeaponFire(Handle:event, const String:name[],bool:dontBroadcast)
{
	new CTAmmo = GetConVarInt(InfiniteAmmo)
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_DEERStarted == 1 && CTAmmo == 1 && IsPlayerAlive(client) && (GetClientTeam(client) == counterTerrorist))
	{
		decl String:sWeapon[30];
		GetEventString(event,"weapon",sWeapon,30);
		new userid = GetClientOfUserId(GetEventInt(event, "userid"));
		new Slot1 = GetPlayerWeaponSlot(userid, CS_SLOT_PRIMARY);
		new Slot2 = GetPlayerWeaponSlot(userid, CS_SLOT_SECONDARY);
		
		if(IsValidEntity(Slot1))
		{
			if(GetEntProp(Slot1, Prop_Data, "m_iState") == 2)
			{
				SetEntProp(Slot1, Prop_Data, "m_iClip1", GetEntProp(Slot1, Prop_Data, "m_iClip1")+1);
				return;
			}
		}
		if(IsValidEntity(Slot2))
		{
			if(GetEntProp(Slot2, Prop_Data, "m_iState") == 2)
			{
				SetEntProp(Slot2, Prop_Data, "m_iClip1", GetEntProp(Slot2, Prop_Data, "m_iClip1")+1);
				return;
			}
		}
	}
}

//---------------------------
// G I V E   W E A P O N S  
//---------------------------
stock GiveCTWeapons(client)
{
	new wepIdx;
	for (new i; i < 4; i++)
	{
		if ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			AcceptEntityInput(wepIdx, "Kill");
			GivePlayerItem(client, "weapon_knife");
			GivePlayerItem(client, "item_nvgs"); 
		}
	}
}

//----------------------
// U N B L I N D   C T 
//----------------------
public Action:UnBlindCT(Handle:timer, any:client)
{
	PerformBlind(client, 255);
}

/*
|=======================================================================================|
|																						|
|					T E R R O R I S T   R E L A T E D   A C T I O N S					|
|																						|
|=======================================================================================|
*/
//---------------------------
// S T R I P   W E A P O N S  
//---------------------------
stock StripAllTWeapons(client)
{
	new wepIdx;
	for (new i; i < 4; i++)
	{
		if ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			AcceptEntityInput(wepIdx, "Kill");
			GivePlayerItem(client, "weapon_knife");
			GivePlayerItem(client, "item_nvgs"); 
		}
	}
}

//--------------------------
// H E A L T H   B O O S T 
//--------------------------
stock TSetHealth(client)
{
	if (g_DEERStarted == 1 || IsClientInGame(client) && IsPlayerAlive(client))
	{
		if (GetClientTeam( client ) == terrorist)
		{
			new Terrorist_Health = GetRandomInt(10000,25000);
			SetEntityHealth(client, Terrorist_Health);
			CPrintToChat(client, "{white}You are the DEER! Your health is {green}%d", Terrorist_Health)
		}
	}
	return Plugin_Handled;
}

//--------------------------------
// H P   R E G E N E R A T I O N 
//--------------------------------

public HealthHookPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_DEERStarted == 1)
	{
		new iUserId = GetEventInt(event, "userid");
		new client = GetClientOfUserId(iUserId);

		if(g_hRegenTimer[client] == INVALID_HANDLE)
		{
			g_hRegenTimer[client] = CreateTimer(GetConVarFloat(HealthInterval), Regenerate, client, TIMER_REPEAT);
		}
	}
}

public Action:Regenerate(Handle:timer, any:client)
{
	if (g_DEERStarted == 1)
	{
		new ClientHealth = GetClientHealth(client);

		if(ClientHealth < GetConVarInt(RegenMaxHP) && GetClientTeam(client) == terrorist)
		{
			SetClientHealth(client, ClientHealth + GetConVarInt(HealthPerInterval));
		}
		else
		{
			SetClientHealth(client, GetConVarInt(RegenMaxHP));
			g_hRegenTimer[client] = INVALID_HANDLE;
			KillTimer(timer);
		}
	}
}

SetClientHealth(client, amount)
{
	new HealthOffs = FindDataMapOffs(client, "m_iHealth");
	SetEntData(client, HealthOffs, amount, true);
}

//-------------------------------------------------
// U N F R E E Z E   F O R   3 0   S E C O N D S
//-------------------------------------------------
public Action:UnFreezeDEER (Handle:timer, any:client)
{
	SetEntityMoveType(client, MOVETYPE_WALK);
}

/*
|=======================================================================================|
|																						|
|				H A N D L E   R O U N D   R E L A T E D   A C T I O N S					|
|																						|
|=======================================================================================|
*/

public Action:DEERRounds(Handle:timer, any:client)
{
	if(g_DEERStarted == 1)
	{
		CreateTimer(30.0, UnFreezeDEER);
	}
}

//------------------------
// R O U N D   S T A R T
//------------------------
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_DEERStarted == 1)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if ( GetClientTeam( client ) == terrorist )
		{
			SetEntityMoveType(client, MOVETYPE_NONE);
			CreateTimer(30.0, UnFreezeDEER);
		}
	}
}

/*
|=======================================================================================|
|																						|
|					T E A M   R A T I O   R E L A T E D   A C T I O N S					|
|																						|
|=======================================================================================|
*/	
//------------------------
// C T / T   R A T I O 
//------------------------

public Action:DEERTeams( client, args )
{
	if (GetConVarInt(AllowDeer) == 1 && (g_DEERStarted == 1))
	{	
		//-----------------------------------------
		// Get the CVar T:CT ratio
		//-----------------------------------------

		new teamRatio = GetConVarInt( FindConVar( "sm_deer_ratio" ) );
	
		//-----------------------------------------
		// System online?
		//-----------------------------------------

		if ( ! GetConVarBool( FindConVar( "sm_deer_allow" ) ) )
		{
			return Plugin_Continue;
		}
	
		//-----------------------------------------
		// Is it a human?
		//-----------------------------------------
	
		if ( ! client || ! IsClientInGame( client ) || IsFakeClient( client ) )
		{
			return Plugin_Continue;
		}
	
		//-----------------------------------------
		// Bypass for SM admins
		//-----------------------------------------
	
		/*if ( GetUserAdmin( client ) != INVALID_ADMIN_ID )
		{
			return Plugin_Continue;
		}*/
	
		//-----------------------------------------
		// Get new and old teams
		//-----------------------------------------
	
		decl String:teamString[3];
		GetCmdArg( 1, teamString, sizeof( teamString ) );
	
		new newTeam = StringToInt(teamString);
		new oldTeam = GetClientTeam(client);
	
		//-----------------------------------------
		// Are we trying to switch to CT?
		//-----------------------------------------
	
		if ( newTeam == counterTerrorist && oldTeam != counterTerrorist )
		{
			new idx			= 0;
			new countTs 	= 0;
			new countCTs 	= 0;
		
		//-----------------------------------------
		// Count up our players!
		//-----------------------------------------
		
			for ( idx = 1; idx <= MaxClients; idx++ )
			{
		      if ( IsClientInGame( idx ) )
		      {
				 if ( GetClientTeam( idx ) == terrorist )
		         {
		            countTs++;
		         }
				 
				 if ( GetClientTeam( idx ) == counterTerrorist )
		         {
		            countCTs++;
		         }
		      }      
		}
		
		//-----------------------------------------
		// Are we trying to unbalance the ratio?
		//-----------------------------------------

		if ( countTs < ( ( countCTs ) / teamRatio ) || ! countTs )
		{
			return Plugin_Continue;
		}
		else
		{
			//-----------------------------------------
			// Send client sound
			//-----------------------------------------
			
			ClientCommand( client, "play ui/freeze_cam.wav" );
			
			//-----------------------------------------
			// Show client message
			//-----------------------------------------
			
			CPrintToChat( client, "Transfer denied, there are enough DEER's!", teamRatio );

			//-----------------------------------------
			// Kill the team change request
			//-----------------------------------------

			return Plugin_Handled;
		}		
	}
	}
	return Plugin_Continue;
}

public Action:AnyoneDies(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_DEERStarted == 1)
	{
		CleanUp()
	}
}

CleanUp()
{  // By Kigen (c) 2008
	new maxent = GetMaxEntities(), String:name[64];
	for (new i=GetMaxClients();i<maxent;i++)
	{
		if ( IsValidEdict(i) && IsValidEntity(i) )
		{
			GetEdictClassname(i, name, sizeof(name));
			if ( ( StrContains(name, "weapon_") != -1 || StrContains(name, "item_") != -1 ) && GetEntDataEnt2(i, g_WeaponParent) == -1 )
					RemoveEdict(i);
		}
	}
}

PerformBlind(client, amount)
{	
	new Handle:message = StartMessageOne("Fade", client);
	BfWriteShort(message, 1536);
	BfWriteShort(message, 1536);
	
	if (amount == 0)
	{
		BfWriteShort(message, 0x0010);
	}
	else
	{
		BfWriteShort(message, 0x0008);
	}
	
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, amount);
	EndMessage();
}
