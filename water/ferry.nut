/* Ferries part of AI.
   Builds ferries/hovercrafts. */

require("water.nut");

class Ferry extends Water {
    /* Open new connections only in cities with this population. */
    min_population = 500;

    /* Passengers cargo id. */
    _passenger_cargo_id = -1;

    constructor(maintenance) {
        Water.constructor(maintenance);
        this._passenger_cargo_id = _GetPassengersCargoId();
    }
}

function Ferry::AreFerriesAllowed() {
    return AreShipsAllowed() && ship_model.ExistsForCargo(this._passenger_cargo_id);
}

/* Gets passengers cargo ID. */
function Ferry::_GetPassengersCargoId() {
    local cargo_list = AICargoList();
    cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
    cargo_list.KeepValue(1);
    cargo_list.Valuate(AICargo.GetTownEffect);
    cargo_list.KeepValue(AICargo.TE_PASSENGERS);
    return cargo_list.Begin();
}

/* Randomizes results so different instances of ShipAI don't approach same towns. */
function __val__GetPopulationRand(town_id) {
    return AITown.GetPopulation(town_id) + AIBase.RandRange(101) - 50;
}

function Ferry::GetTownsThatHavePassengerDockOrderedByPop() {
    local towns = AITownList();
    towns.Valuate(AITown.GetPopulation);
    towns.KeepAboveValue(this.min_population);

    local dock_capable = GetTownsThatHaveDock(this._passenger_cargo_id, towns);
    dock_capable.Valuate(__val__GetPopulationRand);
    dock_capable.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return dock_capable;
}

function Ferry::BuildFerryRoutes() {
    local ferries_built = 0;
    if(!this.AreFerriesAllowed())
        return 0;

    local min_capacity = ship_model.GetMinCapacityForCargo(this._passenger_cargo_id);
    if(min_capacity == -1)
        return 0;

    local towns = GetTownsThatHavePassengerDockOrderedByPop();

    for(local town_id = towns.Begin(); !towns.IsEnd(); town_id = towns.Next()) {

        this.maintenance.PerformIfNeeded();

        local town = Town(town_id);
        local dock1 = town.GetExistingDock(this._passenger_cargo_id);

        /* Monthly production is used to determine the potential ship size. */
        if(town.GetMonthlyProduction(this._passenger_cargo_id) <= min_capacity)
            continue;

        // If there is no a dock in a city or not enough passengers - skip it
        if(dock1 == null || dock1.GetCargoWaiting(this._passenger_cargo_id) < 2 * min_capacity) {
            continue;
        }

        /* Find a city suitable for connection closest to ours. */
        local towns2 = AIList();
        towns2.AddList(towns);
        towns2.RemoveItem(town_id);
        towns2.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town_id));
        towns2.KeepBelowValue(this.max_distance); /* Cities too far away. */
        towns2.KeepAboveValue(this.min_distance); /* Cities too close. */

        for(local town2_id = towns2.Begin(); !towns2.IsEnd(); town2_id = towns2.Next()) {
            local town2 = Town(town2_id);
            local dock2 = town2.GetExistingDock(this._passenger_cargo_id);

            // If there is no a dock in a city or not enough passengers - skip it
            if(dock2 == null || dock2.GetCargoWaiting(this._passenger_cargo_id) < 2 * min_capacity) {
                continue;
            }

            /* Buy and schedule ship. */
            if(BuildAndStartShip(dock1, dock2, this._passenger_cargo_id, false, town.GetMonthlyProduction(this._passenger_cargo_id))) {
                AILog.Info("Building ferry between " + town.GetName() + " and " + town2.GetName());
                ferries_built++;
            } else if(!AreFerriesAllowed())
                return ferries_built;
        }
    }

    return ferries_built;
}
