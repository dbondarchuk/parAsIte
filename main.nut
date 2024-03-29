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

/** @file main.nut Implementation of ParAsIte, containing the main loop. */

import("queue.fibonacci_heap", "FibonacciHeap", 2);

require("utils/airport.nut");
require("utils/array.nut");
require("utils/general.nut");
require("utils/tile.nut");
require("utils/town.nut");
require("utils/valuator.nut");

require("stationmanager.nut");
require("townmanager.nut");
require("aystar.nut");

require("network/point.nut");
require("network/graph.nut");

require("air/aircraftmanager.nut");

require("road/rpf.nut");
require("road/routebuilder.nut");
require("road/routefinder.nut");
require("road/roadline.nut");
require("road/busline.nut");
require("road/truckline.nut");
require("road/buslinemanager.nut");
require("road/trucklinemanager.nut");
require("road/roadnetwork.nut");

require("rail/railpathfinder.nut");
require("rail/railfollower.nut");
require("rail/trainmanager.nut");
require("rail/railroutebuilder.nut");
require("rail/trainline.nut");

require("water/ferry.nut");
require("water/freight.nut");
require("water/maintenance.nut");

/**
 * The main class of ParAsIte.
 */
class ParAsIte extends AIController {
    /* private: */

    _passenger_cargo_id = null; ///< The CargoID of the main passenger cargo.
    _town_managers = null; ///< A table mapping TownID to TownManager.
    _truck_manager = null; ///< The TruckLineManager managing all truck lines.
    _bus_manager = null; ///< The BusLineManager managing all bus lines.
    _aircraft_manager = null; ///< The AircraftManager managing all air routes.
    _train_manager = null; ///< The TrainManager managing all train routes.
    _freight = null; ///< The Freight managing all freight ship routes.
    _ferry = null; ///< The Ferry managing all ferry routes.
    _pending_events = null; ///< An array containing [EventType, value] pairs of unhandles events.
    _save_data = null; ///< Cache of save data during load.
    _save_version = null; ///< Cache of version the save data was saved with.
    last_vehicle_check = null; ///< The last date we checked whether some routes needed more/less vehicles.
    last_cash_output = null; ///< The last date we printed the date + current amount of cash to AILog.
    last_improve_buslines_date = null; ///< The last date we tried to improve our buslines.
    need_vehicle_check = null; ///< True if the last vehicle check was aborted due to not having enough money.
    sell_stations = null; ///< An array with [StationID, StationType] pairs of stations that need to be removed.
    sell_vehicles = null; ///< An AIList with as items VehicleIDs of vehicles we are going to sell.
    _sorted_cargo_list = null; ///< An AIList with the best cargo to transport as first item.
    _sorted_cargo_list_updated = null; ///< The last date we renewed _sorted_cargo_list.
    station_table = null; ///< A table mapping StationID to StationManager.

    /* public: */

    constructor() {
        ::main_instance <- this;

        /* Introduce a constant for sorting AILists here, it may be in the api later.
         * This needs to be done here, before any instance of it is made. */
        //AIAbstractList.SORT_ASCENDING <- true;
        //AIAbstractList.SORT_DESCENDING <- false;

        this._save_data = null;
        this._save_version = null;

        /* Most of the initialization is done in Init, but we set some variables
         * here so we can save them without checking for null. */
        this._pending_events = [];
        this.sell_stations = [];
    }

    /**
     * Initialize all 'global' variables. Since there is a limit on the time the constructor
     * can take we don't do this in the constructor.
     */
    function Init() {
        this._passenger_cargo_id = Utils_General.GetPassengerCargoID();

        this._town_managers = {};
        local town_list = AITownList();
        foreach(town_id, dummy in town_list) {
            this._town_managers.rawset(town_id, TownManager(town_id));
        }

        this._truck_manager = TruckLineManager();
        this._bus_manager = BusLineManager();
        this._aircraft_manager = AircraftManager();
        this._train_manager = TrainManager();

        local maintenance = Maintenance();
        this._freight = Freight(maintenance);
        this._ferry = Ferry(maintenance);

        this.last_vehicle_check = 0;
        this.last_cash_output = AIDate.GetCurrentDate();
        this.last_improve_buslines_date = 0;
        this.need_vehicle_check = false;
        this.sell_vehicles = AIList();
        this._sorted_cargo_list = null;
        this._sorted_cargo_list_updated = 0;
        this.station_table = {};
    }

    /**
     * Get the StationManager for a certain station. If there is no
     * StationManager yet for that station, create one.
     * @param station_id The StationID to get the StationManager for.
     * @return The StationManager for the station.
     */
    function GetStationManager(station_id);

    /**
     * Get an AIList with all CargoIDs sorted by profitability.
     * @return An AIList with all valid CargoIDs.
     */
    function GetSortedCargoList();

    /**
     * Save all data we need to be able to resume later.
     * @return A table containing all data that needs to be saved.
     * @note This is called by OpenTTD, no need to call from within the AI.
     */
    function Save();

    /**
     * Store the savegame data we get.
     * @param version The version of this AI that was used to save the game.
     * @param data The data that was stored by Save().
     * @note This is called by OpenTTD, no need to call from within the AI.
     */
    function Load(version, data);

    /**
     * Use the savegame data to reconstruct as much state as possible.
     */
    function CallLoad();

    /**
     * Get all events from AIEventController and store them in an
     *   in an internal array.
     */
    function GetEvents();

    /**
     * Try to find a connected depot in the neighbourhood of a tile.
     * @param roadtile The tile to start searching.
     * @return Either a TileIndex of a depot or null.
     */
    static function ScanForDepot(roadtile);

    /**
     * Handle all pending events. Events are stored internal in the _pending_events
     *  array as [AIEventType, value] pair. The value that is saved depends on the
     *  events. For example, for AI_ET_INDUSTRY_CLOSE the IndustryID is saved in value.
     */
    function HandleEvents();

    /**
     * Try to send all vehicles that will be sold off to a depot. If this fails try
     *   to turn a vehicles and then send it again to a depot.
     */
    function SendVehicleToSellToDepot();

    /**
     * Message all VehicleManagers that some cargo is transported from
     * some industry. This is to make sure we don't create both a truck
     * and a train line for the same cargo.
     * @param cargo The transported CargoID.
     * @param ind The IndustryID of the source industry.
     */
    function TransportCargo(cargo, ind);

    /**
     * Are we allowed to use a given VehicleType? This functions checks
     * several settings:
     * 1. Is the vehicle disabled via the global AI settings.
     * 2. Is the use of this type disabled via the AI specific options.
     * 3. Are more than 0 units of this type allowed.
     * @param vehicle_type The VehicleType to check.
     * @return True if we can use this vehicle type.
     */
    static function UseVehicleType(vehicle_type);

    /**
     * Check if there is at least one supported vehicle type available.
     * @return True iff there is at least one vehicle type available.
     */
    static function SomeVehicleTypeAvailable();

    /**
     * Do some general maintenance. This happens in several steps:
     * 1. All events are handled (@see HandleEvents).
     * 2. All vehicles that will be sold are sent do a depot.
     * 3. Every 90 days the current loan/bank amount is logged.
     * 4. Every 200 days the buslines are improved (@see BusLine::ImproveLines).
     * 5. Every 11 days all routes are checked whether they need more/less vehicles.
     * 6. All stations that should be sold are sold now.
     */
    function DoMaintenance();

    /**
     * Build the company headquarters if they haven't been build yet.
     */
    function BuildHQ();

    /**
     * The mainloop.
     * @note This is called by OpenTTD, no need to call from within the AI.
     */
    function Start();

    /* private: */

    /**
     * Valuator for cargos. It returns the profit over a certain distance
     * multiplied by a random value between 1 and 1,2.
     * @param cargo_id The cargo to get the profit of.
     * @return The profit for the given cargo.
     */
    static function CargoValuator(cargo_id);
};

function ParAsIte::BuildHQ() {
    if (AICompany.GetCompanyHQ(AICompany.COMPANY_SELF) != AIMap.TILE_INVALID) return;
	local town_list = AITownList();
	town_list.Valuate(AIBase.RandItem);
	local town = town_list.Begin();

    local tilelist = Utils_Town.GetTilesAroundTown(town, 1, 1);
    tilelist.Valuate(AIBase.RandItem);
    foreach(tile, dummy in tilelist) {
        if (AICompany.BuildCompanyHQ(tile)) {
            AILog.Info("Built company headquarters near " + AITown.GetName(town));
            return true;
        }
    }

    return false;
}

function ParAsIte::GetStationManager(station_id) {
    assert(AIStation.IsValidStation(station_id));

    if (!this.station_table.rawin(station_id)) {
        this.station_table.rawset(station_id, StationManager(station_id));
    }
    return this.station_table.rawget(station_id);
}

/* static */
function ParAsIte::CargoValuator(cargo_id) {
    local val = AICargo.GetCargoIncome(cargo_id, 80, 40);
    return val + (AIBase.RandRange(val) / 3);
}

function ParAsIte::GetSortedCargoList() {
    if (AIDate.GetCurrentDate() - this._sorted_cargo_list_updated > 200) {
        this._sorted_cargo_list = AICargoList();
        this._sorted_cargo_list.Valuate(ParAsIte.CargoValuator);
        this._sorted_cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
    }
    return this._sorted_cargo_list;
}

function ParAsIte::GetMaxCargoPercentTransported(town_id) {
    return 60;
}

function ParAsIte::Save() {
    if (this._save_data != null) {
        this._save_data.rawset("version", this._save_version);
        return this._save_data;
    }

    /* All checks for != null below are needed because it's possible that Save()
     * is called before we call Init() (from Start()). */
    local data = {};
    if (this.sell_vehicles != null) {
        local to_sell = [];
        foreach(veh, dummy in this.sell_vehicles) {
            to_sell.push(veh);
        }
        data.rawset("vehicles_to_sell", to_sell);
    }
    data.rawset("stations_to_sell", this.sell_stations);
    if (this._truck_manager != null) data.rawset("trucklinemanager", this._truck_manager.Save());
    if (this._bus_manager != null) data.rawset("buslinemanager", this._bus_manager.Save());
    if (this._train_manager != null) data.rawset("trainmanager", this._train_manager.Save());

    this.GetEvents();
    data.rawset("pending_events", this._pending_events);

    return data;
}

function ParAsIte::Load(version, data) {
    this._save_data = data;
    this._save_version = version;
    if (data.rawin("version")) this._save_version = data.rawget("version").tointeger();
}

function ParAsIte::CallLoad() {
    if (this._save_data == null) return;

    AILog.Info("Loading savegame saved with ParAsIte " + this._save_version);

    if (this._save_data.rawin("vehicles_to_sell")) {
        foreach(v in this._save_data.rawget("vehicles_to_sell")) {
            if (AIVehicle.IsValidVehicle(v)) this.sell_vehicles.AddItem(v, 0);
        }
    }

    if (this._save_data.rawin("stations_to_sell")) {
        this.sell_stations = this._save_data.rawget("stations_to_sell");
    }

    if (this._save_data.rawin("trucklinemanager")) {
        this._truck_manager.Load(this._save_data.rawget("trucklinemanager"));
    }

    if (this._save_data.rawin("buslinemanager")) {
        this._bus_manager.Load(this._save_data.rawget("buslinemanager"));
    }

    if (this._save_data.rawin("trainmanager")) {
        this._train_manager.Load(this._save_data.rawget("trainmanager"));
    }

    if (this._save_data.rawin("pending_events")) {
        this._pending_events = this._save_data.rawget("pending_events");
    }
}

function ParAsIte::GetEvents() {
    while (AIEventController.IsEventWaiting()) {
        local e = AIEventController.GetNextEvent();
        switch (e.GetEventType()) {
            case AIEvent.AI_ET_INDUSTRY_CLOSE:
                local ind = AIEventIndustryClose.Convert(e).GetIndustryID();
                this._pending_events.push([AIEvent.AI_ET_INDUSTRY_CLOSE, ind]);
                break;

            case AIEvent.AI_ET_INDUSTRY_OPEN:
                local ind = AIEventIndustryOpen.Convert(e).GetIndustryID();
                this._pending_events.push([AIEvent.AI_ET_INDUSTRY_OPEN, ind]);
                break;
        }
    }
}

/* static */
function ParAsIte::ScanForDepot(roadtile) {
    local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
        AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)
    ];
    local tile_to_try = [roadtile];
    local tried = AIList();
    while (tile_to_try.len() > 0) {
        local cur_tile;
        cur_tile = tile_to_try[0];
        tile_to_try.remove(0);
        tried.AddItem(cur_tile, 0);
        foreach(offset in offsets) {
            if (AIRoad.AreRoadTilesConnectedByRoadTramType(cur_tile, cur_tile + offset, AIRoad.ROADTRAMTYPES_ROAD)) {
                if (AIRoad.IsRoadDepotTile(cur_tile + offset) && AICompany.IsMine(AITile.GetOwner(cur_tile + offset))) return cur_tile + offset;
                if (!tried.HasItem(cur_tile + offset)) tile_to_try.push(cur_tile + offset);
                continue;
            }
        }
        if (AIMap.DistanceManhattan(roadtile, cur_tile) > 10) return null;
    }
    return null;
}

function ParAsIte::HandleEvents() {
    foreach(event_pair in this._pending_events) {
        switch (event_pair[0]) {
            case AIEvent.AI_ET_INDUSTRY_CLOSE:
                this._truck_manager.IndustryClose(event_pair[1]);
                this._train_manager.IndustryClose(event_pair[1]);
                break;

            case AIEvent.AI_ET_INDUSTRY_OPEN:
                this._truck_manager.IndustryOpen(event_pair[1]);
                this._train_manager.IndustryOpen(event_pair[1]);
                break;
        }
    }
    this._pending_events = [];
}

function ParAsIte::SendVehicleToSellToDepot() {
    this.sell_vehicles.Valuate(AIVehicle.IsValidVehicle);
    this.sell_vehicles.KeepValue(1);
    foreach(vehicle, dummy in this.sell_vehicles) {
        if (AIVehicle.SellVehicle(vehicle)) continue;
        if (AIVehicle.GetVehicleType(vehicle) != AIVehicle.VT_RAIL && !AIOrder.IsGotoDepotOrder(vehicle, AIOrder.ORDER_CURRENT)) {
            if (!AIVehicle.SendVehicleToDepot(vehicle)) {
                AIVehicle.ReverseVehicle(vehicle);
                AIController.Sleep(50);
                AIVehicle.SendVehicleToDepot(vehicle);
            }
        }
    }
    /* Remove all sold vehicles. */
    this.sell_vehicles.Valuate(AIVehicle.IsValidVehicle);
    this.sell_vehicles.KeepValue(1);
}

function ParAsIte::TransportCargo(cargo, ind) {
    ::main_instance._truck_manager.TransportCargo(cargo, ind);::main_instance._train_manager.TransportCargo(cargo, ind);
}

/* static */
function ParAsIte::UseVehicleType(vehicle_type) {
    switch (vehicle_type) {
        case "planes":
            return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR) && AIController.GetSetting("use_planes") && AIGameSettings.GetValue("vehicle.max_aircraft") > 0;
        case "trains":
            return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_RAIL) && AIController.GetSetting("use_trains") && AIGameSettings.GetValue("vehicle.max_trains") > 0;
        case "trucks":
            return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD) && AIController.GetSetting("use_trucks") && AIGameSettings.GetValue("vehicle.max_roadveh") > 0;
        case "busses":
            return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD) && AIController.GetSetting("use_busses") && AIGameSettings.GetValue("vehicle.max_roadveh") > 0;
        case "ships":
            return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_WATER) && AIController.GetSetting("use_ships") && AIGameSettings.GetValue("vehicle.max_ships") > 0;
    }
}

/* static */
function ParAsIte::SomeVehicleTypeAvailable() {
    return ParAsIte.UseVehicleType("planes") || ParAsIte.UseVehicleType("trains") ||
        ParAsIte.UseVehicleType("trucks") || ParAsIte.UseVehicleType("busses");
    /* TODO: add ships here as soon as support for them is implemented. */
}

function ParAsIte::DoMaintenance() {
    this.GetEvents();
    this.HandleEvents();
    this.SendVehicleToSellToDepot();
    if (AIDate.GetCurrentDate() - this.last_cash_output > 90) {
        local curdate = AIDate.GetCurrentDate();
        AILog.Info("Current date: " + AIDate.GetYear(curdate) + "-" + AIDate.GetMonth(curdate) + "-" + AIDate.GetDayOfMonth(curdate));
        AILog.Info("Cash - loan: " + AICompany.GetBankBalance(AICompany.COMPANY_SELF) + " - " + AICompany.GetLoanAmount());
        this.last_cash_output = AIDate.GetCurrentDate();
    }
    Utils_General.GetMoney(200000);
    if (AIDate.GetCurrentDate() - this.last_improve_buslines_date > 200) {
        this._bus_manager.ImproveLines();
        this.last_improve_buslines_date = AIDate.GetCurrentDate();
    }
    Utils_General.GetMoney(200000);
    if (AIDate.GetCurrentDate() - this.last_vehicle_check > 90 || this.need_vehicle_check) {
        local ret1 = this._bus_manager.CheckRoutes();
        local ret2 = this._truck_manager.CheckRoutes();
        local ret3 = this._train_manager.CheckRoutes();
        local ret4 = this._aircraft_manager.CheckRoutes();
        this._freight.maintenance.PerformIfNeeded();
        this._ferry.maintenance.PerformIfNeeded();
        this.last_vehicle_check = AIDate.GetCurrentDate();
        this.need_vehicle_check = ret1 || ret2 || ret3 || ret4;
    }
    local removed = [];
    foreach(idx, pair in this.sell_stations) {
        local veh_list = AIVehicleList_Station(pair[0]);
        veh_list.Valuate(AIVehicle.GetVehicleType);
        switch (pair[1]) {
            case AIStation.STATION_TRAIN:
                veh_list.KeepValue(AIVehicle.VT_RAIL);
                break;

            case AIStation.STATION_TRUCK_STOP:
                veh_list.KeepValue(AIVehicle.VT_ROAD);
                break;

            case AIStation.STATION_BUS_STOP:
                veh_list.KeepValue(AIVehicle.VT_ROAD);
                break;

            case AIStation.STATION_AIRPORT:
                veh_list.KeepValue(AIVehicle.VT_AIR);
                break;

            case AIStation.STATION_DOCK:
                veh_list.KeepValue(AIVehicle.VT_WATER);
                break;

            default:
                assert(false);
        }
        if (!veh_list.IsEmpty()) continue;
        local tiles = AITileList_StationType(pair[0], pair[1]);
        foreach(tile, dummy in tiles) {
            AITile.DemolishTile(tile);
        }
        if (!AIStation.IsValidStation(pair[0])) {
            removed.append(idx);
            this.station_table.rawdelete(pair[0]);
        }
    }
    for (local i = removed.len() - 1; i >= 0; i--) {
        this.sell_stations.remove(removed[i]);
    }
}

function ParAsIte::SetCompanyName() {
    local company_name_suffixes = ["Transport", "International", "and co.", "Ltd.", "Global Transport"];

    /* Create a bitmap of all vehicle types we can use. */
    local vehicle_types = 0;
    if (ParAsIte.UseVehicleType("planes")) vehicle_types = vehicle_types | (1 << AIVehicle.VT_AIR);
    if (ParAsIte.UseVehicleType("trains")) vehicle_types = vehicle_types | (1 << AIVehicle.VT_RAIL);
    if (ParAsIte.UseVehicleType("trucks")) vehicle_types = vehicle_types | (1 << AIVehicle.VT_ROAD);
    if (ParAsIte.UseVehicleType("busses")) vehicle_types = vehicle_types | (1 << AIVehicle.VT_ROAD);
    if (ParAsIte.UseVehicleType("ships")) vehicle_types = vehicle_types | (1 << AIVehicle.VT_WATER);

    /* A few special names if we can only use 1 vehicle type. */
    switch (vehicle_types) {
        case (1 << AIVehicle.VT_AIR):
            company_name_suffixes = ["Airlines", "Airways"];
            break;

        case (1 << AIVehicle.VT_RAIL):
            company_name_suffixes = ["Rails", "Railways"];
            break;

        case (1 << AIVehicle.VT_WATER):
            company_name_suffixes = ["Shipping"];
            break;
    }
    local prefix = "ParAsIte ";
    Utils_General.SetCompanyName(prefix, Utils_Array.RandomReorder(company_name_suffixes));
}

function ParAsIte::Start() {
    /* Check if the names of some settings are valid. Of course this isn't
     * completely failsafe, as the meaning could be changed but not the name,
     * but it'll catch some problems. */
    Utils_General.CheckSettings(["vehicle.max_roadveh", "vehicle.max_aircraft", "vehicle.max_trains", "vehicle.max_ships",
        "difficulty.vehicle_breakdowns", "construction.build_on_slopes", "station.modified_catchment", "vehicle.wagon_speed_limits"
    ]);
    /* Call our real constructor here to prevent 'is taking too long to load' errors. */
    this.Init();

    /* All vehicle groups are deleted when starting and recreated in all Load/AfterLoad
     * functions. This is done so we don't have so save the GroupIDs and can
     * easier load savegames saved by other AIs that use a different group
     * structure. */
    local group_list = AIGroupList();
    foreach(group, dummy in group_list) {
        AIGroup.DeleteGroup(group);
    }

    /* Use the savegame data (if any) to reconstruct as much state as possible. */
    this.CallLoad();
    if (!this.SomeVehicleTypeAvailable()) {
        AILog.Error("No supported vehicle type is available.");
        AILog.Error("Quitting.");
        return;
    }
    local start_tick = AIController.GetTick();

    if (AICompany.GetName(AICompany.COMPANY_SELF).find("ParAsIte") == null) {
        this.SetCompanyName();
        AILog.Info(AICompany.GetName(AICompany.COMPANY_SELF) + " has just started!");
    }

    AIGroup.EnableWagonRemoval(true);

    if (AIGameSettings.GetValue("difficulty.vehicle_breakdowns") >= 1 || AIController.GetSetting("always_autorenew")) {
        AILog.Info("Breakdowns are on or the setting always_autorenew is on, so enabling autorenew");
        AICompany.SetAutoRenewMonths(-3);
        AICompany.SetAutoRenewStatus(true);
    } else {
        AILog.Info("Breakdowns are off, so disabling autorenew");
        AICompany.SetAutoRenewStatus(false);
    }

    this._bus_manager.AfterLoad();
    this._truck_manager.AfterLoad();
    this._aircraft_manager.AfterLoad();

    //this._train_manager.AfterLoad();
    this._save_data = null;
    AILog.Info("Loading done");

    local build_busses = false;
    local build_road_route = 3;
    local last_type = AIRoad.ROADTYPE_ROAD;
    AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);

	ParAsIte.BuildHQ();

    local iter = 0;
    while (1) {
        this.DoMaintenance();

        /* To speed-up the path finding, we search for the more complicated paths rarely. */
        if(iter % 11 == 5) {
            this._freight.max_parts = 2;
            this._ferry.max_parts = 2;
        } else if(iter % 11 == 10) {
            this._freight.max_parts = 3;
            this._ferry.max_parts = 3;
        } else {
            this._freight.max_parts = 1;
            this._ferry.max_parts = 1;
        }

        // if (this.need_vehicle_check) {
        // 	AIController.Sleep(20);
        // 	continue;
        // }
        last_type = last_type == AIRoad.ROADTYPE_ROAD ? AIRoad.ROADTYPE_TRAM : AIRoad.ROADTYPE_ROAD;
        if (AIRoad.IsRoadTypeAvailable(last_type)) AIRoad.SetCurrentRoadType(last_type);
        local build_route = false;
        Utils_General.GetMoney(200000);
        if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) >= 20000) {
            AILog.Info("Enough money to build aircraft. Building it.");
            local veh_list = AIVehicleList();
            veh_list.Valuate(AIVehicle.GetVehicleType);
            veh_list.KeepValue(AIVehicle.VT_AIR);
            AILog.Info("MAIN:: Total planes found: " + veh_list.Count());
            if (this.UseVehicleType("planes") && AIGameSettings.GetValue("vehicle.max_aircraft") > veh_list.Count()) {
                AILog.Info("MAIN:: Total planes found: " + veh_list.Count());
                AILog.Info("MAIN:: AIR Trying to build a new route");
                try {
                    build_route = this._aircraft_manager.BuildNewRoute(false);
                } catch(e) {
                    AILog.Error("Failed to build aircraft: " + e);
                }
                if (!build_route) {
                    AILog.Info("Failed to build plane route. Will try to build Helicopter route");
                    try {
                        build_route = this._aircraft_manager.BuildNewRoute(true);
                    } catch(e) {
                        AILog.Error("Failed to build helicopter: " + e);
                    }
                }
                Utils_General.GetMoney(200000);
                AILog.Info("Build air route: " + build_route);
            }
            // veh_list = AIVehicleList();
            // veh_list.Valuate(AIVehicle.GetVehicleType);
            // veh_list.KeepValue(AIVehicle.VT_RAIL);
            // if (this.UseVehicleType("trains") && AIGameSettings.GetValue("vehicle.max_trains") * 0.9 > veh_list.Count()) {
            // 	build_route = this._train_manager.BuildNewRoute() || build_route;
            // }
            build_road_route = 3;
        } // else if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) >= 180000) {
        // 	local veh_list = AIVehicleList();
        // 	veh_list.Valuate(AIVehicle.GetVehicleType);
        // 	veh_list.KeepValue(AIVehicle.VT_RAIL);
        // 	local new_train_route = this.UseVehicleType("trains") && AIGameSettings.GetValue("vehicle.max_trains") * 0.9 > veh_list.Count();
        // 	local veh_list = AIVehicleList();
        // 	veh_list.Valuate(AIVehicle.GetVehicleType);
        // 	veh_list.KeepValue(AIVehicle.VT_AIR);
        // 	if (this.UseVehicleType("planes") && AIGameSettings.GetValue("vehicle.max_aircraft") > veh_list.Count()) {
        // 		if (new_train_route && AIBase.RandRange(2) == 0) {
        // 			build_route = this._train_manager.BuildNewRoute();
        // 		} else {
        // 			build_route = this._aircraft_manager.BuildNewRoute();
        // 		}
        // 	} else if (new_train_route) {
        // 		build_route = this._train_manager.BuildNewRoute();
        // 	}
        // 	build_road_route = 3;
        // }

        Utils_General.GetMoney(200000);
        local veh_list = AIVehicleList();
        veh_list.Valuate(AIVehicle.GetVehicleType);
        veh_list.KeepValue(AIVehicle.VT_ROAD);
        if (!build_route && build_road_route > 0 && AIGameSettings.GetValue("vehicle.max_roadveh") * 0.9 > veh_list.Count()) {
            if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) >= 30000) {
                if (build_busses) {
                    if (this.UseVehicleType("busses")) build_route = this._bus_manager.NewLineExistingRoad();
                    if (this.UseVehicleType("trucks") && !build_route) build_route = this._truck_manager.NewLineExistingRoad();
                } else {
                    if (this.UseVehicleType("trucks")) build_route = this._truck_manager.NewLineExistingRoad();
                    if (this.UseVehicleType("busses") && !build_route) build_route = this._bus_manager.NewLineExistingRoad();
                }
            }

            // By commenting the next line out ParAsIte will first build truck routes before it starts on bus routes.
            build_busses = !build_busses;
            if (build_route) build_road_route--;
        }

        Utils_General.GetMoney(200000);
        local new_freights = _freight.BuildIndustryFreightRoutes();
        new_freights += _freight.BuildTownFreightRoutes();
        local new_ferries = _ferry.BuildFerryRoutes();

        Utils_General.GetMoney(200000);
        if (AIController.GetSetting("plant_trees")) {
        	if (AICompany.GetLoanAmount() == 0 && AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 200000) {
        		local town_list = AITownList();
        		town_list.Valuate(AIBase.RandItem);
				local town = town_list.Begin();

				AILog.Info("Enough money to plant some trees around " + AITown.GetName(town));
        		this._town_managers[town].PlantTrees();
        	}
        }
        Utils_General.GetMoney(200000);
        if (AIController.GetSetting("buy_companies")) {
        	if (AICompany.GetLoanAmount() == 0 && AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 200000) {
                for(local companyId = AICompany.COMPANY_FIRST; companyId <= AICompany.COMPANY_LAST; companyId++) {
                    local resolvedId = AICompany.ResolveCompanyID(companyId);
                    if (resolvedId == AICompany.COMPANY_INVALID || AICompany.IsMine(resolvedId) || !AICompany.IsAICompany(resolvedId)) continue;

                    local name = AICompany.GetName(resolvedId);
                    AILog.Info("Trying to buy shares in company " + name);

                    local result = AICompany.BuyShareInCompany(resolvedId);
                    AILog.Info("Bought shares in company " + name + ": " + result);

                    if (result) break;
                }
        	}
        }
        // Utils_General.GetMoney(200000);

        iter++;
        AIController.Sleep(20);
    }
};