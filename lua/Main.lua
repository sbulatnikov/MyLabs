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

	UI.Render()
	ML.Log( "MyLabs " .. ML.VERSION .. " загружен" .. ( ML.db.auto and "" or ", автоматика выключена" ) ) --@debug
end

common.RegisterEventHandler( Start, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Start() end
