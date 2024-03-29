/* Freight ships. */

require("water.nut");

class Freight extends Water {
    /* Less this percent of the cargo transported to open a new route. */
    percent_to_open_new_route = 61;

    constructor(maintenance) {
        Water.constructor(maintenance);
    }
}

function Freight::GetIndustriesThatHaveDock(industries) {
    /* Randomize, to process industries in random order. */
    industries.Valuate(AIBase.RandItem);
    industries.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

    /* To avoid exceeding CPU limit in Valuator, we split the list in parts */
    local merged = AIList();
    local start_time = AIDate.GetCurrentDate();
    for(local i=0; i<industries.Count(); i+=50) {
        local chunk = AIList();
        chunk.AddList(industries);
        chunk.RemoveTop(i);
        chunk.KeepTop(50);
        chunk.Valuate(_val_IndustryHasDock, true);
        chunk.RemoveValue(0);
        merged.AddList(chunk);

        /* On big maps this can take forever, we stop after 6 months. */
        if(AIDate.GetCurrentDate() - start_time > 180)
            break;
    }

    /* Randomize, so that each instance of ShipAI on the map targets a different industry */
    merged.Valuate(AIBase.RandItem);
    merged.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

    return merged;
}

function Freight::GetCargoProducersThatHaveDock(cargo) {
    local producers = AIIndustryList_CargoProducing(cargo);
    producers.Valuate(AIIndustry.GetLastMonthProduction, cargo);
    producers.KeepAboveValue(0); /* production more than 0. */
    producers.Valuate(AIIndustry.GetLastMonthTransportedPercentage, cargo);
    producers.KeepBelowValue(this.percent_to_open_new_route); /* Less than 60% of cargo transported. */
    return GetIndustriesThatHaveDock(producers);
}

function Freight::BuildTownFreightRoutes() {
    local ships_built = 0;
    if(!AreShipsAllowed())
        return ships_built;

    local cargos = AICargoList();
    cargos.Valuate(AICargo.IsFreight);
    cargos.KeepValue(1); /* Only freight cargo. */
    cargos.Valuate(AICargo.GetTownEffect);
    cargos.RemoveValue(AICargo.TE_NONE); /* Only cargos that are accepted by towns. */
    cargos.Valuate(AICargo.GetCargoIncome, 150, 100);
    cargos.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING); /* Sort by payment rates. */

    for(local cargo = cargos.Begin(); !cargos.IsEnd(); cargo = cargos.Next()) {

        local min_capacity = ship_model.GetMinCapacityForCargo(cargo);
        /* There is no vehicle to transport this cargo. */
        if(min_capacity == -1)
            continue;

        local producers = GetCargoProducersThatHaveDock(cargo);
        local acceptors = GetTownsThatHaveDock(cargo);

        for(local producer_id = producers.Begin(); !producers.IsEnd(); producer_id = producers.Next()) {

            this.maintenance.PerformIfNeeded();

            /* Industry may cease to exist. */
            if(!AIIndustry.IsValidIndustry(producer_id))
                continue;

            local close_acceptors = AIList();
            close_acceptors.AddList(acceptors);
            close_acceptors.Valuate(AITown.GetDistanceManhattanToTile, AIIndustry.GetLocation(producer_id));
            close_acceptors.KeepBelowValue(this.max_distance); /* Cities too far away. */
            close_acceptors.KeepAboveValue(this.min_distance); /* Cities too close. */
            close_acceptors.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
            if(close_acceptors.IsEmpty())
                continue;

            local producer = Industry(producer_id, true);

            /* Monthly production is used to determine the potential ship size. */
            if(producer.GetMonthlyProduction(cargo) <= 0)
                continue;

            local dock1 = producer.GetExistingDock();

            /* If there is already a dock serving the producer but there is not much cargo waiting,
               there is no point in opening a new route. */
            if(dock1 == null || (dock1.HadOperatedCargo(cargo) &&
               dock1.GetCargoWaiting(cargo) < 2 * min_capacity))
                continue;

            /* No coast, let's check artificial ports locations. */
            local producer_artificial_ports = [];

            for(local acceptor_id = close_acceptors.Begin(); !close_acceptors.IsEnd(); acceptor_id = close_acceptors.Next()) {

                /* Let's get more info about the starting dock. */
                if(dock1 == null || (dock1.is_landdock && !dock1.IsValidStation())) {
                    /* No coast nearby for producer, take the possible artificial dock location instead. */
                    local min_dist = 99999999;
                    foreach(port in producer_artificial_ports) {
                        local dist = AITown.GetDistanceManhattanToTile(acceptor_id, port.tile);
                        if(dist != -1 && dist < min_dist) {
                            min_dist = dist;
                            dock1 = port;
                        }
                    }
                }

                if(dock1 == null) {
                    AILog.Warning(producer.GetName() + " can no longer have the dock built nearby");
                    break;
                }

                local acceptor = Town(acceptor_id);
                local dock2 = acceptor.GetExistingDock(cargo);
                if(dock2 == null) {
                    continue;
                }


                if(BuildAndStartShip(dock1, dock2, cargo, true, producer.GetMonthlyProduction(cargo))) {
                    AILog.Info("Building " + AICargo.GetCargoLabel(cargo) + " ship between " + producer.GetName() + " and " + acceptor.GetName());
                    ships_built++;
                    break;
                } else if(!AreShipsAllowed())
                    return ships_built;
            }
        }
    }

    return ships_built;
}

function Freight::BuildIndustryFreightRoutes() {
    local ships_built = 0;
    if(!AreShipsAllowed())
        return ships_built;

    local cargos = AICargoList();
    cargos.Valuate(AICargo.IsFreight);
    cargos.KeepValue(1); /* Only freight cargo. */
    cargos.Valuate(AICargo.GetTownEffect);
    cargos.KeepValue(AICargo.TE_NONE); /* Only cargos that are accepted by other industries. */
    cargos.Valuate(AICargo.GetCargoIncome, 150, 100);
    cargos.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING); /* Sort by payment rates. */

    for(local cargo = cargos.Begin(); !cargos.IsEnd(); cargo = cargos.Next()) {

        local min_capacity = ship_model.GetMinCapacityForCargo(cargo);
        /* There is no vehicle to transport this cargo. */
        if(min_capacity == -1)
            continue;

        local producers = GetCargoProducersThatHaveDock(cargo);
        local acceptors = GetIndustriesThatHaveDock(AIIndustryList_CargoAccepting(cargo));

        for(local producer_id = producers.Begin(); !producers.IsEnd(); producer_id = producers.Next()) {

            this.maintenance.PerformIfNeeded();

            /* Industry may cease to exist. */
            if(!AIIndustry.IsValidIndustry(producer_id))
                continue;

            local producer = Industry(producer_id, true);

            /* Monthly production is used to determine the potential ship size. */
            if(producer.GetMonthlyProduction(cargo) <= 0)
                continue;

            local dock1 = producer.GetExistingDock();

            if(dock1 == null || (dock1.HadOperatedCargo(cargo) &&
               dock1.GetCargoWaiting(cargo) < 2 * min_capacity))
                continue;

            /* Find the closest acceptors. */
            local close_acceptors = AIList()
            close_acceptors.AddList(acceptors); /* No clone method... */
            close_acceptors.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(producer.id));
            close_acceptors.KeepBelowValue(this.max_distance);
            close_acceptors.KeepAboveValue(this.min_distance);
            close_acceptors.Valuate(_val_IndustryHasDock, false);
            close_acceptors.RemoveValue(0);
            close_acceptors.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

            for(local acceptor_id = close_acceptors.Begin(); !close_acceptors.IsEnd(); acceptor_id = close_acceptors.Next()) {

                /* Industries may get closed. */
                if(!AIIndustry.IsValidIndustry(acceptor_id))
                    continue;

                /* For symmetric cargo. */
                if(acceptor_id == producer_id)
                    continue;

                local acceptor = Industry(acceptor_id, false);

                local dock2 = acceptor.GetExistingDock();

                /* No dock */
                if(dock2 == null) {
                    return
                }

                if(BuildAndStartShip(dock1, dock2, cargo, true, producer.GetMonthlyProduction(cargo))) {
                    AILog.Info("Building " + AICargo.GetCargoLabel(cargo) + " ship between " + producer.GetName() + " and " + acceptor.GetName());
                    ships_built++;
                    break;
                } else if(!AreShipsAllowed())
                    return ships_built;
            }
        }
    }

    return ships_built;
}
