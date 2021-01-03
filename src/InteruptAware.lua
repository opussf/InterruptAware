INTERUPTAWARE_SLUG, InteruptAware = ...
INTERUPTAWARE_MSG_VERSION = GetAddOnMetadata( INTERUPTAWARE_SLUG, "Version" )
INTERUPTAWARE_MSG_ADDONNAME = GetAddOnMetadata( INTERUPTAWARE_SLUG, "Title" )
INTERUPTAWARE_MSG_AUTHOR = GetAddOnMetadata( INTERUPTAWARE_SLUG, "Author" )

-- Colours
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

InteruptAware_log = {}

InteruptAware_options = { ["debugLevel"] = 1 }

function InteruptAware.Print( msg, showName )
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = string.format( "%s%s>%s %s",
				COLOR_NEON_BLUE, INTERUPTAWARE_SLUG, COLOR_END, msg )
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end

function InteruptAware.LogMsg( msg, debugLevel, alsoPrint )
	-- debugLevel  (Always - nil), (Critical - 1), (Error - 2), (Warning - 3), (Info - 4)
	if( debugLevel == nil ) or
			( ( debugLevel and InteruptAware_options.debugLevel ) and InteruptAware_options.debugLevel >= debugLevel ) then
		table.insert( InteruptAware_log, { [time()] = (debugLevel and debugLevel..": " or "" )..msg } )
		InteruptAware.Print( msg )
	end
end
function InteruptAware.OnLoad()
	InteruptAwareFrame:RegisterEvent( "ADDON_LOADED" )
	InteruptAwareFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
end
function InteruptAware.ADDON_LOADED()
end
function InteruptAware.COMBAT_LOG_EVENT_UNFILTERED()
end
--[[
function StripDice.VARIABLES_LOADED()
	StripDiceFrame:UnregisterEvent( "VARIABLES_LOADED" )
	StripDice.LogMsg( "v"..STRIPDICE_MSG_VERSION.." loaded." )
	local expireTS = time() - 604800
	local pruneCount = 0
	local minPrune = time()
	local maxPrune = 0
	local doPrune = true
	while( doPrune ) do
		if( StripDice_log and StripDice_log[1] ~= nil ) then    -- has to exist, and have something at index 1
			for ts, _ in pairs( StripDice_log[1] ) do           -- look in the pairs, since we don't know the key value
				if( ts < expireTS ) then                        -- if this is too old, remove it
					maxPrune = math.max( maxPrune, ts )
					minPrune = math.min( minPrune, ts )
					table.remove( StripDice_log, 1 )
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
		StripDice.LogMsg( "Pruned "..pruneCount.." log entries, from "..
			date( "%c", minPrune ).." to "..date( "%c", maxPrune ).."." )  -- set to (info - 4)?
	end
end
function StripDice.GROUP_ROSTER_UPDATE()
	local NumGroupMembers = GetNumGroupMembers()
	if( NumGroupMembers == 0 ) then  -- turn off listening
		if( StripDice.gameActive ) then
			StripDice.LogMsg( "Deactivating Dice game.", 4 )
		end
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_SYSTEM" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_SAY" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_PARTY" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_PARTY_LEADER" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_RAID" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_RAID_LEADER" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_RAID_WARNING" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_INSTANCE_CHAT" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_INSTANCE_CHAT_LEADER" )
		StripDiceFrame:UnregisterEvent( "CHAT_MSG_YELL" )
		StripDice.StopGame()
		StripDice.gameActive = nil
	elseif( NumGroupMembers > 0 and not StripDice.gameActive ) then
		StripDice.LogMsg( "Dice game is active with "..NumGroupMembers.." in the group.", 4 )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_SYSTEM" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_SAY" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_PARTY" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_PARTY_LEADER" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_RAID" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_RAID_LEADER" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_RAID_WARNING" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_INSTANCE_CHAT" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_INSTANCE_CHAT_LEADER" )
		StripDiceFrame:RegisterEvent( "CHAT_MSG_YELL" )
		StripDice.gameActive = true
	end
end
function StripDice.RemoveIconFromOtherSettings( iconValue, skipTableName )
	-- take the iconValue to search for
	-- skip the named table
	local popTable = { ["lowIcon"] = true, ["highIcon"] = true }
	for settingTable, struct in pairs( StripDice_options ) do
		--StripDice.LogMsg( "Table: "..settingTable, true )
		if( settingTable ~= skipTableName ) then
			--StripDice.LogMsg( "Remove from table", true )
			for i, val in pairs( struct ) do
				--StripDice.LogMsg( "table: "..settingTable.." value: "..val.." =? "..iconValue.."  index: "..i, true )
				if( val == iconValue ) then
					--StripDice.LogMsg( "Matched value, remove it.", true )
					if( popTable[settingTable] ) then
						--StripDice.LogMsg( "Popping from table at pos: "..i, true )
						table.remove( StripDice_options[settingTable], i )
					else
						--StripDice.LogMsg( "Setting index "..i.." to nil.", true )
						StripDice_options[settingTable][i] = nil
					end
				end
			end
		end
	end
end
function StripDice.ReportSettings()
	StripDice.LogMsg( "Show settings", 4 )  -- Info
	local reportTables = {
			{ ["t"] = "highIcon", ["str"] = "High" },
			{ ["t"] = "lowIcon", ["str"] = "Low" }
	}
	local reportTable = {}
	for _, struct in ipairs( reportTables ) do
		local count = 0
		local iconList = {}
		for _, iconNum in ipairs( StripDice_options[struct.t] or {} ) do
			for iconName, num in pairs( StripDice.raidIconValues ) do
				if( num == iconNum ) then
					table.insert( iconList, "{"..iconName.."}" )
				end
			end
		end
		if( #iconList > 0 ) then
			table.insert( reportTable, string.format( "%s: %s", struct.str, table.concat( iconList, ", " ) ) )
		end
	end
	local iconList = {}
	for val, iconNum in pairs( StripDice_options.specificRollIcon or {} ) do
		for iconName, num in pairs( StripDice.raidIconValues ) do
			if( num == iconNum ) then
				table.insert( iconList, val.."-{"..iconName.."}" )
			end
		end
	end
	if( #iconList > 0 ) then
		table.insert( reportTable, string.format( "Specific: %s", table.concat( iconList, ", " ) ) )
	end

	if( #reportTable > 0 ) then
		StripDice.LogMsg( table.concat( reportTable, ", " ) ) -- nil = always
	end
end
StripDice.PLAYER_ENTERING_WORLD = StripDice.GROUP_ROSTER_UPDATE
function StripDice.CHAT_MSG_SAY( ... )
	_, msg, language, _, _, other = ...
	msg = string.lower( msg )
	if( string.find( msg, "settings" ) ) then -- report the settings
		StripDice.ReportSettings()
	elseif( string.find( msg, "set" ) ) then  -- set is the key word here
		--print( msg )
		local hl = string.match( msg, "(low)" ) or string.match( msg, "(high)" )
		if( hl ) then
			local variableName = hl.."Icon"
			local index = 0
			for testString in string.gmatch( msg, "%S+" ) do
				--StripDice.LogMsg( "testString: "..testString, true )
				for iconName, iconValue in pairs( StripDice.raidIconValues ) do
					if( string.match( testString, iconName ) ) then
						if( index == 0 ) then StripDice_options[variableName] = {}; end
						index = index + 1
						StripDice_options[variableName][index] = ( iconValue > 0 and iconValue or nil )
						StripDice.RemoveIconFromOtherSettings( iconValue, variableName )
					end
				end
			end
		else  -- until the above is refactored to include this setting
			local value = tonumber( string.match( msg, "(%d+)" ) )
			if( value ) then
				--print( "value: "..value )
				for testString in string.gmatch( msg, "%S+" ) do
					for iconName, iconValue in pairs( StripDice.raidIconValues ) do
						if( string.match( testString, iconName ) ) then
							--StripDice.LogMsg( "Found "..iconName.." in msg", true )
							if( not StripDice_options.specificRollIcon ) then
								StripDice_options.specificRollIcon = {}
							end
							StripDice_options.specificRollIcon[value] = ( iconValue > 0 and iconValue or nil )
							StripDice.RemoveIconFromOtherSettings( iconValue, "specificRollIcon" )
						end
					end
				end
			end
		end
		StripDice.ReportSettings()
	elseif( string.find( msg, "roll" ) ) then  -- roll starts a roll
		--StripDice.LogMsg( "msg:"..msg, true )
		StripDice.StopGame()
		StripDice.currentGame = time()
		StripDice_games[ StripDice.currentGame ] = {}
		StripDice.LogMsg( "A roll has been started.  Game: "..StripDice.currentGame )

		local pruneCount = 0
		for gameTS in pairs( StripDice_games ) do
			if( gameTS + 604800 < StripDice.currentGame ) then
				StripDice_games[gameTS] = nil
				pruneCount = pruneCount + 1
			end
		end
		if( pruneCount > 0 ) then
			StripDice.LogMsg( "Pruned "..pruneCount.." old games.", 4 )
		end
	elseif( StripDice.currentGame and StripDice.currentGame + 60 < time() ) then  -- game is started, and older than 1 minute
		StripDice.LogMsg( "Game timed out" )
		StripDice.StopGame()
	end
end
StripDice.CHAT_MSG_PARTY = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_PARTY_LEADER = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_RAID = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_RAID_LEADER = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_RAID_WARNING = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_INSTANCE_CHAT = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_INSTANCE_CHAT_LEADER = StripDice.CHAT_MSG_SAY
StripDice.CHAT_MSG_YELL = StripDice.CHAT_MSG_SAY

function StripDice.CHAT_MSG_SYSTEM( ... )
	_, roll = ...
	--StripDice.Print( roll )
	local found, _, who, roll, low, high = string.find( roll, "(.+) rolls (%d+) %((%d+)%-(%d+)%)")
	if( found ) then
		roll = tonumber( roll )
		low = tonumber( low )
		high = tonumber( high )
		StripDice.LogMsg( who.." rolled a "..roll.." in the range of ("..low.." - "..high..")", 4 ) -- info
		if( StripDice.currentGame and StripDice.currentGame + 60 >= time() ) then
			if( StripDice_games[StripDice.currentGame][who] ) then
				DoEmote( "No", who )
				StripDice.LogMsg( who.." has already rolled." )
			else
				StripDice_games[StripDice.currentGame][who] = roll
			end
			-- build sorted rolls table
			local rolls = {}
			for _,rolled in pairs( StripDice_games[StripDice.currentGame] ) do
				table.insert( rolls, rolled )
			end
			table.sort( rolls )

			-- build min and max from rolls
			StripDice.min = {}
			StripDice.max = {}
			local numRolls = #rolls
			for i = 1, numRolls do
				--print( i..": "..rolls[i] )
				table.insert( StripDice.min, rolls[i] )
				table.insert( StripDice.max, rolls[numRolls - (i-1)] )
			end

			local numHigh = #StripDice_options.highIcon
			local numLow = #StripDice_options.lowIcon

			--print( "I have "..#rolls.." rolls." )
			--print( "I need "..numHigh.." high rolls, and "..numLow.." low rolls ("..( numHigh + numLow )..")" )

			-- find how many of what I need.
			while( #rolls < ( numHigh + numLow ) ) do
				if( numHigh > numLow ) then
					--print( "High - 1" )
					numHigh = numHigh - 1
				elseif( numLow > numHigh ) then
					numLow = numLow - 1
					--print( "Low - 1" )
				else
					--print( "Both - 1" )
					numLow = numLow - 1
					numHigh = numHigh - 1
				end
			end
			-- reset to at least 1
			if( numHigh == 0 and #StripDice_options.highIcon >= 1 ) then numHigh = 1; end
			if( numLow  == 0 and #StripDice_options.lowIcon >= 1 ) then numLow  = 1; end

			numHigh = math.min( numHigh, #StripDice_options.highIcon )
			numLow = math.min( numLow, #StripDice_options.lowIcon )

			StripDice.LogMsg( "I need "..numHigh.." high rolls, and "..numLow.." low rolls ("..( numHigh + numLow )..")", 4 )
			StripDice.LogMsg( "high icon count: "..#StripDice_options.highIcon.."   low icon count: "..#StripDice_options.lowIcon, 4 )

			-- find who has the top n rolls
			--print( "Find Max" )
			StripDice.maxWho = {}
			local who = {}
			for rollIndex = 1, numHigh do
				rollValue = StripDice.max[rollIndex]
				for name, roll in pairs( StripDice_games[StripDice.currentGame] ) do
					if( roll == rollValue and who[name] == nil ) then
						who[name] = roll
						table.insert( StripDice.maxWho, name )
					end
				end
				--print( "rollIndex: "..rollIndex.." rollValue: "..rollValue )
			end

			--print( "Find Min" )
			StripDice.minWho = {}
			who = {}
			for rollIndex = 1, numLow do
				rollValue = StripDice.min[rollIndex]
				for name, roll in pairs( StripDice_games[StripDice.currentGame] ) do
					if( roll == rollValue and who[name] == nil ) then
						who[name] = roll
						table.insert( StripDice.minWho, name )
					end
				end
				--print( "rollIndex: "..rollIndex.." rollValue: "..rollValue )
			end
			for i,name in ipairs( StripDice.minWho ) do
				if( not name or not StripDice_options.lowIcon[i] ) then
					StripDice.LogMsg( "Icon: "..(StripDice_options.lowIcon[i] or "nil" ) )
					StripDice.LogMsg( "Name: "..(name or "nil" ) )
				end
				StripDice.LogMsg( "Min: Put "..(StripDice_options.lowIcon[i] or "nil?").." on "..( name or "nil?"), 4 )
				SetRaidTarget( name, ( StripDice_options.lowIcon[i] or 0 ) )
			end
			for i,name in ipairs( StripDice.maxWho ) do
				StripDice.LogMsg( "Max: Put "..StripDice_options.highIcon[i].." on "..name, 4 )
				SetRaidTarget( name, ( StripDice_options.highIcon[i] or 0 ) )
			end
			--print( "Find Specific" )
			StripDice.specificWho = {}
			for name, roll in pairs( StripDice_games[StripDice.currentGame] ) do
				if( StripDice_options.specificRollIcon and StripDice_options.specificRollIcon[roll] ) then
					StripDice.LogMsg( "Specific: Put "..StripDice_options.specificRollIcon[roll].." on "..name, 4 )
					table.insert( StripDice.specificWho, name )
					SetRaidTarget( name, ( StripDice_options.specificRollIcon[roll] or 0 ) )
				end
			end
		end
	end
end
function StripDice.StopGame()
	-- @TODO  'fix this too'
	StripDice.currentGame = nil
	if( StripDice.minWho ) then  -- Remove the icons
		for _,name in pairs( StripDice.minWho ) do
			SetRaidTarget( name, 0 )
		end
	end
	StripDice.min = nil
	StripDice.minWho = nil
	if( StripDice.maxWho ) then  -- Remove the icons
		for _,name in pairs( StripDice.maxWho ) do
			SetRaidTarget( name, 0 )
		end
	end
	StripDice.max = nil
	StripDice.maxWho = nil
	-- specificWho
	if( StripDice.specificWho ) then
		for _,name in pairs( StripDice.specificWho ) do
			SetRaidTarget( name, 0 )
		end
	end
	StripDice.specificWho = nil
end
]]
