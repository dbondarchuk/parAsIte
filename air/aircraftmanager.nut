/*
 * This file is part of ParAsIte.
 *
 * ParAsIte is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * ParAsIte is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with ParAsIte.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2020 Dmytro Bondarchuk
 */

/** @file aircraftmanager.nut Implemenation of AircraftManager. */

/**
 * Class that manages all aircraft routes.
 */
class AircraftManager {
    _small_engine_id = null; ///< The EngineID of newly build small planes.
    _engine_id = null; ///< The EngineID of newly build big planes.
    _small_engine_group = null; ///< The GroupID of all small planes.
    _big_engine_group = null; ///< The GroupID of all big planes.

    /* public: */

    /**
     * Create a aircraft manager.
     */
    constructor() {
        this._engine_id = null;
    }

    /**
     * Load all information not specially saved by the AI. This way it's easier
     *  to load a savegame saved by another AI.
     */
    function AfterLoad();

    /**
     * Build a new air route. First all existing airports are scanned if some of
     *  them need more planes, if not, more airports are build.
     * @return True if and only if a new route was succesfully created.
     */
    function BuildNewRoute();

    /**
     * Try to build two planes, one on station_a and one on station_b. Both planes
     * will get orders to fly between those two airports.
     * @param station_a The first station.
     * @param station_b The second station.
     * @return True if at least one plane was build succesful.
     */
    function BuildPlanes(station_a, station_b);

    /**
     * Get the miminum passenger acceptance before we'll build an airport
     * or this type at a location.
     * @param airport_type The AirportType to get the minimum acceptance for.
     * @return The minimum passenger cargo acceptance.
     */
    function MinimumPassengerAcceptance(airport_type);

    /* private: */

    /**
     * A valuator for planes engines. Currently it depends linearly on both
     *  capacity and speed, but this will change in the future.
     * @return A higher value if the engine is better.
     */
    function _SortEngineList(engine_id);

    /**
     * Find out what the best EngineID is and store it in _engine_id and
     *  _small_engine_id. If the EngineID changes, set autoreplace from the old
     *  to the new type.
     */
    function _FindEngineID();

    /**
     * A valuator to determine the order in which towns are searched. The value
     *  is random but with respect to the town population.
     * @param town_id The town to get a value for.
     * @return A value for the town.
     */
    function _TownValuator(town_id);

	/**
	 * Is it possible to route some more planes to this station.
	 * @param station_id The StationID of the station to check.
	 * @return Whether or not some more planes can be routes to this station.
	 */
	function CanBuildPlanes(station_id);

	/**
	 * Check all airports in this town to see if there is one we can
	 *  route more planes to.
	 * @param allow_small_airport True if a small airport is acceptable.
	 * @return The StationID of the airport of null if none was found.
	 */
	function GetExistingAirport(allow_small_airport);
};

function AircraftManager::AfterLoad() {
    /* (Re)create the groups so we can seperatly autoreplace big and small planes. */
    this._small_engine_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
    AIGroup.SetName(this._small_engine_group, "Small planes");
    this._big_engine_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
    AIGroup.SetName(this._big_engine_group, "Big planes");

    /* Move all planes in the relevant groups. */
    /* TODO: check if any big planes are going to small airports and
     * reroute or replace them? */
    /* TODO: evaluate airport orders (they might be from another AI. */
    local vehicle_list = AIVehicleList();
    vehicle_list.Valuate(AIVehicle.GetVehicleType);
    vehicle_list.KeepValue(AIVehicle.VT_AIR);
    vehicle_list.Valuate(AIVehicle.GetEngineType);
    foreach(v, engine in vehicle_list) {
        if (AIEngine.GetPlaneType(engine) == AIAirport.PT_BIG_PLANE) {
            AIGroup.MoveVehicle(this._big_engine_group, v);
        } else if (AIEngine.GetPlaneType(engine) == AIAirport.PT_SMALL_PLANE) {
            AIGroup.MoveVehicle(this._small_engine_group, v);
        } else {
            ::main_instance.sell_vehicles.AddItem(v, 0);
        }
    }
}

function AircraftManager::CheckRoutes() {
    local station_list = AIStationList.GetAllStations(AIStation.STATION_AIRPORT);

    foreach(airport in station_list) {
		local tile = AIStation.GetLocation(airport);
		local type = AIAirport.GetAirportType(tile);
		if (AITile.GetCargoAcceptance(tile, ::main_instance._passenger_cargo_id, AIAirport.GetAirportWidth(type), AIAirport.GetAirportHeight(type), AIAirport.GetAirportCoverageRadius(type)) < 20) {
			AILog.Warning("Selling all planes from airport " + AIStation.GetName(airport));
			local veh_list = AIVehicleList_Station(airport);::main_instance.sell_vehicles.AddList(veh_list);::main_instance.SendVehicleToSellToDepot();
		}
	}

    return false;
}

function AircraftManager::_TownValuator(town_id) {
    return AIBase.RandRange(AITown.GetPopulation(town_id));
}

function AircraftManager::CanBuildPlanes(station_id)
{
	local max_planes = AIAirport.GetNumTerminals(AIStation.GetLocation(station_id)) * 4;
	local list = AIVehicleList_Station.GetAllVehicles(station_id);
	if (list.Count() + 2 > max_planes) return false;
	list.Valuate(AIVehicle.GetAge);
	list.KeepBelowValue(200);
	return list.Count() == 0;
}

function AircraftManager::GetExistingAirport(town_id, allow_small_airport)
{
	AILog.Info("Getting all airports in " + AITown.GetName(town_id));
	local station_list = AIStationList.GetAllStations(AIStation.STATION_AIRPORT);
	station_list.Valuate(AIStation.GetNearestTown);
	station_list.KeepValue(town_id);

	AILog.Info("Found " + station_list.Count() + " airports in " + AITown.GetName(town_id));

	foreach (airport, dummy in station_list) {
		AILog.Info("1");
		AILog.Info("Airport - " + AIStation.GetName(airport));
		/* We don't support heliport */
		if (Utils_Airport.IsHeliport(airport)) continue;
		/* If there are zero or one planes going to the airport, we assume
		 * it can handle some more planes. */
		AILog.Info("2");
		if (AIVehicleList_Station.GetAllVehicles(airport).Count() <= 1 && (allow_small_airport || !Utils_Airport.IsSmallAirport(airport))) return airport;
		/* Skip the airport if it can't handle more planes. */
		AILog.Info("3");
		if (!this.CanBuildPlanes(airport)) continue;
		/* If the airport is small and small airports are not ok, don't return it. */
		AILog.Info("4");
		if (Utils_Airport.IsSmallAirport(airport) && !allow_small_airport) continue;
		/* Only return an airport if there are enough waiting passengers, ie the current
		 * number of planes can't handle it. */
		AILog.Info("5");
		if (AIStation.GetCargoWaiting(airport, ::main_instance._passenger_cargo_id) > 500 ||
				(AIStation.GetCargoWaiting(airport, ::main_instance._passenger_cargo_id) > 250 && Utils_Airport.IsSmallAirport(airport)) ||
				AIStation.GetCargoRating(airport, ::main_instance._passenger_cargo_id) < 50) {
			return airport;
		}
	}
	return null;
}

function AircraftManager::BuildPlanes(station_a, station_b) {
    local small_airport = Utils_Airport.IsSmallAirport(station_a) || Utils_Airport.IsSmallAirport(station_b);
	local engineId = (small_airport || this._engine_id == null) ? this._small_engine_id : this._engine_id;
	if (engineId == null) return false;

    /* Make sure we have enough money to buy two planes. */
    /* TODO: there is no check if enough money is available, so possible
     * we can't even buy one plane (if they are really expensive. */
    Utils_General.GetMoney(2 * AIEngine.GetPrice(engineId));

    local success = true;
    /* Build the first plane at the first airport. */
    local v = AIVehicle.BuildVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_a)), engineId);
    if (!AIVehicle.IsValidVehicle(v)) {
        AILog.Error("Building plane failed: " + AIError.GetLastErrorString());

        success = false;
    }

    if (success) {
        /* Add the vehicle to the right group. */
        AIGroup.MoveVehicle(small_airport || this._engine_id == null ? this._small_engine_group : this._big_engine_group, v);
        /* Add the orders to the vehicle. */
        AIOrder.AppendOrder(v, AIStation.GetLocation(station_a), AIOrder.AIOF_NONE);
        AIOrder.AppendOrder(v, AIStation.GetLocation(station_b), AIOrder.AIOF_NONE);
        AIVehicle.StartStopVehicle(v);
    }

    /* Clone the first plane, but build it at the second airport. */
    v = AIVehicle.CloneVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_b)), v, false);
    if (!AIVehicle.IsValidVehicle(v)) {
        AILog.Warning("Cloning plane failed: " + AIError.GetLastErrorString());
        /* Since the first plane was build succesfully, return true. */
        return success;
    }

    /* Add the vehicle to the right group. */
    AIGroup.MoveVehicle(small_airport || this._engine_id == null ? this._small_engine_group : this._big_engine_group, v);
    /* Start with going to the second airport. */
    AIOrder.SkipToOrder(v, 1);
    AIVehicle.StartStopVehicle(v);

    return true;
}

function AircraftManager::MinimumPassengerAcceptance(airport_type) {
    if (!AIGameSettings.GetValue("station.modified_catchment")) return 40;
    switch (airport_type) {
        case AIAirport.AT_SMALL:
            return 40;
        case AIAirport.AT_LARGE:
            return 80;
        case AIAirport.AT_METROPOLITAN:
            return 80;
        case AIAirport.AT_INTERNATIONAL:
            return 100;
        case AIAirport.AT_COMMUTER:
            return 40;
        case AIAirport.AT_INTERCON:
            return 100;
        default:
            return 80;
    }
}

function AircraftManager::BuildNewRoute() {
    /* First update the type of vehicle we will build. */
    this._FindEngineID();
	local engineId = this._engine_id != null ? this._engine_id : this._small_engine_id;

    if (engineId == null) return;

	AILog.Info("Looking for town list");

    /* We want to search all towns for highest to lowest population but in a
     * somewhat random order. */
    local town_list = AITownList();
    Utils_Valuator.Valuate(town_list, this._TownValuator);
    town_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
    local town_list2 = AIList();
    town_list2.AddList(town_list);

	AILog.Info("Got town list");

    /* Check if we can add planes to some already existing airports. */
    foreach(town_from, d in town_list) {
        /* Check if there is an airport in the first town that needs extra planes. */
		AILog.Info("Town from: " + AITown.GetName(town_from));
        local station_a = this.GetExistingAirport(town_from, this._small_engine_id != null);
        
		AILog.Info("Station A " + station_a);
		
		if (station_a == null) continue;
		if (AIAirport.IsHangarTile(AIStation.GetLocation(station_a))) {
				AILog.Warning("Tile index returned for station " + AIStation.GetName(station_a) + " is hangar. Skipping it");
				continue;
		}

        foreach(town_to, d in town_list2) {
            /* Check the distance between the towns. */
            local distance = AIMap.DistanceManhattan(AITown.GetLocation(town_from), AITown.GetLocation(town_to));
            if (distance < 50 || distance > 300) continue;

            /* Check if there is an airport in the second town that needs extra planes. */
            local station_b = this.GetExistingAirport(town_to, this._small_engine_id != null);
            if (station_b == null) continue;
			AILog.Info("Station B " + station_b);
			if (AIAirport.IsHangarTile(AIStation.GetLocation(station_b))) {
				AILog.Warning("Tile index returned for station " + AIStation.GetName(station_b) + " is hangar. Skipping it");
				continue;
			}

			AILog.Info("Building planes from " + AIStation.GetName(station_a) + " to " + AIStation.GetName(station_b));
            return this.BuildPlanes(station_a, station_b);
        }
    }

    return false;
}

function AircraftManager::_SortEngineList(engine_id) {
	local runnigCost = AIEngine.GetRunningCost(engine_id);
    return AIEngine.GetCapacity(engine_id) * AIEngine.GetMaxSpeed(engine_id) / (runnigCost > 0 ? runnigCost / 10 : 1);
}

function AircraftManager::_FindEngineID() {
    /* First find the EngineID for new big planes. */
    local list = AIEngineList(AIVehicle.VT_AIR);
    Utils_Valuator.Valuate(list, this._SortEngineList);
    list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);;
	list.Valuate(AIEngine.GetPrice);
	list.KeepBelowValue(AICompany.GetBankBalance(AICompany.COMPANY_SELF));
	list.KeepAboveValue(1);
	list.Valuate(AIEngine.GetCargoType);
	list.KeepValue(::main_instance._passenger_cargo_id);
	list.Valuate(AIEngine.GetCapacity);
	list.KeepAboveValue(60);
    local new_engine_id = null;
    if (list.Count() != 0) {
        new_engine_id = list.Begin();
        /* If both the old and the new id are valid and they are different,
         *  initiate autoreplace from the old to the new type. */
        if (this._engine_id != null 
			&& new_engine_id != null 
			&& this._engine_id != new_engine_id 
			&& AIEngine.GetCapacity(new_engine_id) > AIEngine.GetCapacity(this._engine_id)) {
            AIGroup.SetAutoReplace(this._big_engine_group, this._engine_id, new_engine_id);
        }
    }
    this._engine_id = new_engine_id;
	if (this._engine_id != null)	{
		AILog.Info("Big plane engine selected: " + AIEngine.GetName(this._engine_id));
	} else {
		AILog.Info("Didn't find an engine for big planes");
	}

    /* And now also for small planes. */
    local list = AIEngineList(AIVehicle.VT_AIR);
    /* Only small planes allowed, no big planes or helicopters. */
    list.Valuate(AIEngine.GetPlaneType);
    list.RemoveValue(AIAirport.PT_BIG_PLANE);
    Utils_Valuator.Valuate(list, this._SortEngineList);
    list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
	list.Valuate(AIEngine.GetPrice);
	list.KeepBelowValue(AICompany.GetBankBalance(AICompany.COMPANY_SELF));
	list.KeepAboveValue(1);
	list.Valuate(AIEngine.GetCargoType);
	list.KeepValue(::main_instance._passenger_cargo_id);
	list.Valuate(AIEngine.GetCapacity);
	list.KeepAboveValue(30);
    local new_engine_id = null;
    if (list.Count() != 0) {
        new_engine_id = list.Begin();
        /* If both the old and the new id are valid and they are different,
         *  initiate autoreplace from the old to the new type. */
        if (this._small_engine_id != null 
			&& new_engine_id != null 
			&& this._small_engine_id != new_engine_id
			&& AIEngine.GetCapacity(new_engine_id) > AIEngine.GetCapacity(this._small_engine_id)) {
            AIGroup.SetAutoReplace(this._small_engine_group, this._small_engine_id, new_engine_id);
        }
    }

    this._small_engine_id = new_engine_id;
	if (this._small_engine_id != null)	{
		AILog.Info("Small plane engine selected: " + AIEngine.GetName(this._small_engine_id));
	} else {
		AILog.Info("Didn't find a new engine for small planes");
	}
	
}