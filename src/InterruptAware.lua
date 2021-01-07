INTERRUPTAWARE_SLUG, InterruptAware = ...
INTERRUPTAWARE_MSG_VERSION = GetAddOnMetadata( INTERRUPTAWARE_SLUG, "Version" )
INTERRUPTAWARE_MSG_ADDONNAME = GetAddOnMetadata( INTERRUPTAWARE_SLUG, "Title" )
INTERRUPTAWARE_MSG_AUTHOR = GetAddOnMetadata( INTERRUPTAWARE_SLUG, "Author" )

-- Colours
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

InterruptAware_log = {}

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
InterruptAware.reportEvents = {
	["SPELL_AURA_BROKEN"]  = true,
	["SPELL_AURA_BROKEN_SPELL"] = true,
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_INTERRUPT"] = true,
}
function InterruptAware.COMBAT_LOG_EVENT_UNFILTERED()
	-- ignore pvp
	if UnitIsPVP("player") then
		return
	end

	local _, t, _, sourceID, sourceName, sourceFlags, sourceRaidFlags,
			destID, destName, destFlags, _, spellID, spName, _, ext1, ext2, ext3 = CombatLogGetCurrentEventInfo()

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
		InterruptAware.LogMsg( t..": "..GetSpellLink( spellID) .. "\124r\124h\124h on \124cffff0000"..destName.."\124r\124h\124h removed by "..sourceName, LOG_INFO, false )
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
