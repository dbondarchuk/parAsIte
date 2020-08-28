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
require("version.nut");

class ParAsIte extends AIInfo {
	version_major = 1;
	function GetAuthor()        { return "Dmytro Bondarchuk"; }
	function GetName()          { return "ParAsIte"; }
	function GetShortName()     { return "ParAsIte"; }
	function GetDescription()   { return "An AI that uses several types of transport on competitors infrastructure"; }
	function GetVersion()       { return version_major << 24 | revision; }
	function MinVersionToLoad() { return 21; }
	function GetDate()          { return "2020-08-28"; }
	function CreateInstance()   { return "ParAsIte"; }
	function GetAPIVersion()    { return "1.0"; }
	function GetSettings() {
		AddSetting({name = "use_busses", description = "Enable busses", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "use_trucks", description = "Enable trucks", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "use_planes", description = "Enable aircraft", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "use_trains", description = "Enable trains", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "always_autorenew", description = "Always use autoreplace regardless of the breakdown setting", easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "debug_signs", description = "Enable building debug signs", easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN});
	}
};

RegisterAI(ParAsIte());
