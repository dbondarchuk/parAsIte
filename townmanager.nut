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
	_airports = null;            ///< An array of all airports build in this town.

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
		this._airport_failed_date = 0;
		this._airports = [];
	}

	/**
	 * Get the TileIndex from a road depot within this town. Build a depot if needed.
	 * @param station_manager The StationManager of the station we want a depot near.
	 * @return The TileIndex of a road depot tile within the town.
	 */
	function GetDepot(station_manager);

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
	 * Improve the town rating in this town by building trees.
	 * @param min_rating The minimum required rating.
	 * @return Whether or not the rating could be improved enough.
	 */
	function ImproveTownRating(min_rating);

/* private: */

	/**
	 * Is it possible to route some more planes to this station.
	 * @param station_id The StationID of the station to check.
	 * @return Whether or not some more planes can be routes to this station.
	 */
	function CanBuildPlanes(station_id);

	/**
	 * Get the maximum number of airports for this town.
	 * @return The maximum number of airports.
	 */
	function MaxAirports();

	/**
	 * Check all airports in this town to see if there is one we can
	 *  route more planes to.
	 * @param allow_small_airport True if a small airport is acceptable.
	 * @return The StationID of the airport of null if none was found.
	 */
	function GetExistingAirport(allow_small_airport);
};

function TownManager::CanBuildPlanes(station_id)
{
	local max_planes = 0;
	switch (AIAirport.GetAirportType(AIStation.GetLocation(station_id))) {
		case AIAirport.AT_SMALL:         max_planes =  4; break;
		case AIAirport.AT_LARGE:         max_planes =  6; break;
		case AIAirport.AT_METROPOLITAN:  max_planes = 10; break;
		case AIAirport.AT_INTERNATIONAL: max_planes = 16; break;
		case AIAirport.AT_COMMUTER:      max_planes =  8; break;
		case AIAirport.AT_INTERCON:      max_planes = 24; break;
		default: 
			AILog.Error("Unsupported airport type encountered");
			return 0;
	}
	local list = AIVehicleList_Station(station_id);
	if (list.Count() + 2 > max_planes) return false;
	list.Valuate(AIVehicle.GetAge);
	list.KeepBelowValue(200);
	return list.Count() == 0;
}

function TownManager::MaxAirports()
{
	return max(1, AITown.GetPopulation(this._town_id) / 2500);
}

function TownManager::GetExistingAirport(allow_small_airport)
{
	local station_list = AIStationList(AIStation.STATION_AIRPORT);
	station_list.Valuate(AIStation.GetNearestTown);
	station_list.KeepValue(this._town_id);

	foreach (airport in this._airports) {
		/* If there are zero or one planes going to the airport, we assume
		 * it can handle some more planes. */
		if (AIVehicleList_Station(airport).Count() <= 1 && (allow_small_airport || !Utils_Airport.IsSmallAirport(airport))) return airport;
		/* Skip the airport if it can't handle more planes. */
		if (!this.CanBuildPlanes(airport)) continue;
		/* If the airport is small and small airports are not ok, don't return it. */
		if (Utils_Airport.IsSmallAirport(airport) && !allow_small_airport) continue;
		/* Only return an airport if there are enough waiting passengers, ie the current
		 * number of planes can't handle it. */
		if (AIStation.GetCargoWaiting(airport, ::main_instance._passenger_cargo_id) > 500 ||
				(AIStation.GetCargoWaiting(airport, ::main_instance._passenger_cargo_id) > 250 && Utils_Airport.IsSmallAirport(airport)) ||
				AIStation.GetCargoRating(airport, ::main_instance._passenger_cargo_id) < 50) {
			return airport;
		}
	}
	return null;
}

function TownManager::ScanMap()
{
	local station_list = AIStationList(AIStation.STATION_BUS_STOP);
	station_list.Valuate(AIStation.GetNearestTown);
	station_list.KeepValue(this._town_id);

	foreach (station_id, dummy in station_list) {
		local vehicle_list = AIVehicleList_Station(station_id);
		vehicle_list.RemoveList(::main_instance.sell_vehicles);
		if (vehicle_list.Count() > 0) {
			this._used_stations.push(StationManager(station_id));
		} else {
			this._unused_stations.push(StationManager(station_id));
		}
	}

	local depot_list = AIDepotList(AITile.TRANSPORT_ROAD);
	depot_list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	depot_list.KeepValue(1);
	depot_list.Valuate(AIMap.DistanceManhattan, AITown.GetLocation(this._town_id));
	depot_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
	foreach (tile, dis in depot_list) {
		if (!this._depot_tiles.rawin(AIRoad.ROADTYPE_ROAD) && AIRoad.HasRoadType(tile, AIRoad.ROADTYPE_ROAD)) {
			this._depot_tiles.rawset(AIRoad.ROADTYPE_ROAD, tile);
		}
		if (!this._depot_tiles.rawin(AIRoad.ROADTYPE_TRAM) && AIRoad.HasRoadType(tile, AIRoad.ROADTYPE_TRAM)) {
			this._depot_tiles.rawset(AIRoad.ROADTYPE_TRAM, tile);
		}
	}
}

function TownManager::ImproveTownRating(min_rating)
{
	/* Check whether the current rating is good enough. */
	local rating = AITown.GetRating(this._town_id, AICompany.COMPANY_SELF);
	if (rating == AITown.TOWN_RATING_NONE || rating >= min_rating) return true;

	/* Build trees to improve the rating. We build this tree in an expanding
	 * circle starting around the town center. */
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
		/* Check whether the current rating is good enough. */
		if (AITown.GetRating(this._town_id, AICompany.COMPANY_SELF) >= min_rating) return true;
	}

	/* It was not possible to improve the rating to the requested value. */
	return false;
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

function TownManager::GetDepot(station_manager)
{
	if (!this._depot_tiles.rawin(AIRoad.GetCurrentRoadType())) {
		local stationtiles = AITileList_StationType(station_manager.GetStationID(), AIStation.STATION_BUS_STOP);
		stationtiles.Valuate(AIRoad.GetRoadStationFrontTile);
		this._depot_tiles.rawset(AIRoad.GetCurrentRoadType(), ParAsIte.BuildDepot(stationtiles.GetValue(stationtiles.Begin())));
	}
	return this._depot_tiles.rawget(AIRoad.GetCurrentRoadType());
}

function TownManager::CanGetStation()
{
	if (this._unused_stations.len() > 0) return true;
	local rating = AITown.GetRating(this._town_id, AICompany.COMPANY_SELF);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) return false;
	if (AIDate.GetCurrentDate() - this._station_failed_date < 60) return false;
	if (max(1, AITown.GetPopulation(this._town_id) / 300) > this._used_stations.len()) return true;
	return false;
}

function TownManager::CanBuildDrivethroughStop(tile)
{
	local test = AITestMode();

	if (AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(0, 1)) || AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(0, -1))) {
		if (AIRoad.BuildDriveThroughRoadStation(tile, tile + AIMap.GetTileIndex(0, 1), AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) return tile + AIMap.GetTileIndex(0, 1);
	} else if (AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(1, 0)) || AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(-1, 0))) {
		if (AIRoad.BuildDriveThroughRoadStation(tile, tile + AIMap.GetTileIndex(1, 0), AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) return tile + AIMap.GetTileIndex(1, 0);
	}
	return 0;
}

function TownManager::SupportNormalStop(road_type)
{
	if (road_type == AIRoad.ROADTYPE_ROAD) return true;
	return false;
}

function TownManager::GetNeighbourRoadCount(tile)
{
	local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
	local num = 0;
	foreach (offset in offsets) {
		if (AIRoad.IsRoadTile(tile + offset)) num++;
	}
	return num;
}

function TownManager::GetStation(force_dtrs)
{
	local town_center = AITown.GetLocation(this._town_id);
	if (this._unused_stations.len() > 0) return this._unused_stations[0];
	/* We need to build a new station. */
	local rating = AITown.GetRating(this._town_id, AICompany.COMPANY_SELF);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) {
		AILog.Warning("Town rating: " + rating);
		AILog.Warning("Town rating is bad, not going to try building a station in " + AITown.GetName(this._town_id));
		return null;
	}

	local list = AITileList();
	local radius = 10;
	local population = AITown.GetPopulation(this._town_id);
	if (population > 10000) radius += 5;
	if (population > 15000) radius += 5;
	if (population > 25000) radius += 5;
	if (population > 35000) radius += 5;
	if (population > 45000) radius += 5;
	Utils_Tile.AddSquare(list, town_center, radius);
	list.Valuate(AITile.GetMaxHeight);
	list.KeepAboveValue(0);
	list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	list.KeepValue(1);
	foreach (station in this._used_stations) {
		local station_id = station.GetStationID();
		list.Valuate(AIMap.DistanceSquare, AIStation.GetLocation(station_id));
		list.KeepAboveValue(35);
	}
	list.Valuate(AITile.GetCargoAcceptance, ::main_instance._passenger_cargo_id, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
	list.KeepAboveValue(25);
	list.Valuate(TownManager.GetNeighbourRoadCount);
	list.KeepAboveValue(0);

	if (force_dtrs || AIController.GetSetting("build_bus_dtrs") || !this.SupportNormalStop(AIRoad.GetCurrentRoadType())) {
		/* First try to build a drivethough road stop. */
		local drivethrough_list = AIList();
		drivethrough_list.AddList(list);
		drivethrough_list.KeepBelowValue(3);
		drivethrough_list.Valuate(Utils_Town.TileOnTownLayout, this._town_id, true);
		drivethrough_list.KeepValue(1);
		drivethrough_list.Valuate(AIMap.DistanceManhattan, town_center);
		drivethrough_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
		foreach (tile, d in drivethrough_list) {
			local front_tile = TownManager.CanBuildDrivethroughStop(tile);
			if (front_tile <= 0) continue;
			local back_tile = tile + (tile - front_tile);
			if (!(AIRoad.AreRoadTilesConnected(front_tile, tile) && AIRoad.AreRoadTilesConnected(tile, back_tile))) {
				if (!AIRoad.BuildRoad(front_tile, back_tile)) continue;
			}
			if (RouteFinder.FindRouteBetweenRects(front_tile, back_tile, 0, [tile]) == null) {
				local forbidden_tiles = [tile];
				if (abs(tile - front_tile) == 1) {
					if (!AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(0, 1))) forbidden_tiles.append(tile + AIMap.GetTileIndex(0, 1));
					if (!AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(0, -1))) forbidden_tiles.append(tile + AIMap.GetTileIndex(0, -1));
				} else {
					if (!AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(1, 0))) forbidden_tiles.append(tile + AIMap.GetTileIndex(1, 0));
					if (!AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(-1, 0))) forbidden_tiles.append(tile + AIMap.GetTileIndex(-1, 0));
				}
				if (RouteBuilder.BuildRoadRoute(RPF([this._town_id]), [front_tile], [back_tile], 1, 20, forbidden_tiles) != 0) {
					AILog.Warning("Front side could not be connected to back side");
					if (AIController.GetSetting("debug_signs")) AISign.BuildSign(tile, "!!!");
					continue;
				}
			}
			if (!AIRoad.BuildDriveThroughRoadStation(tile, front_tile, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) {
				AILog.Warning("Drivethrough stop could not be build");
				continue;
			}
			local manager = StationManager(AIStation.GetStationID(tile));
			this._unused_stations.push(manager);
			return manager;
		}
	}

	if (!this.SupportNormalStop(AIRoad.GetCurrentRoadType()) || force_dtrs) return null;

	/* No drivethrough station could be build, so try a normal station. */
	rating = AITown.GetRating(this._town_id, AICompany.COMPANY_SELF);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) return null;
	list.Valuate(AIRoad.IsRoadTile);
	list.KeepValue(0);
	list.Valuate(Utils_Town.TileOnTownLayout, this._town_id, false);
	list.KeepValue(0);
	list.Valuate(AIMap.DistanceManhattan, town_center);
	list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
	foreach (t, dis in list) {
		if (AICompany.IsMine(AITile.GetOwner(t))) continue;
		local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
		                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
		foreach (offset in offsets) {
			if (!AIRoad.IsRoadTile(t + offset)) continue;
			if (!Utils_Tile.IsNearlyFlatTile(t + offset)) continue;
			if (AITile.GetMaxHeight(t) != AITile.GetMaxHeight(t + offset)) continue;
			if (RouteFinder.FindRouteBetweenRects(t + offset, AITown.GetLocation(this._town_id), 0) == null) continue;
			if (!AITile.IsBuildable(t) && !AITile.DemolishTile(t)) continue;
			{
				local testmode = AITestMode();
				if (!AIRoad.BuildRoad(t, t + offset)) continue;
				if (!AIRoad.BuildRoadStation(t, t + offset, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) continue;
			}
			if (!AIRoad.BuildRoad(t, t + offset)) continue;
			if (!AIRoad.BuildRoadStation(t, t + offset, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) continue;
			local manager = StationManager(AIStation.GetStationID(t));
			this._unused_stations.push(manager);
			return manager;
		}
	}
	this._station_failed_date = AIDate.GetCurrentDate();
	AILog.Error("no staton build in " + AITown.GetName(this._town_id));
	return null;
}
