require("dock.nut");
require("utils.nut");

class Industry {
    id = -1;
    is_producer = false;

    constructor(id, is_producer) {
        this.id = id;
        this.is_producer = is_producer;
    }
}

function Industry::GetName() {
    if(this.is_producer)
        return AIIndustry.GetName(this.id) + "(producer)";
    else
        return AIIndustry.GetName(this.id) + "(acceptor)";
}

/* Valuator. */
function _val_IndustryHasDock(industry_id, is_producer) {
    local industry = Industry(industry_id, is_producer);
    return industry.GetExistingDock() != null;
}

function Industry::GetExistingDock() {
    if(AIIndustry.HasDock(this.id))
        return Dock(AIIndustry.GetDockLocation(this.id), -1, true);

    local tiles;
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    if(this.is_producer)
        tiles = AITileList_IndustryProducing(this.id, radius);
    else
        tiles = AITileList_IndustryAccepting(this.id, radius);
    tiles.Valuate(AIMarine.IsDockTile);
    tiles.KeepValue(1);
    tiles.Valuate(IsSimpleSlope);
    tiles.KeepValue(1);
    if(tiles.IsEmpty())
        return null;

    return Dock(tiles.Begin());
}

/* Gets monthly production to determine the potential ship size. */
function Industry::GetMonthlyProduction(cargo) {
    return AIIndustry.GetLastMonthProduction(this.id, cargo) - AIIndustry.GetLastMonthTransported(this.id, cargo);
}
