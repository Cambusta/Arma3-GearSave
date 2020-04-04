/*
 gSave v.0.2.6
 ------------
 by Dunecat (aka Cambusta)
 Steam: http://steamcommunity.com/id/cmb_fnc_dunecat/
 BI Forums: https://forums.bistudio.com/user/835008-semiconductor/

 Description
 -----------
 This script allows you as a mission maker to save or load gear of players and containers at any time thus allowing your players
 to collect and use their very own gear in the course of several missions.

 Functions
 ---------

 	S - funtions that will execute only on server (listen or dedicated) and wouldn't have any effect if called on client
 	* - optional argument

 	// Gear saving
 	// Gear is saved to and loaded only from profiles of an actual players, a dedicated server will ignore these functions.

 	[saveId] spawn dnct_fnc_SaveGear 			Saves gear of a local player to his profile.
 	[saveId] spawn dnct_fnc_SaveGearGlobal 		Causes all players to save their gear.
 	[saveId] spawn dnct_fnc_LoadGear			Loads gear of a local player from his profile.
 	[saveId] spawn dnct_fnc_LoadGearGlobal		Causes all players to load gear from their respective profiles.

	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 	// Container content saving
 	// The contents of a container can be saved to profiles of both actual players and dedicated server. Hoever, gear could be loaded only from profiles of listen
 	// or dedicated servers. While all players posses the same data, only server loads it and distributes over the network to ensure lack of conflict.

 	[saveId, container] spawn dnct_fnc_SaveContainer 		Saves contents of a certain container into local player's profile.
 	[saveId, container] spawn dnct_fnc_SaveContainerGlobal 	Causes all clients and listen/dedicated server to save contents of the container to their profiles.
S 	[saveId, container] spawn dnct_fnc_LoadContainer   		Loads gear from server's profile into a certain container. Executes only on server (incl. listen), has global effect.
S 	[saveId, container] spawn dnct_fnc_LoadContainerGlobal 	Causes listen/dedicated server to load gear from its profile to a certain container.

	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 	// Vehicle saving
 	// Saves or loads a vehicle (its position, direction, damage, ammo, fuel, fuel/repair/ammo cargo and textures). PLEASE NOTE: These functions does not saves vehicle's gear, 
 	// you have to save it manually using container saving.

 	[saveId, vehicle] spawn dnct_fnc_SaveVehicle 															Saves vehicle into local's player profile
 	[saveId, vehicle] spawn dnct_fnc_SaveVehicleGlobal														Causes all clients and listen/dedicated server to save a vehicle
S 	[saveId, *canCollide (bool), *custom position, *custom direction] call dnct_fnc_LoadVehicle 			Loads vehicle. Executes only on server (incl. listen), has global effect. 
																	  ''''									If called, returns a local variable that contains created vehicle.					
S 	[saveId, *canCollide (bool), *custom position, *custom direction] spawn dnct_fnc_LoadVehicleGlobal		Causes listen/dedicated server to load a vehicle.

	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 	// Service functions
 	   These allow mission maker to freely delete a certain gear record. It's a good idea to delete data from players profile once you don't need it anymore.

 	[] spawn dnct_fnc_getSaves					returns an array containing all saves and their types. It also displays said array if script is in debug mode.
 	[saveId] spawn dnct_fnc_RemoveGear			removes a gear record with specified id from local players profile
 	[saveId] spawn dnct_fnc_RemoveGearGlobal	removes a gear record with specified id from all players and listen/dedicated server's profile

	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 How to
 ------

 	1. Put "gSaveFncs.sqf" into your mission's folder.

 	2. Create an "init.sqf" file and put the following line in it: 

 	   call compile preprocessFileLineNumbers "gearSaveFncs.sqf";


 	3. If you plan to save the contents of a containers, it is recommended to put an empty marker named "gSaveFiller" somewhere near the containes in
 	   question. Sometimes if the container is too far away from position of a filler unit (an invisible guy that assembles weapons and puts them into 
 	   container) you might experience problems with loading weapons into it. Also keep in mind that there is a 2 second delay between adding weapons to a container 
 	   (that delay does not affect all other items, however).                                                   """"""""""""""


 	4. It is recommended to give players time to save or load their gear before saving or loading containers. Consider adding a brief pause (~5s) between
       dnct_fnc_load(save)Gear and dnct_fnc_load(save)Container calls, like this:

       0 = [] spawn { ["mymission"] spawn dnct_fnc_SaveGear; sleep 5; ["mymission_container"] spawn dnct_fnc_SaveContainer; };


 	5. 	a. Use local versions (without 'Global' postfix) of functions if you're calling them from 'Activation' fields of globlal triggers ('Server Only' is unchecked), 
 		   waypoints 'activation' fields, units 'initialization' fields and the like.

 		b. Use global versions of functions when you're calling them from server-side scripts, 'Server Only' triggers or when you're calling a function from one 
 		   particular client but want it to have a global effect (for example, server admin forcing a dedicated server to load a vehicle).


 	6. IMPORTANT: before exporting the mission, don't forget to set dnct_var_gsave_debug to false (see line 112) to disable debug hints and rpt messages.



 A word regarding messages
 -------------------------

 Disabling the debug mode won't suppress following messages generated by the script:

 	 1. Empty or incorrect save ID or other function arguments;
 	 2. Error message shown when user tries to load a wrong type of gear (i.e. adding a player's loadout to a container);
 	 3. Error message shown when there is a weapon with an unknown type (i.e. neither a rifle, launcher, handgun or binocular);

 Since those messages signal an unrecoverable error they will not be suppressed by disabled debug mode allowing players to easily understand 
 that the mission is broken.

 */
///////////////////////////////////////////////////////// USER CONTROLLED VARIABLES ///////////////////////////////////////////////////////////////////////

					// Debug mode switch; replace 'true' with 'false' to suppress debug messages
					dnct_var_gsave_debug = true;
					

					// Enables BI's vehicle randomization (applies when loading vehicle with dnct_fnc_LoadVehicle or dnct_fnc_LoadVehicleGlobal)
					dnct_var_gsave_enableRandomization = false;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//										DO NOT EDIT TEXT PAST THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING												  //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define PRIMARY 1
#define SECONDARY 4
#define HANDGUN 2
#define BINOCULAR 4096

#define UNIT 1
#define CONTAINER 2
#define VEHICLE 3

#define dnct_var_allow_crutches true

dnct_fnc_SaveGear = {

	if(!isDedicated) then
	{
		_saveId = param[0, "", [""]];

		if(_saveID != "") then
		{
			_varName = format["gsave_%1", _saveId];
			_savedGears = profileNamespace getVariable["gsave_list", []];
			_unit = player;

			_pAssigned = assignedItems _unit;
			_pHeadgear = headgear _unit;

			_pPrimaryWep = primaryWeapon _unit;
			_pSecondWep = secondaryWeapon _unit;
			_pHandgunWep = handgunWeapon _unit;

			_pWeaponsInfo = weaponsItems _unit;

			_pVestWeapons = "";
			_pVestMagazines = "";
			_pVestItems = "";
			_pUniformWeapons = "";
			_pUniformMagazines = "";
			_pUniformItems = "";
			_pBackpackWeapons = "";
			_pBackpackMagazines = "";
			_pBackpackItems = "";

			_pVest = vest _unit;
			if(_pVest != "") then
			{
				_pVestWeapons = weaponsItemsCargo (vestContainer _unit);
				_pVestMagazines = magazinesAmmoCargo (vestContainer _unit);
				_pVestItems = itemCargo (vestContainer _unit);
			};

			_pUniform = uniform _unit;
			if(_pUniform != "") then
			{
				_pUniformWeapons = weaponsItemsCargo (uniformContainer _unit);
				_pUniformMagazines = magazinesAmmoCargo (uniformContainer _unit);
				_pUniformItems = itemCargo (uniformContainer _unit);
			};

			_pBackpack = backpack _unit;
			if(_pBackpack != "") then
			{
				_pBackpackWeapons = weaponsItemsCargo (backpackContainer _unit);
				_pBackpackMagazines = magazinesAmmoCargo (backpackContainer _unit);
				_pBackpackItems = itemCargo (backpackContainer _unit);
			};

			_pGoggles = goggles _unit;

			_pGear = [UNIT, _pAssigned, _pHeadgear, _pPrimaryWep, _pSecondWep, _pHandgunWep, _pWeaponsInfo,
					  _pVest, _pVestWeapons, _pVestMagazines, _pVestItems, _pUniform, _pUniformWeapons, _pUniformMagazines, _pUniformItems, _pBackpack, _pBackpackWeapons, _pBackpackMagazines, _pBackpackItems, _pGoggles];



		    if(!(_varName in _savedGears)) then
			{ _savedGears pushBack _varName; };

		    profileNamespace setVariable["gsave_list", _savedGears];
		    profileNamespace setVariable[_varName, _pGear];

		    if(dnct_var_gsave_debug) then
		    { 
		    	hint parseText format["<t align='left' size='1.2'>gSave: save successful!</t><br/><br/><t align='left'>Unit preset has been saved with an ID of '%1'.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _saveID]; 
		    };
		}
		else
		{ 
			hint parseText format["<t align='left' size='1.2'>gSave Gear Save Error</t><br/><br/><t align='left'>Empty or incorrect save ID.</t><br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly saved due to error specified above. However, you still can try to complete this mission without your gear.</t>"]; 
		};
	};
};

dnct_fnc_LoadGear = {

	if(!isDedicated) then
	{
		_saveId = param[0, "", [""]];

		if(_saveID != "") then
		{
			_varName = format["gsave_%1", _saveId];
			_savedGears = profileNamespace getVariable["gsave_list", []];

			if(_varName in _savedGears) then
			{
				_pGear = profileNamespace getVariable[_varName, []];

				_rType = _pGear select 0;

				if(_rType == UNIT) then
				{
					_pAssigned = _pGear select 1;
					_pHeadgear = _pGear select 2;

					_pPrimaryWep = _pGear select 3;
					_pSecondWep = _pGear select 4;
					_pHandgunWep = _pGear select 5;

					_pWeaponsInfo = _pGear select 6;

					_pVest = _pGear select 7;
					_pVestWeps = _pGear select 8;
					_pVestMags = _pGear select 9;
					_pVestItems = _pGear select 10;

					_pUniform = _pGear select 11;
					_pUniformWeps = _pGear select 12;
					_pUniformMags = _pGear select 13;
					_pUniformItems = _pGear select 14;

					_pBackpack = _pGear select 15;
					_pBackpackWeps = _pGear select 16;
					_pBackpackMags = _pGear select 17;
					_pBackpackItems = _pGear select 18;

					_pGoggles = _pGear select 19;

					removeAllWeapons player;
					removeAllItems player;
					removeAllAssignedItems player;
					removeUniform player;
					removeVest player;
					removeBackpack player;
					removeHeadgear player;
					removeGoggles player;

					player addHeadgear _pHeadgear; 
					player forceAddUniform _pUniform;
					player addVest _pVest;
					player addBackpack _pBackpack;


					{ 

						if([_x] call dnct_fnc_getWeaponType != BINOCULAR) then
						{ player linkItem _x; }
						else
						{ player addWeapon _x; };

					} foreach _pAssigned;

					_primaryWeaponIndex = [_pPrimaryWep, _pWeaponsInfo] call dnct_fnc_findWeaponIndexInfo;
					if(_primaryWeaponIndex != -1) then
					{
						_primaryWeaponInfo = _pWeaponsInfo select _primaryWeaponIndex;
						[_primaryWeaponInfo] call dnct_fnc_unitAddWeaponInfo;
					};

					_secondaryWeaponIndex = [_pSecondWep, _pWeaponsInfo] call dnct_fnc_findWeaponIndexInfo;
					if(_secondaryWeaponIndex != -1) then
					{
						_secondaryWeaponInfo = _pWeaponsInfo select _secondaryWeaponIndex;
						[_secondaryWeaponInfo] call dnct_fnc_unitAddWeaponInfo;
					};

					_handgunWeaponIndex = [_pHandgunWep, _pWeaponsInfo] call dnct_fnc_findWeaponIndexInfo;
					if(_handgunWeaponIndex != -1) then
					{
						_handgunWeaponInfo = _pWeaponsInfo select _handgunWeaponIndex;
						[_handgunWeaponInfo] call dnct_fnc_unitAddWeaponInfo;
					};

					if(_pVest != "") then
					{
						{ [(vestContainer player), _x] call dnct_fnc_cargoAddWeaponInfo; } foreach _pVestWeps;
						{ [(vestContainer player), _x] call dnct_fnc_cargoAddMagazineInfo; } foreach _pVestMags;
						{ player addItemToVest _x; } foreach _pVestItems;
					};

					if(_pUniform != "") then
					{
						{ [(uniformContainer player), _x] call dnct_fnc_cargoAddWeaponInfo; } foreach _pUniformWeps;
						{ [(uniformContainer player), _x] call dnct_fnc_cargoAddMagazineInfo; } foreach _pUniformMags;
						{ player addItemToUniform _x; } foreach _pUniformItems;
					};

					if(_pBackpack != "") then
					{
						{ [(backpackContainer player), _x] call dnct_fnc_cargoAddWeaponInfo; } foreach _pBackpackWeps;
						{ [(backpackContainer player), _x] call dnct_fnc_cargoAddMagazineInfo; } foreach _pBackpackMags;
						{ player addItemToBackpack _x; } foreach _pBackpackItems;
					};

					player addGoggles _pGoggles;

					if(dnct_var_gsave_debug) then
					{ hint parseText format["<t align='left' size='1.2'>gSave: load successful!</t><br/><br/><t align='left'>Unit preset with and ID of '%1' has been loaded.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _saveID]; };
				}
				else
				{
					hint parseText format["<t align='left' size='1.2'>gSave Gear Load Error</t><br/><br/><t align='left'>Gear record with an ID of '%1' represents a container content or vehicle and cannot be loaded into a unit.</t><br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly loaded due to error specified above. However, you still can try to complete this mission without your gear.</t>", _saveID];
				};

			}
			else
			{ 
				if(dnct_var_gsave_debug) then
				{
					hint parseText format["<t align='left' size='1.2'>gSave Gear Load Warning</t><br/><br/><t align='left'>Unit gear record with an ID of '%1' does not exist.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _saveID];
				};
			};
		}
		else
		{
			 hint parseText "<t align='left' size='1.2'>gSave Gear Load Error</t><br/><br/><t align='left'>Empty or incorrect save ID.</t><br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly loaded due to error specified above. However, you still can try to complete this mission without your gear.</t>";
		};
	};
	
};

dnct_fnc_SaveContainer = {

	_saveId = param[0, "", [""]];
	_container = param[1, objNull, [objNull]];

	if((_saveId != "") && (!isNull _container)) then
	{
		if(alive _container) then
		{
			if(!(_container isKindOf "Man")) then
			{
				_varName = format["gsave_%1", _saveId];
				_savedGears = profileNamespace getVariable["gsave_list", []];

				_cWeps = weaponsItemsCargo _container;
				_cMags = magazinesAmmoCargo _container;
				_cItems = itemCargo _container;
				_cContainers = [];

				{
					_cDescription = [];		
					_cRef = _x select 1;

					_scWeps = weaponsItemsCargo _cRef;
					_scMags = magazinesAmmoCargo _cRef;
					_scItems = itemCargo _cRef;

					_cDescription = [_x select 0, _scWeps, _scMags, _scItems];
					_cContainers pushBack _cDescription;

				} foreach (everyContainer _container);

				_cGear = [CONTAINER, _cWeps, _cMags, _cItems, _cContainers];

			    if(!(_varName in _savedGears)) then
				{ _savedGears pushBack _varName; };

			    profileNamespace setVariable["gsave_list", _savedGears];
			    profileNamespace setVariable[_varName, _cGear];

			    if(dnct_var_gsave_debug) then
				{ hint parseText format["<t align='left' size='1.2'>gSave: container save successful!</t><br/><br/><t align='left'>Container '%1' has been saved with an ID of '%2'.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _container, _saveID]; };
			}
			else
			{
				if(dnct_var_gsave_debug) then
				{ hint parseText "<t align='left' size='1.2'>gSave Container Save Error</t><br/><br/><t align='left'>You are have tried to save unit's gear as container's preset. Please check your container's variable name.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>"; };
			};
		}
		else
		{
			if(dnct_var_gsave_debug) then
			{ hint parseText "<t align='left' size='1.2'>gSave Container Save Error</t><br/><br/><t align='left'>You have tried to save content of a container that is destroyed. Destroyed containers have no content.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>"; };
		};
	}
	else
	{
		hint parseText format["<t align='left' size='1.2'>gSave Container Save Error</t><br/><br/><t align='left'>dnct_fnc_SaveContainer received an incorrect set of arguments (%1).<br/><br/>Please ensure that the first argument is string representig a certain save ID and the second argument is a valid container.<br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly saved due to error specified above. However, you still can try to complete this mission without your gear.</t>", str(_this)];
	};
};

dnct_fnc_LoadContainer = {

	if(isServer) then
	{
		_saveId = param[0, "", [""]];
		_container = param[1, objNull, [objNull]];

		if((_saveId != "") && (!isNull _container)) then
		{
			_saveId = _this select 0;
			_container = _this select 1;
			_varName = format["gsave_%1", _saveId];
			_savedGears = profileNamespace getVariable["gsave_list", []];

			if(alive _container) then
			{

				if(_varName in _savedGears) then
				{
					_cGear = profileNamespace getVariable[_varName, []];

					_rType = _cGear select 0;

					if(_rType == CONTAINER) then
					{
						if(dnct_var_gsave_debug) then
						{ hint parseText format["<t align='left' size='1.2'>gSave Information</t><br/><br/><t align='left'>Please keep in mind that there is a 2 second delay when adding each weapon to a container therefore container loading might require some time if you have plenty of weapons saved.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>"]; sleep 2; };

						_cWeps = _cGear select 1;
						_cMags = _cGear select 2;
						_cItems = _cGear select 3;
						_cContainers = _cGear select 4;
						_cContainersList = [];

						_tContainerFiller = call dnct_fnc_createContainerFiller;

						{ _cContainersList pushBack (_x select 0); } foreach _cContainers;

						{
							if([_x] call dnct_fnc_getWeaponType != BINOCULAR) then
							{ [_container, _x, _tContainerFiller] call dnct_fnc_cargoAddWeaponInfo; }
							else
							{ _container addWeaponCargoGlobal [(_x select 0), 1]; };

						} foreach _cWeps;

						{
							_container addMagazineAmmoCargo [_x select 0, 1, _x select 1];
						} foreach _cMags;

						{
						if(!(_x in _cContainersList)) then
						{ _container addItemCargoGlobal [_x, 1]; };
						} foreach _cItems;

						{	
							_scType = _x select 0;
							_scWeps = _x select 1;
							_scMags = _x select 2;
							_scItems= _x select 3;

							_lastContainer = nil;

							if(_scType isKindOf "Bag_Base") then
							{ _container addBackpackCargoGlobal[_scType, 1]; }
							else
							{ _container addItemCargoGlobal[_scType, 1]; };

							_lastContainer = (everyContainer _container) select (count (everyContainer _container) - 1) select 1;

							{
								[_lastContainer, _x] call dnct_fnc_cargoAddWeaponInfo
							} foreach _scWeps;

							{
								_lastContainer addMagazineAmmoCargo [_x select 0, 1, _x select 1];
							} foreach _scMags;

							{
								_lastContainer addItemCargoGlobal [_x, 1];
							} foreach _scItems;		

						} foreach _cContainers;

						[_tContainerFiller] call dnct_fnc_deleteContainerFiller;

						if(dnct_var_gsave_debug) then
						{ hint parseText format["<t align='left' size='1.2'>gSave: container load successful!</t><br/><br/><t align='left'>Container preset with and ID of '%1' has been loaded into '%2'.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _varName, _container]; };
					}
					else
					{
						hint parseText format["<t align='left' size='1.2'>gSave Container Load Error</t><br/><br/><t align='left'>Gear record with and id of '%1' does not represent a container contents and thus cannot be loaded into container.</t><br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly loaded due to error specified above. However, you still can try to complete this mission without your gear.</t>", _varName];
					};

				}
				else
				{ 
					if(dnct_var_gsave_debug) then
					{
						hint parseText format["<t align='left' size='1.2'>gSave Container Load Error</t><br/><br/><t align='left'>Container gear record with an ID of '%1' does not exist.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _varName];
					};
				};
			}
			else
			{
				if(dnct_var_gsave_debug) then
				{ hint parseText "<t align='left' size='1.2'>gSave Container Load Error</t><br/><br/><t align='left'>You have tried to load preset into a destroyed container. Destroyed containers cannot hold any content.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>"; };
			};
		}
		else
		{
			hint parseText format["<t align='left' size='1.2'>gSave Container Load Error</t><br/><br/><t align='left'>dnct_fnc_LoadContainer received an incorrect set of arguments (%1).<br/><br/>Please ensure that the first argument is string representig a certain save ID and the second argument is a valid container.<br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly loaded due to error specified above. However, you still can try to complete this mission without your gear.</t>", str(_this)];
		};
	};
};

dnct_fnc_SaveVehicle = {

	_saveId = param[0, "", [""]];
	_vehicle = param[1, objNull, [objNull]];

	if((_saveId != "") && (!isNull _vehicle)) then
	{

		if(_vehicle isKindOf "AllVehicles") then
		{
			if(alive _vehicle) then
			{
				_varName = format["gsave_%1", _saveId];
				_savedGears = profileNamespace getVariable["gsave_list", []];
				_unit = player;

	   			_vType = typeof _vehicle;
	   			_vPos = getPosATL _vehicle;
	   			_vDir = direction _vehicle;
		   		_vHitpoints = getAllHitpointsDamage _vehicle;
	   			_vAmmo = magazinesAmmo _vehicle;
	   			_vFuel = fuel _vehicle;

	   			_vFuelCargo = getFuelCargo _vehicle;
	   			_vAmmoCargo = getAmmoCargo _vehicle;
	   			_vRepairCargo = getRepairCargo _vehicle;

	   			_vTextures = getObjectTextures _vehicle;

	   			if(!finite _vFuelCargo) then
	   			{ _vFuelCargo = -1; };

	   			if(!finite _vAmmoCargo) then
	   			{ _vAmmoCargo = -1; };

	   			if(!finite _vRepairCargo) then
	   			{ _vRepairCargo = -1; };

		   		_vRecord = [VEHICLE, _vType, _vPos, _vDir, _vHitpoints, _vAmmo, _vFuel, _vFuelCargo, _vAmmoCargo, _vRepairCargo, _vTextures];

	   			if(!(_varName in _savedGears)) then
				{ _savedGears pushBack _varName; };

			    profileNamespace setVariable["gsave_list", _savedGears];
		    	profileNamespace setVariable[_varName, _vRecord];

			    if(dnct_var_gsave_debug) then
				{ hint parseText format["<t align='left' size='1.2'>gSave: vehicle save successful!</t><br/><br/><t align='left'>Vehicle '%1' has been saved with an ID of '%2'.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _vehicle, _saveID]; };
			}
			else
			{
			    if(dnct_var_gsave_debug) then
				{ hint parseText format["<t align='left' size='1.2'>gSave Vehicle Save Error</t><br/><br/><t align='left'>The vehicle '%1' has beed destroyed. Destroyed vehicles could not be saved.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _vehicle]; };
			};
		}
		else
		{

			if(dnct_var_gsave_debug) then
			{ hint parseText "<t align='left' size='1.2'>gSave Vehicle Save Error</t><br/><br/><t align='left'>You attemped to save an entity that does not appear to be a vehicle (isKindOf ""AllVehicles"" check returns false).<br/><br/>Please make sure that the object you're trying to save is indeed a vehicle and if it is, make changes to this script or simply try another vehicle.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>"; };	
		};
	}
	else
	{
		hint parseText format["<t align='left' size='1.2'>gSave Vehicle Save Error</t><br/><br/><t align='left'>dnct_fnc_SaveVehicle received an incorrect set of arguments (%1).<br/><br/>Please ensure that the first argument is string representig a certain save ID and the second argument is a valid vehicle.<br/><br/><t align='left' size='0.8'>This message means that the vehicle cannot be properly loaded due to error specified above. However, you still can try to complete this mission without that vehicle.</t>", str(_this)];
	};	
};

dnct_fnc_LoadVehicle = {

	if(isServer) then
	{
		_saveId = param[0, "", [""]];
		_exact = param[1, false, [true]];
		_position = param[2, [0,0,0], [[]], [3]];
		_direction = param[3, 3084, [0]];

		if(_saveId != "") then
		{
			_varName = format["gsave_%1", _saveId];
			_savedGears = profileNamespace getVariable["gsave_list", []];

			if(_varName in _savedGears) then
			{
				_vRecord = profileNamespace getVariable[_varName, ""];

				_rType = _vRecord select 0;

				if(_rType == VEHICLE) then
				{
					_vType = _vRecord select 1;
					_vPos = _vRecord select 2;
					_vDir = _vRecord select 3;
					_vHitpointsNames = (_vRecord select 4) select 0;
					_vHitpointsDamage = (_vRecord select 4) select 2;
					_vAmmo = _vRecord select 5;
					_vFuel = _vRecord select 6;
					_vFuelCargo = _vRecord select 7;
					_vAmmoCargo = _vRecord select 8;
					_vRepairCargo = _vRecord select 9;
					_vTextures = _vRecord select 10;

					if(_position isEqualTo [0,0,0]) then
					{ _position  = _vPos; };

					if(_direction == 3084) then
					{ _direction = _vDir; };

					_special = "NONE";

					if(_exact) then
					{ _special = "CAN_COLLIDE"; };

					_veh = createVehicle[_vType, _position, [], 0, _special];
					_veh setVariable ["BIS_enableRandomization", dnct_var_gsave_enableRandomization];
					_veh setDir _direction;

					clearWeaponCargoGlobal _veh;
					clearMagazineCargoGlobal _veh;
					clearItemCargoGlobal _veh;
					clearBackpackCargoGlobal _veh;

					{
						_damage = _vHitpointsDamage select _forEachIndex;
						_veh setHitPointDamage[_x, _damage];
					} foreach _vHitpointsNames;

					_veh setVehicleAmmo 0;

					{
						_magType = _x select 0;
						_magAmmo = _x select 1;
						_veh addMagazine[_magType, _magAmmo];
					} foreach _vAmmo;

					_veh setFuel _vFuel;

					if(_vFuelCargo != -1) then
					{ _veh setFuelCargo _vFuelCargo; };

					if(_vAmmoCargo != -1) then
					{ _veh setAmmoCargo _vAmmoCargo; };

					if(_vRepairCargo != -1) then
					{ _veh setRepairCargo _vRepairCargo; };

					{
						_veh setObjectTextureGlobal[_forEachIndex, _x];
					} foreach _vTextures;

					if(dnct_var_gsave_debug) then
					{ hint parseText format["<t align='left' size='1.2'>gSave: vehicle load successful!</t><br/><br/><t align='left'>Vehicle preset with an ID of '%1' has been loaded at %2.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _saveID, _position]; };

					_veh
				}
				else
				{
					hint parseText format["<t align='left' size='1.2'>gSave Vehicle Load Error</t><br/><br/><t align='left'>Record with and id of '%1' does not represent vehicle and thus cannot be loaded.</t><br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly loaded due to error specified above. However, you still can try to complete this mission without your gear.</t>", _varName];	
				};				

			}
			else
			{
				if(dnct_var_gsave_debug) then
				{
					hint parseText format["<t align='left' size='1.2'>gSave Vehicle Load Error</t><br/><br/><t align='left'>Vehicle record with an ID of '%1' does not exist.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _saveId];
				};	
			};
		}
		else
		{
			hint parseText format["<t align='left' size='1.2'>gSave Vehicle Load Error</t><br/><br/><t align='left'>dnct_fnc_LoadVehicle received an incorrect set of arguments (%1).<br/><br/>Please ensure that the first argument is string representig a certain save ID. Refer to documentation for additional information on function's arguments.<br/><br/><t align='left' size='0.8'>This message means that the vehicle cannot be properly loaded due to error specified above. However, you still can try to complete this mission without that vehicle.</t>", _this];
		};
	};
};

dnct_fnc_RemoveGear = {

	_saveId = _this select 0;

	_varName = format["gsave_%1", _saveId];
	_savedGears = profileNamespace getVariable["gsave_list", []];
	_savedGears = _savedGears - [_varName];

	profileNamespace setVariable[_varName, nil];
	profileNamespace setVariable["gsave_list", _savedGears];

	if(dnct_var_gsave_debug) then
	{ hint parseText format["<t align='left' size='1.2'>gSave: gear has been removed!</t><br/><br/><t align='left'>A gear record with an id of %1 has been removed from profile.</t><br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _saveId]; };
};

dnct_fnc_unitAddWeaponInfo = {
	
	_weaponInfo= _this select 0;
	_unit = param[1, player];

	_weapon = _weaponInfo select 0;
	_supp	= _weaponInfo select 1;
	_laser  = _weaponInfo select 2;
	_optic	= _weaponInfo select 3;
	_magInfo= _weaponInfo select 4;
	_glInfo	= nil;
	_bipod = "";
	_type = [_weapon] call dnct_fnc_getWeaponType;

	if(count _weaponInfo == 7) then
	{ 
		_glInfo = _weaponInfo select 5; 
		_bipod = _weaponInfo select 6;
	}
	else
	{ _bipod = _weaponInfo select 5; };	

	switch(_type) do
	{
		case PRIMARY : { 
					if(count _magInfo > 1) then
					{ _unit addMagazine[(_magInfo select 0), (_magInfo select 1)]; };

					if(!isNil "_glInfo") then
					{ _unit addMagazine[(_glInfo select 0), (_glInfo select 1)]; };

					_unit addWeapon _weapon;
					removeAllPrimaryWeaponItems _unit;
					_unit addPrimaryWeaponItem _supp;
					_unit addPrimaryWeaponItem _laser;
					_unit addPrimaryWeaponItem _optic;
					_unit addPrimaryWeaponItem _bipod;
				 };

		case SECONDARY :  {
					{ _unit removeSecondaryWeaponItem _x; } foreach (secondaryWeaponItems _unit); 

					if(count _magInfo > 1) then
					{ _unit addMagazine[(_magInfo select 0), (_magInfo select 1)]; };

					if(!isNil "_glInfo") then
					{ _unit addMagazine[(_glInfo select 0), (_glInfo select 1)]; };

					_unit addWeapon _weapon;
					_unit addSecondaryWeaponItem _supp;
					_unit addSecondaryWeaponItem _laser;
					_unit addSecondaryWeaponItem _optic;
					_unit addSecondaryWeaponItem _bipod;
			     };
		case HANDGUN : {
					removeAllHandgunItems _unit; 

					if(count _magInfo > 1) then
					{ _unit addMagazine[(_magInfo select 0), (_magInfo select 1)]; };

					if(!isNil "_glInfo") then
					{ _unit addMagazine[(_glInfo select 0), (_glInfo select 1)]; };

					_unit addWeapon _weapon;
					_unit addHandgunItem _supp;
					_unit addHandgunItem _laser;
					_unit addHandgunItem _optic;
					_unit addHandgunItem _bipod;
				 };
		default  {
					hint parseText format["<t align='left' size='1.2'>gSave Weapon Adding Error</t><br/><br/><t align='left'>Cannot add weapon to a unit: '%1' weapon has an unsupported type (%2).</t><br/><br/><t align='left' size='0.8'>This message means that the gear cannot be properly loaded due to error specified above. However, you still can try to complete this mission without your gear.</t>", _type, _weapon];
				 };
	};
};

dnct_fnc_cargoAddWeaponInfo = {
	
	_container = _this select 0;
	_weaponInfo= _this select 1;
	_containerFiller = _this select 2;

	_weapon = _weaponInfo select 0;
	_supp	= _weaponInfo select 1;
	_laser  = _weaponInfo select 2;
	_optic	= _weaponInfo select 3;
	_magInfo= _weaponInfo select 4;
	_glInfo	= nil;
	_bipod = "";

	if(count _weaponInfo == 7) then
	{ 
		_glInfo = _weaponInfo select 5; 
		_bipod = _weaponInfo select 6;
	}
	else
	{ _bipod = _weaponInfo select 5; };				

	[_weaponInfo, _container, _containerFiller] call fnc_addWeaponWithItems;
};

dnct_fnc_cargoAddMagazineInfo = {
	
	_container = _this select 0;
	_magInfo   = _this select 1;

	_container addMagazineAmmoCargo[(_magInfo select 0), 1, (_magInfo select 1)];
};

dnct_fnc_findWeaponIndexInfo = {
	
	_weaponClassname = _this select 0;
	_weaponInfo = _this select 1;
	_index= - 1;

	{
		if((_x select 0) == _weaponClassname) then
		{ _index =  _forEachIndex; };
	} foreach _weaponInfo;

	_index
};

fnc_addWeaponWithItems = {

	/*
		All credit for this idea goes to larrow
		https://forums.bistudio.com/topic/188339-adding-weapon-to-crate-with-specific-attachments/?p=2984843
	*/

    params [ "_weaponInfo", "_container", "_containerFiller" ];    

    _weapon = _weaponInfo select 0;
    _weaponType = [_weapon] call dnct_fnc_getWeaponType;
    
    [_weaponInfo, _containerFiller] call dnct_fnc_unitAddWeaponInfo; 
    _containerFiller action [ "DropWeapon", _container, _weapon ];

    if(dnct_var_allow_crutches) then
    { sleep 2; };
};

dnct_fnc_SaveGearGlobal = 
{
	_saveId = _this select 0;
	[_saveId] remoteExec ["dnct_fnc_SaveGear"];
};

dnct_fnc_LoadGearGlobal = 
{
	_saveId = _this select 0;
	[_saveId] remoteExec ["dnct_fnc_LoadGear"];
};

dnct_fnc_SaveContainerGlobal = 
{
	_saveId = _this select 0;
	_container = _this select 1;
	[_saveId, _container] remoteExec ["dnct_fnc_SaveContainer"];
};

dnct_fnc_LoadContainerGlobal = 
{
	_saveId = _this select 0;
	_container = _this select 1;
	[_saveId, _container] remoteExec ["dnct_fnc_LoadContainer", 2];
};

dnct_fnc_SaveVehicleGlobal = 
{
	_saveId = _this select 0;
	_vehicle = _this select 1;
	[_saveId, _vehicle] remoteExec ["dnct_fnc_SaveVehicle"];
};

dnct_fnc_LoadVehicleGlobal = 
{
	_saveId = _this select 0;
	_exact = param[1, false, [true]];
	_position = param[2, [0,0,0], [[]], [3]];
	_direction = param[3, 3084, [0]];

	[_saveId, _exact, _position, _direction] remoteExec ["dnct_fnc_LoadVehicle"];
};

dnct_fnc_RemoveGearGlobal = 
{
	_saveId = _this select 0;
	[_saveId] remoteExec ["dnct_fnc_RemoveGear"];
};

dnct_fnc_purgeData = 
{

	/*
		WARNING
	    """""""

	   	This function will delete literally all data that is used by the script so the only time you want to use
	   	it when you need to remove all traces of this script from your Arma 3 profile. PLEASE USE THIS FUNCTION
	    MINDFULLY BECAUSE YOU MIGHT DELETE PLAYER'S PROGRESS COMPLETELY.

	    To prevent such situations from occureing, this function by default will only execute in debug mode.
	*/

	if(dnct_var_gsave_debug) then
	{
		_savedGears = profileNamespace getVariable["gsave_list", []];

		{ profileNamespace setVariable[_x, nil]; } foreach _savedGears;
		profileNamespace setVariable["gsave_list", nil];

		if(dnct_var_gsave_debug) then 
		{ 
			hint parseText "<t align='left' size='1.2'>gSave: purging successful!</t><br/><br/><t align='left'>All script data was deleted from this player's profile.<br/><br/><t color='#ff0000'>Please note: this function can only be executed in debug mode.</t>";
		};
	}
	else
	{
		hint parseText "<t align='left' size='1.2'>gSave Purge Warning</t><br/><br/><t align='left'>To prevent accidental data loss, gSave will not execute purgeData or purgeDataGlobal functions unless switched to debug mode.</t>";
	};
};

dnct_fnc_purgeDataGlobal = 
{
	/*
		WARNING
	    """""""

	   	This function will delete literally all data that is used by the script so the only time you want to use
	   	it when you need to remove all traces of this script from your Arma 3 profile. PLEASE USE THIS FUNCTION
	    MINDFULLY BECAUSE YOU MIGHT DELETE PLAYER'S PROGRESS COMPLETELY.

	    To prevent such situations from occuring, this function by default will only execute in debug mode.

	*/

	[] remoteExec ["dnct_fnc_purgeData"];
};

dnct_fnc_getSaves = {
	_saveList = profileNamespace getVariable["gsave_list", []];
	_result = [];
	_hintText = "";

	{
		_currSave = profileNamespace getVariable[_x, []];

		_saveId = toArray _x;
		_saveId deleteRange [0, 6];
		_saveId = toString _saveId;

		switch(_currSave select 0) do
		{
			case UNIT : { _result pushBack[1, _saveId]; };
			case CONTAINER : { _result pushBack[2, _saveId]; };
			case VEHICLE : { _result pushBack[3, _saveId]; };
			default { _result pushBack[-99, _saveId]; };
		};

	} foreach _saveList;

	if(dnct_var_gsave_debug) then 
	{
		{ _hintText = (_hintText + str(_x)) + "<br/>"; } foreach _result;
		hint parseText format["<t align='left' size='1.2'>gSave: Save List</t><br/><br/><t align='left'>Here's a list of all available saves in format [Type (1 - unit, 2 - container, 3 - vehicle, -99 - error), Name]<br/><br/>-----------------------------------<br/>%1-----------------------------------<br/><br/>Please note that this functions also returns an array in indicated format.<br/><br/><t align='left' size='0.8' color='#808080'>This message is displayed only in debug mode.</t>", _hintText];
	};

	_result		
};

dnct_fnc_getWeaponType = {
	
	_weapon = param[0, ""];

	if(typeName _weapon == "ARRAY") then
	{ _weapon = _weapon select 0; };

	_type = getNumber (configFile >> "CfgWeapons" >> _weapon >> "Type");

	_type
};

dnct_fnc_createContainerFiller = {
	
	_fnc_clearUnit = {
        params[ "_unit" ];
        removeAllWeapons _unit;
        removeAllItems _unit;
    };

    _containerFillerPos = getMarkerPos "gSaveFiller";
    
    _grp = createGroup civilian;
    _containerFiller = _grp createUnit [ "C_Man_1", _containerFillerPos, [], 0, "NONE" ];
    _containerFiller allowDamage false;
    
    if(!dnct_var_gsave_debug) then
    { hideObjectGlobal _containerFiller; };

    {
        _containerFiller disableAI _x
    }forEach [
        "TARGET",
        "AUTOTARGET",
        "MOVE",
        "ANIM",
        "TEAMSWITCH",
        "FSM",
        "CHECKVISIBLE",
        "COVER",
        "AUTOCOMBAT"
    ];

    _containerFiller call _fnc_clearUnit;

    _containerFiller
};

dnct_fnc_deleteContainerFiller = {

	_containerFiller = _this select 0;
	_group = group _containerFiller;

	deleteVehicle _containerFiller;
	deleteGroup _group;	
};