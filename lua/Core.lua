--------------------------------------------------------------------------------
-- MyLabs / Core.lua — данные аккаунта, рога, валюты лабиринта, сундучок.
-- Всё состояние лежит в общей секции настроек "MyLabsData" (одна на все персонажи).
--------------------------------------------------------------------------------
ML.Core = {}
local C = ML.Core
local S, N, Lower = ML.S, ML.N, ML.Lower

--------------------------------------------------------------------------------
-- Справочники. Игра не даёт системных имён, поэтому всё опознаётся по словам
-- в названиях (в нижнем регистре), русским и английским.
--------------------------------------------------------------------------------
-- что производит рог
ML.PRODUCTS = {
	{ k = "gold",    name = "Золото",            icon = "RES_GOLD",    words = { "монет", "золот", "gold", "coin" } },
	{ k = "tear1",   name = "Сияющие слёзы",     icon = "RES_TEAR1",   words = { "сияющ" } },
	{ k = "tear2",   name = "Сверкающие слёзы",  icon = "RES_TEAR2",   words = { "сверкающ" } },
	{ k = "tear3",   name = "Светящиеся слёзы",  icon = "RES_TEAR3",   words = { "светящ" } },
	{ k = "granite", name = "Гранит",            icon = "RES_GRANITE", words = { "гранит", "granit" }, unique = true },
	{ k = "coral",   name = "Коралл",            icon = "RES_CORAL",   words = { "коралл", "coral" }, unique = true },
	{ k = "embrium", name = "Эмбриум",           icon = "RES_EMBRIUM", words = { "эмбриум", "embrium" } },
}
ML.PRODUCT = {}
for _, p in ipairs( ML.PRODUCTS ) do ML.PRODUCT[ p.k ] = p end
-- набор по умолчанию (подписочные серверы), пока меню рога на этом персонаже не видели
ML.DEFAULT_MENU = { "gold", "tear1", "tear2", "granite", "coral" }

-- валюты лабиринта (порядок = порядок в окне)
ML.RESOURCES = {
	{ k = "granite",  name = "Астральный гранит",  icon = "RES_GRANITE",  words = { "астральный гранит", "astral granit" } },
	{ k = "coral",    name = "Астральный коралл",  icon = "RES_CORAL",    words = { "астральный коралл", "astral coral" } },
	{ k = "embrium",  name = "Эмбриум",            icon = "RES_EMBRIUM",  words = { "эмбриум", "embrium" } },
	{ k = "meteor",   name = "Фрагменты метеорита", icon = "RES_METEOR",  words = { "фрагмент метеорит", "meteorite" } },
	{ k = "supplies", name = "Припасы",            icon = "RES_SUPPLIES", words = { "припасы", "supplies", "provision" } },
	{ k = "mercs",    name = "Плата наёмникам",    icon = "RES_MERCS",    words = { "плата наёмник", "плата наемник", "mercenar" } },
}

-- что можно взять из сундучка хранителя
ML.CHEST_CHOICES = {
	{ k = "gold",    name = "Золото",        icon = "RES_GOLD" },
	{ k = "tear",    name = "Слеза дракона", icon = "RES_TEAR1" },
	{ k = "coral",   name = "Коралл",        icon = "RES_CORAL" },
	{ k = "granite", name = "Гранит",        icon = "RES_GRANITE" },
}

local HORN_WORDS = { "рог изобилия", "horn of" }
local CHEST_WORDS = { "сундучок хранител", "keeper's chest" }
local CORAL_PER_EMBRIUM = 5        -- курс обмена у Генератора Эмбриума (из LabCalendar, в игре не проверен)
local PRODUCTION_DAYS = 15

local function HasWord( text, words )
	for _, w in ipairs( words ) do
		if string.find( text, w, 1, true ) then return true end
	end
	return false
end

local function ProductKey( text )
	text = Lower( text )
	for _, p in ipairs( ML.PRODUCTS ) do
		if HasWord( text, p.words ) then return p.k end
	end
	return nil
end

local function ResourceKey( name )
	name = Lower( name )
	for _, r in ipairs( ML.RESOURCES ) do
		if HasWord( name, r.words ) then return r.k end
	end
	return nil
end

-- Валюта лабиринта по описанию от игры: название + категория «Greatness» (если игра её называет)
local function CurrencyKey( info )
	if type( info ) ~= "table" then return nil end
	local key = ResourceKey( S( info.name ) )
	if not key or info.category == nil then return key end
	local cat = info.category:GetInfo()
	if type( cat ) == "table" and type( cat.sysName ) == "string" and cat.sysName ~= "" and cat.sysName ~= "Greatness" then return nil end
	return key
end

--------------------------------------------------------------------------------
-- Хранилище
--------------------------------------------------------------------------------
-- Секция общая для всех персонажей аккаунта. Секцию с именем аддона («MyLabs») занимает LibDnD:
-- он хранит в ней положение окна и кнопки и переписывает её целиком.
local SECTION = "MyLabsData"
ML.db = nil            -- { v, chars = { key = char }, order = { key... }, auto }
C.resImage = {}        -- значки валют, которые отдала игра (живут до перезагрузки интерфейса)
C.me = nil             -- ключ текущего персонажа
local dirty = false
local changedHook = nil

function C.OnChanged( fn ) changedHook = fn end

local function Changed()
	dirty = true
	if changedHook then changedHook() end
end
C.Changed = Changed

function C.Load()
	local g = userMods.GetGlobalConfigSection( SECTION )
	-- Ожидаем: при первом запуске секции нет (nil) — начинаем с пустой
	g = type( g ) == "table" and g or {}
	local db = type( g.db ) == "table" and g.db or {}
	db.v = 1
	db.chars = type( db.chars ) == "table" and db.chars or {}
	db.order = type( db.order ) == "table" and db.order or {}
	if db.auto == nil then db.auto = true end
	-- список рогов без дыр: пустые записи хранилище могло не сохранить
	for key, ch in pairs( db.chars ) do
		if type( ch ) ~= "table" then
			db.chars[ key ] = nil
		else
			local horns = type( ch.horns ) == "table" and ch.horns or {}
			local n = type( ch.hornCount ) == "number" and ch.hornCount or 0
			for k, _ in pairs( horns ) do
				if type( k ) == "number" and k > n then n = k end
			end
			n = math.min( n, 12 )
			local fixed = {}
			for i = 1, n do fixed[ i ] = type( horns[ i ] ) == "table" and horns[ i ] or { n = 0 } end
			ch.horns = fixed
			ch.name = type( ch.name ) == "string" and ch.name or "?"
		end
	end
	local order, seen = {}, {}
	for _, key in ipairs( db.order ) do
		if db.chars[ key ] and not seen[ key ] then
			seen[ key ] = true
			order[ #order + 1 ] = key
		end
	end
	for key, _ in pairs( db.chars ) do
		if not seen[ key ] then order[ #order + 1 ] = key end
	end
	db.order = order
	ML.db = db
	ML.DEBUG = g.debug == true --@debug
end

function C.Save()
	dirty = false
	local g = { db = ML.db }
	g.debug = ML.DEBUG --@debug
	userMods.SetGlobalConfigSection( SECTION, g )
end

function C.Char( key )
	return ML.db and ML.db.chars[ key or C.me ] or nil
end

local function EnsureMe()
	local sid = avatar.GetServerId()
	local name = S( object.GetName( avatar.GetId() ) )
	local shard = S( mission.GetShardName() )
	-- Ожидаем: если GetServerId не дал номер, ключ персонажа строим из ника и сервера
	local key = type( sid ) == "number" and ( "c" .. N( sid ) ) or ( "n" .. name .. "@" .. shard )
	C.me = key
	local db = ML.db
	local ch = db.chars[ key ]
	if type( ch ) ~= "table" then
		ch = {}
		db.chars[ key ] = ch
		db.order[ #db.order + 1 ] = key
	end
	ch.name, ch.shard = name, shard
	ch.horns = type( ch.horns ) == "table" and ch.horns or {}
	ch.res = type( ch.res ) == "table" and ch.res or {}
	ch.menu = type( ch.menu ) == "table" and ch.menu or {}
	ch.vol = type( ch.vol ) == "table" and ch.vol or {}
	local fac = unit.GetFactionId( avatar.GetId() )
	local info = fac and fac:GetInfo()
	if type( info ) == "table" and type( info.sysName ) == "string" then ch.fac = info.sysName end
	ch.seen = ML.Now()
	return ch
end

--------------------------------------------------------------------------------
-- Валюты лабиринта
--------------------------------------------------------------------------------
function C.ReadCurrencies()
	local ch = C.Char()
	if not ch then return end
	local ids = avatar.GetCurrencies()
	-- Ожидаем: сразу после входа список валют может быть ещё не готов (nil) — прочитаем по EVENT_CURRENCY_VALUE_CHANGED
	if type( ids ) ~= "table" then return end
	local res = {}
	for _, r in ipairs( ML.RESOURCES ) do res[ r.k ] = 0 end      -- нулевых валют в списке игры нет
	for _, id in pairs( ids ) do
		local info = id:GetInfo()
		local key = CurrencyKey( info )
		if key then
			local val = avatar.GetCurrencyValue( id )
			if type( val ) == "table" and type( val.value ) == "number" then res[ key ] = val.value end
			if info.image ~= nil then C.resImage[ key ] = info.image end
		end
	end
	ch.res, ch.resAt = res, ML.Now()
	Changed()
end

function C.OnCurrency( p )
	local ch = C.Char()
	if not ch or p.id == nil then return end
	local info = p.id:GetInfo()
	local key = CurrencyKey( info )
	if not key then return end
	local val = avatar.GetCurrencyValue( p.id )
	if type( val ) == "table" and type( val.value ) == "number" then
		ch.res[ key ], ch.resAt = val.value, ML.Now()
		Changed()
	end
end

--------------------------------------------------------------------------------
-- Рог: разбор реплики
--------------------------------------------------------------------------------
local function Keys( t )
	local keys = {}
	if type( t ) ~= "table" then return keys end
	for k, _ in pairs( t ) do
		if type( k ) == "number" then keys[ #keys + 1 ] = k end
	end
	table.sort( keys )
	return keys
end

-- поля данных реплики или ответа: alias -> значение
local function DataOf( cue )
	local out = {}
	if type( cue ) ~= "table" or type( cue.data ) ~= "table" then return out end
	for _, d in pairs( cue.data ) do
		if type( d ) == "table" and type( d.alias ) == "string" then
			if d.number ~= nil then out[ d.alias ] = d.number
			elseif d.money ~= nil then out[ d.alias ] = d.money
			elseif d.string ~= nil then out[ d.alias ] = S( d.string ) end
		end
	end
	return out
end

-- Тексты реплик рога (в нижнем регистре). Состояние сначала определяется по полям данных,
-- текст — там, где полей нет.
local T_DONE = { "завершил производство", "completed production", "production is complete" }
local T_NEXT = { "готов к новому производству", "ready for new production" }
local T_CANCEL = { "производство отменено", "production cancel" }
local T_BROKEN = { "восстановления работоспособности", "being repaired" }
local T_STARTING = { "запускается производство", "production is starting" }

-- Возвращает { state, prod, prodName, amount, per, launch = { key = индекс ответа }, vol = { key = объём },
--              avail = { key... }, collect = индекс, cont = индекс, cost = цена нового рога }
-- state: busy      — занят (prod, amount, per дней; broken — чинится после грабежа)
--        free      — свободен, launch — что можно запустить
--        done      — производство завершено, collect — ответ «забрать»
--        collected — ресурс только что забран, cont — ответ «дальше»
--        canceled  — производство только что остановлено игроком (вариантов запуска в реплике ещё нет)
--        launched  — производство только что запущено (prod)
function C.Parse( cue, answers )
	local r = { state = "unknown", launch = {}, vol = {}, avail = {} }
	if type( cue ) ~= "table" then cue = {} end
	local data = DataOf( cue )
	local text = Lower( ML.Text( cue.text ) )
	r.text = text
	local first = nil                 -- первый ответ, кроме «Прочитать инструкцию»
	for _, k in ipairs( Keys( answers ) ) do
		local a = answers[ k ]
		if type( a ) == "table" then
			local ad = DataOf( a )
			local name = Lower( S( a.name ) )
			if type( ad.cost ) == "number" and HasWord( name, HORN_WORDS ) then r.cost = ad.cost end
			if ad.money ~= nil and ad.granite ~= nil then
				r.volAll = ad             -- «Прочитать инструкцию»: объёмы производства сервера
			else
				if first == nil then first = { idx = k, data = ad } end
				if type( ad.value ) == "number" then
					local key = ProductKey( name )
					if key and r.launch[ key ] == nil then
						r.launch[ key ], r.vol[ key ] = k, ad.value
						r.avail[ #r.avail + 1 ] = key
					end
				end
			end
		end
	end

	local function FromData( d )
		for _, v in pairs( d ) do
			if type( v ) == "string" and v ~= "" and ProductKey( v ) then
				r.prodName, r.prod = v, ProductKey( v )
			end
		end
	end

	if type( data.periods ) == "number" and data.product ~= nil then
		r.state = "busy"
		r.prodName = tostring( data.product )
		r.prod = ProductKey( r.prodName )
		r.amount = type( data.amount ) == "number" and data.amount or nil
		r.per = data.periods
		r.broken = HasWord( text, T_BROKEN ) or nil
	elseif HasWord( text, T_BROKEN ) then
		r.state, r.broken = "busy", true
		FromData( data )
		r.amount = type( data.amount ) == "number" and data.amount or nil
	elseif HasWord( text, T_DONE ) and first then
		r.state, r.collect = "done", first.idx
		FromData( first.data )
		for _, v in pairs( first.data ) do
			if type( v ) == "number" then r.amount = v end
		end
	elseif #r.avail > 0 then
		-- есть варианты запуска — рог свободен, что бы ни было написано в реплике
		r.state = "free"
	elseif HasWord( text, T_NEXT ) then
		r.state, r.cont = "collected", first and first.idx or nil
	elseif HasWord( text, T_CANCEL ) then
		r.state, r.cont = "canceled", first and first.idx or nil
	else
		local key = ProductKey( S( cue.name ) )
		if key and ( type( data.value ) == "number" or HasWord( text, T_STARTING ) ) then
			r.state, r.prod = "launched", key
			r.amount = type( data.value ) == "number" and data.value or nil
		end
	end
	return r
end

--------------------------------------------------------------------------------
-- Рог: какое это «место». Игра не отдаёт ни постоянного номера, ни позиции рога:
-- внутри одного посещения зоны рог привязан по id объекта, при новом посещении —
-- сначала по состоянию, затем по близости точки разговора.
--------------------------------------------------------------------------------
C.Recount = function() end   -- задаётся ниже: пересчитать рога в зоне при следующем разговоре
local bind = {}              -- id объекта -> номер места (живёт одно посещение зоны)
local bound = {}             -- номер места -> id объекта
local bindZone = nil

function C.ResetBind()
	bind, bound = {}, {}
end

-- сколько дней осталось по нашим данным (рог сообщает только целые дни)
function C.DaysLeft( h, now )
	if type( h ) ~= "table" or h.st ~= "busy" or type( h.per ) ~= "number" then return nil end
	local passed = math.floor( math.max( 0, ( now or ML.Now() ) - ( h.seen or 0 ) ) / ML.DAY_MS )
	return math.max( 0, h.per - passed )
end

local function Compatible( h, st, now )
	if h.st == nil then return 0.5 end                       -- про место ещё ничего не известно
	if st.state ~= "busy" and st.state ~= "done" then return h.st == "free" and 0 or 1 end
	if st.state == "busy" then
		-- запуск отправлен, но ответ рога мы не увидели: это почти наверняка тот самый рог
		if h.st == "free" and h.tried ~= nil and h.tried == st.prod then return 0.1 end
		if h.st ~= "busy" or h.prod ~= st.prod then return 1 end
		local left = C.DaysLeft( h, now ) or 0
		return math.abs( left - ( st.per or 0 ) ) <= 1 and 0 or 0.8
	end
	if st.state == "done" then
		if h.st == "done" then return h.prod == st.prod and 0 or 0.6 end
		if h.st == "busy" and h.prod == st.prod then return ( C.DaysLeft( h, now ) or 0 ) <= 1 and 0 or 0.7 end
		return 1
	end
	return 0.5
end

function C.SlotFor( ch, objId, st, pos, hornCount )
	if bind[ objId ] then return bind[ objId ] end
	local n = math.max( hornCount or 0, #ch.horns )
	for i = #ch.horns + 1, n do ch.horns[ i ] = { n = 0 } end
	ch.hornCount = n
	local now = ML.Now()
	local best, bestCost = nil, nil
	for i = 1, n do
		if not bound[ i ] then
			local h = ch.horns[ i ]
			local cost
			if h.st == nil then
				-- строка, о которой ещё ничего не известно: берётся, если знакомой строки рядом (ближе 9 м)
				-- с подходящим состоянием нет. Неизвестные — по порядку номеров.
				cost = 9 + i * 0.01
			else
				cost = Compatible( h, st, now ) * 100
				if pos and type( h.x ) == "number" then
					local dx, dy = pos.posX - h.x, pos.posY - h.y
					cost = cost + math.min( 40, math.sqrt( dx * dx + dy * dy ) )
				else
					cost = cost + 20
				end
			end
			if bestCost == nil or cost < bestCost then best, bestCost = i, cost end
		end
	end
	if not best then
		-- все места заняты другими рогами этого посещения: рогов стало больше, чем мы знали
		C.Recount()
		best = n + 1
		ch.horns[ best ] = { n = 0 }
		ch.hornCount = best
	end
	bind[ objId ], bound[ best ] = best, objId
	return best
end

-- может ли ресурс быть назначен этому месту (Коралл и Гранит — один рог на персонажа)
function C.TakenBy( ch, key, exceptSlot )
	local p = ML.PRODUCT[ key ]
	if not p or not p.unique then return nil end
	for i, h in ipairs( ch.horns ) do
		if i ~= exceptSlot and h.assign == key then return i end
	end
	return nil
end

function C.Menu( ch )
	local seen, list = {}, {}
	for _, k in ipairs( ML.DEFAULT_MENU ) do
		seen[ k ] = true
		list[ #list + 1 ] = k
	end
	for _, k in ipairs( ch.menu or {} ) do
		if ML.PRODUCT[ k ] and not seen[ k ] then
			seen[ k ] = true
			list[ #list + 1 ] = k
		end
	end
	return list
end

local function Learn( ch, key )
	if not key then return end
	for _, k in ipairs( ch.menu ) do
		if k == key then return end
	end
	ch.menu[ #ch.menu + 1 ] = key
end

--------------------------------------------------------------------------------
-- Рог: разговор и автоматика
--------------------------------------------------------------------------------
local acts = {}              -- id объекта -> { tick, count }: защита от зацикливания
local posAt = {}             -- id объекта -> секунда, когда точка разговора учтена в последний раз
local pending = nil          -- { obj, slot, kind = collect|launch, key, tick }
local hornCount, hornCountOk = 0, false

-- Сколько рогов в зоне. Список устройств просматривается один раз за посещение зоны
-- (и заново — после разговора с прорабом: мог появиться новый рог).
local hornIds = {}           -- id рогов из списка устройств зоны
local function CountHorns()
	if hornCountOk then return hornCount end
	local devs = avatar.GetDeviceList()
	local n = 0
	hornIds = {}
	if type( devs ) == "table" then
		for _, devId in pairs( devs ) do
			if HasWord( Lower( S( object.GetName( devId ) ) ), HORN_WORDS ) then
				n = n + 1
				hornIds[ type( devId ) == "number" and devId or tostring( devId ) ] = true
			end
		end
	end
	hornCount, hornCountOk = n, true
	return n
end

-- Все строки уже заняты, а с нами говорит рог, которого среди них нет. Если привязанных рогов
-- больше нет в зоне, значит игра сменила им id без смены зоны: привязки устарели, собираем заново.
-- Иначе лишняя строка появилась бы на ровном месте.
local function DropStaleBind( ch, objId )
	if bind[ objId ] then return end
	local taken = 0
	for _ in pairs( bound ) do taken = taken + 1 end
	if taken == 0 or taken < #ch.horns then return end
	hornCountOk = false
	if CountHorns() == 0 then return end
	for id in pairs( bind ) do
		if not hornIds[ id ] then
			C.ResetBind()
			return
		end
	end
end

C.Recount = function() hornCountOk = false end

local function Act( objId, idx, what )
	local a = acts[ objId ]
	if not a or ML.tick - a.tick > 10 then
		a = { tick = ML.tick, count = 0 }
		acts[ objId ] = a
	end
	if a.count >= 4 then
		-- защита от зацикливания; молча не останавливаемся — игрок должен видеть, почему ничего не выбрано
		if not a.told then
			a.told = true
			ML.Log( "автоматика остановлена: слишком много шагов подряд у одного рога" ) --@debug
			ML.Chat( "слишком много действий с одним рогом подряд — пауза 10 секунд" )
		end
		return false
	end
	a.count = a.count + 1
	ML.Debug( "автоматика: " .. what .. " (ответ " .. N( idx ) .. ")" ) --@debug
	-- Ожидаем: ответ мог не подойти (реплика сменилась). SelectInteractorCue ничего не возвращает —
	-- результат видно по следующей реплике, её разбирает C.OnInteraction при новом EVENT_INTERACTION_STARTED.
	avatar.SelectInteractorCue( idx )
	return true
end

local function ProdTitle( key, rawName )
	local p = key and ML.PRODUCT[ key ]
	return p and p.name or ( rawName ~= nil and rawName ~= "" and rawName ) or "?"
end
C.ProdTitle = ProdTitle

local function SetBusy( ch, h, key, rawName, amount, per, now )
	h.st, h.prod, h.prodName, h.amount, h.per, h.seen = "busy", key, rawName, amount, per, now
	h.blocked, h.tried = nil, nil
end

function C.OnInteraction()
	local ch = C.Char()
	if not ch then return end
	local rawId = avatar.GetInterlocutor()
	-- Ожидаем: разговор мог уже закончиться — собеседника нет
	if rawId == nil then return end
	-- id объекта в игре — число; на случай другого типа ключом служит его строковый вид
	local objId = type( rawId ) == "number" and rawId or tostring( rawId )
	local answers = avatar.GetInteractorNextCues()
	local name = Lower( S( object.GetName( rawId ) ) )

	if not HasWord( name, HORN_WORDS ) then
		-- прораб: цена следующего рога стоит в ответе «Построить … рог изобилия за N»
		local st = C.Parse( nil, answers )
		if st.cost then
			-- цена относится к следующему рогу, поэтому запоминаем, при скольких рогах её назвали
			hornCountOk = false
			local count = math.min( 12, CountHorns() )
			if count > ( ch.hornCount or 0 ) then
				for i = #ch.horns + 1, count do ch.horns[ i ] = { n = 0 } end
				ch.hornCount = count
			end
			if ch.cost ~= st.cost or ch.costFor ~= ( ch.hornCount or 0 ) then
				ch.cost, ch.costAt, ch.costFor = st.cost, ML.Now(), ch.hornCount or 0
				Changed()
			end
		end
		return
	end

	local cue = avatar.GetInteractorCue()
	local st = C.Parse( cue, answers )
	--@debug
	if ML.DEBUG then
		local n = 0
		for _ in pairs( type( answers ) == "table" and answers or {} ) do n = n + 1 end
		ML.Log( "рог id=" .. tostring( objId ) .. ": состояние " .. st.state .. " | можно запустить: " .. table.concat( st.avail, "," ) --@debug
			.. " | ответов " .. n .. " | реплика «" .. S( type( cue ) == "table" and cue.name or nil ) .. "» | текст: "
			.. string.sub( st.text or "", 1, 160 ) )
	end
	--@end
	if st.state == "unknown" then return end           -- инструкция, подтверждения и прочее

	local now = ML.Now()
	local pos = avatar.GetPos()
	-- Ожидаем: позиции может не быть — тогда рог сопоставляем без точки разговора
	pos = ( type( pos ) == "table" and type( pos.posX ) == "number" and type( pos.posY ) == "number" ) and pos or nil

	DropStaleBind( ch, objId )
	local count = CountHorns()
	local slot = C.SlotFor( ch, objId, st, pos, count )
	local h = ch.horns[ slot ]
	--@debug
	ML.Debug( "рог id=" .. tostring( objId ) .. " -> строка " .. slot .. " | было: " .. tostring( h.st ) .. " " .. tostring( h.prod ) --@debug
		.. " | назначено: " .. tostring( h.assign ) .. " | рогов в зоне " .. count )
	--@end

	if pos and ( posAt[ objId ] == nil or ML.tick - posAt[ objId ] >= 3 ) then
		-- средняя точка разговора с этим местом; несколько реплик одного разговора — одна точка
		posAt[ objId ] = ML.tick
		local n = math.min( h.n or 0, 7 )
		h.x = ( ( h.x or pos.posX ) * n + pos.posX ) / ( n + 1 )
		h.y = ( ( h.y or pos.posY ) * n + pos.posY ) / ( n + 1 )
		h.n = n + 1
	end
	for key, v in pairs( st.vol ) do ch.vol[ key ] = v end
	for _, key in ipairs( st.avail ) do Learn( ch, key ) end

	-- наш шаг, на который это ответ (ответ приходит сразу; старый шаг уже ни при чём)
	local mine = pending and pending.obj == objId and ML.tick - pending.tick <= 10 and pending or nil

	if st.state == "busy" then
		SetBusy( ch, h, st.prod, st.prodName, st.amount, st.per, now )
		h.broken = st.broken
		Learn( ch, st.prod )
		-- по умолчанию рог продолжает добывать то же самое; занятый Коралл/Гранит второй раз не назначаем
		if h.assign == nil and st.prod and not C.TakenBy( ch, st.prod, slot ) then h.assign = st.prod end
		if mine and mine.kind == "launch" then
			ML.Chat( "рог " .. slot .. ": запущено — " .. ProdTitle( st.prod, st.prodName ) )
			pending = nil
		end
	elseif st.state == "launched" then
		SetBusy( ch, h, st.prod, nil, st.amount or ch.vol[ st.prod ], PRODUCTION_DAYS, now )
		h.broken = nil
		ML.Chat( "рог " .. slot .. ": запущено — " .. ProdTitle( st.prod ) )
		pending = nil
	elseif st.state == "done" then
		h.st, h.prod, h.prodName, h.amount, h.per, h.seen = "done", st.prod, st.prodName, st.amount, 0, now
		h.broken = nil
	else                                     -- free, collected, canceled
		if st.state == "collected" or ( mine and mine.kind == "collect" ) then
			ML.Chat( "рог " .. slot .. ": забрано — " .. ProdTitle( h.prod, h.prodName )
				.. ( type( h.amount ) == "number" and ( " " .. ML.Num( h.amount ) ) or "" ) )
			if mine and mine.kind == "collect" then pending = nil end
		end
		h.st, h.prod, h.prodName, h.amount, h.per, h.seen = "free", nil, nil, nil, nil, now
		h.broken = nil
	end
	Changed()

	if not ML.db.auto then return end
	if st.state == "done" and st.collect ~= nil then
		-- шаг записывается до вызова: ответ рога может прийти раньше, чем вызов вернётся
		pending = { obj = objId, slot = slot, kind = "collect", tick = ML.tick }
		if not Act( objId, st.collect, "рог " .. slot .. ": забираю" ) then pending = nil end
	elseif st.state == "collected" and st.cont ~= nil then
		Act( objId, st.cont, "рог " .. slot .. ": дальше" )
	elseif st.state == "free" then
		-- Правило одно: свободный рог с назначением запускается при любом разговоре — и сразу после
		-- того, как игрок сам остановил производство. Чтобы рог остался свободным, есть «Не запускать».
		local want = h.assign
		if not want or want == "none" then
			ML.Debug( "рог " .. slot .. ": свободен, запускать нечего (назначено: " .. tostring( want ) .. ")" ) --@debug
		else
			local idx = st.launch[ want ]
			if idx ~= nil then
				h.blocked = nil
				h.tried = want
				pending = { obj = objId, slot = slot, kind = "launch", key = want, tick = ML.tick }
				if not Act( objId, idx, "рог " .. slot .. ": запускаю " .. ProdTitle( want ) ) then
					h.tried, pending = nil, nil
				end
			else
				ML.Debug( "рог " .. slot .. ": варианта «" .. tostring( want ) .. "» в реплике нет" ) --@debug
				if h.blocked ~= want then
					h.blocked = want               -- например, Коралл ещё добывает другой рог
					ML.Chat( "рог " .. slot .. ": " .. ProdTitle( want ) .. " сейчас запустить нельзя, рог оставлен свободным" )
				end
			end
		end
	end
end

function C.OnZoneChanged()
	local zone = cartographer.GetCurrentZoneInfo()
	local sys = type( zone ) == "table" and zone.sysZoneName ~= nil and tostring( zone.sysZoneName ) or nil
	local ch = C.Char()
	if ch then ch.zone = sys end
	if sys ~= bindZone then
		C.ResetBind()
		bindZone = sys
		hornCountOk = false
		pending, acts, posAt = nil, {}, {}
	end
end

--------------------------------------------------------------------------------
-- Назначение ресурса месту (из окна)
--------------------------------------------------------------------------------
function C.Assign( charKey, slot, key )
	local ch = C.Char( charKey )
	local h = ch and ch.horns[ slot ]
	if not h then return false end
	if key ~= "none" and C.TakenBy( ch, key, slot ) then return false end
	h.assign = key
	h.blocked = nil
	Changed()
	return true
end

-- забыть всё о рогах персонажа: строки соберутся заново из разговоров
function C.ForgetHorns( charKey )
	local ch = C.Char( charKey )
	if not ch then return end
	ch.horns, ch.hornCount = {}, nil
	if ( charKey or C.me ) == C.me then
		C.ResetBind()
		hornCountOk = false
	end
	Changed()
end

--------------------------------------------------------------------------------
-- Сводка для окна
--------------------------------------------------------------------------------
-- готовых (или с истёкшим сроком), свободных с назначением (нужно внимание), дней до ближайшего
function C.Summary( ch, now )
	local ready, attention, soonest, known = 0, 0, nil, 0
	for _, h in ipairs( ch.horns or {} ) do
		if h.st then known = known + 1 end
		if h.st == "done" then
			ready = ready + 1
		elseif h.st == "busy" then
			local left = C.DaysLeft( h, now )
			if left == 0 then ready = ready + 1
			elseif left and ( soonest == nil or left < soonest ) then soonest = left end
		elseif h.st == "free" and h.assign and h.assign ~= "none" then
			attention = attention + 1
		end
	end
	return ready, attention, soonest, known
end

function C.ReadyTotal( now )
	local total = 0
	now = now or ML.Now()
	for _, key in ipairs( ML.db.order ) do
		local ch = ML.db.chars[ key ]
		if ch then total = total + ( C.Summary( ch, now ) ) end
	end
	return total
end

-- расчёт нового рога: { state = all|nodata|ok|embrium|lack, cost, coral, lack, embNeed, embHave }
function C.NewHorn( ch )
	local r = { coral = ch.res and ch.res.coral or nil, embHave = ch.res and ch.res.embrium or nil }
	if ( ch.hornCount or 0 ) >= 12 then
		r.state = "all"
		return r
	end
	-- цена, названная при другом числе рогов, устарела: рог с тех пор достроен
	if type( ch.cost ) ~= "number" or type( r.coral ) ~= "number" or ch.costFor ~= ( ch.hornCount or 0 ) then
		r.state = "nodata"
		return r
	end
	r.cost = ch.cost
	r.lack = math.max( 0, ch.cost - r.coral )
	r.embNeed = math.ceil( r.lack / CORAL_PER_EMBRIUM )
	if r.lack == 0 then r.state = "ok"
	elseif ( r.embHave or 0 ) >= r.embNeed then r.state = "embrium"
	else r.state = "lack" end
	return r
end

--------------------------------------------------------------------------------
-- Сундучок хранителя: вся стопка открывается сразу в выбранный ресурс
--------------------------------------------------------------------------------
local chestAt = nil          -- в какую секунду проверить сумку

function C.ChestSoon( seconds )
	chestAt = ML.tick + ( seconds or 2 )
end

local function ChestVariant( itemId, want )
	local list = itemLib.GetUsagesItemInfo( itemId )
	-- Ожидаем: у предмета может не быть вариантов использования — тогда не открываем
	if type( list ) ~= "table" then return nil end
	local found, n = nil, 0
	for _, u in pairs( list ) do
		if type( u ) == "table" then
			local kind = nil
			if u.givenAltCurrency ~= nil then
				local info = u.givenAltCurrency:GetInfo()
				local key = type( info ) == "table" and ResourceKey( S( info.name ) ) or nil
				if key == "coral" or key == "granite" then kind = key end
			elseif u.givenItem ~= nil then
				kind = "tear"
			else
				kind = "gold"
			end
			if kind == want then
				found, n = u.sysIndex, n + 1
			end
		end
	end
	if n == 1 and type( found ) == "number" then return found end
	return nil
end

local chestTry = nil         -- { count, tries, key }: сундучки, которые мы открываем прямо сейчас

local function ChestChoice( key )
	for _, c in ipairs( ML.CHEST_CHOICES ) do
		if c.k == key then return c end
	end
	return nil
end
C.ChestChoice = ChestChoice

function C.OpenChests()
	local ch = C.Char()
	if not ch or not ML.db.auto or not ChestChoice( ch.chest ) then
		chestTry = nil
		return
	end
	if ITEM_CONT_INVENTORY == nil then return end
	local items = containerLib.GetItems( ITEM_CONT_INVENTORY )
	-- Ожидаем: сумка может быть ещё не загружена (nil) — проверим при следующем поводе
	if type( items ) ~= "table" then return end
	for _, itemId in pairs( items ) do
		local info = itemLib.GetItemInfo( itemId )
		if type( info ) == "table" and HasWord( Lower( S( info.name ) ), CHEST_WORDS ) then
			local title = ChestChoice( ch.chest ).name
			local idx = ChestVariant( itemId, ch.chest )
			if idx == nil then
				ML.Chat( "сундучок хранителя: вариант «" .. title .. "» не найден среди наград, не открываю" )
				chestTry = nil
				return
			end
			if chestTry and chestTry.tries >= 3 then
				-- сразу после почты сундучок может не открываться; три попытки — и ждём следующего повода
				ML.Chat( "сундучок хранителя открыть не удалось. Попробую ещё раз при следующем входе или смене выбора" )
				chestTry = nil
				return
			end
			local stack = itemLib.GetStackInfo( itemId )
			-- Ожидаем: GetStackInfo возвращает nil для предмета не в стопке — тогда он один
			local count = type( stack ) == "table" and tonumber( stack.count ) or 1
			if count < 1 then count = 1 end
			chestTry = { count = count, tries = ( chestTry and chestTry.tries or 0 ) + 1, title = title }
			ML.Debug( "сундучок: открываю " .. N( count ) .. " шт., вариант " .. N( idx ) .. ", попытка " .. chestTry.tries ) --@debug
			-- Ожидаем: сразу после почты сундучок может не открыться. UseItemAndTakeActions ничего не возвращает —
			-- через 3 секунды проверяем сумку: сундучки остались — пробуем снова, не больше трёх раз.
			avatar.UseItemAndTakeActions( itemId, count, idx )
			C.ChestSoon( 3 )                 -- проверим, что сундучки действительно исчезли
			return
		end
	end
	if chestTry then                     -- сундучков в сумке больше нет: открыты
		ch.chestGot, ch.chestCount = ML.Now(), chestTry.count
		ML.Chat( "сундучки хранителя открыты: " .. N( chestTry.count ) .. " шт. — " .. chestTry.title )
		chestTry = nil
		Changed()
	end
end

function C.OnItemAdded( p )
	if p.isNewItem ~= true then return end
	if ITEM_CONT_INVENTORY ~= nil and p.slotType ~= ITEM_CONT_INVENTORY then return end
	local info = itemLib.GetItemInfo( p.itemId )
	if type( info ) == "table" and HasWord( Lower( S( info.name ) ), CHEST_WORDS ) then C.ChestSoon( 2 ) end
end

function C.SetChest( charKey, key )
	local ch = C.Char( charKey )
	if not ch then return end
	ch.chest = key
	Changed()
	if charKey == C.me then
		chestTry = nil
		C.ChestSoon( 1 )
	end
end

--------------------------------------------------------------------------------
-- Запуск и секундный такт
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Посещения лабиринтов за неделю: счётчик игры из окна «Сражения»
--------------------------------------------------------------------------------
-- Сражение «Лабиринт» узнаём по типу «грабительский налёт» с недельным лимитом; номер сражения
-- у игры меняется от входа к входу, поэтому его не храним.
local function LabyrinthVisits( id )
	local info = matchMaking.GetEventInfo( id )
	-- Ожидаем: описания сражения может не быть (nil) — пропускаем
	if type( info ) ~= "table" or type( info.eventType ) ~= "table" or info.eventType.pillage == nil then return nil end
	local max = info.maxVisitsPerWeek
	if type( max ) ~= "number" or max <= 0 then return nil end
	-- Ожидаем: пока посещений за неделю не было, игра счётчик не присылает (nil) — это ноль
	local n = type( info.weeklyVisits ) == "number" and info.weeklyVisits or 0
	return n, max
end

local function StoreVisits( n, max )
	local ch = C.Char()
	if not ch then return end
	local v = ch.visits
	local same = type( v ) == "table" and v.n == n and v.max == max
	ch.visits = { n = n, max = max, at = ML.Now() }
	if not same then Changed() end
end

function C.ReadVisits()
	-- Ожидаем: список сражений приходит не сразу после запроса — дождёмся EVENT_MATCH_MAKING_EVENTS_CHANGED
	if not matchMaking.IsEventListValid() then return end
	local ids = matchMaking.GetEvents()
	if type( ids ) ~= "table" then return end
	for _, id in pairs( ids ) do
		local n, max = LabyrinthVisits( id )
		if n then
			StoreVisits( n, max )
			return
		end
	end
end

function C.OnVisitsChanged( p )
	local n, max = LabyrinthVisits( p.eventId )
	if n then StoreVisits( n, max ) end
end

-- Просим игру присылать список сражений (сама она делает это только при открытом окне «Сражения»)
function C.ListenVisits()
	-- Ожидаем: сражения персонажу могут быть ещё закрыты — тогда посещений не показываем
	if not matchMaking.CanUseMatchMaking() then return end
	matchMaking.ListenEvents( true )
	C.ReadVisits()
end

-- Сколько раз персонаж посетил лабиринты за неделю: n, max; nil — данных нет.
-- Число, записанное больше недели назад, игра уже точно обнулила — его не показываем.
function C.Visits( ch, now )
	local v = ch.visits
	if type( v ) ~= "table" or type( v.n ) ~= "number" or type( v.max ) ~= "number" or type( v.at ) ~= "number" then return nil end
	if ( now or ML.Now() ) - v.at > 7 * ML.DAY_MS then return nil end
	return v.n, v.max
end

function C.Init()
	C.Load()
	EnsureMe()
	C.OnZoneChanged()
	C.ReadCurrencies()
	C.ListenVisits()
	C.ChestSoon( 5 )
	C.Save()
end

function C.OnSecond()
	if chestAt and ML.tick >= chestAt then
		chestAt = nil
		C.OpenChests()
	end
	if dirty then C.Save() end
end
