-- Прогон MyLabs на заглушках API игры.
--   texlua run.lua <папка Scripts собранного аддона> <tree.lua>
-- Файл хранится в UTF-8; перед запуском переводится в Windows-1251 (как и скрипты аддона): см. test/run.sh
local dir, treeFile = arg[ 1 ], arg[ 2 ]
local out, all, fails, checks = {}, {}, 0, 0
local handlers, reactions = {}, {}
local stored = { MyLabs = { runs = 9, lastRun = "наблюдатель 0.1.5" } }   -- секции настроек (переживают «перезаход»)
local clock = 1794570000000              -- серверное время, мс
local calls = 0                          -- сколько раз аддон обратился к API игры

local function check( cond, what )
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print( "  НЕ ПРОШЛО: " .. what )
	end
end
local function section( title ) print( "== " .. title ) end

function Global( name, v ) _G[ name ] = v end
local function W( s ) return { w = s } end

-- хранилище игры не хранит пустые таблицы и функции: копируем так же
local function Clone( t )
	if type( t ) ~= "table" then return t end
	local r, n = {}, 0
	for k, v in pairs( t ) do
		local c = Clone( v )
		if type( c ) ~= "function" and not ( type( c ) == "table" and next( c ) == nil ) then r[ k ] = c n = n + 1 end
	end
	return r
end

--------------------------------------------------------------------------------
-- Мир: персонаж, рога, валюты, сумка
--------------------------------------------------------------------------------
local VOL = { money = 40170, granite = 100, coral = 100, tear_rare = 30, tear_epic = 20, embrium = 20, multiplier = 100 }
local LAUNCH = {
	{ key = "gold", name = "<html>Чеканить монеты в количестве <r name=\"value\"/> золотых</html>", value = 40170, product = "Золото" },
	{ key = "tear1", name = "Производить сияющие слёзы дракона (легендарные) в количестве <r name=\"value\"/> шт.", value = 30, product = "Сияющие слёзы дракона" },
	{ key = "tear2", name = "Производить сверкающие слёзы дракона (чудесного качества) в количестве <r name=\"value\"/> шт.", value = 20, product = "Сверкающие слёзы дракона" },
	{ key = "granite", name = "Материализовать астральный гранит в количестве <r name=\"value\"/> ед.", value = 100, product = "Астральный гранит" },
	{ key = "coral", name = "Материализовать астральный коралл в количестве <r name=\"value\"/> ед.", value = 100, product = "Астральный коралл" },
}
local world = nil
local talk = nil                         -- { id, name, cue, answers, horn }
local selected = {}                      -- что аддон выбрал в разговорах: { "рог:ответ" }
local pump = {}                          -- отложенные события
local syncEvents = false                 -- true: ответ рога приходит прямо внутри SelectInteractorCue
local Fire

local function Busy( product )
	for _, h in ipairs( world.horns ) do
		if h.state == "busy" and h.product == product then return true end
	end
	return false
end

local function HornTalk( h )
	local instr = { name = W( "Прочитать инструкцию" ), text = W( "За 15 дней рог производит..." ), data = {} }
	local i = 0
	for alias, v in pairs( VOL ) do
		instr.data[ i ] = alias == "money" and { alias = alias, money = v } or { alias = alias, number = v }
		i = i + 1
	end
	local t = { id = h.id, name = "Рог изобилия", horn = h, answers = {} }
	local title = W( "Управление рогом изобилия" )
	if h.step == "launched" then
		t.cue = { name = W( h.launchName ), text = W( "Запускается производство... ждите" ), data = { [ 0 ] = { alias = "value", number = h.amount } } }
	elseif h.step == "collected" then
		t.cue = { name = title, text = W( "Рог изобилия готов к новому производству!" ), data = {} }
		t.answers[ 0 ] = { name = W( "Далее" ), text = W( "" ), data = {} }
	elseif h.step == "canceled" then
		t.cue = { name = title, text = W( "Производство отменено." ), data = {} }
		t.answers[ 0 ] = { name = W( "Далее" ), text = W( "" ), data = {} }
	elseif h.state == "busy" then
		t.cue = { name = title, text = W( "<html>Рог изобилия занят производством.</html>" ),
			data = { [ 0 ] = { alias = "periods", number = h.per }, [ 1 ] = { alias = "product", string = W( h.product ) }, [ 2 ] = { alias = "amount", number = h.amount } } }
		t.answers[ 0 ] = { name = W( "Остановить производство" ), text = W( "Операция необратима" ), data = {} }
		t.answers[ 1 ] = { name = W( "Ускорить производство за 1 Искру героя" ), text = W( "" ), data = {} }
		t.answers[ 2 ] = instr
	elseif h.state == "done" then
		t.cue = { name = title, text = W( "Рог изобилия завершил производство." ), data = {} }
		t.answers[ 0 ] = { name = W( "Получить продукцию" ), text = W( "" ),
			data = { [ 0 ] = { alias = "product", string = W( h.product ) }, [ 1 ] = { alias = "amount", number = h.amount } } }
		t.answers[ 1 ] = instr
	else
		t.cue = { name = title, text = W( "Здесь можно управлять рогом.\nРог изобилия готов к работе." ), data = {} }
		local n = 0
		for _, l in ipairs( LAUNCH ) do
			local unique = l.key == "coral" or l.key == "granite"
			if not ( unique and Busy( l.product ) ) then
				t.answers[ n ] = { name = W( l.name ), text = W( "Запускается производство... ждите" ), isSpecial = true, launch = l,
					data = { [ 0 ] = { alias = "value", number = l.value }, [ 1 ] = { alias = "image", string = W( "" ) } } }
				n = n + 1
			end
		end
		t.answers[ n ] = instr
	end
	return t
end

local function TalkTo( h, pos )
	if pos then world.pos = { posX = pos[ 1 ], posY = pos[ 2 ], posZ = 23 } end
	talk = HornTalk( h )
	Fire( "EVENT_INTERACTION_STARTED" )
	while #pump > 0 do table.remove( pump, 1 )() end
end

local function Select( idx )
	local h = talk and talk.horn
	selected[ #selected + 1 ] = ( h and ( "рог" .. h.no ) or "?" ) .. ":" .. tostring( idx )
	if not h then error( "выбор ответа вне разговора с рогом" ) end
	local a = talk.answers[ idx ]
	if not a then error( "нет ответа " .. tostring( idx ) ) end
	if h.step == "collected" or h.step == "canceled" then
		h.step = nil
	elseif h.state == "done" and idx == 0 then
		world.collected[ #world.collected + 1 ] = h.product
		h.state, h.step, h.product = "free", "collected", nil
	elseif h.state == "free" and a.launch then
		h.state, h.product, h.amount, h.per, h.step, h.launchName = "busy", a.launch.product, a.launch.value, 15, "launched", a.launch.name
	else
		error( "аддон выбрал ответ, который выбирать нельзя: " .. userMods.FromWString( a.name ) )
	end
	local function Next()
		talk = HornTalk( h )
		if h.step == "launched" then h.step = nil end
		Fire( "EVENT_INTERACTION_STARTED" )
	end
	if syncEvents then Next() else pump[ #pump + 1 ] = Next end
end

local function Currency( name, value )
	return { GetInfo = function() return { name = W( name ), image = { tex = name }, category = { GetInfo = function() return { sysName = "Greatness" } end } } end, v = value, n = name }
end

--------------------------------------------------------------------------------
-- API игры
--------------------------------------------------------------------------------
-- apitype: WString в заглушках — таблица { w = ... }
function apitype( v ) if type( v ) == "table" and v.w then return "WString" end return type( v ) end
userMods = {
	ToWString = function( s ) return { w = s } end,
	FromWString = function( w ) if type( w ) == "table" and w.w then return w.w end error( "not wstring" ) end,
	SendSelfChatMessage = function( w, level ) out[ #out + 1 ] = w.w if os.getenv( "VERBOSE" ) then print( "    чат: " .. w.w ) end end,
	GetGlobalConfigSection = function( name ) return Clone( stored[ name ] ) end,
	SetGlobalConfigSection = function( name, t ) stored[ name ] = Clone( t ) world.saves = world.saves + 1 end,
}
common = {
	LogInfo = function( filter, w ) out[ #out + 1 ] = "LOG " .. w.w all[ #all + 1 ] = w.w end,
	RegisterEventHandler = function( fn, ev ) handlers[ ev ] = handlers[ ev ] or {} table.insert( handlers[ ev ], fn ) end,
	RegisterReactionHandler = function( fn, name ) reactions[ name ] = fn end,
	GetLocalDateTimeMs = function() return clock + 3 * 3600000 end,
	GetDateTimeFromMs = function( ms )
		local s = math.floor( ms / 1000 )
		return { d = 13 + math.floor( ( s - 1794570000 - 3 * 3600 ) / 86400 ), m = 11, y = 2026, h = math.floor( s / 3600 ) % 24, min = math.floor( s / 60 ) % 60, s = s % 60 }
	end,
	GetAddonRelatedTextureGroup = function( name, flag )
		return { HasTexture = function( self, key ) return world.icons[ key ] == true end, GetTexture = function( self, key ) return { tex = key } end }
	end,
}
mission = {
	GetWorldTimeMs = function() return clock end,
	GetShardName = function() return W( "Нить судьбы" ) end,
}
avatar = {
	IsExist = function() return true end,
	GetId = function() return 42 end,
	GetServerId = function() return world.serverId end,
	GetInterlocutor = function() return talk and talk.id or nil end,
	GetPos = function() return world.pos end,
	GetInteractorCue = function() return talk and talk.cue or nil end,
	GetInteractorNextCues = function() return talk and talk.answers or nil end,
	SelectInteractorCue = function( index ) Select( index ) end,
	UseItemAndTakeActions = function( itemId, count, useAction )
		world.used[ #world.used + 1 ] = { itemId, count, useAction }
		if world.chestOpens then world.bag[ 3 ] = nil end
	end,
	GetDeviceList = function()
		local t = { [ 0 ] = 55 }
		for i, h in ipairs( world.horns ) do t[ i ] = h.id end
		return t
	end,
	GetCurrencies = function()
		local t, n = {}, 0
		for _, c in ipairs( world.currencies ) do
			if c.v ~= 0 then t[ n ] = c n = n + 1 end
		end
		return t
	end,
	GetCurrencyValue = function( id ) return { value = id.v, maxValue = 0 } end,
}
object = {
	GetName = function( id )
		if id == 42 then return W( world.name ) end
		if id == 55 then return W( "Почтовый ящик" ) end
		if talk and talk.id == id then return W( talk.name ) end
		for _, h in ipairs( world.horns ) do
			if h.id == id then return W( "Рог изобилия" ) end
		end
		return W( "" )
	end,
}
unit = { GetFactionId = function( id ) return { GetInfo = function() return { sysName = world.faction } end } end }
cartographer = { GetCurrentZoneInfo = function() return { sysZoneName = world.zone, zoneName = W( "Личный аллод" ) } end }
ITEM_CONT_INVENTORY = 5
WIDGET_ALIGN_LOW_ABS = 7
containerLib = { GetItems = function( c ) return world.bag end }
itemLib = {
	GetItemInfo = function( id ) return { name = W( id == 901 and "Сундучок хранителя подземелий" or "Хлам" ), sysName = "" } end,
	GetStackInfo = function( id ) return { count = 10, limit = 20 } end,
	GetUsagesItemInfo = function( id )
		-- как в игре 13.11.2026: описание у всех «Обменять», золото — без валюты и без предмета
		return { { sysIndex = 0, usageDesc = W( "Обменять" ), givenCount = 853 },
			{ sysIndex = 1, usageDesc = W( "Обменять" ), givenCount = 1, givenItem = 900 },
			{ sysIndex = 2, usageDesc = W( "Обменять" ), givenCount = 5, givenAltCurrency = Currency( "Астральный коралл", 0 ) },
			{ sysIndex = 3, usageDesc = W( "Обменять" ), givenCount = 5, givenAltCurrency = Currency( "Астральный гранит", 0 ) } }
	end,
}
DnD = { Init = function( a, b, c, d ) end, StopDragging = function() end }

-- Как в игре: число аргументов считается строго, лишний nil — ошибка
local function Strict( libname, lib )
	for k, f in pairs( lib ) do
		if type( f ) == "function" then
			local np = debug.getinfo( f, "u" ).nparams
			lib[ k ] = function( ... )
				local n = select( "#", ... )
				calls = calls + 1
				if n ~= np then error( libname .. "." .. k .. ": wrong params count (" .. n .. ", should be " .. np .. ")" ) end
				return f( ... )
			end
		end
	end
end
for name, lib in pairs( { userMods = userMods, common = common, mission = mission, avatar = avatar, object = object,
	unit = unit, cartographer = cartographer, containerLib = containerLib, itemLib = itemLib } ) do Strict( name, lib ) end

--------------------------------------------------------------------------------
-- Виджеты: дерево собранного аддона
--------------------------------------------------------------------------------
local tree = dofile( treeFile )
local widgetCalls, instance = 0, 0
local WM = {}
function WM.GetName( self ) return self._name end
function WM.GetParent( self ) return self._parent end
function WM.GetInstanceId( self ) return self._id end
function WM.Show( self, on ) if type( on ) ~= "boolean" then error( "Show: not boolean" ) end self._visible = on end
function WM.IsVisible( self ) return self._visible end
function WM.Enable( self, on ) self._enabled = on end
function WM.SetFade( self, a ) self._fade = a end
function WM.SetVal( self, tag, w ) if type( w ) ~= "table" or not w.w then error( "SetVal: not wstring" ) end self._vals[ tag ] = w.w end
function WM.SetVariant( self, v ) if v >= self._node.variants then error( self._name .. ": нет варианта " .. v ) end self._variant = v end
function WM.SetBackgroundTexture( self, t ) if type( t ) ~= "table" then error( "SetBackgroundTexture: not texture" ) end self._tex = t.tex end
function WM.GetPlacementPlain( self ) local c = {} for k, v in pairs( self._pl ) do c[ k ] = v end return c end
function WM.SetPlacementPlain( self, pl ) self._pl = pl end
function WM.GetRealRect( self ) return { x1 = 100, y1 = 100, x2 = 200, y2 = 130 } end
function WM.GetChildChecked( self, name, recursive )
	local function Find( w )
		for _, c in ipairs( w._children ) do
			if c._name == name then return c end
			if recursive then
				local r = Find( c )
				if r then return r end
			end
		end
	end
	local r = Find( self )
	if not r then error( "GetChildChecked: нет виджета " .. name .. " в " .. self._name ) end
	return r
end
for k, f in pairs( WM ) do
	local np = debug.getinfo( f, "u" ).nparams
	WM[ k ] = function( ... )
		widgetCalls = widgetCalls + 1
		if select( "#", ... ) ~= np then error( "widget:" .. k .. ": wrong params count" ) end
		return f( ... )
	end
end
local function Build( node, parent )
	instance = instance + 1
	local w = setmetatable( { _name = node.name, _parent = parent, _node = node, _visible = node.visible, _enabled = true, _variant = 0,
		_vals = {}, _children = {}, _id = instance, _pl = { posX = node.x, posY = node.y, sizeX = node.w, sizeY = node.h } }, { __index = WM } )
	for i, c in ipairs( node.children ) do w._children[ i ] = Build( c, w ) end
	return w
end

local function Find( name, root )
	local function F( w )
		if w._name == name then return w end
		for _, c in ipairs( w._children ) do
			local r = F( c )
			if r then return r end
		end
	end
	return F( root or mainForm )
end
local function Val( w ) return w._vals.value end
local function Shown( w )               -- виден сам и все родители
	local p = w
	while p do
		if not p._visible then return false end
		p = p._parent
	end
	return true
end
local function Click( w )
	local r = nil
	for _, name in ipairs( w._node.reactions ) do r = name end
	if not r or not reactions[ r ] then error( "у виджета " .. w._name .. " нет реакции" ) end
	reactions[ r ]( { widget = w, sender = w._name, active = true } )
	reactions[ r ]( { widget = w, sender = w._name, active = false } )   -- игра может прислать реакцию дважды
end
--------------------------------------------------------------------------------
-- Запуск аддона («вход персонажем»)
--------------------------------------------------------------------------------
Fire = function( ev, p )
	for _, fn in ipairs( handlers[ ev ] or {} ) do fn( p ) end
end
local function Tick( n )
	for _ = 1, n or 1 do
		clock = clock + 1000
		Fire( "EVENT_SECOND_TIMER" )
	end
end
local function Login( w )
	world = w
	world.saves, world.used, world.collected = 0, {}, {}
	world.icons = {}
	for _, k in ipairs( tree.icons ) do world.icons[ k ] = true end
	handlers, reactions, talk, pump = {}, {}, nil, {}
	ML = nil
	mainForm = Build( tree.form, nil )
	for _, f in ipairs( { "Util.lua", "Core.lua", "UI.lua", "Main.lua" } ) do dofile( dir .. "/" .. f ) end
	Tick( 1 )
end
local function Log( pattern )
	for _, line in ipairs( out ) do
		if string.find( line, pattern, 1, true ) then return true end
	end
	return false
end

-- точки разговора с рогами Лиги (PlayersAllod02), снятые наблюдателем 13.11.2026
local LEAGUE = { { 2774.8, 2840.6 }, { 2773.8, 2829.8 }, { 2775.0, 2817.5 }, { 2782.5, 2807.3 }, { 2797.4, 2796.0 }, { 2810.3, 2791.8 },
	{ 2823.6, 2793.3 }, { 2833.5, 2799.7 }, { 2826.8, 2829.0 }, { 2810.6, 2843.5 }, { 2794.2, 2830.0 }, { 2813.1, 2812.8 } }
local function Horns( n, firstId, f )
	local t = {}
	for i = 1, n do
		t[ i ] = { no = i, id = firstId + i, state = "busy", product = "Золото", amount = 40170, per = 7 }
		if f then f( t[ i ], i ) end
	end
	return t
end
local function Reenter( firstId )          -- вышли из зоны и вошли снова: у объектов новые id
	local zone = world.zone
	world.zone = "Novograd"
	Fire( "EVENT_AVATAR_CLIENT_ZONE_CHANGED" )
	world.zone = zone
	Fire( "EVENT_AVATAR_CLIENT_ZONE_CHANGED" )
	for i, h in ipairs( world.horns ) do h.id = firstId + i end
end
local function SlotOf( ch, pos )           -- в какой строке лежит место с этой точкой разговора
	local best, bd = nil, nil
	for i, h in ipairs( ch.horns ) do
		if h.x then
			local d = math.sqrt( ( h.x - pos[ 1 ] ) ^ 2 + ( h.y - pos[ 2 ] ) ^ 2 )
			if not bd or d < bd then best, bd = i, d end
		end
	end
	return best
end

--------------------------------------------------------------------------------
section( "1. Основной персонаж: 12 рогов, все Золото, 7 дней" )
Login( { name = "Бэкендерка", serverId = 1001, faction = "League", zone = "PlayersAllod02", bag = { [ 0 ] = 900 }, pos = { posX = 0, posY = 0, posZ = 0 },
	horns = Horns( 12, 7000 ),
	currencies = { Currency( "Эмбриум", 2583 ), Currency( "Астральный гранит", 1645 ), Currency( "Астральный коралл", 150 ),
		Currency( "Фрагмент метеорита", 1 ), Currency( "Припасы", 1000000 ), Currency( "Плата наёмникам", 0 ), Currency( "Знак доблести", 77 ) } } )
local me = ML.Core.Char()
check( ML.Core.me == "c1001" and me.name == "Бэкендерка" and me.fac == "League", "персонаж записан" )
check( me.res.embrium == 2583 and me.res.granite == 1645 and me.res.coral == 150 and me.res.meteor == 1 and me.res.supplies == 1000000 and me.res.mercs == 0,
	"шесть валют лабиринта прочитаны, нулевая — ноль" )
Click( Find( "MLButton" ) )
check( Shown( Find( "HornsHint" ) ) and not Find( "HornRow1" )._visible and Val( Find( "HornsCount" ) ) == "",
	"пока с рогами не говорили — строк нет, только пояснение" )
-- строки появляются по мере разговоров
for i = 1, 3 do TalkTo( world.horns[ i ], LEAGUE[ i ] ) end
Tick( 1 )
check( Find( "HornRow3" )._visible and not Find( "HornRow4" )._visible and not Find( "HornsHint" )._visible
	and Val( Find( "HornNoText", Find( "HornRow3" ) ) ) == "3" and Val( Find( "HornsCount" ) ) == "3 из 12",
	"поговорили с тремя рогами — в окне три строки (" .. tostring( Val( Find( "HornsCount" ) ) ) .. ")" )
Click( Find( "MLButton" ) )
-- в следующий заход подошли к рогу, которого ещё не видели: он получает новую строку, а не чужую
Reenter( 8000 )
TalkTo( world.horns[ 9 ], LEAGUE[ 9 ] )
check( SlotOf( me, LEAGUE[ 9 ] ) == 4 and SlotOf( me, LEAGUE[ 1 ] ) == 1 and SlotOf( me, LEAGUE[ 2 ] ) == 2 and SlotOf( me, LEAGUE[ 3 ] ) == 3,
	"новый рог в следующий заход — четвёртая строка, первые три на месте" )
selected = {}
local base = calls
for i, h in ipairs( world.horns ) do TalkTo( h, LEAGUE[ i ] ) end
print( "  обращений к API на 12 разговоров: " .. ( calls - base ) .. ", выбрано ответов: " .. #selected )
check( #selected == 0, "с занятыми рогами аддон ничего не выбирает" )
check( me.hornCount == 12 and #me.horns == 12, "рогов 12" )
local allGold = true
for i = 1, 12 do
	local h = me.horns[ i ]
	if not ( h.st == "busy" and h.prod == "gold" and h.per == 7 and h.assign == "gold" and h.amount == 40170 ) then allGold = false end
end
check( allGold, "у всех строк: Золото, 7 дней, назначено Золото" )
Tick( 2 )
check( world.saves <= 3, "записей настроек немного: " .. world.saves )
-- второй проход теми же рогами в том же посещении: строки не плодятся
for i, h in ipairs( world.horns ) do TalkTo( h, { LEAGUE[ i ][ 1 ] + 3, LEAGUE[ i ][ 2 ] - 2 } ) end
check( #me.horns == 12, "второй проход не добавил строк" )

section( "2. Перезаход: у рогов новые id, обходим в другом порядке и с других сторон" )
local before = {}
for i = 1, 12 do before[ i ] = SlotOf( me, LEAGUE[ i ] ) end
Reenter( 9000 )
local order = { 7, 3, 12, 1, 9, 5, 11, 2, 8, 4, 10, 6 }
for _, i in ipairs( order ) do TalkTo( world.horns[ i ], { LEAGUE[ i ][ 1 ] - 2.5, LEAGUE[ i ][ 2 ] + 3.1 } ) end
local same = true
for i = 1, 12 do
	if SlotOf( me, LEAGUE[ i ] ) ~= before[ i ] then same = false end
end
check( same and #me.horns == 12, "каждый рог вернулся в свою строку" )

-- игра сменила рогам id, а события смены зоны не было: лишних строк появиться не должно
for i, h in ipairs( world.horns ) do h.id = 9500 + i end
for _, i in ipairs( order ) do TalkTo( world.horns[ i ], LEAGUE[ i ] ) end
same = true
for i = 1, 12 do
	if SlotOf( me, LEAGUE[ i ] ) ~= before[ i ] then same = false end
end
check( #me.horns == 12 and me.hornCount == 12 and same, "новые id без смены зоны: строк по-прежнему 12 (" .. #me.horns .. "), рога на своих местах" )

section( "3. Окно" )
local win = Find( "MLWindow" )
check( not win._visible, "окно закрыто после входа" )
Click( Find( "MLButton" ) )
check( win._visible, "щелчок по кнопке открывает окно (двойная реакция — один раз)" )
check( Val( Find( "CardName" ) ) == "Бэкендерка" and Shown( Find( "HereBadge" ) ), "карточка текущего персонажа" )
check( Val( Find( "ChipValue", Find( "Chip1" ) ) ) == "1 645" and Val( Find( "ChipValue", Find( "Chip5" ) ) ) == "1 млн", "ресурсы в плашках" )
check( Find( "ChipIcon", Find( "Chip6" ) )._tex == "RES_MERCS", "у нулевой «Платы наёмникам» — свой значок" )
check( Val( Find( "HornsCount" ) ) == "12" and Find( "HornRow12" )._visible, "все 12 рогов в таблице" )
local row3 = Find( "HornRow3" )
check( Val( Find( "RunName", row3 ) ) == "Золото" and Val( Find( "HornTime", row3 ) ) == "7 дн." and Val( Find( "AssignName", row3 ) ) == "Золото",
	"строка рога: Золото -> Золото, 7 дн." )
check( Find( "Arrow", row3 )._tex == "ARROW_OFF" and Find( "AssignBtn", row3 )._variant == 0, "назначение совпадает — без выделения" )
check( not Shown( Find( "MLBadge" ) ) and Shown( Find( "ReadyBadgeNone" ) ), "готовых нет" )
check( Val( Find( "NewBadgeMuteText" ) ) == "Все рога построены", "новый рог: все построены" )

-- выпадающий список: Коралл одному рогу
Click( Find( "AssignBtn", row3 ) )
local menu = Find( "Menu" )
check( Shown( menu ) and Shown( Find( "MenuCatcher" ) ), "список открыт" )
local names = {}
for i = 1, 8 do
	local it = Find( "MenuItem" .. i )
	if it._visible then names[ #names + 1 ] = Val( Find( "MenuName", it ) ) end
end
check( table.concat( names, "|" ) == "Золото|Сияющие слёзы|Сверкающие слёзы|Гранит|Коралл|Не запускать", "состав списка: " .. table.concat( names, "|" ) )
check( menu._pl.posY + menu._pl.sizeY <= win._pl.sizeY and menu._pl.posY > 0, "список внутри окна" )
Click( Find( "MenuItem5" ) )
check( not menu._visible and me.horns[ 3 ].assign == "coral", "выбран Коралл" )
check( Find( "Arrow", row3 )._tex == "ARROW_ON" and Find( "AssignBtn", row3 )._variant == 2, "отличие от запущенного выделено" )
Click( Find( "AssignBtn", Find( "HornRow12" ) ) )
check( menu._pl.posY + menu._pl.sizeY <= win._pl.sizeY, "у нижней строки список раскрыт вверх" )
local coral = Find( "MenuItem5" )
check( Find( "MenuOwner", coral )._visible and Val( Find( "MenuOwnerText", coral ) ) == "3" and Shown( Find( "MenuNameDim", coral ) ),
	"Коралл у другого рога показан занятым, с номером рога-владельца" )
Click( coral )
check( me.horns[ 12 ].assign == "gold" and menu._visible, "занятый Коралл второму рогу не назначается" )
Click( Find( "MenuCatcher" ) )
check( not menu._visible, "щелчок мимо закрывает список" )
check( ML.Core.Assign( ML.Core.me, 12, "coral" ) == false, "и в данных Коралл остаётся у одного рога" )
-- подсказок в аддоне нет: ни панели, ни реакций на наведение
local hasTip = Find( "Tooltip" ) ~= nil or reactions.ml_tip ~= nil
local function AnyPointing( w )
	for _, r in ipairs( w._node.reactions ) do
		if r == "ml_tip" then return true end
	end
	for _, c in ipairs( w._children ) do
		if AnyPointing( c ) then return true end
	end
	return false
end
check( not hasTip and not AnyPointing( mainForm ), "всплывающих подсказок нет" )

section( "4. Через 7 дней рога готовы: сбор и запуск назначенного" )
Tick( 2 )
clock = clock + 7 * 86400000
Tick( 61 )
check( Val( Find( "MLBadgeText" ) ) == "12" and Shown( Find( "MLBadge" ) ), "на кнопке 12 готовых (по расчёту, без разговора)" )
check( Shown( Find( "HornPillOk", row3 ) ) and Val( Find( "ReadyBadgeText" ) ) == "Готово: 12", "в окне рога помечены готовыми" )
for _, h in ipairs( world.horns ) do h.state, h.per = "done", 0 end
Reenter( 11000 )
selected, out = {}, {}
base = calls
TalkTo( world.horns[ 1 ], LEAGUE[ 1 ] )
check( table.concat( selected, " " ) == "рог1:0 рог1:0 рог1:0", "рог 1: забрать -> дальше -> Золото (" .. table.concat( selected, " " ) .. ")" )
check( world.horns[ 1 ].state == "busy" and world.horns[ 1 ].product == "Золото", "рог 1 снова добывает Золото" )
local s1 = SlotOf( me, LEAGUE[ 1 ] )
check( me.horns[ s1 ].st == "busy" and me.horns[ s1 ].per == 15 and me.horns[ s1 ].prod == "gold", "в данных: Золото, 15 дней" )
check( Log( "забрано — Золото 40 170" ) and Log( "запущено — Золото" ), "сообщения в чат о сборе и запуске" )
print( "  обращений к API на разговор со сбором и запуском: " .. ( calls - base ) )
selected = {}
syncEvents = true                          -- ответ рога приходит раньше, чем вернулся вызов
TalkTo( world.horns[ 3 ], LEAGUE[ 3 ] )
syncEvents = false
check( table.concat( selected, " " ) == "рог3:0 рог3:0 рог3:4", "рог 3: забрать -> дальше -> Коралл (" .. table.concat( selected, " " ) .. ")" )
check( world.horns[ 3 ].product == "Астральный коралл" and me.horns[ SlotOf( me, LEAGUE[ 3 ] ) ].prod == "coral", "рог 3 добывает Коралл" )
-- «Не запускать»: забрать и оставить свободным
local s5 = SlotOf( me, LEAGUE[ 5 ] )
ML.Core.Assign( ML.Core.me, s5, "none" )
selected = {}
TalkTo( world.horns[ 5 ], LEAGUE[ 5 ] )
check( table.concat( selected, " " ) == "рог5:0 рог5:0" and world.horns[ 5 ].state == "free" and me.horns[ s5 ].st == "free",
	"«Не запускать»: забрано, рог свободен (" .. table.concat( selected, " " ) .. ")" )
selected = {}
TalkTo( world.horns[ 5 ], LEAGUE[ 5 ] )
check( #selected == 0, "свободный рог с «Не запускать» не трогаем" )
Tick( 2 )
check( Shown( Find( "HornPillMute", Find( "HornRow" .. s5 ) ) ) and Val( Find( "RunNameDim", Find( "HornRow" .. s5 ) ) ) == "Не запущен", "в окне: не запущен, свободен" )
-- Гранит назначен, но ещё один рог назначить Коралл нельзя; Коралл занят рогом 3 — назначенный Коралл не запускается
local s6 = SlotOf( me, LEAGUE[ 6 ] )
me.horns[ SlotOf( me, LEAGUE[ 3 ] ) ].assign = "gold"
ML.Core.Assign( ML.Core.me, s6, "coral" )
selected, out = {}, {}
TalkTo( world.horns[ 6 ], LEAGUE[ 6 ] )
check( table.concat( selected, " " ) == "рог6:0 рог6:0" and world.horns[ 6 ].state == "free", "Коралл ещё занят: рог забран и оставлен свободным" )
check( Log( "Коралл сейчас запустить нельзя" ), "об этом сказано в чате" )
out = {}
TalkTo( world.horns[ 6 ], LEAGUE[ 6 ] )
check( not Log( "запустить нельзя" ) and #selected == 2, "повторно не сообщаем и не выбираем" )
Tick( 2 )
check( Shown( Find( "HornPillWarn", Find( "HornRow" .. s6 ) ) ), "в окне рог помечен «Свободен» (ждёт)" )
-- автоматика выключена
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs auto off" ) } )
selected = {}
TalkTo( world.horns[ 7 ], LEAGUE[ 7 ] )
check( #selected == 0 and me.horns[ SlotOf( me, LEAGUE[ 7 ] ) ].st == "done", "автоматика выключена: готовый рог записан, но не тронут" )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs auto on" ) } )
TalkTo( world.horns[ 7 ], LEAGUE[ 7 ] )
check( world.horns[ 7 ].state == "busy", "автоматика включена: забран и запущен" )
-- игрок сам остановил рог: как только рог показал меню запуска, назначенное запускается заново
local h8 = world.horns[ 8 ]
local s8 = SlotOf( me, LEAGUE[ 8 ] )
h8.state, h8.product, h8.per = "busy", "Золото", 9
TalkTo( h8, LEAGUE[ 8 ] )
h8.state, h8.product, h8.step = "free", nil, "canceled"
selected = {}
TalkTo( h8, LEAGUE[ 8 ] )
check( #selected == 0 and me.horns[ s8 ].st == "free", "реплика «Производство отменено»: рог записан свободным, выбирать пока нечего" )
h8.step = nil
TalkTo( h8, LEAGUE[ 8 ] )
check( table.concat( selected, " " ) == "рог8:0" and h8.state == "busy" and me.horns[ s8 ].prod == "gold",
	"после ручной остановки при следующей же реплике назначенное запущено заново (" .. table.concat( selected, " " ) .. ")" )
-- то же через выход из разговора: остановил, закрыл, заговорил снова
h8.state, h8.product = "free", nil
selected = {}
TalkTo( h8, LEAGUE[ 8 ] )
check( table.concat( selected, " " ) == "рог8:0" and h8.state == "busy", "остановил, заговорил снова — запущено" )
-- реплика с текстом «производство отменено», в которой уже есть варианты запуска, — это свободный рог
h8.state, h8.product = "free", nil
talk = HornTalk( h8 )
talk.cue.text = W( "Производство отменено. Рог изобилия готов к работе." )
selected = {}
Fire( "EVENT_INTERACTION_STARTED" )
while #pump > 0 do table.remove( pump, 1 )() end
check( table.concat( selected, " " ) == "рог8:0", "текст про отмену не мешает запуску, если варианты запуска уже показаны" )
-- чтобы рог остался свободным после остановки, есть «Не запускать»
ML.Core.Assign( ML.Core.me, s8, "none" )
h8.state, h8.product = "free", nil
selected = {}
TalkTo( h8, LEAGUE[ 8 ] )
check( #selected == 0 and me.horns[ s8 ].st == "free", "«Не запускать»: остановленный рог остаётся свободным" )
-- игрок сам запустил производство
talk = HornTalk( h8 )
Select( 1 )
while #pump > 0 do table.remove( pump, 1 )() end
check( me.horns[ SlotOf( me, LEAGUE[ 8 ] ) ].prod == "tear1" and me.horns[ SlotOf( me, LEAGUE[ 8 ] ) ].per == 15, "ручной запуск слёз записан" )

section( "5. Сундучок хранителя" )
world.bag[ 3 ] = 901
world.chestOpens = true
Click( Find( "ChestBtn" ) )
names = {}
for i = 1, 8 do
	local it = Find( "MenuItem" .. i )
	if it._visible then names[ #names + 1 ] = Val( Find( "MenuName", it ) ) end
end
check( table.concat( names, "|" ) == "Золото|Слеза дракона|Коралл|Гранит|Не открывать", "выбор для сундучка: " .. table.concat( names, "|" ) )
Click( Find( "MenuItem3" ) )
check( me.chest == "coral" and Val( Find( "ChestBtnName" ) ) == "Коралл", "выбран Коралл" )
out = {}
Tick( 2 )
check( #world.used == 1 and world.used[ 1 ][ 1 ] == 901 and world.used[ 1 ][ 2 ] == 10 and world.used[ 1 ][ 3 ] == 2, "вся стопка (10) открыта в Коралл: вариант 2" )
Tick( 4 )
check( Log( "сундучки хранителя открыты: 10 шт. — Коралл" ) and me.chestGot ~= nil, "открытие подтверждено после проверки сумки" )
-- сундучок пришёл почтой, но сразу не открывается
world.used, world.chestOpens = {}, false
world.bag[ 3 ] = 901
out = {}
Fire( "EVENT_CONTAINER_ITEM_ADDED", { itemId = 900, slotType = 5, slot = 1, isNewItem = true, sysName = "" } )
Tick( 4 )
check( #world.used == 0, "обычный предмет в сумке сундучки не трогает" )
Fire( "EVENT_CONTAINER_ITEM_ADDED", { itemId = 901, slotType = 5, slot = 3, isNewItem = true, sysName = "" } )
Tick( 1 )
check( #world.used == 0, "в первую секунду после почты не открываем" )
Tick( 20 )
check( #world.used == 3 and Log( "открыть не удалось" ), "три попытки и понятное сообщение (попыток: " .. #world.used .. ")" )
me.chest = "tear"
world.used = {}
ML.Core.ChestSoon( 0 )
Tick( 1 )
check( world.used[ 1 ] and world.used[ 1 ][ 3 ] == 1, "слеза дракона — вариант 1" )
me.chest = "gold"
world.used = {}
ML.Core.ChestSoon( 0 )
Tick( 1 )
check( world.used[ 1 ] and world.used[ 1 ][ 3 ] == 0, "золото — вариант 0" )
world.bag[ 3 ] = nil
Tick( 5 )

section( "6. Второй персонаж: Империя, 7 рогов, свободный рог, прораб" )
Tick( 2 )
check( stored.MyLabsData and stored.MyLabs.runs == 9, "данные лежат в своей секции, секция LibDnD не тронута" )
Login( { name = "Фронтендер", serverId = 1002, faction = "Empire", zone = "PlayersAllod01", bag = {}, pos = { posX = 0, posY = 0, posZ = 0 },
	horns = Horns( 7, 20000, function( h, i )
		if i == 7 then h.product, h.amount = "Астральный коралл", 100 end
		if i == 6 then h.state, h.product = "free", nil end
	end ),
	currencies = { Currency( "Эмбриум", 406 ), Currency( "Астральный коралл", 690 ), Currency( "Плата наёмникам", 750 ) } } )
me = ML.Core.Char()
check( ML.Core.me == "c1002" and #ML.db.order == 2 and ML.db.chars.c1001.name == "Бэкендерка", "данные первого персонажа на месте, второй добавлен" )
check( #ML.db.chars.c1001.horns == 12 and ML.db.chars.c1001.horns[ 1 ].st ~= nil, "рога первого персонажа пережили запись и чтение" )
-- рога Империи стоят тесно: по 8 м
local EMP = {}
for i = 1, 7 do EMP[ i ] = { 7940 + i * 8, 2790 } end
selected = {}
for i, h in ipairs( world.horns ) do TalkTo( h, EMP[ i ] ) end
check( #selected == 0, "свободный рог без назначения не запускается" )
check( me.hornCount == 7 and me.horns[ SlotOf( me, EMP[ 7 ] ) ].prod == "coral" and me.horns[ SlotOf( me, EMP[ 6 ] ) ].st == "free", "7 рогов: Коралл и свободный записаны" )
check( me.horns[ SlotOf( me, EMP[ 7 ] ) ].assign == "coral", "рогу с Кораллом назначен Коралл" )
-- прораб
talk = { id = 555, name = "Буба Молоток", cue = { name = W( "Прораб" ), text = W( "Чего надо?" ), data = {} },
	answers = { [ 0 ] = { name = W( "<html>Построить восьмой рог изобилия за <r name=\"cost\"/> ед. астрального коралла</html>" ), text = W( "" ),
		data = { [ 0 ] = { alias = "cost", number = 2880 } } } } }
Fire( "EVENT_INTERACTION_STARTED" )
check( me.cost == 2880, "цена восьмого рога от прораба" )
local nh = ML.Core.NewHorn( me )
check( nh.state == "lack" and nh.lack == 2190 and nh.embNeed == 438 and nh.embHave == 406, "расчёт: не хватает 2190 Коралла = 438 Эмбриума, есть 406" )
world.currencies[ 1 ].v = 450
Fire( "EVENT_CURRENCY_VALUE_CHANGED", { id = world.currencies[ 1 ], delta = 44, sysName = "" } )
check( me.res.embrium == 450 and ML.Core.NewHorn( me ).state == "embrium", "Эмбриума стало 450: можно строить за Эмбриум" )
-- окно: список из двух персонажей, карточка чужого
Click( Find( "MLButton" ) )
check( Val( Find( "CharName", Find( "CharRow1" ) ) ) == "Фронтендер" and Val( Find( "CharName", Find( "CharRow2" ) ) ) == "Бэкендерка"
	and not Find( "CharRow3" )._visible, "список: текущий первым" )
check( Find( "CharFac", Find( "CharRow1" ) )._tex == "FAC_EMPIRE" and Find( "CharFac", Find( "CharRow2" ) )._tex == "FAC_LEAGUE", "значки фракций" )
check( Find( "ChipIcon", Find( "Chip6" ) )._tex == "Плата наёмникам" and Val( Find( "ChipValue", Find( "Chip6" ) ) ) == "750", "«Плата наёмникам»: значок от игры и значение" )
check( Shown( Find( "CharPillWarn", Find( "CharRow1" ) ) ) == false and Val( Find( "CharTime", Find( "CharRow1" ) ) ) == "7 дн.", "строка списка: ближайший через 7 дн." )
check( Val( Find( "NewBadgeOkText" ) ) == "Можно строить за Эмбриум" and Val( Find( "NewNeed", Find( "NewRow1" ) ) ) == "2 880"
	and Val( Find( "NewLackWarn", Find( "NewRow1" ) ) ) == "2 190" and Val( Find( "NewNeed", Find( "NewRow2" ) ) ) == "438"
	and Val( Find( "NewLackOk", Find( "NewRow2" ) ) ) == "0", "блок нового рога" )
check( Find( "HornRow7" )._visible and not Find( "HornRow8" )._visible, "у персонажа с семью рогами — семь строк" )
Click( Find( "CharRow2" ) )
check( Val( Find( "CardName" ) ) == "Бэкендерка" and not Find( "HereBadge" )._visible and string.find( Val( Find( "CardSeen" ) ) or "", "данные от", 1, true ),
	"карточка другого персонажа" )
check( Val( Find( "HornsCount" ) ) == "12" and Find( "CardFac" )._tex == "FAC_LEAGUE", "его рога и фракция" )
-- назначение чужому персонажу из окна
local other = ML.db.chars.c1001
local freeSlot = nil
for i, h in ipairs( other.horns ) do
	if h.st == "free" and h.assign == "none" then freeSlot = i end
end
Click( Find( "AssignBtn", Find( "HornRow" .. freeSlot ) ) )
Click( Find( "MenuItem2" ) )
check( other.horns[ freeSlot ].assign == "tear1", "назначение другому персонажу сохраняется" )
Click( Find( "CharRow1" ) )
-- назначаем свободному рогу Гранит и подходим к нему
local s6e = SlotOf( me, EMP[ 6 ] )
Click( Find( "AssignBtn", Find( "HornRow" .. s6e ) ) )
Click( Find( "MenuItem4" ) )
check( me.horns[ s6e ].assign == "granite", "свободному рогу назначен Гранит" )
selected = {}
TalkTo( world.horns[ 6 ], EMP[ 6 ] )
check( table.concat( selected, " " ) == "рог6:3" and world.horns[ 6 ].product == "Астральный гранит", "Гранит запущен (" .. table.concat( selected, " " ) .. ")" )
-- построен восьмой рог
world.horns[ 8 ] = { no = 8, id = 20008, state = "free" }
TalkTo( world.horns[ 8 ], { 8010, 2805 } )
check( me.hornCount == 8 and ML.Core.NewHorn( me ).state == "nodata", "восьмой рог появился, старая цена больше не годится" )
talk = { id = 555, name = "Буба Молоток", cue = { name = W( "Прораб" ), text = W( "Чего надо?" ), data = {} },
	answers = { [ 0 ] = { name = W( "Построить девятый рог изобилия за 3600 ед. астрального коралла" ), text = W( "" ), data = { [ 0 ] = { alias = "cost", number = 3600 } } } } }
Fire( "EVENT_INTERACTION_STARTED" )
check( ML.Core.NewHorn( me ).cost == 3600, "новая цена от прораба принята" )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs reset" ) } )
check( #me.horns == 0 and #ML.db.chars.c1001.horns == 12, "/mylabs reset забывает рога только текущего персонажа" )
Tick( 2 )

section( "6а. Семь рогов: поговорили с шестью, перезашли, поговорили с теми же шестью" )
Login( { name = "МасВоок", serverId = 1003, faction = "League", zone = "PlayersAllod02", bag = {}, pos = { posX = 0, posY = 0, posZ = 0 },
	horns = Horns( 7, 30000 ), currencies = { Currency( "Астральный коралл", 30 ) } } )
me = ML.Core.Char()
local function Known()
	local n = 0
	for _, h in ipairs( me.horns ) do
		if h.st then n = n + 1 end
	end
	return n
end
for i = 1, 6 do TalkTo( world.horns[ i ], LEAGUE[ i ] ) end
check( Known() == 6 and me.hornCount == 7, "первый заход: записано 6 из 7" )
for pass = 1, 3 do
	Reenter( 31000 + pass * 100 )
	for i = 6, 1, -1 do TalkTo( world.horns[ i ], { LEAGUE[ i ][ 1 ] + pass, LEAGUE[ i ][ 2 ] - 2 * pass } ) end
end
check( Known() == 6 and #me.horns == 7, "три перезахода с теми же шестью рогами: записано по-прежнему 6 (" .. Known() .. "), строк не больше 7 (" .. #me.horns .. ")" )
-- подошли к знакомому рогу совсем с другой стороны (12 м от прежней точки)
Reenter( 32000 )
TalkTo( world.horns[ 1 ], { LEAGUE[ 1 ][ 1 ] - 12, LEAGUE[ 1 ][ 2 ] } )
for i = 2, 6 do TalkTo( world.horns[ i ], LEAGUE[ i ] ) end
check( #me.horns == 7 and Known() <= 7, "подход с другой стороны: строк всё равно не больше, чем рогов в зоне (" .. Known() .. " из " .. #me.horns .. ")" )
TalkTo( world.horns[ 7 ], LEAGUE[ 7 ] )
for pass = 1, 2 do
	Reenter( 33000 + pass * 100 )
	for i = 1, 7 do TalkTo( world.horns[ i ], LEAGUE[ i ] ) end
end
check( #me.horns == 7 and Known() == 7, "полный проход: 7 строк на 7 рогов" )
Tick( 2 )

section( "7. Ошибки в журнале" )
local errors = 0
for _, line in ipairs( all ) do
	if string.find( line, "ОШИБКА", 1, true ) or string.find( line, "ошибка ", 1, true ) or string.find( line, "нет функции", 1, true ) then
		errors = errors + 1
		print( "  " .. line )
	end
end
check( errors == 0, "ошибок в журнале: " .. errors )
print( string.format( "проверок: %d, не прошло: %d", checks, fails ) )
os.exit( fails == 0 and 0 or 1 )
