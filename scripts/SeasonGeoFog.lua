-- Season Geo System By FarmerBoy
-- Modulo Gestione Nebbia

-- Copyright (c) 2026 FarmerBoy. All Rights Reserved.
-- The use, integration, and execution of this code are freely permitted within the video game Farming Simulator 25.
-- Republishing, selling, or redistributing the LUA source files on third-party platforms is strictly prohibited without 
-- the explicit written consent of the original author.
-- Any GEO XML files mustn't include credit to the original author, you are free to do what you want with that.

function SeasonGEO:manageFog()
    -- 1. Controllo difensivo iniziale
    local mission = g_currentMission
    if not mission or not mission.environment or not mission.environment.weather then return end
    
    local seasonToFog = mission.environment.weather.seasonToFog
    local xmlPath = self:findSeasonGeoMod()
    if xmlPath == nil then return end

	local xmlFile = loadXMLFile("CurrentSeasonGeo", xmlPath)

    -- 2. MAPPING PRO: Definito una volta sola, locale per velocità
    local WEATHER_TO_ID = { -- SUN PARTIALLY_CLOUDY CLOUDY RAIN SNOW HAIL TWISTER THUNDER
        ["SUN"]     		 = 1,
		["PARTIALLY_CLOUDY"] = 2,
        ["CLOUDY"]  		 = 3,
        ["RAIN"]   			 = 4,
        ["SNOW"]    		 = 5,
        ["HAIL"]    		 = 6,
        ["TWISTER"] 		 = 7,
		["THUNDER"] 		 = 8
    }

    for index, fogObject in ipairs(seasonToFog) do
        -- L'indice XML parte da 0, Lua da 1. Calcoliamo la base una volta sola.
        local seasonXmlIndex = index - 1
        local baseKey = string.format("SeasonGeo.weatherManagment.season(%d).fog", seasonXmlIndex)
        local groundKey = baseKey .. ".groundFog"
        local heightKey = baseKey .. ".heightFog"
        
        local ft = fogObject.template -- Abbreviazione per leggibilità

        -- 3. LETTURA DATI (Corretto Int/Float e nomi attributi)
        
        -- Valley Depth
        ft.groundFogMinValleyDepth.min = getXMLFloat(xmlFile, groundKey .. ".minValleyDepth#min")
        ft.groundFogMinValleyDepth.max = getXMLFloat(xmlFile, groundKey .. ".minValleyDepth#max")

        -- Densità
        ft.groundFogGroundLevelDensity.min = getXMLFloat(xmlFile, groundKey .. ".groundLevelDensity#min")
        ft.groundFogGroundLevelDensity.max = getXMLFloat(xmlFile, groundKey .. ".groundLevelDensity#max")

        ft.heightFogGroundLevelDensity.min = getXMLFloat(xmlFile, heightKey .. ".groundLevelDensity#min")
        ft.heightFogGroundLevelDensity.max = getXMLFloat(xmlFile, heightKey .. ".groundLevelDensity#max")

        -- Orari
        ft.groundFogStartDayTimeMinutes.min = getXMLInt(xmlFile, groundKey .. ".startDayTimeMinutes#min")
        ft.groundFogStartDayTimeMinutes.max = getXMLInt(xmlFile, groundKey .. ".startDayTimeMinutes#max")
        
        ft.groundFogEndDayTimeMinutes.min = getXMLInt(xmlFile, groundKey .. ".endDayTimeMinutes#min")
        ft.groundFogEndDayTimeMinutes.max = getXMLInt(xmlFile, groundKey .. ".endDayTimeMinutes#max")

        -- Altezze
        ft.heightFogMaxHeight.min = getXMLFloat(xmlFile, heightKey .. ".maxHeight#min")
        ft.heightFogMaxHeight.max = getXMLFloat(xmlFile, heightKey .. ".maxHeight#max")
        
        ft.groundFogExtraHeight.min = getXMLFloat(xmlFile, groundKey .. ".extraHeight#min")
        ft.groundFogExtraHeight.max = getXMLFloat(xmlFile, groundKey .. ".extraHeight#max")
        
        -- Coverage (Float)
        ft.groundFogCoverageEdge0.min = getXMLFloat(xmlFile, groundKey .. ".coverageEdge0#min")
        ft.groundFogCoverageEdge0.max = getXMLFloat(xmlFile, groundKey .. ".coverageEdge0#max")
        
        ft.groundFogCoverageEdge1.min = getXMLFloat(xmlFile, groundKey .. ".coverageEdge1#min")
        ft.groundFogCoverageEdge1.max = getXMLFloat(xmlFile, groundKey .. ".coverageEdge1#max")


        -- 4. LOGICA WEATHER TYPES
        -- Resettiamo la configurazione precedente
        for i=1, 8 do 
            ft.groundFogWeatherTypes[i] = nil 
        end

        local i = 0
        while true do
            -- Costruiamo la chiave dinamica
            local key = string.format("%s.weatherTypes.weatherType(%d)#name", groundKey, i)
            local name = getXMLString(xmlFile, key)

            if name == nil then break end -- Uscita dal ciclo

            local typeIndex = WEATHER_TO_ID[name]
            
            if typeIndex then
                ft.groundFogWeatherTypes[typeIndex] = true
            else
                print("Warning: Weather type '" .. tostring(name) .. "' not recognized inside SeasonGeo XML")
            end

            i = i + 1
        end
    end

	-- PREVENTS MEMORY LEAKS
    if xmlFile ~= nil then 
        delete(xmlFile) 
    end
end