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

/** @file utils/airport.nut Some aircraft-related functions. */

/**
 * A utility class containing some aircraft-related functions.
 */
class Utils_Airport
{
/* public: */

	/**
	 * Check if a certain airport is a small airport.
	 * @param station_id The Station to check.
	 * @return Whether the airport is small.
	 */
	static function IsSmallAirport(station_id);

	/**
	 * Check if a certain airport is a heliport.
	 * @param station_id The Station to check.
	 * @return Whether the airport is a heliport.
	 */
	static function IsHeliport(station_id);
};

function Utils_Airport::IsSmallAirport(station_id)
{
	assert(AIStation.HasStationType(station_id, AIStation.STATION_AIRPORT));

	local hasShortStrip = AIAirport.HasShortStrip(AIStation.GetLocation(station_id));
	AILog.Info(AIStation.GetName(station_id) + " airport has short strip: " + hasShortStrip);
	return hasShortStrip;
}

function Utils_Airport::IsHeliport(station_id)
{
	assert(AIStation.HasStationType(station_id, AIStation.STATION_AIRPORT));

	//local type = AIAirport.GetAirportType(AIStation.GetLocation(station_id));
	//return type == AIAirport.AT_HELIPORT || type == AIAirport.AT_HELISTATION || type == AIAirport.AT_HELIDEPOT;

	return AIAirport.OnlyHelicopters(AIStation.GetLocation(station_id));
}

function Utils_Airport::HasHangars(station_id)
{
	assert(AIStation.HasStationType(station_id, AIStation.STATION_AIRPORT));

	return AIAirport.GetNumHangars(AIStation.GetLocation(station_id)) > 0;
}

