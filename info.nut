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

class ParAsIte extends AIInfo {
	version_major = 1;
	function GetAuthor()        { return "Dmytro Bondarchuk"; }
	function GetName()          { return "ParAsIte"; }
	function GetShortName()     { return "PRAI"; }
	function GetDescription()   { return "An AI that uses several types of transport on competitors infrastructure"; }
	function GetVersion()       { return 1 }
	function GetDate()          { return "2023-05-15"; }
	function CreateInstance()   { return "ParAsIte"; }
	function GetAPIVersion()    { return "1.0"; }
	function GetSettings() {
		AddSetting({name = "use_busses", description = "Enable busses", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "use_trucks", description = "Enable trucks", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "use_planes", description = "Enable aircraft", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "use_trains", description = "Enable trains", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "plant_trees", description = "Plant trees (as charity gesture)", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "buy_companies", description = "Try to buy other AI companies", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN | AICONFIG_INGAME});
		AddSetting({name = "airport_terminal_multiplier", description = "Max number of airplanes per airport terminal", easy_value = 3, medium_value = 3, hard_value = 3, custom_value = 3, min_value = 1, max_value = 10	 flags = AICONFIG_INGAME});
		AddSetting({name = "heliport_helipad_multiplier", description = "Max number of helicopters per helipad", easy_value = 5, medium_value = 5, hard_value = 5, custom_value = 5, min_value = 1, max_value = 10	 flags = AICONFIG_INGAME});
		AddSetting({name = "max_planes_per_route", description = "Max number of planes/helicopter per route (all companies)", easy_value = 4, medium_value = 4, hard_value = 4, custom_value = 4, min_value = 1, max_value = 20	 flags = AICONFIG_INGAME});
		AddSetting({name = "max_own_planes_per_route", description = "Max number of own planes/helicopter per route", easy_value = 2, medium_value = 2, hard_value = 2, custom_value = 2, min_value = 1, max_value = 20	 flags = AICONFIG_INGAME});
		AddSetting({name = "max_own_airport_planes", description = "Max percentage of own planes/helicopter per airport", easy_value = 50, medium_value = 50, hard_value = 50, custom_value = 50, min_value = 1, max_value = 100	 flags = AICONFIG_INGAME});
		AddSetting({name = "ban_unprofitable_air_routes_years", description = "Don't build on unprofitable air routes for years", easy_value = 2, medium_value = 2, hard_value = 2, custom_value = 2, min_value = 1, max_value = 20	 flags = AICONFIG_INGAME});
		AddSetting({name = "max_buses_per_station", description = "Max number of buses per station(including competitors)", easy_value = 20, medium_value = 20, hard_value = 20, custom_value = 20, min_value = 5, max_value = 100	 flags = AICONFIG_INGAME});
		AddSetting({name = "always_autorenew", description = "Always use autoreplace regardless of the breakdown setting", easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "debug_signs", description = "Enable building debug signs", easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN});
	}
};

RegisterAI(ParAsIte());
