require("global.nut");
require("utils.nut");

class Dock {
    tile = -1;
    orientation = -1;
    is_landdock = false;
    is_offshore = false;

    /* Don't use too big value here, it may cause the depots on the other
     * waterbody to be chosen. */
    max_depot_distance = 10;

    constructor(dock, artificial_orientation = -1, _is_offshore = false) {
        this.tile = dock;
        this.is_offshore = _is_offshore;

        if(!_is_offshore) {
            /* We need to find the hill tile. */
            if(AIMarine.IsDockTile(dock) && AITile.GetSlope(dock) == AITile.SLOPE_FLAT) {
                if(AIMarine.IsDockTile(dock + NORTH))
                    this.tile = dock + NORTH;
                else if(AIMarine.IsDockTile(dock + SOUTH))
                    this.tile = dock + SOUTH;
                else if(AIMarine.IsDockTile(dock + WEST))
                    this.tile = dock + WEST;
                else if(AIMarine.IsDockTile(dock + EAST))
                    this.tile = dock + EAST;
            }

            if(artificial_orientation != -1) {
                /* Artificial dock. */
                this.orientation = artificial_orientation;
                this.is_landdock = true;
            } else {
                /* Coast dock or existing one. */
                switch(AITile.GetSlope(this.tile)) {
                    case AITile.SLOPE_NE:
                        /* West. */
                        this.orientation = 0;
                        if(AIMarine.IsCanalTile(this.tile + WEST + WEST))
                            this.is_landdock = true;
                        break;
                    case AITile.SLOPE_NW:
                        /* South. */
                        this.orientation = 1;
                        if(AIMarine.IsCanalTile(this.tile + SOUTH + SOUTH))
                            this.is_landdock = true;
                        break;
                    case AITile.SLOPE_SE:
                        /* North. */
                        if(AIMarine.IsCanalTile(this.tile + NORTH + NORTH))
                            this.is_landdock = true;
                        this.orientation = 2;
                        break;
                    case AITile.SLOPE_SW:
                        /* East. */
                        if(AIMarine.IsCanalTile(this.tile + EAST + EAST))
                            this.is_landdock = true;
                        this.orientation = 3;
                        break;
                    default:
                        this.orientation = -1;
                        break;
                }
            }
        }
    }
}

function Dock::IsValidStation() {
    return AIStation.IsValidStation(AIStation.GetStationID(this.tile));
}

function Dock::GetStationID() {
    return AIStation.GetStationID(this.tile);
}

function Dock::GetName() {
    return AIStation.GetName(AIStation.GetStationID(this.tile));
}

/* Returns the dock's tile which is a target for pathfinder
   - standard coast dock - front part of the dock (for line or coast pathfinder)
   - offshore dock - water tile in the destination direction, not obscured by oil rig
   - land dock - canal tile in front of the dock
 */
function Dock::GetPfTile(dest = -1) {
    /* Some industries (offshores only?) can have a dock built on water which will break the line pathfinder.
       We need to find a tile that is not obstructed by the industry itself. */
    if(this.is_offshore) {
        if(dest == -1)
            return -1;

        local water = AITileList();
        SafeAddRectangle(water, this.tile, 4);
        water.Valuate(AIMap.DistanceManhattan, dest);
        water.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        if(water.IsEmpty())
            return -1; /* Something's wrong... */

        return water.Begin();
    }

    /* canal pathfinder needs to start from water tile, not dock tile */
    local front = 1;
    if(this.is_landdock)
        front = 2;

    switch(this.orientation) {
        case 0:
            /* West. */
            return this.tile + AIMap.GetTileIndex(front, 0);
        case 1:
            /* South. */
            return this.tile + AIMap.GetTileIndex(0, front);
        case 2:
            /* North. */
            return this.tile + AIMap.GetTileIndex(0, -front);
        case 3:
            /* East. */
            return this.tile + AIMap.GetTileIndex(-front, 0);
        default:
            return -1;
    }
}

function Dock::GetOccupiedTiles() {
    local tiles = AITileList();
    tiles.AddTile(this.tile);
    switch(orientation) {
        case 0:
            /* West */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(2, -1));
            }
            return tiles;
        case 1:
            /* South. */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 2));
            }
            return tiles;
        case 2:
            /* North. */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -2));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, -3));
            }
            return tiles;
        case 3:
            /* East. */
            tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 0));
            if(this.is_landdock) {
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 0));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(0, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, -1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(1, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-2, 1));
                tiles.AddTile(this.tile + AIMap.GetTileIndex(-1, 1));
            }
            return tiles;
        default:
            return tiles;
    }
}

function _val_IsDockCapable(tile) {
    if(!AITile.IsBuildable(tile) || !IsSimpleSlope(tile))
        return false;

    local front1 = GetHillFrontTile(tile, 1);
    local front2 = GetHillFrontTile(tile, 2);
    if(AITile.GetSlope(front1) != AITile.SLOPE_FLAT ||
       AITile.GetSlope(front2) != AITile.SLOPE_FLAT)
        return false;

    /* TODO: we should check if front1 is not a bridge somehow
     * AITile.IsBuildable doesn't work for water
     * AIBridge.IsBridge tile works only for bridge's start/end
     * AIBridge.GetBridgeID precondition is that AIBridge.IsBridge returns true
     * AIRoad.IsRoadTile returns false (I didn't try it on land..)
     * AITile.HasTransportType same
     */
    return AITile.IsWaterTile(front1) && AITile.IsWaterTile(front2) &&
          !AIMarine.IsWaterDepotTile(front2);
}

/* Should be used only for sea */
function _val_IsWaterDepotCapable(tile, orientation) {
    /* TODO: we should somehow check if it is not a bridge tile */
    if(!AITile.IsWaterTile(tile) || AITile.GetMaxHeight(tile) > 0)
        return false;

    /* depot is the 2nd depot tile, front is the tile in front of the depot,
     * left/right are side tiles. */
    local depot2, front, left1, left2, right1, right2;
    switch(orientation) {
        /* West. */
        case 0:
            depot2 = tile + WEST;
            front = depot2 + WEST;
            left1 = tile + SOUTH;
            left2 = depot2 + SOUTH;
            right1 = tile + NORTH;
            right2 = depot2 + NORTH;
            break;
        /* South. */
        case 1:
            depot2 = tile + SOUTH;
            front = depot2 + SOUTH;
            left1 = tile + EAST;
            left2 = depot2 + EAST;
            right1 = tile + WEST;
            right2 = depot2 + WEST;
            break;
        /* North. */
        case 2:
            depot2 = tile + NORTH;
            front = depot2 + NORTH;
            left1 = tile + WEST;
            left2 = depot2 + WEST;
            right1 = tile + EAST;
            right2 = depot2 + EAST;
            break;
        /* East. */
        default:
            depot2 = tile + WEST;
            front = depot2 + EAST;
            left1 = tile + NORTH;
            left2 = depot2 + NORTH;
            right1 = tile + SOUTH;
            right2 = depot2 + SOUTH;
            break;
    }

    /* Must have at least one exit and shouldn't block
       any infrastructure on the sides (like dock or lock). */
    return AITile.IsWaterTile(depot2) && AITile.IsWaterTile(front) &&
           AITile.IsWaterTile(left1) && AITile.IsWaterTile(left2) &&
           AITile.IsWaterTile(right1) && AITile.IsWaterTile(right2) &&
           !AIMarine.IsLockTile(depot2) && !AIMarine.IsLockTile(front) &&
           !AIMarine.IsLockTile(left1) && !AIMarine.IsLockTile(left2) &&
           !AIMarine.IsLockTile(right1) && !AIMarine.IsLockTile(right2);
}

/* Land docks have its water depot in fixed place. */
function Dock::_GetLandDockDepotLocation() {
    if(!this.is_landdock)
        return -1;
    switch(this.orientation) {
        /* West. */
        case 0:
            return this.tile + WEST + NORTH;
        /* South. */
        case 1:
            return this.tile + SOUTH + WEST;
        /* North. */
        case 2:
            return this.tile + NORTH + EAST;
        /* East. */
        default:
            return this.tile + EAST + SOUTH;
    }
}

/* Finds water depot close to the dock. */
function Dock::FindWaterDepot() {
    /* Artificial docks have its water depot in fixed place. */
    if(this.is_landdock) {
        local depot = _GetLandDockDepotLocation();
        if(!AIMarine.IsWaterDepotTile(depot))
            return -1;
        return depot;
    }

    /* Let's look nearby. */
    local depots = AIDepotList.GetAllDepots(AITile.TRANSPORT_WATER);
    depots.Valuate(AIMap.DistanceMax, this.tile);
    depots.KeepBelowValue(this.max_depot_distance + 1);
    if(depots.IsEmpty())
        return -1;
    depots.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    return depots.Begin();
}

/* True if this dock had serviced specific cargo at some point. */
function Dock::HadOperatedCargo(cargo) {
    return AIStation.HasCargoRating(GetStationID(), cargo);
}

function Dock::GetCargoWaiting(cargo) {
    return AIStation.GetCargoWaiting(GetStationID(), cargo);
}

function Dock::GetVehicles() {
    return AIVehicleList_Station(GetStationID());
}
