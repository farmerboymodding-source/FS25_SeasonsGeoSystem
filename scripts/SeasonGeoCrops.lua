-- Season Geo System By FarmerBoy
-- Modulo Gestione Colture

-- Copyright (c) 2026 FarmerBoy. All Rights Reserved.
-- The use, integration, and execution of this code are freely permitted within the video game Farming Simulator 25.
-- Republishing, selling, or redistributing the LUA source files on third-party platforms is strictly prohibited without 
-- the explicit written consent of the original author.
-- Any GEO XML files mustn't include credit to the original author, you are free to do what you want with that.

function SeasonGEO:manageAllCrops()
	local xmlPath = self:findSeasonGeoMod()
	if xmlPath == nil then
		return
	end
	
	-- Apriamo l'XML UNA SOLA VOLTA per ottimizzare la memoria e le prestazioni
	local xmlFile = loadXMLFile("CurrentSeasonGeo", xmlPath)

	-- Iteriamo dinamicamente su TUTTE le colture registrate nel gioco base o da altre mod
	for cropName, cropPath in pairs(g_fruitTypeManager.nameToFruitType) do
		
		-- Creiamo la chiave per cercare nell'XML (es: "wheat", "barley") in minuscolo
		local cropNodeName = string.lower(cropName)
		local growthKey = string.format("SeasonGeo.cropsManagment.%s.growth.seasonal", cropNodeName)
		
		-- Se questa coltura esiste nel nostro XML, la gestiamo
		if hasXMLProperty(xmlFile, growthKey) then
			if cropPath ~= nil and cropPath.growthDataSeasonal ~= nil and cropPath.growthDataSeasonal.periods ~= nil and cropPath.growthDataSeasonal.periods[1] ~= nil then
				self:manageCrop(cropPath, string.upper(cropName), xmlFile, growthKey)
			else
				print(string.format("SeasonGEO: Impossibile accedere ai periodi stagionali di %s!", cropName))
			end
		end
	end
	
	-- Chiudiamo l'XML alla fine del ciclo completo
	delete(xmlFile)
end


function SeasonGEO:manageCrop(crop, cropName, xmlFile, growthKey)
	-- Non serve più caricare l'XML qui, ce lo passiamo dalla funzione madre
	
	local month
	local monthName
	local i
	
	-- Ripristino la tabella degli stati (mapping 1:1) per evitare conflitti con stati vanilla
	for m=1,12 do
		for k=1,15 do -- Esteso a 15 per coprire colture complesse come il pioppo
			crop.growthDataSeasonal.periods[m].growthMapping[k] = k
		end
	end
	
	-- 1. Definisci i "preset" delle mappe usando i dati estratti dal tuo Markdown
	local maps = {
		standard = { -- Valido per Wheat, Barley, ecc.
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenSmall2"]   = 3,
			["greenMiddle"]   = 4,
			["greenMiddle2"]  = 5,
			["greenBig"]      = 6,
			["greenBig2"]     = 7,
			["harvestReady"]  = 8,
			["dead"]          = 9,
			["harvested"]     = 10
		},
		soybean = {
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenMiddle"]   = 3,
			["greenMiddle2"]  = 4,
			["greenBig"]      = 5,
			["greenBig2"]     = 6,
			["harvestReady"]  = 7,
			["dead"]          = 8,
			["harvested"]     = 9
		},
		grass = {
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenMiddle"]   = 3,
			["harvestReady"]  = 4,
			["cut"]           = 5,
			["cutRolled"]     = 6
		},
		canola = { 
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenSmall2"]   = 3,
			["greenSmall3"]   = 4,
			["greenMiddle"]   = 5,
			["greenMiddle2"]  = 6,
			["greenBig"]      = 7,
			["greenBig2"]     = 8,
			["harvestReady"]  = 9,
			["dead"]          = 10,
			["harvested"]     = 11
		},
		oat = { 
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenMiddle"]   = 3,
			["greenBig"]  	  = 4,
			["harvestReady"]  = 5,
			["dead"]		  = 6,
			["harvested"]     = 7
		},
		rootCrop = { -- Valido per Potato, Sugarbeet, ecc. (Adattato dal tuo markdown)
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenSmall2"]   = 3,
			["greenMiddle"]   = 4,
			["greenMiddle2"]  = 5, -- (Beet)
			["greenBig"]      = 6,
			["greenBig2"]     = 7, -- (Beet)
			["harvestReady"]  = 8,
			["dead"]          = 9,
			["harvested"]     = 10,
			["cutHaulm"]      = 11
		},
		sunflower = {
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenSmall2"]   = 3,
			["greenMiddle"]   = 4,
			["greenMiddle2"]  = 5,
			["greenBig"]      = 6,
			["greenBig2"]     = 7,
			["harvestReady"]  = 8,
			["dead"]          = 9,
			["harvested"]     = 10
		},
		maize = {
			["invisible"]     = 1,
			["greenSmall"]    = 2,
			["greenMiddle"]   = 3,
			["greenBig"]      = 4,
			["harvestReadyGreen"] = 5,
			["harvestReady"]  = 7,
			["dead"]          = 8,
			["harvested"]     = 9
		}
	}

	-- 2. Configurazione assegnazioni
	local cropConfig = {
		["WHEAT"]       = maps.standard,
		["BARLEY"]      = maps.standard,
		["CANOLA"]      = maps.canola,
		["OAT"]         = maps.oat,
		["SOYBEAN"]     = maps.soybean,
		["SUNFLOWER"]   = maps.sunflower,
		["GRASS"]       = maps.grass,
		["MAIZE"]       = maps.maize,
		["POTATO"]      = maps.rootCrop,
		["SUGARBEET"]   = maps.rootCrop
	}

	local stateMap = cropConfig[cropName] or maps.standard
	
	for i = 0, 11 do
		local growthPeriodKey = string.format("%s.period(%d)", growthKey, i)
		monthName = getXMLString(xmlFile, growthPeriodKey .. "#name")
		local plantingAllowed = getXMLBool(xmlFile, growthPeriodKey .. "#plantingAllowed")
		local isHarvestable = getXMLBool(xmlFile, growthPeriodKey .. "#isHarvestable")
		
		if monthName == "EARLY_SPRING" then month = 1
		elseif monthName == "MID_SPRING" then month = 2
		elseif monthName == "LATE_SPRING" then month = 3
		elseif monthName == "EARLY_SUMMER" then month = 4
		elseif monthName == "MID_SUMMER" then month = 5
		elseif monthName == "LATE_SUMMER" then month = 6
		elseif monthName == "EARLY_AUTUMN" then month = 7
		elseif monthName == "MID_AUTUMN" then month = 8
		elseif monthName == "LATE_AUTUMN" then month = 9
		elseif monthName == "EARLY_WINTER" then month = 10
		elseif monthName == "MID_WINTER" then month = 11
		elseif monthName == "LATE_WINTER" then month = 12
		end
		
		if plantingAllowed then
			crop.growthDataSeasonal.periods[month].plantingAllowed = true
		else 
			crop.growthDataSeasonal.periods[month].plantingAllowed = false
		end
		
		if isHarvestable then
			crop.growthDataSeasonal.periods[month].isHarvestable = true
		else 
			crop.growthDataSeasonal.periods[month].isHarvestable = false
		end
		
		local j = 0
		while true do
			local updatePeriodKey = string.format("%s.update(%d)", growthPeriodKey, j)
			local startStateName = getXMLString(xmlFile, updatePeriodKey .. "#startState")
			
			if startStateName == nil then break end
			
			local endStateName = getXMLString(xmlFile, updatePeriodKey .. "#endState")
			local startStateId = stateMap[startStateName]
			local endStateId = stateMap[endStateName]
			
			if startStateId and endStateId then
				crop.growthDataSeasonal.periods[month].growthMapping[startStateId] = endStateId
			else
				print(string.format("Warning SeasonGEO: Stato sconosciuto in %s - Start='%s', End='%s'", cropName, tostring(startStateName), tostring(endStateName)))
			end
			j = j + 1
		end
	end
end