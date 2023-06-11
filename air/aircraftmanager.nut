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
    _helicopter_engine_id = null; ///< The EngineID of newly build helicopters.
    _small_engine_group = null; ///< The GroupID of all small planes.
    _big_engine_group = null; ///< The GroupID of all big planes.
    _helicopters_group = null; ///< The GroupID of all helicopters.

    _unprofitable_plane_routes = {}; /// < Map of plane routes which are considered not profitable. "station_a,station_b" -> date when was declared such
    _unprofitable_helicopter_routes = {}; /// < Map of helicopter routes which are considered not profitable. "station_a,station_b" -> date when was declared such

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
     * @param is_helicopter_route If we are trying to build Helicopter route
     * @return True if and only if a new route was succesfully created.
     */
    function BuildNewRoute(is_helicopter_route);

    /**
     * Try to build two planes, one on station_a and one on station_b. Both planes
     * will get orders to fly between those two airports.
     * @param station_a The first station.
     * @param station_b The second station.
     * @param is_helicopter_route If we are trying to build Helicopter route
     * @return True if at least one plane was build succesful.
     */
    function BuildPlanes(station_a, station_b, is_helicopter_route);

    /* private: */

    /**
     * A valuator for planes engines. Currently it depends linearly on both
     *  capacity and speed, but this will change in the future.
     * @return A higher value if the engine is better.
     */
    function _SortEngineList(engine_id);

    /**
     * A valuator for vehicles. Get plane type
     */
    function _GetVehiclePlaneType(vehicle_id);

    /**
     * A valuator for planes engines. Returns plane range or 2048 if it's unlimited
     */
    function _GetPlaneRange(engine_id);

    /**
     * Find out what the best EngineID is and store it in _engine_id and
     *  _small_engine_id. If the EngineID changes, set autoreplace from the old
     *  to the new type.
     * @param min_distance Minimum needed distance
     */
    function _FindEngineID(min_distance);

    /**
     * A valuator to determine the order in which towns are searched. The value
     *  is random but with respect to the town population.
     * @param town_id The town to get a value for.
     * @return A value for the town.
     */
    function _TownValuator(town_id);

    /**
     * A valuator to determine the order in which stations towns are searched. The value
     *  is random but with respect to the town population.
     * @param town_id The town to get a value for.
     * @return A value for the town.
     */
    function _StationTownValuator(town_id);

    /**
     * Gets all planes on the route
     * @param station_a Starting airport
     * @param station_b Destination airport
     * @param all Whether to get competitors planes
     * @param is_helicopter Whether to get helicopters instead of planes
     * @return List of the planes on route
     */
    function _GetRoutePlanes(station_a, station_b, all, is_helicopter);

    /**
     * Gets all planes in the airport
     * @param airport Airport
     * @param all Whether to get competitors planes
     * @param is_helicopter Whether to get helicopters instead of planes
     * @return List of the planes in the airport
     */
    function _GetAirportPlanes(airport, all, is_helicopter);

    /**
     * Gets maximum number of allowed aircrafts in the airport
     * @param airport Airport
     * @param is_helicopter Whether to get helicopters instead of planes
     * @return Maximum number of allowed aircrafts in the airport
     */
    function _GetMaxAircraftsForAirport(airport, is_helicopter);

	/**
	 * Is it possible to route some more planes to this station.
	 * @param station_id The StationID of the station to check.
     * @param is_helicopter_route If we are trying to build Helicopter route
	 * @return Whether or not some more planes can be routes to this station.
	 */
	function CanBuildPlanes(station_id, is_helicopter_route);
};

function AircraftManager::AfterLoad() {
    //AILog.Info("AircraftManager::AfterLoad Starting AfterLoad script")
    /* (Re)create the groups so we can seperatly autoreplace big and small planes. */
    this._small_engine_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
    AIGroup.SetName(this._small_engine_group, "Small planes");
    this._big_engine_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
    AIGroup.SetName(this._big_engine_group, "Big planes");
    this._helicopters_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
    AIGroup.SetName(this._helicopters_group, "Helicopters");

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
        } else if (AIEngine.GetPlaneType(engine) == AIAirport.PT_HELICOPTER) {
            AIGroup.MoveVehicle(this._helicopters_group, v);
        } else {
            ::main_instance.sell_vehicles.AddItem(v, 0);
        }
    }
}

function AircraftManager::CheckRoutes() {
    local station_list = AIStationList.GetAllStations(AIStation.STATION_AIRPORT);
    local station_list_2 = AIList();
    station_list_2.AddList(station_list);

    AILog.Info("AircraftManager::CheckRoutes  Found " + station_list.Count() + " airports");

    local all_planes = AIVehicleList();
    all_planes.Valuate(AIVehicle.GetVehicleType);
    all_planes.KeepValue(AIVehicle.VT_AIR);

    local planes_invalid_order = AIList();
    planes_invalid_order.AddList(all_planes);
    planes_invalid_order.Valuate(AIVehicle.HasInvalidOrders);
    planes_invalid_order.KeepValue(1);

    if (planes_invalid_order.Count() > 0) {
        AILog.Warning("We have " + planes_invalid_order.Count() + " planes with invalid order. Selling them");
        ::main_instance.sell_vehicles.AddList(planes_invalid_order);
        ::main_instance.SendVehicleToSellToDepot();
    }

    local unprofitable_planes = AIList();
    unprofitable_planes.AddList(all_planes);

    unprofitable_planes.Valuate(AIVehicle.GetProfitThisYear);
    unprofitable_planes.KeepBelowValue(0);

    unprofitable_planes.Valuate(AIVehicle.GetProfitLastYear);
    unprofitable_planes.KeepBelowValue(0);

    foreach(airport, d in station_list) {
		local tile = AIStation.GetLocation(airport);
		local type = AIAirport.GetAirportType(tile);
		if (AITile.GetCargoAcceptance(tile, ::main_instance._passenger_cargo_id, AIAirport.GetAirportWidth(type), AIAirport.GetAirportHeight(type), AIAirport.GetAirportCoverageRadius(type)) < 20) {
			AILog.Warning("AircraftManager::CheckRoutes  Selling all planes from airport " + airport + ":" + AIStation.GetName(airport) + ". Type: " + type + ". Tile: " + tile);
			local veh_list = AIVehicleList_Station(airport);
            ::main_instance.sell_vehicles.AddList(veh_list);
            ::main_instance.SendVehicleToSellToDepot();
		}

        local airport_own_planes = this._GetAirportPlanes(airport, false, false);
        local airport_max_planes = this._GetMaxAircraftsForAirport(airport, false);
        local max_planes = airport_max_planes * AIController.GetSetting("max_own_airport_planes") / 100;
        if (airport_own_planes.Count() > max_planes) {
            local number_planes_to_sell = airport_own_planes.Count() - max_planes;

            AILog.Info("We have number (" + number_planes_to_sell + ") + of planes on " + AIStation.GetName(airport) + " over the allocated quota: max:: " + airport_max_planes + "; own:: " +  airport_own_planes.Count());

            local planes_to_sell = AIList();
            planes_to_sell.AddList(airport_own_planes);

            planes_to_sell.Valuate(AIVehicle.GetProfitLastYear);
            planes_to_sell.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

            planes_to_sell.KeepBottom(number_planes_to_sell);

            ::main_instance.sell_vehicles.AddList(planes_to_sell);
            ::main_instance.SendVehicleToSellToDepot();
        }

        local airport_own_helicopters = this._GetAirportPlanes(airport, false, true);
        local airport_max_helicopters = this._GetMaxAircraftsForAirport(airport, true);
        local max_helicopters = airport_max_helicopters * AIController.GetSetting("max_own_airport_planes") / 100;
        if (airport_own_helicopters.Count() > max_helicopters) {
            local number_helicopters_to_sell = airport_own_helicopters.Count() - max_helicopters;

            AILog.Info("We have number (" + number_helicopters_to_sell + ") + of helicopters on " + AIStation.GetName(airport) + " over the allocated quota: max:: " + airport_max_helicopters + "; own:: " +  airport_own_helicopters.Count());

            local helicopters_to_sell = AIList()
            helicopters_to_sell.AddList(airport_own_helicopters);

            helicopters_to_sell.Valuate(AIVehicle.GetProfitLastYear);
            helicopters_to_sell.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

            helicopters_to_sell.KeepBottom(number_helicopters_to_sell);

            ::main_instance.sell_vehicles.AddList(helicopters_to_sell);
            ::main_instance.SendVehicleToSellToDepot();
        }

        foreach(airport_2, d2 in station_list_2) {
            //AILog.Warning("AircraftManager::CheckRoutes Checking route between " + AIStation.GetName(airport) + " and " + AIStation.GetName(airport_2));

            if (airport == airport_2) continue;

            local own_planes = this._GetRoutePlanes(airport, airport_2, false, false);

            if (own_planes.Count() > AIController.GetSetting("max_own_planes_per_route")) {
                AILog.Warning("AircraftManager::CheckRoutes There are larger amount of own planes on the route from " + AIStation.GetName(airport) + " to " + AIStation.GetName(airport_2));

                local planes_to_sell = AIList()
                planes_to_sell.AddList(own_planes)

                planes_to_sell.KeepBottom(planes_to_sell.Count() - AIController.GetSetting("max_own_planes_per_route"));

                ::main_instance.sell_vehicles.AddList(planes_to_sell);
                ::main_instance.SendVehicleToSellToDepot();
            }

            local unprofitable_route_planes = AIList();

            //AILog.Warning("AircraftManager::CheckRoutes The plane route between " + AIStation.GetName(airport) + " and " + AIStation.GetName(airport_2) + " has " + own_planes.Count() + " planes");
            unprofitable_route_planes.AddList(own_planes);
            unprofitable_route_planes.KeepList(unprofitable_planes);

            if (unprofitable_route_planes.Count() > 0) {
                AILog.Warning("AircraftManager::CheckRoutes The plane route between " + AIStation.GetName(airport) + " and " + AIStation.GetName(airport_2) + " has some unprofitable planes. Disabling building new planes here for awhile");
                this._unprofitable_plane_routes.rawset(airport + "," + airport_2, AIDate.GetCurrentDate());
            }

            local own_helicopters = this._GetRoutePlanes(airport, airport_2, false, true);
            if (own_helicopters.Count() > AIController.GetSetting("max_own_planes_per_route")) {
                AILog.Warning("AircraftManager::CheckRoutes There are larger amount of own helicopters on the route from " + AIStation.GetName(airport) + " to " + AIStation.GetName(airport_2));

                local planes_to_sell = AIList()
                planes_to_sell.AddList(own_helicopters)

                planes_to_sell.KeepBottom(planes_to_sell.Count() - AIController.GetSetting("max_own_planes_per_route"));

                ::main_instance.sell_vehicles.AddList(planes_to_sell);
                ::main_instance.SendVehicleToSellToDepot();
            }

            local unprofitable_helicopter_planes = AIList();
            unprofitable_helicopter_planes.AddList(own_helicopters);
            unprofitable_helicopter_planes.KeepList(unprofitable_planes);

            if (unprofitable_route_planes.Count() > 0) {
                AILog.Warning("AircraftManager::CheckRoutes The helicopter route between " + AIStation.GetName(airport) + " and " + AIStation.GetName(airport_2) + " has some unprofitable planes. Disabling building new planes here for awhile");
                this._unprofitable_helicopter_routes.rawset(airport + "," + airport_2, AIDate.GetCurrentDate());
            }
        }
	}

    AILog.Warning("Selling " + unprofitable_planes.Count() + " unprofittable planes");
    ::main_instance.sell_vehicles.AddList(unprofitable_planes);
    ::main_instance.SendVehicleToSellToDepot();

    return false;
}

function AircraftManager::_TownValuator(town_id) {
    return AIBase.RandRange(AITown.GetPopulation(town_id));
}

function AircraftManager::_StationTownValuator(station_id) {
    return AIBase.RandRange(AITown.GetPopulation(AIStation.GetNearestTown(station_id)));
}

function AircraftManager::CanBuildPlanes(station_id, is_helicopter_route)
{
    //AILog.Info("AircraftManager::CanBuildPlanes Checking if can build planes in airport " + station_id + ":" + AIStation.GetName(station_id));

    if (!is_helicopter_route && Utils_Airport.IsHeliport(station_id)) {
        //AILog.Info(AIStation.GetName(station_id) + " is a heliport and we are not building a helicopter route");
        return false;
    }

	local max_planes = this._GetMaxAircraftsForAirport(station_id, is_helicopter_route);

	local list = AIVehicleList_Station.GetAllVehicles(station_id);
    list.Valuate(AIVehicle.GetVehicleType);
    list.KeepValue(AIVehicle.VT_AIR);

    Utils_Valuator.Valuate(list, this._GetVehiclePlaneType)
    if (is_helicopter_route) {
        list.KeepValue(AIAirport.PT_HELICOPTER);
    } else {
        list.RemoveValue(AIAirport.PT_HELICOPTER);
    }

    //AILog.Info("AircraftManager::CanBuildPlanes Found " + list.Count() + " " + (is_helicopter_route ? "helicopters" : "planese") + " in airport " + station_id + ":" + AIStation.GetName(station_id) + ". Max planes that can be built here: " + max_planes)

	return list.Count() + 2 <= max_planes;
}

function AircraftManager::BuildPlanes(station_a, station_b, is_helicopter_route) {
    local is_heliport = Utils_Airport.IsHeliport(station_a) || Utils_Airport.IsHeliport(station_b);
    if (is_heliport && !is_helicopter_route) {
        //AILog.Info("One of the airports is heliport and we aren't building a Helicopter route");
        return false;
    }

    local small_airport = Utils_Airport.IsSmallAirport(station_a) || Utils_Airport.IsSmallAirport(station_b);
	local engineId = is_helicopter_route
        ? this._helicopter_engine_id
        : ((small_airport || this._engine_id == null) ? this._small_engine_id : this._engine_id);

	if (engineId == null) return false;

    /* Make sure we have enough money to buy two planes. */
    /* TODO: there is no check if enough money is available, so possible
     * we can't even buy one plane if they are really expensive. */

    local neededMoney = 2 * AIEngine.GetPrice(engineId);
    //AILog.Info("Trying to get amount of money: " + neededMoney);
    Utils_General.GetMoney(neededMoney);

    local success = true;
    /* Build the first plane at the first airport. */
    //AILog.Info ("Building a plane from " + AIStation.GetName(station_a) + " to " + AIStation.GetName(station_b));
    if (!Utils_Airport.HasHangars(station_a)) {
        //AILog.Info(AIStation.GetName(station_a) + " is heliport");
        return false;
    }

    local v = AIVehicle.BuildVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_a)), engineId);
    if (!AIVehicle.IsValidVehicle(v)) {
        AILog.Error("Building plane failed: " + AIError.GetLastErrorString());

        success = false;
    }

    if (success) {
        //AILog.Info ("Successfully built a plane from " + AIStation.GetName(station_a) + " to " + AIStation.GetName(station_b));

        /* Add the vehicle to the right group. */
        local groupId = AIEngine.GetPlaneType(engineId) == AIAirport.PT_HELICOPTER
            ? this._helicopters_group
            : AIEngine.GetPlaneType(engineId) == AIAirport.PT_BIG_PLANE ? this._big_engine_group : this._small_engine_group;

        AIGroup.MoveVehicle(groupId, v);
        /* Add the orders to the vehicle. */
        AIOrder.AppendOrder(v, AIStation.GetLocation(station_a), AIOrder.AIOF_NONE);
        AIOrder.AppendOrder(v, AIStation.GetLocation(station_b), AIOrder.AIOF_NONE);
        AIVehicle.StartStopVehicle(v);
    }

    if (!Utils_Airport.HasHangars(station_b)) {
        //AILog.Info(AIStation.GetName(station_b) + " is heliport");
        return true;
    }

    //AILog.Info ("Building a plane from " + AIStation.GetName(station_b) + " to " + AIStation.GetName(station_a));

    /* Clone the first plane, but build it at the second airport. */
    v = AIVehicle.CloneVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_b)), v, false);
    if (!AIVehicle.IsValidVehicle(v)) {
        AILog.Warning("Cloning plane failed: " + AIError.GetLastErrorString());
        /* Since the first plane was build succesfully, return true. */
        return success;
    }

    //AILog.Info ("Successfully built a plane from " + AIStation.GetName(station_b) + " to " + AIStation.GetName(station_a));

    /* Add the vehicle to the right group. */
    local groupId = AIEngine.GetPlaneType(engineId) == AIAirport.PT_HELICOPTER
        ? this._helicopters_group
        : AIEngine.GetPlaneType(engineId) == AIAirport.PT_BIG_PLANE ? this._big_engine_group : this._small_engine_group;

    AIGroup.MoveVehicle(groupId, v);
    /* Start with going to the second airport. */
    AIOrder.SkipToOrder(v, 1);
    AIVehicle.StartStopVehicle(v);

    return true;
}

function AircraftManager::BuildNewRoute(is_helicopter_route) {
    /* First update the type of vehicle we will build. */

    //AILog.Info("AircraftManager::BuildNewRoute Building a " + (is_helicopter_route ? "heliport" : "plane") + " route");

    //AILog.Info("AircraftManager::BuildNewRoute  Getting all airports");
	local station_list_1 = AIStationList.GetAllStations(AIStation.STATION_AIRPORT);

    Utils_Valuator.Valuate(station_list_1, this._StationTownValuator);
    station_list_1.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

	//AILog.Info("AircraftManager::BuildNewRoute Found " + station_list_1.Count() + " airports.");

    local station_list_2 = AIList();
    station_list_2.AddList(station_list_1);

	//AILog.Info("AircraftManager::BuildNewRoute  Got airports");

    /* Check if we can add planes to some already existing airports. */
    foreach(station_a, d in station_list_1) {
		//AILog.Info("AircraftManager::BuildNewRoute  Station from: " + AIStation.GetName(station_a));

		if (AIAirport.IsHangarTile(AIStation.GetLocation(station_a))) {
				AILog.Warning("AircraftManager::BuildNewRoute  Tile index returned for station " + AIStation.GetName(station_a) + " is hangar. Skipping it");
				continue;
		}

        local station_a_own_planes = this._GetAirportPlanes(station_a, false, is_helicopter_route);
        local station_a_max_planes = this._GetMaxAircraftsForAirport(station_a, is_helicopter_route) * AIController.GetSetting("max_own_airport_planes") / 100;
        if (station_a_own_planes.Count() + 2 > station_a_max_planes) {
            AILog.Info("We will have over the quota planes in " + AIStation.GetName(station_a));
            continue;
        }

        foreach(station_b, d in station_list_2) {
            if (station_a == station_b) continue;

			//AILog.Info("Station B " + AIStation.GetName(station_b));

			if (AIAirport.IsHangarTile(AIStation.GetLocation(station_b))) {
				AILog.Warning("AircraftManager::BuildNewRoute  Tile index returned for station " + AIStation.GetName(station_b) + " is hangar. Skipping it");
				continue;
			}

            local all_planes = this._GetRoutePlanes(station_a, station_b, true, is_helicopter_route);

            if (all_planes.Count() >= AIController.GetSetting("max_planes_per_route")) {
                //AILog.Info("There are enough planes on this route");
                continue;
            }

            local own_planes = this._GetRoutePlanes(station_a, station_b, false, is_helicopter_route);

            if (own_planes.Count() >= AIController.GetSetting("max_own_planes_per_route")) {
                //AILog.Info("There are enough my own planes on this route");
                continue;
            }

            local station_b_own_planes = this._GetAirportPlanes(station_b, false, is_helicopter_route);
            local station_b_max_planes = this._GetMaxAircraftsForAirport(station_b, is_helicopter_route) * AIController.GetSetting("max_own_airport_planes") / 100;
            if (station_b_own_planes.Count() + 2 > station_b_max_planes) {
                AILog.Info("We will have over the quota planes in " + AIStation.GetName(station_b));
                continue;
            }

            local unprofitable_key = station_a + "," + station_b;
            if (!is_helicopter_route && this._unprofitable_plane_routes.rawin(unprofitable_key)) {
                local when = this._unprofitable_plane_routes.rawget(unprofitable_key);
                if (AIDate.GetCurrentDate() - when <= 365 * AIController.GetSetting("ban_unprofitable_air_routes_years")) {
                    AILog.Warning("AircraftManager::BuildNewRoute The plane route between " + AIStation.GetName(station_a) + " and " + AIStation.GetName(station_b) + " was unprofitable. Skipping it.");
                    continue;
                } else {
                    AILog.Warning("AircraftManager::BuildNewRoute The plane route between " + AIStation.GetName(station_a) + " and " + AIStation.GetName(station_b) + " was unprofitable but it's expired. Will try to build planes there.");
                    this._unprofitable_plane_routes.rawdelete(unprofitable_key);
                }
            } else if (is_helicopter_route && this._unprofitable_helicopter_routes.rawin(unprofitable_key)) {
                local when = this._unprofitable_helicopter_routes.rawget(unprofitable_key);
                if (AIDate.GetCurrentDate() - when <= 365 * AIController.GetSetting("ban_unprofitable_air_routes_years")) {
                    AILog.Warning("AircraftManager::BuildNewRoute The helicopter route between " + AIStation.GetName(station_a) + " and " + AIStation.GetName(station_b) + " was unprofitable. Skipping it.");
                    continue;
                } else {
                    AILog.Warning("AircraftManager::BuildNewRoute The helicopter plane route between " + AIStation.GetName(station_a) + " and " + AIStation.GetName(station_b) + " was unprofitable but it's expired. Will try to build planes there.");
                    this._unprofitable_helicopter_routes.rawdelete(unprofitable_key);
                }
            }

            /* Check the distance between the towns. */
            local distance = AIMap.DistanceSquare(AIStation.GetLocation(station_a), AIStation.GetLocation(station_b));

            //AILog.Info("AircraftManager::BuildNewRoute Distance between " + AIStation.GetName(station_a) + " and " + AIStation.GetName(station_b) + " is " + distance);
            this._FindEngineID(distance); // Maybe we can upgrade the plane?

            if (!this.CanBuildPlanes(station_a, is_helicopter_route)) {
                //AILog.Info("Can't build planes from " + AIStation.GetName(station_a));
                continue;
            }

            if (!this.CanBuildPlanes(station_b, is_helicopter_route)) {
                //AILog.Info("Can't build planes from " + AIStation.GetName(station_b));
                continue;
            }

            if (distance < (is_helicopter_route ? 20*20 : 50*50)) {
                //AILog.Info("AircraftManager::BuildNewRoute Distance between " + AIStation.GetName(station_a) + " and " + AIStation.GetName(station_b) + " is too short");
                continue;
            }

            if (is_helicopter_route && distance > 100*100) {
                //AILog.Info("AircraftManager::BuildNewRoute Distance is too long for the heliport route");
                continue;
            }

			//AILog.Info("AircraftManager::BuildNewRoute  Building planes from " + AIStation.GetName(station_a) + " to " + AIStation.GetName(station_b));
            return this.BuildPlanes(station_a, station_b, is_helicopter_route);
        }
    }

    return false;
}

function AircraftManager::_GetRoutePlanes(station_a, station_b, all, is_helicopter) {
    local veh_in_a = all ? AIVehicleList_Station.GetAllVehicles(station_a) : AIVehicleList_Station(station_a);
    local veh_in_b = all ? AIVehicleList_Station.GetAllVehicles(station_b) : AIVehicleList_Station(station_b);

    veh_in_a.Valuate(AIVehicle.GetVehicleType);
    veh_in_a.KeepValue(AIVehicle.VT_AIR);
    veh_in_b.Valuate(AIVehicle.GetVehicleType);
    veh_in_b.KeepValue(AIVehicle.VT_AIR);

    Utils_Valuator.Valuate(veh_in_a, this._GetVehiclePlaneType);
    Utils_Valuator.Valuate(veh_in_b, this._GetVehiclePlaneType);
    if (is_helicopter) {
        veh_in_a.KeepValue(AIAirport.PT_HELICOPTER);
        veh_in_b.KeepValue(AIAirport.PT_HELICOPTER);
    } else {
        veh_in_a.RemoveValue(AIAirport.PT_HELICOPTER);
        veh_in_b.RemoveValue(AIAirport.PT_HELICOPTER);
    }

    veh_in_a.KeepList(veh_in_b);

    return veh_in_a;
}

function AircraftManager::_GetAirportPlanes(airport, all, is_helicopter) {
    local veh_list = all ? AIVehicleList_Station.GetAllVehicles(airport) : AIVehicleList_Station(airport);

    veh_list.Valuate(AIVehicle.GetVehicleType);
    veh_list.KeepValue(AIVehicle.VT_AIR);

    Utils_Valuator.Valuate(veh_list, this._GetVehiclePlaneType);
    if (is_helicopter) {
        veh_list.KeepValue(AIAirport.PT_HELICOPTER);
    } else {
        veh_list.RemoveValue(AIAirport.PT_HELICOPTER);
    }

    veh_list.KeepList(veh_list);

    return veh_list;
}

function AircraftManager::_GetMaxAircraftsForAirport(airport, is_helicopter) {
    return is_helicopter
        ? AIAirport.GetNumHelipads(AIStation.GetLocation(airport)) * AIController.GetSetting("heliport_helipad_multiplier")
        :  AIAirport.GetNumTerminals(AIStation.GetLocation(airport)) * AIController.GetSetting("airport_terminal_multiplier");
}

function AircraftManager::_SortEngineList(engine_id) {
	local runnigCost = AIEngine.GetRunningCost(engine_id);
    local speed = AIEngine.GetMaxSpeed(engine_id);
    local capacity = AIEngine.GetCapacity(engine_id);
    ////AILog.Info("AircraftManager::_SortEngineList :: " + AIEngine.GetName(engine_id) + ": Max speed is " + speed + ". Capacity is " + capacity + ". Running cost: " + runnigCost);

    if (AIEngine.GetPlaneType(engine_id) == AIAirport.PT_HELICOPTER) {
        ////AILog.Info("AircraftManager::_SortEngineList :: " + AIEngine.GetName(engine_id) + " is a helicopter. Max speed is " + speed + ". capacity is " + capacity);
        speed = speed * speed * speed;
    }

    if (AIEngine.GetPlaneType(engine_id) != AIAirport.PT_HELICOPTER) {
        capacity = capacity * capacity;
    }

    local result = capacity * speed / (runnigCost > 0 ? runnigCost / 10 : 1);
    ////AILog.Info("AircraftManager::_SortEngineList :: " + AIEngine.GetName(engine_id) + " result is " + result);

    return result;
}

function AircraftManager::_GetPlaneRange(engine_id) {
	local range = AIEngine.GetMaximumOrderDistance(engine_id);
    local result = range == 0 ? -1 : range;

    ////AILog.Info("Range for plane " + AIEngine.GetName(engine_id) + " is " + result);

    return result;
}

function AircraftManager::_GetVehiclePlaneType(vehicle_id) {
	local engine_id = AIVehicle.GetEngineType(vehicle_id);
    return AIEngine.GetPlaneType(engine_id);
}

function AircraftManager::_FindEngineID(min_distance) {
    local maxMoney = Utils_General.GetMaxMoney();
    /* First for helicopters. */
    local list = AIEngineList(AIVehicle.VT_AIR);
    /* Only helicopters. */
    list.Valuate(AIEngine.GetPlaneType);
    list.KeepValue(AIAirport.PT_HELICOPTER);

    Utils_Valuator.Valuate(list, this._GetPlaneRange);
	list.KeepAboveValue(min_distance);

    Utils_Valuator.Valuate(list, this._SortEngineList);
    list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

	list.Valuate(AIEngine.GetPrice);
	list.KeepBelowValue(maxMoney);
	list.KeepAboveValue(1);
	list.Valuate(AIEngine.GetCargoType);
	list.KeepValue(::main_instance._passenger_cargo_id);
	list.Valuate(AIEngine.GetCapacity);
	list.KeepAboveValue(15);
    local new_engine_id = null;
    if (list.Count() != 0) {
        new_engine_id = list.Begin();
        /* If both the old and the new id are valid and they are different,
         *  initiate autoreplace from the old to the new type. */
        if (this._helicopter_engine_id != null
			&& new_engine_id != null
			&& this._helicopter_engine_id != new_engine_id
            && AIEngine.GetMaximumOrderDistance(new_engine_id) > AIEngine.GetMaximumOrderDistance(this._helicopter_engine_id)
            && AIEngine.GetMaxSpeed(new_engine_id) > AIEngine.GetMaxSpeed(this._helicopter_engine_id)
			&& AIEngine.GetCapacity(new_engine_id) > AIEngine.GetCapacity(this._helicopter_engine_id)) {
            AIGroup.SetAutoReplace(this._helicopters_group, this._helicopter_engine_id, new_engine_id);
        }
    }

    this._helicopter_engine_id = new_engine_id;
	if (this._helicopter_engine_id != null)	{
		//AILog.Info("Helicopter engine selected: " + AIEngine.GetName(this._helicopter_engine_id));
	} else {
		//AILog.Info("Didn't find a new engine for helicopters");
	}

    /* Then small planes. */
    local list = AIEngineList(AIVehicle.VT_AIR);
    /* Only small planes allowed, no big planes or helicopters. */
    list.Valuate(AIEngine.GetPlaneType);
    list.KeepValue(AIAirport.PT_SMALL_PLANE);

    Utils_Valuator.Valuate(list, this._GetPlaneRange);
	list.KeepAboveValue(min_distance);

    Utils_Valuator.Valuate(list, this._SortEngineList);
    list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

	list.Valuate(AIEngine.GetPrice);
	list.KeepBelowValue(maxMoney);
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
            && AIEngine.GetMaximumOrderDistance(new_engine_id) > AIEngine.GetMaximumOrderDistance(this._small_engine_id)
			&& AIEngine.GetCapacity(new_engine_id) > AIEngine.GetCapacity(this._small_engine_id)) {
            AIGroup.SetAutoReplace(this._small_engine_group, this._small_engine_id, new_engine_id);
        }
    }

    this._small_engine_id = new_engine_id;
	if (this._small_engine_id != null)	{
		//AILog.Info("Small plane engine selected: " + AIEngine.GetName(this._small_engine_id));
	} else {
		//AILog.Info("Didn't find a new engine for small planes");
	}

    /* And also the EngineID for new big planes. */
    local list = AIEngineList(AIVehicle.VT_AIR);
	//AILog.Info("AircraftManager::_FindEngineID Found " + list.Count() + " engines");

    Utils_Valuator.Valuate(list, this._GetPlaneRange);
	list.KeepAboveValue(min_distance);

    Utils_Valuator.Valuate(list, this._SortEngineList);
    list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);


    list.Valuate(AIEngine.GetPlaneType);
    list.RemoveValue(AIAirport.PT_HELICOPTER);
	list.Valuate(AIEngine.GetPrice);
	list.KeepBelowValue(maxMoney);
	list.KeepAboveValue(1);
	list.Valuate(AIEngine.GetCargoType);
	list.KeepValue(::main_instance._passenger_cargo_id);
	list.Valuate(AIEngine.GetCapacity);
	list.KeepAboveValue(50);

	//AILog.Info("AircraftManager::_FindEngineID Filtered to " + list.Count() + " engines");

    if (list.Count() != 0) {
        new_engine_id = list.Begin();
        /* If both the old and the new id are valid and they are different,
         *  initiate autoreplace from the old to the new type. */
        if (this._engine_id != null
			&& new_engine_id != null
			&& this._engine_id != new_engine_id
            && AIEngine.GetMaximumOrderDistance(new_engine_id) > AIEngine.GetMaximumOrderDistance(this._engine_id)
			&& AIEngine.GetCapacity(new_engine_id) > AIEngine.GetCapacity(this._engine_id)) {
            AIGroup.SetAutoReplace(this._big_engine_group, this._engine_id, new_engine_id);
        }
    }
    this._engine_id = new_engine_id;
	if (this._engine_id != null)	{
		//AILog.Info("Big plane engine selected: " + AIEngine.GetName(this._engine_id));
	} else {
		//AILog.Info("Didn't find an engine for big planes");
	}

}