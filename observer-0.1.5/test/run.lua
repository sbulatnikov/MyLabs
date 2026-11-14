-- Прогон MyLabs на заглушках API: texlua test/run.lua <папка lua>
local dir = arg[ 1 ] or "lua"
local out = {}
local handlers = {}
local section = nil
local clock = 1794570000000
used = nil

function Global( name, v ) _G[ name ] = v end

userMods = {
	ToWString = function( s ) return { w = s } end,
	FromWString = function( w ) if type( w ) == "table" and w.w then return w.w end error( "not wstring" ) end,
	SendSelfChatMessage = function( w, level ) out[ #out + 1 ] = "CHAT(" .. tostring( level ) .. "): " .. w.w end,
	GetGlobalConfigSection = function( name ) return section end,
	SetGlobalConfigSection = function( name, t ) section = t end,
	GetAccountUniqueId = function() return "5C976713F32D4D60B51F5281E35CBA6B" end,
}
common = {
	LogInfo = function( filter, w ) out[ #out + 1 ] = type( w ) == "table" and w.w or tostring( w ) end,
	RegisterEventHandler = function( fn, ev ) handlers[ ev ] = handlers[ ev ] or {} table.insert( handlers[ ev ], fn ) end,
	GetLocalDateTimeMs = function() return clock end,
	GetLocalDateTime = function() return { d = 13, m = 11, y = 2026, h = 12, min = 45, s = 7 } end,
	GetDateTimeFromMs = function( ms ) return { d = 13, m = 11, y = 2026, h = 13, min = 45, s = 7 } end,
}
mission = {
	GetWorldTimeMs = function() return clock + 3600000 end,
	GetGlobalDateTimeMs = function() return clock + 5 end,
	GetShardName = function() return { w = "Нить судьбы" } end,
}
local W = function( s ) return { w = s } end
local horn = { id = 7001, name = "Рог изобилия", pos = nil }
local talk = nil
local myPos = { posX = 100.5, posY = 20.25, posZ = 3 }
avatar = {
	IsExist = function() return true end,
	GetId = function() return 42 end,
	GetServerId = function() return setmetatable( {}, { __tostring = function() return "PersistentId:123" end } ) end,
	GetInterlocutor = function() return talk and talk.id or nil end,
	GetInteractorInfo = function() return talk and { interactorId = talk.id, hasCues = true, isVendor = false, extended = { [ 3 ] = true } } or nil end,
	GetTarget = function() return talk and talk.id or nil end,
	GetPos = function() return myPos end,
	GetInteractorCue = function() return talk and talk.cue or nil end,
	GetInteractorNextCues = function() return talk and talk.answers or nil end,
	GetDir = function() return 1.57 end,
	UseItemAndTakeActions = function( itemId, count, useAction ) used = { itemId, count, useAction } end,
	GetDeviceList = function() return { 7001, 7002, 55 } end,
	GetCurrencies = function()
		return { [ 0 ] = { GetInfo = function() return { sysName = "astral_coral", name = W( "Астральный коралл" ), sysStorage = "avatar", category = { GetInfo = function() return { sysName = "maze" } end } } end, v = 1085 },
			[ 1 ] = { GetInfo = function() return { sysName = "embrium", name = W( "Эмбриум" ) } end, v = 320 },
			[ 2 ] = { GetInfo = function() return { name = W( "Гранит без имени" ) } end, v = 1 },
			[ 3 ] = { GetInfo = function() return { name = W( "Припасы без имени" ) } end, v = 2 } }
	end,
	GetCurrencyValue = function( id ) return { value = id.v, maxValue = nil } end,
	GetCurrencyCategories = function() return { [ 0 ] = "cat" } end,
	-- две валюты без системного имени: обе должны попасть в журнал
	GetCategoryCurrencies = function( c )
		return { [ 0 ] = { GetInfo = function() return { sysName = "granite", name = W( "Гранит" ) } end, v = 7 } }
	end,
}
object = {
	GetName = function( id ) if id == 42 then return W( "Юникс" ) end return W( talk and talk.name or "" ) end,
	IsDevice = function( id ) return true end,
	IsUnit = function( id ) return false end,
	GetPos = function( id ) return nil end,
	GetDistance = function( id, is2D ) return 3.5 end,
	IsInUsageRange = function( id ) return true end,
	GetInstantProjectedInfo = function( id, off ) return nil end,
	GetBuffs = function( id ) return { 11, 12, 13 } end,
	GetBuffSysName = function( b ) if b == 12 then return nil end return "buff_" .. b end,
}
unit = {
	GetPlayerShardName = function( id ) return W( "Нить судьбы" ) end,
	GetFactionId = function( id ) return { GetInfo = function() return { sysName = "League", name = W( "Лига" ) } end } end,
}
cartographer = { GetCurrentZoneInfo = function() return { sysZoneName = "PlayerMaze", sysSubZoneName = "", zoneName = W( "Лабиринт" ), subZoneName = W( "" ), allod = W( "Личный аллод" ) } end }
ITEM_CONT_INVENTORY = 5
ATTACHED_OBJECT_POS_CENTER = 1
device = { GetTitle = function( id ) return W( "" ) end }
containerLib = { GetItems = function( c ) return { [ 0 ] = 900, [ 3 ] = 901 } end }
itemLib = {
	IsUseItemAndTakeActions = function( id ) return false end,
	GetItemInfo = function( id ) return { name = W( id == 901 and "Сундучок хранителя подземелий" or "Хлам" ), sysName = "", debugName = "Items/Chest.xdb" } end,
	GetStackInfo = function( id ) return { count = 10, limit = 20 } end,
	GetSource = function( id ) return "ENUM_ItemSource_Quest" end,
	GetUsagesItemInfo = function( id )
		-- как в игре 13.11.2026: описание у всех «Обменять», золото без валюты и предмета
		return { { sysIndex = 0, consumeItems = 1, usageDesc = W( "Обменять" ), givenCount = 853 },
			{ sysIndex = 1, consumeItems = 1, usageDesc = W( "Обменять" ), givenCount = 1, givenItem = 900 },
			{ sysIndex = 2, consumeItems = 1, usageDesc = W( "Обменять" ), givenCount = 5,
				givenAltCurrency = { GetInfo = function() return { name = W( "Астральный коралл" ) } end } },
			{ sysIndex = 3, consumeItems = 1, usageDesc = W( "Обменять" ), givenCount = 5,
				givenAltCurrency = { GetInfo = function() return { name = W( "Астральный гранит" ) } end } } }
	end,
}

-- Как в игре: число аргументов считается строго, лишний nil — ошибка
local function Strict( libname, lib )
	for k, f in pairs( lib ) do
		if type( f ) == "function" then
			local np = debug.getinfo( f, "u" ).nparams
			lib[ k ] = function( ... )
				local n = select( "#", ... )
				if n ~= np then error( libname .. "." .. k .. ": wrong params count (" .. n .. ", should be " .. np .. ")" ) end
				return f( ... )
			end
		end
	end
end
for name, lib in pairs( { userMods = userMods, common = common, mission = mission, avatar = avatar, object = object,
	unit = unit, cartographer = cartographer, device = device, containerLib = containerLib, itemLib = itemLib } ) do Strict( name, lib ) end

for _, f in ipairs( { "Util.lua", "Probe.lua", "Main.lua" } ) do dofile( dir .. "/" .. f ) end

local function Fire( ev, p )
	for _, fn in ipairs( handlers[ ev ] or {} ) do fn( p ) end
end
local function Tick( n ) for _ = 1, n do Fire( "EVENT_SECOND_TIMER" ) end end

-- рог занят
talk = { id = 7001, name = "Рог изобилия",
	cue = { name = W( "Управление рогом изобилия" ), text = W( "<html>Рог изобилия занят производством.\nПродукция: <r name=\"product\"/></html>" ), isSpecial = false,
		data = { [ 0 ] = { alias = "product", string = W( "Золото" ) }, [ 1 ] = { alias = "amount", number = 40170 }, [ 2 ] = { alias = "periods", number = 7 } } },
	answers = { [ 0 ] = { name = W( "Ускорить производство за 1 Искру героя" ), text = W( "Энергия Искр успешно преобразована!" ), data = {}, isSpecial = false } } }
Fire( "EVENT_TALK_STARTED" )
Fire( "EVENT_INTERACTION_STARTED" )
Fire( "EVENT_INTERACTION_STARTED" )   -- второй шаг того же разговора
Fire( "EVENT_TALK_STOPPED" )
Tick( 90 )
-- другой рог, рядом, свободен
myPos = { posX = 112.0, posY = 20.0, posZ = 3 }
talk = { id = 7002, name = "Рог изобилия",
	cue = { name = W( "Управление рогом изобилия" ), text = W( "Рог изобилия готов к работе." ), isSpecial = false, data = {} },
	answers = { [ 0 ] = { name = W( "<html>Чеканить монеты в количестве <r name=\"value\"/> золотых</html>" ), text = W( "" ), data = { [ 0 ] = { alias = "value", number = 40170 } } },
		[ 1 ] = { name = W( "Прочитать инструкцию" ), text = W( "За 15 дней..." ), data = { [ 0 ] = { alias = "money", money = 40170 }, [ 1 ] = { alias = "item", itemId = 900 } } } } }
Fire( "EVENT_INTERACTION_STARTED" )
Tick( 90 )
-- снова первый рог, чуть с другой стороны
myPos = { posX = 101.2, posY = 20.9, posZ = 3 }
talk = { id = 7001, name = "Рог изобилия", cue = { name = W( "Управление" ), text = W( "" ), data = { [ 0 ] = { alias = "product", string = W( "Золото" ) } } }, answers = {} }
Fire( "EVENT_INTERACTION_STARTED" )
-- не рог, без реплики
talk = { id = 55, name = "Почтовый ящик", cue = nil, answers = nil }
Fire( "EVENT_INTERACTION_STARTED" )
talk = nil

Fire( "EVENT_CURRENCY_VALUE_CHANGED", { id = { GetInfo = function() return { sysName = "astral_coral", name = W( "Астральный коралл" ) } end, v = 1090 }, delta = 5, sysName = "astral_coral" } )
Fire( "EVENT_CONTAINER_ITEM_ADDED", { isNewItem = true, slotType = 5, slot = 3, itemId = 901, sysName = "MazeKeeperChest" } )
Fire( "EVENT_CONTAINER_ITEM_ADDED", { isNewItem = false, slotType = 5, slot = 3, itemId = 901 } )
Fire( "EVENT_AVATAR_ITEM_TAKEN", { actionType = "ENUM_EnumTakeItemActionType_Mail" } )
Fire( "EVENT_AVATAR_CLIENT_ZONE_CHANGED" )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs" ) } )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/MyLabs mark рог у входа" ) } )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs dump" ) } )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/other" ) } )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest" ) } )
assert( used == nil, "chest list must not open anything" )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest 7" ) } )
assert( used == nil, "unknown variant must not open anything" )
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest coral" ) } )
assert( used and used[ 1 ] == 901 and used[ 2 ] == 1 and used[ 3 ] == 2, "coral must open one chest with sysIndex 2" )
used = nil
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest 0" ) } )
assert( used and used[ 3 ] == 0, "explicit variant" )
used = nil
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest coral all" ) } )
assert( used and used[ 2 ] == 10 and used[ 3 ] == 2, "all chests, coral" )
used = nil
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest coral 3" ) } )
assert( used and used[ 2 ] == 3 and used[ 3 ] == 2, "three chests, coral" )
used = nil
Fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = W( "/mylabs chest coral 99" ) } )
assert( used and used[ 2 ] == 10, "count is capped by the stack" )

local bad = 0
for _, l in ipairs( out ) do
	print( l )
	if string.find( l, "ОШИБКА", 1, true ) or string.find( l, "] ошибка ", 1, true ) or string.find( l, "нет функции", 1, true ) then bad = bad + 1 end
end
if bad > 0 then io.stderr:write( "ПРОВАЛ: строк с ошибками " .. bad .. "\n" ) os.exit( 1 ) end
io.stderr:write( "lines: " .. #out .. ", runs: " .. tostring( section.probe.runs ) .. "\n" )
