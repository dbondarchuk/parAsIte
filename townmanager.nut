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

/** @file townmanager.nut Implementation of TownManager. */

/**
 * Class that manages building multiple bus stations in a town.
 */
class TownManager
{
	_town_id = null;             ///< The TownID this TownManager is managing.
	_unused_stations = null;     ///< An array with all StationManagers of unused stations within this town.
	_used_stations = null;       ///< An array with all StationManagers of in use stations within this town.
	_depot_tiles = null;         ///< A mapping of road types to tileindexes with a depot.
	_station_failed_date = null; ///< Don't try to build a new station within 60 days of failing to build one.

/* public: */

	/**
	 * Create a new TownManager.
	 * @param town_id The TownID this TownManager is going to manage.
	 */
	constructor(town_id) {
		this._town_id = town_id;
		this._unused_stations = [];
		this._used_stations = [];
		this._depot_tiles = {};
		this._station_failed_date = 0;
	}

	/**
	 * Get the TileIndex from a road depot within this town. Build a depot if needed.
	 * @return The TileIndex of a road depot tile within the town.
	 */
	function GetDepot();

	/**
	 * Is it possible to build an extra bus stop in this town?
	 * @return True if and only if an extra bus stop can be build.
	 */
	function CanGetStation();

	/**
	 * Build a new bus stop in the neighbourhood of a given tile.
	 * @param force_dtrs The bus stop needs to be a drive-through stop.
	 * @return The StationManager of the newly build station or null if no
	 *  station could be build.
	 */
	function GetStation(force_dtrs);

	/**
	 * Plant trees around the town
	 */
	function PlantTrees();
};

function TownManager::ScanMap()
{
	local station_list = AIStationList.GetAllStations(AIStation.STATION_BUS_STOP);
	station_list.Valuate(AIStation.GetNearestTown);
	station_list.KeepValue(this._town_id);

	foreach (station_id, dummy in station_list) {
		local vehicle_list = AIVehicleList_Station(station_id);
		vehicle_list.RemoveList(::main_instance.sell_vehicles);
		if (vehicle_list.Count() > 0) {
			AILog.Info("Found " + vehicle_list.Count() + " vehicles at station " + station_id);
			this._used_stations.push(StationManager(station_id));
		} else {
			AILog.Info("Adding new unused station at " + station_id);
			this._unused_stations.push(StationManager(station_id));
		}
	}

	local depot_list = AIDepotList.GetAllDepots(AITile.TRANSPORT_ROAD);
	depot_list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	depot_list.KeepValue(1);
	depot_list.Valuate(AIMap.DistanceManhattan, AITown.GetLocation(this._town_id));
	depot_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
	this._depot_tiles = {};

	foreach (tile, dis in depot_list) {
		AILog.Info("Found depot at tile " + tile);

		if (!AIDepotList.CanBuiltInDepot(tile)) {
			AILog.Info("Can't build in depot at " + tile);	
			continue;
		}
		if (!this._depot_tiles.rawin(AIRoad.ROADTRAMTYPES_ROAD) && AIRoad.HasAnyRoadTypeRoad(tile)) {
			AILog.Info("Adding road depot at " + tile);
			this._depot_tiles.rawset(AIRoad.ROADTRAMTYPES_ROAD, tile);
		}
		if (!this._depot_tiles.rawin(AIRoad.ROADTRAMTYPES_TRAM) && AIRoad.HasAnyRoadTypeTram(tile)) {
			AILog.Info("Adding tram depot at " + tile);
			this._depot_tiles.rawset(AIRoad.ROADTRAMTYPES_TRAM, tile);
		}
	}
}

function TownManager::PlantTrees()
{
	/* Build trees. We build this tree in an expanding circle starting around the town center. */
	local location = AITown.GetLocation(this._town_id);
	for (local size = 3; size <= 10; size++) {
		local list = AITileList();
		Utils_Tile.AddSquare(list, location, size);
		list.Valuate(AITile.IsBuildable);
		list.KeepValue(1);
		/* Don't build trees on tiles that already have trees, as this doesn't
		 * give any town rating improvement. */
		list.Valuate(AITile.HasTreeOnTile);
		list.KeepValue(0);
		foreach (tile, dummy in list) {
			AITile.PlantTree(tile);
		}
	}
}

function TownManager::UseStation(station)
{
	foreach (idx, st in this._unused_stations)
	{
		if (st == station) {
			this._unused_stations.remove(idx);
			this._used_stations.push(station);
			return;
		}
	}
	throw("Trying to use a station that doesn't belong to this town!");
}

function TownManager::GetDepot()
{
	if (this._depot_tiles.rawin(AIRoad.ROADTRAMTYPES_ROAD)) {
		AILog.Info("Getting depot at " + this._depot_tiles.rawget(AIRoad.ROADTRAMTYPES_ROAD));
		return this._depot_tiles.rawget(AIRoad.ROADTRAMTYPES_ROAD);
	}

	return null;
}

function TownManager::CanGetStation()
{
	return this._unused_stations.len() > 0;
}

function TownManager::GetNeighbourRoadCount(tile)
{
	local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
	local num = 0;
	foreach (offset in offsets) {
		if (AIRoad.IsRoadTileOfType(tile + offset, AIRoad.ROADTRAMTYPES_ROAD)) num++;
	}
	return num;
}

function TownManager::GetStation()
{
	local town_center = AITown.GetLocation(this._town_id);
	if (this._unused_stations.len() > 0) return this._unused_stations[0];
	return null;
}
