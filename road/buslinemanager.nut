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

/** @file buslinemanager.nut Implemenation of BusLineManager. */

/**
 * Class that manages all bus routes.
 */
class BusLineManager
{
	_routes = null;                      ///< An array containing all BusLines we manage.
	_max_distance_existing_route = null; ///< The maximum distance between industries where we'll still check if they are alerady connected.
	_max_distance_new_line = null;
	_skip_from = null;                   ///< Skip this amount of source towns in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_to = null;                     ///< Skip this amount of target towns in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_last_search_finished = null;

/* public: */

	/**
	 * Creaet a new bus line manager.
	 */
	constructor()
	{
		this._routes = [];
		this._max_distance_existing_route = 250;
		this._skip_from = 0;
		this._skip_to = 0;
		this._max_distance_new_line = 60;
		this._last_search_finished = 0;
	}

	/**
	 * Try to build a new passenger route using mostly existing road.
	 * @return True if and only if a new route was found.
	 */
	function NewLineExistingRoad();

	/**
	 * Check all build routes to see if they have the correct amount of busses.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckRoutes();

/* private: */

	/**
	 * Try to find two towns that are already connected by road.
	 * @param num_routes_to_check The number of connection to try before returning.
	 * @return True if and only if a new route was created.
	 * @note The function may search less routes in case a new route was
	 *  created or the end of the list was reached. Even if the end of the
	 *  list of possible routes is reached, you can safely call the function
	 *  again, as it will start over with a greater range.
	 */
	function _NewLineExistingRoadGenerator(num_routes_to_check);
};

function BusLineManager::Save()
{
	local data = {};
	return data;
}

function BusLineManager::Load(data)
{
}

function BusLineManager::AfterLoad()
{
	local vehicle_list = AIVehicleList();
	vehicle_list.Valuate(AIVehicle.GetVehicleType);
	vehicle_list.KeepValue(AIVehicle.VT_ROAD);
	vehicle_list.Valuate(AIVehicle.GetCapacity, ::main_instance._passenger_cargo_id);
	vehicle_list.KeepAboveValue(0);
	local st_from = {};
	local st_to = {};
	foreach (v, dummy in vehicle_list) {
		if (AIOrder.GetOrderCount(v) != 3) {
			AILog.Info("Selling vehicle " + v + " due to wrong order count.");
			::main_instance.sell_vehicles.AddItem(v, 0);
			continue;
		}
		if (AIRoad.IsRoadDepotTileOfType(AIOrder.GetOrderDestination(v, 0), AIRoad.ROADTRAMTYPES_ROAD)) AIOrder.MoveOrder(v, 0, 2);
		if (!AIRoad.IsRoadStationTileOfType(AIOrder.GetOrderDestination(v, 0), AIRoad.ROADTRAMTYPES_ROAD) ||
				!AIRoad.IsRoadStationTileOfType(AIOrder.GetOrderDestination(v, 1), AIRoad.ROADTRAMTYPES_ROAD) ||
				!AIRoad.IsRoadDepotTileOfType(AIOrder.GetOrderDestination(v, 2), AIRoad.ROADTRAMTYPES_ROAD)) {
			AILog.Info("Selling vehicle " + v + " due to wrong order.");
			::main_instance.sell_vehicles.AddItem(v, 0);
			continue;
		}
		local station_a = AIStation.GetStationID(AIOrder.GetOrderDestination(v, 0));
		local station_b = AIStation.GetStationID(AIOrder.GetOrderDestination(v, 1));
		if (st_from.rawin(station_a)) {
			if (station_b == st_from.rawget(station_a).GetStationTo().GetStationID()) {
				/* Add the vehicle to both bus station a and b. */
				local station_from = st_from.rawget(station_a).GetStationFrom();
				local station_to = st_from.rawget(station_a).GetStationTo();
				station_from.AddBusses(1, AIMap.DistanceManhattan(AIStation.GetLocation(station_from.GetStationID()), AIStation.GetLocation(station_to.GetStationID())), AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v)));
				station_to.AddBusses(1, AIMap.DistanceManhattan(AIStation.GetLocation(station_from.GetStationID()), AIStation.GetLocation(station_to.GetStationID())), AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v)));
			} else {
				AILog.Info("Selling vehicle " + v + " due to stations 1.");
				::main_instance.sell_vehicles.AddItem(v, 0);
				continue;
			}
		} else {
			/* New BusLine from station_a to station_b. */
			local station_manager_a = StationManager(station_a);
			local station_manager_b = StationManager(station_b);
			local depot_list = AIDepotList.GetAllDepots(AITile.TRANSPORT_ROAD);
			depot_list.Valuate(AIMap.DistanceManhattan, AIStation.GetLocation(station_a));
			depot_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
			local depot_tile = depot_list.Begin();
			//local articulated = station_manager_a.HasArticulatedBusStop() && station_manager_b.HasArticulatedBusStop();
			local articulated = false; // Don't want articulated buses
			local line = BusLine(station_manager_a, station_manager_b, depot_tile, ::main_instance._passenger_cargo_id, articulated);
			this._routes.push(line);
			st_from.rawset(station_a, line);
			st_to.rawset(station_b, null);
		}
	}

	foreach (town_id, manager in ::main_instance._town_managers) {
		manager.ScanMap();
	}

	foreach (route in this._routes) {
		route.InitiateAutoReplace();
	}
}


function BusLineManager::CheckRoutes()
{
	local need_money = false;
	foreach (route in this._routes) {
		if (route.CheckVehicles()) need_money = true;
	}
	return need_money;
}

function BusLineManager::ImproveLines()
{
	return;
	for (local i = 0; i < this._routes.len(); i++) {
		for (local j = i + 1; j < this._routes.len(); j++) {
			if (this._routes[i].GetDistance() < 100 && this._routes[j].GetDistance() < 100) {
				local st_from1 = this._routes[i].GetStationFrom();
				local st_from2 = this._routes[j].GetStationFrom();
				local st_to1 = this._routes[i].GetStationTo();
				local st_to2 = this._routes[j].GetStationTo();
				if (AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) < 200 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) < 200 &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID()), 1) != null &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID()), 1) != null) {
					this._routes[i].ChangeStationTo(st_from2);
					this._routes[j].ChangeStationFrom(st_to1);
					this._routes[i].RenameGroup();
					this._routes[j].RenameGroup();
				} else if (AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) < 200 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) < 200 &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID()), 1) != null &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID()), 1) != null) {
					this._routes[i].ChangeStationTo(st_to2);
					this._routes[j].ChangeStationTo(st_to1);
					this._routes[i].RenameGroup();
					this._routes[j].RenameGroup();
				}
			}
		}
	}
}

function BusLineManager::NewLineExistingRoad()
{
	//if (AIDate.GetCurrentDate() - this._last_search_finished < 10) return false;
	return this._NewLineExistingRoadGenerator(200);
}

function BusLineManager::_NewLineExistingRoadGenerator(num_routes_to_check)
{
	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	engine_list.Valuate(AIEngine.GetRoadTramType);
	engine_list.KeepValue(AIRoad.ROADTRAMTYPES_ROAD);
	engine_list.Valuate(AIEngine.CanRefitCargo, ::main_instance._passenger_cargo_id);
	engine_list.KeepValue(1);
	AILog.Info("Found " + engine_list.Count() + " engines.");
	if (engine_list.Count() == 0) return;

	engine_list.Valuate(AIEngine.IsArticulated);
	engine_list.KeepValue(0);
	local force_dtrs = engine_list.Count() == 0;

	local current_routes = -1;
	local town_from_skipped = 0, town_to_skipped = 0;
	local do_skip = true;
	local towns = [];
	foreach (town, dummy in ::main_instance._town_managers) {
		towns.push(town);
	}

	towns = Utils_Array.RandomReorder(towns)
	foreach (town in towns) {
		local manager = ::main_instance._town_managers[town];
		if (town_from_skipped < this._skip_from && do_skip) {
			town_from_skipped++;
			continue;
		}

		AILog.Info("Checking town " + AITown.GetName(town) + " for stops.");
		if (!manager.CanGetStation()) {
			AILog.Info("No stops were found in " + AITown.GetName(town));
			continue;
		}

		AILog.Info("Stop found.");

		local townlist = AITownList();
		townlist.Valuate(Utils_Valuator.ItemValuator);
		townlist.KeepAboveValue(town);
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
		townlist.KeepBetweenValue(50, this._max_distance_existing_route);
		townlist.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
		foreach (town_to, dummy in townlist) {
			if (town_to_skipped < this._skip_to && do_skip) {
				town_to_skipped++;
				continue;
			}
			
			do_skip = false;
			this._skip_to++;
			local manager2 = ::main_instance._town_managers[town_to];
			AILog.Info("  Checking second town " + AITown.GetName(town_to) + " for stops.");
			if (!manager2.CanGetStation()) {
				AILog.Info("  No stops were found in second town of " + AITown.GetName(town_to));
				continue;
			}

			AILog.Info("  Found stop in second town.");

			current_routes++;
			if (current_routes == num_routes_to_check) {
				AILog.Info("We maxed out retires for finding routes.")
				return false;
			}

			AILog.Info("Looking for a route between: " + AITown.GetName(town) + " and " + AITown.GetName(town_to));
			local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town), AITown.GetLocation(town_to), 3);
			if (route == null) {
				AILog.Info("No routes were found between: " + AITown.GetName(town) + " and " + AITown.GetName(town_to));	
				continue;
			}

			AILog.Info("Found passenger route between: " + AITown.GetName(town) + " and " + AITown.GetName(town_to));
			local maxOnStation = AIController.GetSetting("max_buses_per_station");
			AILog.Info("Max on station: " + maxOnStation);

			local station_from = manager.GetStation();
			if (station_from == null) {AILog.Warning("Couldn't get first station"); break;}

			local onFromStation = AIVehicleList_Station.GetAllVehicles(station_from.GetStationID()).Count();
			AILog.Info("On from station: " + onFromStation);
			if (onFromStation >= maxOnStation){
				AILog.Info("Enough vehicles on station " + AIStation.GetName(station_from.GetStationID()));
				break;
			}

			local station_to = manager2.GetStation();
			if (station_to == null) {AILog.Warning("Couldn't get second station"); continue; }
			local onToStation = AIVehicleList_Station.GetAllVehicles(station_to.GetStationID()).Count();
			
			AILog.Info("On to station: " + onToStation);
			if (onToStation >= maxOnStation){
				AILog.Info("Enough vehicles on station " + AIStation.GetName(station_to.GetStationID()));
				break;
			}
			AILog.Info("Route ok");
			manager.UseStation(station_from);
			::main_instance._town_managers.rawget(town_to).UseStation(station_to);
			local depot_tile = manager.GetDepot();
			if (depot_tile == null) depot_tile = ::main_instance._town_managers.rawget(town_to).GetDepot();
			if (depot_tile == null) break;
			//local articulated = station_from.HasArticulatedBusStop() && station_to.HasArticulatedBusStop();
			local articulated = false; // Don't want articulated buses

			local line = BusLine(station_from, station_to, depot_tile, ::main_instance._passenger_cargo_id, false, articulated);
			this._routes.push(line);
			this._skip_to = 0;
			return true;
		}

		this._skip_to = 0;
		this._skip_from++;
		do_skip = false;
	}

	foreach (town, manager in ::main_instance._town_managers) {
		AILog.Info("Scanning town " + AITown.GetName(town));
		manager.ScanMap();
	}

	AILog.Info("Full town search done!");
	this._max_distance_existing_route = min(300, this._max_distance_existing_route + 50);
	this._skip_to = 0;
	this._skip_from = 0;
	this._last_search_finished = AIDate.GetCurrentDate();
	return false;
}
