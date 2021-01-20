INTERRUPTAWARE_SLUG, InterruptAware = ...
INTERRUPTAWARE_MSG_VERSION = GetAddOnMetadata( INTERRUPTAWARE_SLUG, "Version" )
INTERRUPTAWARE_MSG_ADDONNAME = GetAddOnMetadata( INTERRUPTAWARE_SLUG, "Title" )
INTERRUPTAWARE_MSG_AUTHOR = GetAddOnMetadata( INTERRUPTAWARE_SLUG, "Author" )

-- Colours
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

InterruptAware_log = {}
InterruptAware.defeatedEnemiesList = {}
InterruptAware.playersInCombat = {}
InterruptAware.enemiesInCombat  = {}
InterruptAware.bossesInCombat = {}

function InterruptAware.Print( msg, showName )
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = string.format( "%s%s>%s %s",
				COLOR_NEON_BLUE, INTERRUPTAWARE_SLUG, COLOR_END, msg )
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end

LOG_CRITICAL = 1
LOG_ERROR = 2
LOG_WARNING = 3
LOG_INFO = 4
InterruptAware_options = { ["debugLevel"] = LOG_INFO }

function InterruptAware.LogMsg( msg, debugLevel, alsoPrint )
	-- debugLevel  (Always - nil), (Critical - 1), (Error - 2), (Warning - 3), (Info - 4)
	if( debugLevel == nil ) or
			( ( debugLevel and InterruptAware_options.debugLevel ) and InterruptAware_options.debugLevel >= debugLevel ) then
		table.insert( InterruptAware_log, { [time()] = (debugLevel and debugLevel..": " or "" )..msg } )
		if( alsoPrint ) then
			InterruptAware.Print( msg )
		end
	end
end
function InterruptAware.OnLoad()
	InterruptAwareFrame:RegisterEvent( "ADDON_LOADED" )
	InterruptAwareFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
	InterruptAwareFrame:RegisterEvent( "PLAYER_REGEN_DISABLED" )
end
function InterruptAware.ADDON_LOADED()
	InterruptAwareFrame:UnregisterEvent( "ADDON_LOADED" )
	local expireTS = time() - 604800
	local pruneCount = 0
	local minPrune = time()
	local maxPrune = 0
	local doPrune = true
	while( doPrune ) do
		if( InterruptAware_log and InterruptAware_log[1] ~= nil ) then    -- has to exist, and have something at index 1
			for ts, _ in pairs( InterruptAware_log[1] ) do           -- look in the pairs, since we don't know the key value
				if( ts < expireTS ) then                        -- if this is too old, remove it
					maxPrune = math.max( maxPrune, ts )
					minPrune = math.min( minPrune, ts )
					table.remove( InterruptAware_log, 1 )
					pruneCount = pruneCount + 1
				else                                            -- all others will be too young to delete, stop
					doPrune = false
				end
			end
		else                                                    -- nothing exists to process
			doPrune = false
		end
	end
	if( pruneCount > 0 ) then
		InterruptAware.LogMsg( "Pruned "..pruneCount.." log entries, from "..
			date( "%c", minPrune ).." to "..date( "%c", maxPrune )..".", LOG_INFO, true )  -- set to (info - 4)?
	end
end
function InterruptAware.ResetCombatData()
	InterruptAware.LogMsg( "ResetCombatData", LOG_INFO )
	InterruptAware.playersInCombat = {}
	InterruptAware.enemiesInCombat = {}
	InterruptAware.bossesInCombat = {}
	InterruptAware.defeatedEnemiesList = {}
	InterruptAware.fightHadBosses = false
	InterruptAware.fightHadEnemies = false
	--playerInCombat = false
	--runningCombatCheck = false
	--playersWereInCombat = false
	maxDefeated = 0
end
--[[
function EgoBooster:enterCombatChecks(input)

	resetCombatData()

	playerInCombat = true
	if not cleaningIsRunning then
		cleanDefeatedList()
	end

end
]]

InterruptAware.reportEvents = {
	["SPELL_AURA_BROKEN"]  = true,
	["SPELL_AURA_BROKEN_SPELL"] = true,
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_INTERRUPT"] = true,
}
function InterruptAware.PLAYER_REGEN_DISABLED()
	InterruptAware.ResetCombatData()

end
function InterruptAware.COMBAT_LOG_EVENT_UNFILTERED()
	-- ignore pvp
	if UnitIsPVP("player") then
		return
	end

	local _, t, _, sourceID, sourceName, sourceFlags, sourceRaidFlags,
			destID, destName, destFlags, _, spellID, spName, _, ext1, ext2, ext3 = CombatLogGetCurrentEventInfo()


	-- test and set flag if player is inCombat...  ?  Is this needed?
	if ( destID == UnitGUID("player") and sourceID ~= UnitGUID("player") )
		or ( destID ~= UnitGUID("player") and sourceID == UnitGUID("player") ) then
		playerInCombat = true
		--InterruptAware.LogMsg( "Player is in combat.", LOG_INFO )
	else
		--InterruptAware.LogMsg( "Player is NOT in combat.", LOG_INFO )
		return
	end

	-- skip actions from defeated enemies
	for _, defID in pairs(InterruptAware.defeatedEnemiesList) do
		local filterID = strmatch(defID, "(.+)>>>")
		if filterID == destID or filterID == sourceID then
			return
		end
	end

	--skip outsiders
	if bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) > 0
		and bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) > 0 then
			--InterruptAware.LogMsg( t..": Skipping outsider.", LOG_INFO )
			return
	end

		-- skip events that have nil values for src or dst, but allow death events
	if t ~= "PARTY_KILL" and t ~= "UNIT_DIED" and t ~= "UNIT_DESTROYED" and t ~= "UNIT_DISSIPATES" and not string.find(t, "_INSTAKILL")
			and (not sourceName or not destName ) then
		--InterruptAware.LogMsg( t..": Nil src or dest for non-kill event.", LOG_INFO )
		return
	end

	-- skip is self buff or auras
	if( sourceID == destID or sourceName == destName ) then
		return
	end

	local hostileDest = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
	local hostileSource = bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0

	local isPlayer = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
	local isInList = false

	if isPlayer then
		for _,v in pairs( InterruptAware.playersInCombat ) do
			if v == sourceID then
				isInList = true
				break
			end
		end
	end
	if not isInList and isPlayer then
		--print("add new player", sourceName)
		playersWereInCombat = true
		table.insert( InterruptAware.playersInCombat, sourceID )
		InterruptAware.LogMsg( "Adding "..sourceName.." to playersInCombat. Current #"..#InterruptAware.playersInCombat )
	end

	local enemyInList = false

	local enemyIDToCheck = destID
	if not playerSource and sourceName then
		enemyIDToCheck = sourceID
	end

	local isUnitKilled = false

	if t == "PARTY_KILL" or t == "UNIT_DIED" or t == "UNIT_DESTROYED" or t == "UNIT_DISSIPATES" or string.find(t, "_INSTAKILL") then
		isUnitKilled = true
		InterruptAware.LogMsg( destName .." killed by "..sourceName )
	end

	if not isUnitKilled and (hostileDest or hostileSource) and not string.find(enemyIDToCheck, "Player") then
		local updateEnemyIndex

		for i, v in pairs( InterruptAware.enemiesInCombat ) do
			if v == enemyIDToCheck then
				updateEnemyIndex = i
				enemyInList = true
				break
			end
		end
		if not enemyInList then
			for _, v in pairs( InterruptAware.bossesInCombat ) do
				if v == enemyIDToCheck then
					enemyInList = true
					break
				end
			end
		else
			-- check if enemy was boss and update lists
			for i = 1, 10 do
				if enemyIDToCheck == UnitGUID( "boss"..i ) then
					InterruptAware.LogMsg( "change to boss "..destName..":"..sourceName.." "..enemyIDToCheck, LOG_INFO )
					isEnemyBoss = true
					InterruptAware.fightHadBosses = true
					table.insert( InterruptAware.bossesInCombat, enemyIDToCheck )
					table.remove( InterruptAware.enemiesInCombat, updateEnemyIndex )
					if #InterruptAware.enemiesInCombat == 0 then
						InterruptAware.fightHadEnemies = false
					end
				end
			end
		end
	end
	if not enemyInList and not isUnitKilled and (hostileDest or hostileSource)
			and not string.find( enemyIDToCheck, "Player" ) -- enemy is not player
			and not( string.find( destName, "Explosives" ) or string.find( sourceName, "Explosives" ) ) -- Ignore Explosives Affix
			then
		-- add enemy
		local isEnemyBoss = false

		for i = 1, 10 do
			if enemyIDToCheck == UnitGUID( "boss"..i ) then
				InterruptAware.LogMsg( "add boss "..t.." "..destName.." : "..sourceName.." = "..enemyIDToCheck, LOG_INFO )
				isEnemyBoss = true
				InterruptAware.fightHadBosses = true
				table.insert( bossesInCombat, enemyIDToCheck )
			end
		end
		if not isEnemyBoss then
			InterruptAware.LogMsg( "add enemy "..t.." "..destName.." : "..sourceName.." = "..enemyIDToCheck, LOG_INFO )
			InterruptAware.fightHadEnemies = true
			maxDefeated = maxDefeated + 1
		end

	end
--	InterruptAware.LogMsg( table.concat( { t,
--			(sourceID or "no sourceID"), (sourceName or "no sourceName"), (sourceFlags or "no sourceFlags"), (sourceRaidFlags or "no sourceRaidFlags"),
--			(destID or "no destID"), (destName or "no destName"), (destFlags or "no destFlags"), " ",
--			spellID, spName, " ", (ext1 or "no ext1"), (ext2 or "no ext2"), (ext3 or "no ext3") }, "," ), LOG_INFO, false )


	sourceName = sourceName or "unknown"
	destName = destName or "unknown"
	spName = (spName and (type(spName) == "boolean" and (spName and "true" or "false")) or "no spell?" )

	--InterruptAware.LogMsg( t..": "..GetSpellLink( spellID ).." from "..sourceName.." on "..destName, LOG_INFO, true )
	--InterruptAware.LogMsg( t..": "..spName.." from "..sourceName.." on "..destName, LOG_INFO, true )
	--InterruptAware.LogMsg( t..": "..sourceName.." -> "..destName, LOG_INFO, true )


	if InterruptAware.reportEvents[t] and sourceID ~= destID then
		--InterruptAware.LogMsg( "Tracking "..t, LOG_INFO, true )
		--InterruptAware.LogMsg( t.." <<<"..spellID..">>> on "..destName.." removed by "..sourceName, LOG_INFO, true )
		InterruptAware.LogMsg( date( "(%c) ", time() )..t..": "..GetSpellLink( spellID) .. "\124r\124h\124h on \124cffff0000"..destName.."\124r\124h\124h removed by "..sourceName, nil, false )
		InterruptAware.LogMsg( table.concat( {t, sourceID, sourceName, sourceFlags, destID, destName, destFlags, "SpellID:", spellID, spName}, "," ), LOG_INFO, false )
	else
		--InterruptAware.LogMsg( t, LOG_INFO, true )
	end


--[[



		elseif hostileDest and playerSource and (t == "SPELL_AURA_REFRESH" or t == "SPELL_AURA_APPLIED") and spellID ~= 24131 and spellInList(spellID, SpellsInfo.cc) then
				--print("new cc")
if (t == "SPELL_AURA_BROKEN_SPELL" or t == "SPELL_AURA_BROKEN" or t == "SPELL_AURA_REMOVED") and spellID ~= 24131 and hostileDest and spellInList(spellID, SpellsInfo.cc) then
if t == "SPELL_AURA_BROKEN" then
				local chatMsg = "<<<"..spellID..">>> on " .. destName .. " removed by " .. sourceName
				local playerMsg = GetSpellLink(spellID) .. "\124r\124h\124h on \124cffff0000" .. destName .."\124r\124h\124h removed by " .. unitColor(sourceID) .. sourceName
				if nextMsgTime < time() then
					print("\124Hplayer::CombatInfo:"..time()..":"..chatMsg.."\124h\124cff8888ff[Info]\124r\124h\124h: " .. playerMsg)
					nextMsgTime = time() + 1
				end

			elseif t == "SPELL_AURA_BROKEN_SPELL" then
				local chatMsg = "<<<"..spellID..">>> on " .. destName .. " removed by " .. sourceName .."'s " .. ">>>"..ext1.."<<<"
				local playerMsg = GetSpellLink(spellID) .. "\124r\124h\124h on \124cffff0000" .. destName .."\124r\124h\124h removed by " .. unitColor(sourceID) .. sourceName .. "'s " .. GetSpellLink(ext1)
				if nextMsgTime < time() then
					print("\124Hplayer::CombatInfo:"..time()..":"..chatMsg.."\124h\124cff8888ff[Info]\124r\124h\124h: " .. playerMsg)
					nextMsgTime = time() + 1
				end

			elseif expired then
				local chatMsg = "<<<"..spellID.. ">>> on " .. destName .. " expired"
				local playerMsg = GetSpellLink(spellID) .. "\"\124r\124h\124h on \124cffff0000" .. destName .."\124r\124h\124h expired"
				if nextMsgTime < time() then
					print("\124Hplayer::CombatInfo:"..time()..":"..chatMsg.."\124h\124cff8888ff[Info]\124r\124h\124h: " .. playerMsg)
					nextMsgTime = time() + 1
				end

			elseif t == "SPELL_AURA_REMOVED" then
				local chatMsg = "<<<"..spellID.. ">>> on " .. destName .. " removed"
				local playerMsg = GetSpellLink(spellID) .. "\"\124r\124h\124h on \124cffff0000" .. destName .."\124r\124h\124h removed"
				if nextMsgTime < time() then
					print("\124Hplayer::CombatInfo:"..time()..":"..chatMsg.."\124h\124cff8888ff[Info]\124r\124h\124h: " .. playerMsg)
					nextMsgTime = time() + 1
				end

			end
]]
end
