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


require("../aystar.nut");

/**
 * A Water pathfinder for existing water path ways.
 */
class WaterFollower
{
	_aystar_class = AyStar;
	_max_cost = null;              ///< The maximum cost for a route.
	_pathfinder = null;            ///< A reference to the used AyStar object.

	_running = null;
	_goals = null;

	constructor()
	{
		this._max_cost = 10000000;
		this._pathfinder = this._aystar_class(this._Cost, this._Estimate, this._Neighbours, this._CheckDirection, this, this, this, this);

		this._running = false;
	}

	/**
	 * Initialize a path search between sources and goals.
	 * @param sources The source tiles.
	 * @param goals The target tiles.
	 * @param ignored_tiles An array of tiles that cannot occur in the final path.
	 * @see AyStar::InitializePath()
	 */
	function InitializePath(sources, goals, ignored_tiles = []) {
		this._goals = goals;
		this._pathfinder.InitializePath(sources, goals, ignored_tiles);
	}

	/**
	 * Try to find the path as indicated with InitializePath with the lowest cost.
	 * @param iterations After how many iterations it should abort for a moment.
	 *  This value should either be -1 for infinite, or > 0. Any other value
	 *  aborts immediatly and will never find a path.
	 * @return A route if one was found, or false if the amount of iterations was
	 *  reached, or null if no path was found.
	 *  You can call this function over and over as long as it returns false,
	 *  which is an indication it is not yet done looking for a route.
	 * @see AyStar::FindPath()
	 */
	function FindPath(iterations);
};

function WaterFollower::FindPath(iterations)
{
	local test_mode = AITestMode();
	local ret = this._pathfinder.FindPath(iterations);
	this._running = (ret == false) ? true : false;
	return ret;
}

function WaterFollower::_nonzero(a, b)
{
	return a != 0 ? a : b;
}

function WaterFollower::_IsWater(tile) {
    return (AITile.IsWaterTile(tile) && AITile.GetSlope(tile) == AITile.SLOPE_FLAT) ||
            AIMarine.IsBuoyTile(tile) ||
            AIMarine.IsDockTile(tile) ||
            AIMarine.IsLockTile(tile) ||
            AIMarine.IsCanalTile(tile) ||
            AIMarine.IsWaterDepotTile(tile);
}

function WaterFollower::_Cost(path, new_tile, new_direction, self)
{
	/* path == null means this is the first node of a path, so the cost is 0. */
	if (path == null) return 0;
	return path.GetCost() + AIMap.DistanceManhattan(path.GetTile(), new_tile);
}

function WaterFollower::_Estimate(cur_tile, cur_direction, goal_tiles, self)
{
	local min_cost = self._max_cost;
	foreach (tile in goal_tiles) {
		min_cost = min(min_cost, AIMap.DistanceManhattan(tile, cur_tile));
	}
	return min_cost;
}

function WaterFollower::_Neighbours(path, cur_node, self)
{
	/* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
	if (path.GetCost() >= self._max_cost) return [];

	local offsets = [
			AIMap.GetTileIndex(0, 1),
			AIMap.GetTileIndex(0, -1),
			AIMap.GetTileIndex(1, 0),
			AIMap.GetTileIndex(-1, 0)
		];


	AILog.Info("Checking neighbours for" + path.GetTile() + " " + cur_node);
	AILog.Info("is water: " + self._IsWater(cur_node));
	local tiles = [];
	if (self._IsWater(cur_node)) {
		/* Check if the current tile is part of a bridge or tunnel. */
		if (AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) {
			// if ((AIBridge.IsBridgeTile(cur_node) && AIBridge.GetOtherBridgeEnd(cur_node) == path.GetParent().GetTile()) ||
			//   (AITunnel.IsTunnelTile(cur_node) && AITunnel.GetOtherTunnelEnd(cur_node) == path.GetParent().GetTile())) {
			// 	local other_end = path.GetParent().GetTile();
			// 	local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
			// 	tiles.push([next_tile, self._GetDirection(null, cur_node, next_tile, true)]);
			// } else if (AIBridge.IsBridgeTile(cur_node)) {
			// 	local other_end = AIBridge.GetOtherBridgeEnd(cur_node);;
			// 	local prev_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
			// 	if (prev_tile == path.GetParent().GetTile()) tiles.push([AIBridge.GetOtherBridgeEnd(cur_node), self._GetDirection(null, path.GetParent().GetTile(), cur_node, true)]);
			// } else {
			// 	local other_end = AITunnel.GetOtherTunnelEnd(cur_node);
			// 	local prev_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
			// 	if (prev_tile == path.GetParent().GetTile()) tiles.push([AITunnel.GetOtherTunnelEnd(cur_node), self._GetDirection(null, path.GetParent().GetTile(), cur_node, true)]);
			// }
		} else {
			foreach (offset in offsets) {
				local next_tile = cur_node + offset;
				/* Don't turn back */
				if (path.GetParent() != null && next_tile == path.GetParent().GetTile()) continue;
				/* Disallow 90 degree turns */
				if (path.GetParent() != null && path.GetParent().GetParent() != null &&
					next_tile - cur_node == path.GetParent().GetParent().GetTile() - path.GetParent().GetTile()) continue;

				AILog.Info("Are tiles connected? " + cur_node + " " + next_tile);
				if (self._IsWater(next_tile) || AIMarine.AreWaterTilesConnected(cur_node, next_tile)) {
					AILog.Info("tiles connected " + cur_node + " " + next_tile);
					tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
				}
			}
		}
	}
	return tiles;
}

function WaterFollower::_CheckDirection(tile, existing_direction, new_direction, self)
{
	return false;
}

function WaterFollower::_dir(from, to)
{
	if (from - to == 1) return 0;
	if (from - to == -1) return 1;
	if (from - to == AIMap.GetMapSizeX()) return 2;
	if (from - to == -AIMap.GetMapSizeX()) return 3;
	throw("Shouldn't come here in _dir");
}

function WaterFollower::_GetDirection(from, to, is_bridge)
{
	if (from - to == 1) return 1;
	if (from - to == -1) return 2;
	if (from - to == AIMap.GetMapSizeX()) return 4;
	if (from - to == -AIMap.GetMapSizeX()) return 8;
}
