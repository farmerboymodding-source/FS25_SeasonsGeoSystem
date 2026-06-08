-- Season Geo System By FarmerBoy
-- Modulo Gestione Meteo e Previsioni

-- Copyright (c) 2026 FarmerBoy. All Rights Reserved.
-- The use, integration, and execution of this code are freely permitted within the video game Farming Simulator 25.
-- Republishing, selling, or redistributing the LUA source files on third-party platforms is strictly prohibited without 
-- the explicit written consent of the original author.
-- Any GEO XML files mustn't include credit to the original author, you are free to do what you want with that.

-- Cache per il percorso XML per evitare lag durante i loop
SeasonGEO.cachedXmlPath = nil

function SeasonGEO:manageWeather()
	if SeasonGEO.cachedXmlPath == nil then
		SeasonGEO.cachedXmlPath = SeasonGEO:findSeasonGeoMod()
	end
	
	local xmlPath = SeasonGEO.cachedXmlPath
	if xmlPath == nil then
		return
	end
	
	local xmlFile = loadXMLFile("CurrentSeasonGeo", xmlPath)
	local i
	for i=1, 4 do -- scorre stagioni
		local weatherKey = string.format("SeasonGeo.weatherManagment.season(%d)",i-1)
		local seasonName = getXMLString(xmlFile, weatherKey .. "#name")
		local seasonIndex
		
		if seasonName ~= nil then
			if seasonName == "spring" then
				seasonIndex = 1
			elseif seasonName == "summer" then
				seasonIndex = 2
			elseif seasonName == "autumn" then
				seasonIndex = 3
			else
				seasonIndex = 4
			end
		end
		
		local function compileSeasonWeather(seasonIndexNumber, i, weatherKey)
			if seasonName == nil then return end

			local seasonWeatherObjects = g_currentMission.environment.weather.weatherObjects[i]
			if seasonWeatherObjects == nil then return end

			-- 1. Creazione dinamica degli oggetti meteo mancanti (Come prima, questo è sicuro e necessario)
			local weatherManager = g_currentMission.environment.weather
			local requiredTypes = {1, 3, 4, 5, 6, 7} 

			for _, reqType in ipairs(requiredTypes) do
				if weatherManager.typeToWeatherObject[seasonIndexNumber][reqType] == nil then
					local sourceObj = nil
					for otherSeason = 1, 4 do
						if weatherManager.typeToWeatherObject[otherSeason][reqType] ~= nil then
							sourceObj = weatherManager.typeToWeatherObject[otherSeason][reqType]
							break
						end
					end
					
					if sourceObj ~= nil then
						local newObj = WeatherObject.new(reqType, sourceObj.cloudUpdater, sourceObj.temperatureUpdater, sourceObj.windUpdater, sourceObj.rainUpdater)
						newObj.season = seasonIndexNumber
						newObj.weight = 0 
						
						for _, var in ipairs(sourceObj.variations) do
							table.insert(newObj.variations, var)
						end
						
						table.insert(seasonWeatherObjects, newObj)
						newObj.index = #seasonWeatherObjects
						weatherManager.typeToWeatherObject[seasonIndexNumber][reqType] = newObj
					end
				end
			end

			-- 2. AGGIORNAMENTO CHIRURGICO DELLE VARIAZIONI (Preserva la fisica!)
			local weatherTypesMap = {
				[WeatherType.SUN] = "sun",
				[WeatherType.CLOUDY] = "cloudy",
				[WeatherType.RAIN] = "rain",
				[WeatherType.SNOW] = "snow",
				[WeatherType.HAIL] = "hail",
				[WeatherType.TWISTER] = "twister"
			}

			for k, weatherObj in ipairs(seasonWeatherObjects) do
				if weatherObj ~= nil and weatherObj.season == seasonIndexNumber then
					local typeName = weatherTypesMap[weatherObj.weatherType]
					
					if typeName ~= nil then
						local weatherBaseKey = string.format("%s.%s", weatherKey, typeName)
						
						if hasXMLProperty(xmlFile, weatherBaseKey) then
							-- Aggiorna il peso globale del tipo di meteo (es. probabilità che piova o ci sia il sole)
							weatherObj.weight = getXMLInt(xmlFile, weatherBaseKey .. "#weight") or weatherObj.weight

							-- SVUOTIAMO SOLO L'URNA DELLE PROBABILITA' (RNG Pool)
							weatherObj.weightedVariations = {}
							
							local vIndex = 0
							local baseVariation = weatherObj.variations[1] -- Modello di backup per fisica (vento/pioggia)
							
							while true do
								local variationKey = string.format("%s.variation(%d)", weatherBaseKey, vIndex)
								local varName = getXMLString(xmlFile, variationKey .. "#name")
								
								if varName == nil then break end 
								
								-- Peschiamo la variazione ESISTENTE dal gioco base, senza distruggerla
								local varSettings = weatherObj.variations[vIndex + 1]
								
								-- Se il tuo XML ha PIÙ variazioni del gioco base, ne creiamo una nuova
								-- ma iniettiamo i puntatori REFERENCE a vento, pioggia e nuvole del gioco base!
								if varSettings == nil then
									varSettings = {
										wind = baseVariation.wind,
										rain = baseVariation.rain,
										rainPresetId = baseVariation.rainPresetId,
										clouds = baseVariation.clouds
									}
									table.insert(weatherObj.variations, varSettings)
								end
								
								-- Sovrascriviamo in modo sicuro solo i parametri che ci interessano
								local cloudsPreset = g_currentMission.environment.weather.cloudUpdater.presets[varName]
								if cloudsPreset ~= nil then
									varSettings.clouds = cloudsPreset
								end
								
								varSettings.minHours = getXMLInt(xmlFile, variationKey .. "#minHours") or varSettings.minHours
								varSettings.maxHours = getXMLInt(xmlFile, variationKey .. "#maxHours") or varSettings.maxHours
								varSettings.minTemperature = getXMLInt(xmlFile, variationKey .. "#minTemp") or varSettings.minTemperature
								varSettings.maxTemperature = getXMLInt(xmlFile, variationKey .. "#maxTemp") or varSettings.maxTemperature
								
								-- Popoliamo la nuova urna delle probabilità con i dati del TUO xml
								local varProb = getXMLInt(xmlFile, variationKey .. "#probability") or 1
								for p=1, varProb do
									table.insert(weatherObj.weightedVariations, vIndex + 1)
								end
								
								vIndex = vIndex + 1
							end
						end
					end
				end
			end
		end

		if seasonName ~= nil then
			compileSeasonWeather(seasonIndex, i, weatherKey)
		end
		
	end
	delete(xmlFile)
end

function SeasonGEO:manageForecasts(superFunc, isRebuild)

    local function weightedRandomChoice(list)    
        local total = 0
        if list ~= nil then
            for _, item in ipairs(list) do
                total = total + item.p
            end

            local threshold = math.random() * total
            local cumulative = 0

            for _, item in ipairs(list) do
                cumulative = cumulative + item.p
                if threshold <= cumulative then
                    return item.value
                end
            end
        end
        return 1 
    end

    if SeasonGEO.cachedXmlPath == nil then
        SeasonGEO.cachedXmlPath = SeasonGEO:findSeasonGeoMod()
    end
	
    local xmlFile = nil
    if SeasonGEO.cachedXmlPath ~= nil then
        xmlFile = loadXMLFile("GeoSicily", SeasonGEO.cachedXmlPath)
    end

    self:updateAvailableWeatherObjects()

    local lastItem = self.forecastItems[#self.forecastItems]
    local maxNumOfforecastItemsItems = 2 ^ Weather.SEND_BITS_NUM_OBJECTS - 1
    local newObjects = {}

    while (lastItem == nil or lastItem.startDay < self.owner.currentMonotonicDay + 9) and #self.forecastItems < maxNumOfforecastItemsItems do

        local startDay = self.owner.currentMonotonicDay
        local startDayTime = self.owner.dayTime

        if lastItem ~= nil then
            startDay = lastItem.startDay
            startDayTime = lastItem.startDayTime + lastItem.duration
        end

        local endDay, endDayTime = self.owner:getDayAndDayTime(startDayTime, startDay)
                 
        local newObject = self:createRandomWeatherInstance(self.owner:getVisualSeasonAtDay(endDay), endDay, endDayTime, false)

        if xmlFile ~= nil then
            -- Mappatura tramite costanti ufficiali WeatherType
            local weatherDefinitions = {
                { name = "sun",        type = WeatherType.SUN },
                { name = "cloudy",     type = WeatherType.CLOUDY },
                { name = "rain",       type = WeatherType.RAIN },
				{ name = "snow",       type = WeatherType.SNOW },
                { name = "hail",       type = WeatherType.HAIL },
                { name = "twister",    type = WeatherType.TWISTER }
            }
                 
            local season = newObject.season
            local baseSeasonKey = string.format("SeasonGeo.weatherManagment.season(%d)", season - 1)

            local weatherObjects = {}
                     
            for _, def in ipairs(weatherDefinitions) do
                local objKey = string.format("%s.%s", baseSeasonKey, def.name)
                local probKey = string.format("%s#probability", objKey)
                local pValue = getXMLInt(xmlFile, probKey) or 0
                     
                table.insert(weatherObjects, {
                    value = def,
                    p = pValue
                })
            end
                     
            if #weatherObjects > 0 then
                local chosenWeatherDef = weightedRandomChoice(weatherObjects)
				local targetWeatherType = chosenWeatherDef.type
				
				-- Recupera il VERO objectIndex in base all'ordine di caricamento della mappa
				local weatherObj = self.typeToWeatherObject[season][targetWeatherType]
				
				if weatherObj ~= nil then
                	newObject.objectIndex = weatherObj.index    

					local variationsObjects = {}
					local chosenObjKey = string.format("%s.%s", baseSeasonKey, chosenWeatherDef.name)    
					local variationBaseKey = string.format("%s.variation", chosenObjKey)
							 
					local vIndex = 0
					while true do
						local variationsProbKey = string.format("%s(%d)#probability", variationBaseKey, vIndex)
						local prob = getXMLInt(xmlFile, variationsProbKey)
						if prob == nil then break end 
								 
						table.insert(variationsObjects,{
							value = vIndex + 1,
							p = prob
						})
						vIndex = vIndex + 1
					end

					if #variationsObjects > 0 then
						newObject.variationIndex = weightedRandomChoice(variationsObjects)
					else
						-- Fallback sicuro se non ci sono variazioni definite nell'XML
						newObject.variationIndex = weatherObj:getRandomVariationIndex() or 1    
					end
				else
					print(string.format("SeasonGEO Warning: Il tipo di meteo richiesto (%d) non e' supportato dalla mappa per la stagione %d", targetWeatherType, season))
				end
            end
        end

        self:addWeatherForecast(newObject)
        table.insert(newObjects, newObject)
        lastItem = self.forecastItems[#self.forecastItems]

    end

    if xmlFile ~= nil then delete(xmlFile) end

	-- Fix per il Multiplayer: Se è un rebuild, bisogna mandare TUTTI gli oggetti, non solo i nuovi
    if #newObjects > 0 then 
		local objectsToBroadcast = newObjects
		if isRebuild then
			objectsToBroadcast = self.forecastItems
		end
		g_server:broadcastEvent(WeatherAddObjectEvent.new(objectsToBroadcast, isRebuild or false), false) 
	end
end

Weather.fillWeatherForecast = Utils.overwrittenFunction(Weather.fillWeatherForecast, SeasonGEO.manageForecasts)