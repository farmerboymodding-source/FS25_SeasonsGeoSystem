-- Season Geo System By FarmerBoy Farming Simulator 25
-- Main module (Main)
-- Comments language is Italian at the moment, if you don't understand anything consider using a llm


-- Copyright (c) 2026 FarmerBoy. All Rights Reserved.
-- The use, integration, and execution of this code are freely permitted within the video game Farming Simulator 25.
-- Republishing, selling, or redistributing the LUA source files on third-party platforms is strictly prohibited without 
-- the explicit written consent of the original author.
-- Any GEO XML files mustn't include credit to the original author, you are free to do what you want with that.


SeasonGEO = {}
SeasonGEO.modName = g_currentModName
SeasonGEO.modDirectory = g_currentModDirectory

-- Sub-models loading
source(Utils.getFilename("scripts/SeasonGeoCrops.lua", SeasonGEO.modDirectory))
source(Utils.getFilename("scripts/SeasonGeoWeather.lua", SeasonGEO.modDirectory))
source(Utils.getFilename("scripts/SeasonGeoFog.lua", SeasonGEO.modDirectory))

function SeasonGEO:findSeasonGeoMod()
	for _, mod in pairs(g_modManager:getActiveMods()) do
		local modDescPath = mod.modFile
		if fileExists(modDescPath) then
			local xml = loadXMLFile("modDescCheck", modDescPath)
			if xml ~= nil then
				if hasXMLProperty(xml, "modDesc.SeasonGeoSystem") then
					local isReady = getXMLBool(xml, "modDesc.SeasonGeoSystem.isReady#value")
					if isReady then
						local xmlFileName = getXMLString(xml, "modDesc.SeasonGeoSystem.xmlFilename#path")
						if xmlFileName ~= nil and xmlFileName ~= "" then
							local xmlPath = Utils.getFilename(xmlFileName, mod.modDir)
							delete(xml)
							return xmlPath
						else
							print(string.format("Mod %s is ready but doesn't specify any xmlFileName!", mod.modName))
						end
					end
				end
				delete(xml)
			end
		end
	end
	print("No SeasonGeoSystem with isReady mod found")
	return nil
end

addConsoleCommand("seasonGEO_reload", "Reloads GEO System", "onConsoleReload", SeasonGEO)

function SeasonGEO:onConsoleReload()
    print("Reloading GEO datas...")
    self:manageWeather()
end

function SeasonGEO:loadMap(i3dName)
	-- Recalls sub-modules
	self:manageAllCrops() 
	self:manageWeather() 
	self:manageFog()
end

addModEventListener(SeasonGEO)