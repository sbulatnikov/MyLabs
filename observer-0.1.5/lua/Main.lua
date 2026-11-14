--------------------------------------------------------------------------------
-- MyLabs / Main.lua
-- Запуск, подписки, команды чата:
--   /mylabs              — что делает аддон
--   /mylabs dump         — повторить отчёт (валюты, сумка, зона) в журнал
--   /mylabs mark текст   — поставить свою отметку в журнал
--   /mylabs chest [coral|N] [сколько|all] — сундучок хранителя: показать варианты или открыть
--------------------------------------------------------------------------------
local P = ML.Probe
local started = false

local function Guard( where, fn )
	return function( params )
		local ok, err = pcall( fn, params or {} )
		if not ok then ML.Log( "ОШИБКА в " .. tostring( where ) .. ": " .. tostring( err ) ) end
	end
end

local function On( ev, fn )
	local ok, err = pcall( common.RegisterEventHandler, Guard( ev, fn ), ev )
	if not ok then ML.Log( "не удалось подписаться на " .. ev .. ": " .. tostring( err ) ) end
end

local function OnSecond()
	ML.tick = ML.tick + 1
end

local function OnSlash( p )
	local text = ML.S( p.text )
	local low = string.lower( text )
	if string.sub( low, 1, 7 ) ~= "/mylabs" then return end
	local rest = string.gsub( string.sub( text, 8 ), "^%s+", "" )
	local lowRest = string.lower( rest )
	if lowRest == "dump" then
		P.Report( "по команде /mylabs dump", false )
		ML.Chat( "отчёт записан в Personal\\Logs\\mods.txt" )
	elseif string.sub( lowRest, 1, 5 ) == "chest" then
		local arg = string.gsub( string.gsub( string.sub( rest, 6 ), "^%s+", "" ), "%s+$", "" )
		P.Chest( arg )
	elseif string.sub( lowRest, 1, 4 ) == "mark" then
		local note = string.gsub( string.sub( rest, 5 ), "^%s+", "" )
		ML.Log( ">>> ОТМЕТКА (" .. ML.LocalStamp() .. "): " .. ML.Flat( note, 300 ) )
		ML.Chat( "отметка записана: " .. note )
	else
		ML.Chat( "версия " .. ML.VERSION .. ", запуск №" .. P.RunNo() )
		ML.Chat( "аддон только наблюдает и пишет в Personal\\Logs\\mods.txt" )
		ML.Chat( "/mylabs dump — повторить отчёт; /mylabs mark текст — отметка в журнале" )
		ML.Chat( "/mylabs chest — сундучок хранителя: показать варианты; /mylabs chest coral — взять коралл" )
	end
end

local function Start()
	if started then return end
	started = true

	On( "EVENT_SECOND_TIMER", OnSecond )
	On( "EVENT_UNKNOWN_SLASH_COMMAND", OnSlash )

	On( "EVENT_INTERACTION_STARTED", P.OnInteraction )

	On( "EVENT_CURRENCY_VALUE_CHANGED", P.OnCurrency( "валюта изменилась" ) )
	On( "EVENT_HIDDEN_CURRENCY_VALUE_CHANGED", P.OnCurrency( "скрытая валюта изменилась" ) )

	On( "EVENT_CONTAINER_ITEM_ADDED", P.OnItemAdded )
	On( "EVENT_AVATAR_ITEM_TAKEN", P.OnItemTaken )

	On( "EVENT_AVATAR_CLIENT_ZONE_CHANGED", P.OnZoneChanged )

	P.Report( "вход персонажем", true )
	ML.Chat( "версия " .. ML.VERSION .. ": наблюдаю и пишу в Personal\\Logs\\mods.txt. Команды: /mylabs" )
end

local SafeStart = Guard( "start", Start )
common.RegisterEventHandler( SafeStart, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then SafeStart() end
