INTERUPTAWARE_SLUG, InteruptAware = ...
INTERUPTAWARE_MSG_VERSION = GetAddOnMetadata( INTERUPTAWARE_SLUG, "Version" )
INTERUPTAWARE_MSG_ADDONNAME = GetAddOnMetadata( INTERUPTAWARE_SLUG, "Title" )
INTERUPTAWARE_MSG_AUTHOR = GetAddOnMetadata( INTERUPTAWARE_SLUG, "Author" )

-- Colours
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

InteruptAware_log = {}

function InteruptAware.Print( msg, showName )
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = string.format( "%s%s>%s %s",
				COLOR_NEON_BLUE, INTERUPTAWARE_SLUG, COLOR_END, msg )
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end

LOG_CRITICAL = 1
LOG_ERROR = 2
LOG_WARNING = 3
LOG_INFO = 4
InteruptAware_options = { ["debugLevel"] = LOG_INFO }

function InteruptAware.LogMsg( msg, debugLevel, alsoPrint )
	-- debugLevel  (Always - nil), (Critical - 1), (Error - 2), (Warning - 3), (Info - 4)
	if( debugLevel == nil ) or
			( ( debugLevel and InteruptAware_options.debugLevel ) and InteruptAware_options.debugLevel >= debugLevel ) then
		table.insert( InteruptAware_log, { [time()] = (debugLevel and debugLevel..": " or "" )..msg } )
		if( alsoPrint ) then
			InteruptAware.Print( msg )
		end
	end
end
function InteruptAware.OnLoad()
	InteruptAwareFrame:RegisterEvent( "ADDON_LOADED" )
	InteruptAwareFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
end
function InteruptAware.ADDON_LOADED()
	InteruptAware:UnregisterEvent( "ADDON_LOADED" )
	local expireTS = time() - 604800
	local pruneCount = 0
	local minPrune = time()
	local maxPrune = 0
	local doPrune = true
	while( doPrune ) do
		if( InteruptAware_log and InteruptAware_log[1] ~= nil ) then    -- has to exist, and have something at index 1
			for ts, _ in pairs( InteruptAware_log[1] ) do           -- look in the pairs, since we don't know the key value
				if( ts < expireTS ) then                        -- if this is too old, remove it
					maxPrune = math.max( maxPrune, ts )
					minPrune = math.min( minPrune, ts )
					table.remove( InteruptAware_log, 1 )
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
		InteruptAware.LogMsg( "Pruned "..pruneCount.." log entries, from "..
			date( "%c", minPrune ).." to "..date( "%c", maxPrune ).."." )  -- set to (info - 4)?
	end
end
InteruptAware.reportEvents = {
	["SPELL_AURA_BROKEN"]  = true,
	["SPELL_AURA_BROKEN_SPELL"] = true,
	["SPELL_AURA_REMOVED"] = true,
}
function InteruptAware.COMBAT_LOG_EVENT_UNFILTERED()
	local _, t, _, sourceID, sourceName, sourceFlags, sourceRaidFlags,
			destID, destName, destFlags, _, spellID, spName, _, ext1, ext2, ext3 = CombatLogGetCurrentEventInfo()
	print( t )
	InteruptAware.LogMsg( t..": "..sourceName.." -> "..destName, LOG_INFO, true )

	if InteruptAware.reportEvents[t] then
		InteruptAware.LogMsg( "Tracking "..t, LOG_INFO, true )
		InteruptAware.LogMsg( "<<<"..spellID..">>> on "..destName.." removed by "..sourceName, LOG_INFO, true )
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
