require("pf_coast.nut");
require("pf_canal.nut");

class WaterPathfinder {

    /* List of chunks of paths of 2 types:
     * - water path (only water, no rivers)
     * - canals
     */
    paths = [];
    is_canal = [];
    has_canal = false;
    infrastructure = []; /* canal infrastructure */

    coast_pf = CoastPathfinder();
    canal_pf = CanalPathfinder();

    buoy_distance = 25;

    constructor() {}
}

function WaterPathfinder::_IsWater(tile) {
    return (AITile.IsWaterTile(tile) && AITile.GetMaxHeight(tile) == 0) || /* eliminates rivers */
            AIMarine.IsBuoyTile(tile) ||
            AIMarine.IsDockTile(tile) ||
            AIMarine.IsLockTile(tile) ||
            AIMarine.IsWaterDepotTile(tile);
}

function WaterPathfinder::FindPath(dock1, dock2, max_path_len, max_parts) {
    this.paths = [];
    this.infrastructure = [];
    this.is_canal = [];
    this.has_canal = false;
    local start = dock1.GetPfTile(dock2.tile);
    local end = dock2.GetPfTile(dock1.tile);
    if(!AIMap.IsValidTile(start) || !AIMap.IsValidTile(end)
        || start == end || max_path_len <= 0)
        return false;

    if(AIMap.DistanceManhattan(start, end) > max_path_len)
        return false;

    /* Bresenham algorithm */
    local x0 = AIMap.GetTileX(start), y0 = AIMap.GetTileY(start);
    local x1 = AIMap.GetTileX(end), y1 = AIMap.GetTileY(end);
    local dx = abs(x1 - x0), dy = abs(y1 - y0);
    local sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    local err = (dx > dy ? dx : -dy)/2, e2;

    local len_so_far = 0;
    local straight_paths = [];
    local tmp_path = [];
    while(true) {
        local tile = AIMap.GetTileIndex(x0, y0);
        if(tile == start || tile == end || _IsWater(tile)) {
             /* Still on water */
            tmp_path.push(tile);
            len_so_far++;
        } else {
            /* We reached some obstacle, add tiles visited until we reached it to paths list. */
            if(tmp_path.len() > 0) {
                straight_paths.push(tmp_path);
                tmp_path = [];

                /* To avoid calling less performant pathfinders too many times. */
                if(straight_paths.len() > 1 + max_parts)
                    return false;
            }
        }
        if(tile == end) {
            if(tmp_path.len() > 0)
                straight_paths.push(tmp_path);
            break;
        }

        e2 = err;
        if(e2 >-dx) { err -= dy; x0 += sx; }
        if(e2 < dy) { err += dx; y0 += sy; }
    }

    /* Canal pathfinder must not go over dock tiles, same goes for locks. */
    local land_ignored = AITileList();
    local sea_ignored = AITileList();
    if(dock1.is_landdock)
        land_ignored.AddList(dock1.GetOccupiedTiles());
    else if(!dock1.is_offshore)
        sea_ignored.AddList(dock1.GetOccupiedTiles());
    if(dock2.is_landdock)
        land_ignored.AddList(dock2.GetOccupiedTiles());
    else if(!dock2.is_offshore)
        sea_ignored.AddList(dock2.GetOccupiedTiles());

    /* Try to avoid obstacles */
    for(local i=1; i<straight_paths.len(); i++) {
        this.paths.push(straight_paths[i-1]);
        this.is_canal.push(false);
        local obs_start = straight_paths[i-1].top();
        local obs_end   = straight_paths[i][0];
        local obs_dist  = AIMap.DistanceManhattan(obs_start, obs_end);
        local max_obs_len = min(3 * obs_dist, max_path_len - len_so_far);
        if(coast_pf.FindPath(obs_start, obs_end, max_obs_len)) {
            /* We found a coast following path - cheaper than building a canal */
            this.paths.push(coast_pf.path);
            this.is_canal.push(false);
            len_so_far += coast_pf.path.len();
        } else {
            /* No coast path, let's try planning a canal */
            if(false && canal_pf.FindPath(obs_start, obs_end, max_obs_len, land_ignored, sea_ignored)) {
                /* We found a suitable canal */
                this.paths.push(canal_pf.path);
                this.is_canal.push(true);
                this.has_canal = true;
                this.infrastructure.extend(canal_pf.infrastructure);
                len_so_far += canal_pf.path.len();
            } else
                return false;
        }
    }

    if(straight_paths.len() > 0) {
        this.paths.push(straight_paths.top());
        this.is_canal.push(false);
    }

    return true;
}

function WaterPathfinder::Length() {
    local len = 0;
    foreach(path in this.paths)
        len += path.len();
    return len;
}

function WaterPathfinder::EstimateBuoysCost() {
    return AIMarine.GetBuildCost(AIMarine.BT_BUOY) * ((this.Length() / this.buoy_distance) + 1);
}

/* Checks if there is a buoy in radius of 3 tiles. */
function WaterPathfinder::_GetNearbyBuoy(tile) {
    local tiles = AITileList();
    SafeAddRectangle(tiles, tile, 3);
    tiles.Valuate(AIMarine.IsBuoyTile);
    tiles.KeepValue(1);
    if(!tiles.IsEmpty())
        return tiles.Begin();

    if(AIMarine.BuildBuoy(tile))
        return tile;

    return -1;
}

/* Buoys are essential for longer paths and also speed up the ship pathfinder.
   This function places a buoy every n tiles. Existing buoys are reused. */
function WaterPathfinder::BuildBuoys() {
    /* TODO: this is unsafe, nearby buoy can be on a different water area */
    local buoys = [];
    local full = [];
    foreach(path in this.paths)
        full.extend(path);
    for(local i = this.buoy_distance/2; i<full.len()-(this.buoy_distance/2); i += this.buoy_distance) {
        local buoy = _GetNearbyBuoy(full[i]);
        if(buoy == -1)
            buoy = _GetNearbyBuoy(full[i+1]);
        if(buoy == -1)
            buoy = _GetNearbyBuoy(full[i-1]);
        if(buoy != -1)
            buoys.push(buoy);
    }
    return buoys;
}

function WaterPathfinder::EstimateCanalsCost() {
    /* This method may be costful but there is no BT_CANAL or BT_LOCK for AIMarine.GetBuildCosts. */
    if(!this.has_canal)
        return 0;
    local test = AITestMode();
    local costs = AIAccounting();
    this.BuildCanals();
    return costs.GetCosts();

    //local canal_cost = 8 * AIMarine.GetBuildCost(AIMarine.BT_DEPOT);
    //local lock_cost = 11 * AIMarine.GetBuildCost(AIMarine.BT_DEPOT);
    //local cost = 0;
    //local i = 0;
    //foreach(path in this.paths) {
        //if(this.is_canal[i]) {
            //cost += 2 * lock_cost;
            //cost += (path.len() - 2) * canal_cost;
        //}
        //i++;
    //}
    //return cost;
}

function WaterPathfinder::BuildCanals() {
    if(!this.has_canal)
        return true;

    /* Can be any bridge type, cost is always the same for aqueducts. */
    local bridge_id = AIBridgeList().Begin();
    local i = 0;
    foreach(inf in this.infrastructure) {
        if(!inf.Exists()) {
            if(inf instanceof Aqueduct) {
                if(!AIBridge.BuildBridge(AIVehicle.VT_WATER, bridge_id, inf.edge1, inf.edge2)) {
                    local err_str = AIError.GetLastErrorString();
                    local x = AIMap.GetTileX(inf.edge1);
                    local y = AIMap.GetTileY(inf.edge1);
                    AILog.Error("Failed to build aqueduct at (" + x + "," + y + "): " + err_str);
                    return false;
                } else {
                    local middle = inf.GetMiddleTile();
                    local town_name = AITown.GetName(AITile.GetClosestTown(middle));
                    AISign.BuildSign(middle, town_name + " Aqueduct");
                }
            } else {
                if(!AIMarine.BuildLock(inf.tile)) {
                    local err_str = AIError.GetLastErrorString();
                    local x = AIMap.GetTileX(inf.tile);
                    local y = AIMap.GetTileY(inf.tile);
                    AILog.Error("Failed to build lock at (" + x + "," + y + "): " + err_str);
                    return false;
                }
            }
        }
    }

    local our_company_id = AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
    foreach(path in this.paths) {
        if(this.is_canal[i]) {
            foreach(tile in path) {
                if(AIMarine.IsDockTile(tile) || AITile.IsWaterTile(tile) ||
                   AIMarine.IsCanalTile(tile) || AIMarine.IsBuoyTile(tile) ||
                   AIMarine.IsLockTile(tile))
                    continue;

                /* If something was built there when while we we planning the path - try demolishing it. */
                if(!AITile.IsBuildable(tile) && AITile.GetOwner(tile) != our_company_id) {
                    if(!AITile.DemolishTile(tile)) {
                        local err_str = AIError.GetLastErrorString();
                        local x = AIMap.GetTileX(tile);
                        local y = AIMap.GetTileY(tile);
                        AILog.Error("Failed to clean land to build canal at (" + x + "," + y + "): " + err_str);
                        return false;
                    }

                    /* Why no check for return value here? Because even after demolishing the tile and
                     * successfully building the canal, BuildCanal returns ERR_AREA_NOT_CLEAR.
                     * There is some delay probably. */
                    AIMarine.BuildCanal(tile);

                } else if(!AIMarine.BuildCanal(tile)) {
                    local err_str = AIError.GetLastErrorString();
                    local x = AIMap.GetTileX(tile);
                    local y = AIMap.GetTileY(tile);
                    AILog.Error("Failed to build canal at (" + x + "," + y + "): " + err_str);
                    return false;
                }
            }
        }
        i++;
    }
    return true;
}

