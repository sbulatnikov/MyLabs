--------------------------------------------------------------------------------
-- MyLabs / Main.lua — запуск, события, реакции, команды чата:
--   /mylabs            — открыть или закрыть окно
--   /mylabs auto off   — выключить автоматику (сбор, запуск, сундучки); /mylabs auto on — включить
--   /mylabs reset      — забыть рога текущего персонажа (строки соберутся заново из разговоров)
--------------------------------------------------------------------------------
local UI, C = ML.UI, ML.Core
local started = false

-- Кнопка может прислать реакцию дважды: при нажатии (active = true) и при
-- отпускании (active = false). Обрабатываем щелчок один раз.
local pressed = {}
local function Click( name, fn )
	return function( params )
		local w = params.widget
		local key = name .. ":" .. tostring( w and w:GetInstanceId() or params.sender )
		if params.active == true then
			pressed[ key ] = true
		elseif params.active == false and pressed[ key ] then
			pressed[ key ] = nil
			return
		end
		fn( params )
	end
end

-- щелчок по кнопке сразу после перетаскивания окно не открывает
local dragEnd = nil
local function ButtonDragMoved()
	local id = DnD.Dragging
	local w = id and DnD.Widgets and DnD.Widgets[ id ]
	if not w or w.wtMovable:GetName() ~= "MLHost" then return false end
	local p, r = DnD.Place, DnD.Reset
	return ( p and r and ( p.posX ~= r.posX or p.posY ~= r.posY ) ) and true or false
end

local function OnMain()
	if ButtonDragMoved() then return end
	if dragEnd and ML.tick - dragEnd <= 1 then
		dragEnd = nil
		return
	end
	dragEnd = nil
	UI.ToggleWindow()
end

local CLICKS = {
	ml_main = OnMain,
	ml_close = function() UI.ShowWindow( false ) end,
	ml_char = UI.OnChar,
	ml_assign = UI.OnAssign,
	ml_chest = UI.OnChest,
	ml_menu_pick = UI.OnMenuPick,
	ml_menu_close = UI.CloseMenu,
}

local function OnSecond()
	ML.tick = ML.tick + 1
	C.OnSecond()
	UI.OnSecond()
end

--@debug
-- Разведка (только отладочная сборка): что игра отдаёт по сражениям — посещения за день и неделю,
-- лимиты, тип «грабительский налёт». Нужна, чтобы понять, откуда брать число ограблений.
local function BattleLine( id )
	local info = matchMaking.GetEventInfo( id )
	if type( info ) ~= "table" then return "id=" .. tostring( id ) .. ": описания нет", false end
	local kinds = {}
	if type( info.eventType ) == "table" then
		for k, _ in pairs( info.eventType ) do kinds[ #kinds + 1 ] = tostring( k ) end
	end
	local pillage = type( info.eventType ) == "table" and info.eventType.pillage ~= nil
	return "«" .. ML.Text( info.name ) .. "» тип=" .. table.concat( kinds, "+" )
		.. " сегодня=" .. tostring( info.todayVisits ) .. "/" .. tostring( info.maxVisitsPerDay )
		.. " неделя=" .. tostring( info.weeklyVisits ) .. "/" .. tostring( info.maxVisitsPerWeek )
		.. " сложность=" .. ML.Text( info.difficulty ) .. " (" .. tostring( info.sysDifficultyMode ) .. ")"
		.. " механика=" .. tostring( info.mechanicsType )
		.. " доступно=" .. tostring( info.isAvailable ) .. " причина=" .. tostring( info.sysCause )
		.. " id=" .. tostring( id ), pillage
end

local function BattlesDump( why, all )
	local valid = matchMaking.IsEventListValid()
	ML.Log( "сражения (" .. why .. "): можно пользоваться=" .. tostring( matchMaking.CanUseMatchMaking() ) .. ", список получен=" .. tostring( valid ) )
	if not valid then return end
	local ids = matchMaking.GetEvents()
	if type( ids ) ~= "table" then
		ML.Log( "сражения: GetEvents вернул " .. tostring( ids ) )
		return
	end
	local total, shown = 0, 0
	for _, id in pairs( ids ) do
		total = total + 1
		local line, pillage = BattleLine( id )
		if all or pillage then
			shown = shown + 1
			ML.Log( ( pillage and "НАЛЁТ " or "сражение " ) .. line )
		end
	end
	ML.Log( "сражения: всего " .. total .. ", выписано " .. shown .. ( all and "" or " (только налёты; все — /mylabs battles)" ) )
end

local function OnBattlesChanged()
	BattlesDump( "список изменился", false )
end

local function OnBattleVisits( p )
	local line, pillage = BattleLine( p.eventId )
	ML.Log( "посещения изменились: " .. ( pillage and "НАЛЁТ " or "" ) .. line )
end

-- /mylabs battles: просим игру присылать список сражений и выписываем его целиком
local function BattlesCommand()
	if matchMaking.CanUseMatchMaking() then matchMaking.ListenEvents( true ) end
	BattlesDump( "команда", true )
	ML.Chat( "сражения выписаны в Personal\\Logs\\mods.txt" )
end
--@end

local function OnSlash( p )
	local text = ML.Lower( ML.Trim( ML.S( p.text ) ) )
	if string.sub( text, 1, 7 ) ~= "/mylabs" then return end
	local rest = ML.Trim( string.sub( text, 8 ) )
	if rest == "" then
		UI.ToggleWindow()
	elseif rest == "auto on" or rest == "auto off" then
		ML.db.auto = rest == "auto on"
		C.Changed()
		ML.Chat( ML.db.auto and "автоматика включена: сбор и запуск при разговоре с рогом, открытие сундучков"
			or "автоматика выключена: аддон только записывает то, что видит" )
		if ML.db.auto then C.ChestSoon( 1 ) end
	elseif rest == "reset" then
		C.ForgetHorns()
		ML.Chat( "рога этого персонажа забыты. Поговорите с каждым рогом — строки соберутся заново" )
	--@debug
	elseif rest == "debug" then
		ML.DEBUG = not ML.DEBUG
		C.Changed()
		ML.Chat( "отладка " .. ( ML.DEBUG and "включена: Personal\\Logs\\mods.txt" or "выключена" ) )
	elseif rest == "battles" then
		BattlesCommand()
	--@end
	else
		ML.Chat( "версия " .. ML.VERSION .. ". /mylabs — окно; /mylabs auto on|off — автоматика; /mylabs reset — забыть рога персонажа" )
	end
end

local function On( ev, fn )
	common.RegisterEventHandler( fn, ev )
end

local function Start()
	if started then return end
	started = true
	C.Init()
	UI.Init()
	C.OnChanged( UI.Invalidate )

	DnD.Init( ML.W( "MLHost" ), ML.W( "MLButton" ), true, true )
	DnD.Init( ML.W( "MLWindow" ), ML.W( "Header" ), true, true )
	local stop = DnD.StopDragging
	DnD.StopDragging = function( ... )
		if ButtonDragMoved() then dragEnd = ML.tick end
		return stop( ... )
	end

	for name, fn in pairs( CLICKS ) do common.RegisterReactionHandler( Click( name, fn ), name ) end

	On( "EVENT_SECOND_TIMER", OnSecond )
	On( "EVENT_UNKNOWN_SLASH_COMMAND", OnSlash )
	On( "EVENT_INTERACTION_STARTED", C.OnInteraction )
	On( "EVENT_CURRENCY_VALUE_CHANGED", C.OnCurrency )
	On( "EVENT_CONTAINER_ITEM_ADDED", C.OnItemAdded )
	On( "EVENT_AVATAR_CLIENT_ZONE_CHANGED", C.OnZoneChanged )
	On( "EVENT_MATCH_MAKING_EVENTS_CHANGED", C.ReadVisits )
	On( "EVENT_MATCH_MAKING_EVENT_VISITS_CHANGED", C.OnVisitsChanged )

	UI.Render()
	ML.Log( "MyLabs " .. ML.VERSION .. " загружен" .. ( ML.db.auto and "" or ", автоматика выключена" ) ) --@debug
	--@debug
	On( "EVENT_MATCH_MAKING_EVENTS_CHANGED", OnBattlesChanged )
	On( "EVENT_MATCH_MAKING_EVENT_VISITS_CHANGED", OnBattleVisits )
	BattlesDump( "запуск", false )
	--@end
end

common.RegisterEventHandler( Start, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Start() end
