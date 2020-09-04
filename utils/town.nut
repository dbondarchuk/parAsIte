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

/** @file utils/town.nut Some town-related functions. */

/**
 * A utility class containing some functions related to towns.
 */
class Utils_Town {
    /* public: */

    /**
     * Does this tile fit in with the town road layout?
     * @param tile The tile to check.
     * @param town_id The town to get the road layout from.
     * @param default_value The value to return if we can't determine whether the tile is on the grid.
     * @return True iff the tile on placed on the town grid.
     */
    static function TileOnTownLayout(tile, town_id, default_value);

    /**
     * Checks whether a given rectangle is within the influence of a given town.
     * @param tile The topmost tile of the rectangle.
     * @param town_id The TownID of the town to be checked.
     * @param width The width of the rectangle.
     * @param height The height of the rectangle.
     * @return True if the rectangle is within the influence of the town.
     */
    static function IsRectangleWithinTownInfluence(tile, town_id, width, height);

    /**
     * Get a TileList around a town.
     * @param town_id The TownID of the given town.
     * @param width The width of the proposed station.
     * @param height The height of the proposed station.
     * @return A TileList containing tiles around a town.
     */
    static function GetTilesAroundTown(town_id, width, height);
};

function Utils_Town::TileOnTownLayout(tile, town_id, default_value) {
    local town_loc = AITown.GetLocation(town_id);
    switch (AITown.GetRoadLayout(town_id)) {
        case AITown.ROAD_LAYOUT_ORIGINAL:
        case AITown.ROAD_LAYOUT_BETTER_ROADS:
            return default_value;
        case AITown.ROAD_LAYOUT_2x2:
            return abs(AIMap.GetTileX(tile) - AIMap.GetTileX(town_loc)) % 3 == 0 ||
                abs(AIMap.GetTileY(tile) - AIMap.GetTileY(town_loc)) % 3 == 0;
        case AITown.ROAD_LAYOUT_3x3:
            return abs(AIMap.GetTileX(tile) - AIMap.GetTileX(town_loc)) % 4 == 0 ||
                abs(AIMap.GetTileY(tile) - AIMap.GetTileY(town_loc)) % 46 == 0;
    }
    assert(false);
}

function Utils_Town::IsRectangleWithinTownInfluence(tile, town_id, width, height) {
    if (width <= 1 && height <= 1) return AITile.IsWithinTownInfluence(tile, town_id);
    local offsetX = AIMap.GetTileIndex(width - 1, 0);
    local offsetY = AIMap.GetTileIndex(0, height - 1);
    return AITile.IsWithinTownInfluence(tile, town_id) ||
        AITile.IsWithinTownInfluence(tile + offsetX + offsetY, town_id) ||
        AITile.IsWithinTownInfluence(tile + offsetX, town_id) ||
        AITile.IsWithinTownInfluence(tile + offsetY, town_id);
}

function Utils_Town::GetTilesAroundTown(town_id, width, height) {
    local tiles = AITileList();
    local townplace = AITown.GetLocation(town_id);
    local distedge = AIMap.DistanceFromEdge(townplace);
    local offset = null;
    local radius = 15;
    if (AITown.GetPopulation(town_id) > 5000) radius = 30;
    // A bit different is the town is near the edge of the map
    if (distedge < radius + 1) {
        offset = AIMap.GetTileIndex(distedge - 1, distedge - 1);
    } else {
        offset = AIMap.GetTileIndex(radius, radius);
    }
    tiles.AddRectangle(townplace - offset, townplace + offset);
    tiles.Valuate(Utils_Town.IsRectangleWithinTownInfluence, town_id, width, height);
    tiles.KeepValue(1);
    return tiles;
}