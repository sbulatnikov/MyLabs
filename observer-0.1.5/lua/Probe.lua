--------------------------------------------------------------------------------
-- MyLabs / Probe.lua
-- Наблюдатель: записывает в журнал всё, что игра сообщает о собеседнике
-- (рог изобилия, прораб и прочие), валютах, предметах в сумке и зоне.
-- Никаких действий в игре не выполняет.
--------------------------------------------------------------------------------
ML.Probe = {}
local P = ML.Probe
local S, N, Log, Try, Fn, Flat = ML.S, ML.N, ML.Log, ML.Try, ML.Fn, ML.Flat

local HORN_NAME = "Рог изобилия"
local HORN_ALIASES = { product = true, periods = true, total = true }
local LIMIT_LINES = 1500      -- не больше стольких строк о валютах и о предметах за запуск

local DUMPS_PER_10S = 30       -- не больше стольких полных записей разговора за 10 секунд

local runNo = 0               -- номер запуска аддона (растёт в общей секции настроек)
local dumpTicks = {}          -- моменты последних полных записей
local lastSig, lastSigTick = nil, -1000
local talkSeq = 0
local lastZoneKey, lastZoneSys = nil, nil
local curLines, itemLines = 0, 0

--------------------------------------------------------------------------------
-- Мелочи
--------------------------------------------------------------------------------
local function Pos( p )
	if type( p ) ~= "table" or type( p.posX ) ~= "number" then return "нет" end
	return string.format( "(%.2f, %.2f, %.2f)", p.posX, p.posY or 0, p.posZ or 0 )
end

-- Пары (ключ, значение) с числовыми ключами по возрастанию ключа:
-- таблицы игры бывают и с нуля, и с единицы, и с дырками
local function Indexed( t )
	local keys = {}
	if type( t ) ~= "table" then return keys end
	for k, _ in pairs( t ) do
		if type( k ) == "number" then keys[ #keys + 1 ] = k end
	end
	table.sort( keys )
	return keys
end

local function Zone()
	local z = Try( "cartographer.GetCurrentZoneInfo", Fn( cartographer, "GetCurrentZoneInfo" ) )
	if type( z ) ~= "table" then return { sys = "?", sub = "", name = "", allod = "" } end
	return { sys = tostring( z.sysZoneName ), sub = tostring( z.sysSubZoneName or "" ),
		name = S( z.zoneName ), allod = S( z.allod ), subName = S( z.subZoneName ) }
end

local function ZoneText( z )
	return "sysZoneName=\"" .. z.sys .. "\" sysSubZoneName=\"" .. z.sub .. "\" зона=\"" .. z.name ..
		"\" подзона=\"" .. tostring( z.subName ) .. "\" аллод=\"" .. z.allod .. "\""
end

local function TimeText()
	local w = ML.WorldMs()
	return "местное " .. ML.LocalStamp() .. " | сервер мс=" .. N( w ) .. ( w and ( " (" .. ML.StampFromMs( w ) .. ")" ) or "" )
end

local function CurrencyInfo( id )
	if id == nil then return nil end
	local info = Try( "CurrencyId:GetInfo", function() return id:GetInfo() end )
	return type( info ) == "table" and info or nil
end

--------------------------------------------------------------------------------
-- Предметы
--------------------------------------------------------------------------------
local function Usages( itemId, prefix )
	local list = Try( "itemLib.GetUsagesItemInfo", Fn( itemLib, "GetUsagesItemInfo" ), itemId )
	if type( list ) ~= "table" then
		Log( prefix .. "варианты использования: нет таблицы" )
		return
	end
	local n = 0
	for k, u in pairs( list ) do
		n = n + 1
		if type( u ) == "table" then
			local cur = CurrencyInfo( u.givenAltCurrency )
			Log( prefix .. "вариант [" .. tostring( k ) .. "] sysIndex=" .. N( u.sysIndex ) ..
				" consumeItems=" .. N( u.consumeItems ) ..
				" описание=\"" .. Flat( S( u.usageDesc ), 200 ) .. "\"" ..
				" валюта=" .. ( cur and ( "\"" .. tostring( cur.sysName ) .. "\" (" .. S( cur.name ) .. ")" ) or tostring( u.givenAltCurrency ) ) ..
				" предмет=" .. tostring( u.givenItem ) ..
				" количество=" .. N( u.givenCount ) ..
				" maxStack=" .. N( u.maxStack ) )
		else
			Log( prefix .. "вариант [" .. tostring( k ) .. "] = " .. tostring( u ) )
		end
	end
	if n == 0 then Log( prefix .. "варианты использования: пусто" ) end
end

-- Строка о предмете; возвращает true, если предмет «используется с выбором действия»
local function ItemLine( prefix, itemId, evSysName, slot, onlyUsable )
	local usable = Try( "itemLib.IsUseItemAndTakeActions", Fn( itemLib, "IsUseItemAndTakeActions" ), itemId )
	if onlyUsable and usable ~= true then return false end
	local info = Try( "itemLib.GetItemInfo", Fn( itemLib, "GetItemInfo" ), itemId )
	info = type( info ) == "table" and info or {}
	local stack = Try( "itemLib.GetStackInfo", Fn( itemLib, "GetStackInfo" ), itemId )
	local source = Try( "itemLib.GetSource", Fn( itemLib, "GetSource" ), itemId )
	Log( prefix .. " id=" .. N( itemId ) .. " слот=" .. N( slot ) ..
		" имя=\"" .. Flat( S( info.name ), 120 ) .. "\"" ..
		" sysName(событие)=\"" .. tostring( evSysName ) .. "\"" ..
		" sysName(предмет)=\"" .. tostring( info.sysName ) .. "\"" ..
		" debugName=\"" .. tostring( info.debugName ) .. "\"" ..
		" штук=" .. N( type( stack ) == "table" and stack.count or nil ) ..
		" источник=" .. tostring( source ) ..
		" выборДействия=" .. tostring( usable ) )
	if usable == true then Usages( itemId, "    " ) end
	return usable == true
end

-- При входе печатаются только предметы, у которых есть выбор из нескольких вариантов
-- или вариант с валютой: так должен найтись сундучок хранителя.
function P.Inventory()
	local cont = ITEM_CONT_INVENTORY
	if cont == nil then
		Log( "сумка: нет константы ITEM_CONT_INVENTORY" )
		return
	end
	local items = Try( "containerLib.GetItems", Fn( containerLib, "GetItems" ), cont )
	if type( items ) ~= "table" then
		Log( "сумка: нет данных" )
		return
	end
	local total, usable, shown = 0, 0, 0
	for slot, itemId in pairs( items ) do
		total = total + 1
		if Try( "itemLib.IsUseItemAndTakeActions", Fn( itemLib, "IsUseItemAndTakeActions" ), itemId ) == true then
			usable = usable + 1
			local list = Try( "itemLib.GetUsagesItemInfo", Fn( itemLib, "GetUsagesItemInfo" ), itemId )
			local n, withCurrency = 0, false
			if type( list ) == "table" then
				for _, u in pairs( list ) do
					n = n + 1
					if type( u ) == "table" and u.givenAltCurrency ~= nil then withCurrency = true end
				end
			end
			if n > 1 or withCurrency then
				shown = shown + 1
				ItemLine( "сумка: предмет с выбором", itemId, nil, slot, false )
			end
		end
	end
	Log( "сумка: предметов " .. total .. ", с выбором действия " .. usable .. ", из них с несколькими вариантами или валютой " .. shown )
end

function P.OnItemAdded( p )
	if p.isNewItem ~= true then return end
	if ITEM_CONT_INVENTORY ~= nil and p.slotType ~= ITEM_CONT_INVENTORY then return end
	itemLines = itemLines + 1
	if itemLines > LIMIT_LINES then return end
	ItemLine( "новый предмет в сумке с выбором действия (" .. ML.LocalStamp() .. ")", p.itemId, p.sysName, p.slot, true )
	-- сундучок хранителя разбирается сразу, как только попал в сумку (без открытия)
	local info = Try( "itemLib.GetItemInfo", Fn( itemLib, "GetItemInfo" ), p.itemId )
	local name = type( info ) == "table" and S( info.name ) or ""
	if P.IsChestName( name ) then
		Log( "сундучок появился в сумке: sysName(событие)=\"" .. tostring( p.sysName ) .. "\" слот=" .. N( p.slot ) )
		P.Chest( "" )
	end
end

function P.OnItemTaken( p )
	itemLines = itemLines + 1
	if itemLines > LIMIT_LINES then return end
	Log( "получен предмет: actionType=" .. tostring( p.actionType ) )
end

--------------------------------------------------------------------------------
-- Валюты
--------------------------------------------------------------------------------
-- Нужны только валюты лабиринта: категория «Greatness» и названия с ключевыми словами.
-- У них нет системного имени, поэтому печатаются все поля описания — ищем нелокализованный признак.
local LAB_WORDS = { "ранит", "оралл", "мбриум", "етеорит", "рипас" }

local function IsLabCurrency( info, catSys )
	if catSys == "Greatness" then return true end
	local name = S( info.name )
	for _, w in ipairs( LAB_WORDS ) do
		if string.find( name, w, 1, true ) then return true end
	end
	return false
end

function P.Currencies()
	local ids = Try( "avatar.GetCurrencies", Fn( avatar, "GetCurrencies" ) )
	local total, shown = 0, 0
	for _, k in ipairs( Indexed( ids ) ) do
		total = total + 1
		local id = ids[ k ]
		local info = CurrencyInfo( id )
		if info then
			local cat = info.category and Try( "CurrencyCategoryId:GetInfo", function() return info.category:GetInfo() end )
			local catSys = type( cat ) == "table" and cat.sysName or nil
			if IsLabCurrency( info, catSys ) then
				shown = shown + 1
				local val = Try( "avatar.GetCurrencyValue", Fn( avatar, "GetCurrencyValue" ), id )
				val = type( val ) == "table" and val or {}
				local fields = {}
				for fk, fv in pairs( info ) do
					local t = type( fv )
					fields[ #fields + 1 ] = tostring( fk ) .. "=" ..
						( ( t == "string" or t == "number" or t == "boolean" ) and tostring( fv ) or ( "<" .. t .. ">" ) )
				end
				table.sort( fields )
				Log( "валюта \"" .. Flat( S( info.name ), 80 ) .. "\" значение=" .. N( val.value ) .. " макс=" .. N( val.maxValue ) ..
					" категория=\"" .. tostring( catSys ) .. "\" id=" .. tostring( id ) .. " | поля: " .. table.concat( fields, ", " ) )
			end
		end
	end
	Log( "валюты: всего " .. total .. ", из них похожих на валюты лабиринта " .. shown )
end

function P.OnCurrency( kind )
	return function( p )
		curLines = curLines + 1
		if curLines > LIMIT_LINES then return end
		local info = CurrencyInfo( p.id )
		local val = p.id and Try( "avatar.GetCurrencyValue", Fn( avatar, "GetCurrencyValue" ), p.id )
		val = type( val ) == "table" and val or {}
		Log( kind .. " (" .. ML.LocalStamp() .. ") sysName=\"" .. tostring( p.sysName ) .. "\"" ..
			" имя=\"" .. Flat( S( info and info.name ), 80 ) .. "\"" ..
			" delta=" .. N( p.delta ) .. " стало=" .. N( val.value ) .. " макс=" .. N( val.maxValue ) )
	end
end

--------------------------------------------------------------------------------
-- Зона и эффекты на персонаже (признак главного лабиринта)
--------------------------------------------------------------------------------
function P.Buffs()
	local ids = Try( "object.GetBuffs", Fn( object, "GetBuffs" ), avatar.GetId() )
	if type( ids ) ~= "table" then
		Log( "эффекты на персонаже: нет данных" )
		return
	end
	local names, total, unnamed, seen = {}, 0, 0, {}
	for _, buffId in pairs( ids ) do
		total = total + 1
		local sys = Try( "object.GetBuffSysName", Fn( object, "GetBuffSysName" ), buffId )
		if type( sys ) == "string" and sys ~= "" then
			if not seen[ sys ] then
				seen[ sys ] = true
				names[ #names + 1 ] = sys
			end
		else
			unnamed = unnamed + 1
		end
	end
	table.sort( names )
	Log( "эффекты на персонаже: всего " .. total .. ", без системного имени " .. unnamed )
	local line = ""
	for _, n in ipairs( names ) do
		if #line + #n > 600 then
			Log( "  эффекты: " .. line )
			line = ""
		end
		line = line .. ( line ~= "" and ", " or "" ) .. n
	end
	if line ~= "" then Log( "  эффекты: " .. line ) end
end

function P.OnZoneChanged()
	local z = Zone()
	local key = z.sys .. "/" .. z.sub
	if key == lastZoneKey then return end
	lastZoneKey = key
	Log( "зона (" .. ML.LocalStamp() .. "): " .. ZoneText( z ) )
	if z.sys ~= lastZoneSys then
		lastZoneSys = z.sys
		P.Buffs()
	end
end

--------------------------------------------------------------------------------
-- Реплики собеседника
--------------------------------------------------------------------------------
local KNOWN_DATA = { alias = true, money = true, number = true, string = true, itemId = true,
	image = true, titlePicture = true }

local function DataText( d, found )
	if type( d ) ~= "table" then return tostring( d ) end
	local parts = { "alias=" .. tostring( d.alias ) }
	if d.money ~= nil then parts[ #parts + 1 ] = "money=" .. ( type( d.money ) == "number" and N( d.money ) or S( d.money ) ) end
	if d.number ~= nil then parts[ #parts + 1 ] = "number=" .. N( d.number ) end
	if d.string ~= nil then parts[ #parts + 1 ] = "string=\"" .. Flat( S( d.string ), 200 ) .. "\"" end
	if d.itemId ~= nil then
		local info = Try( "itemLib.GetItemInfo", Fn( itemLib, "GetItemInfo" ), d.itemId )
		parts[ #parts + 1 ] = "itemId=" .. N( d.itemId ) .. " (\"" .. Flat( S( type( info ) == "table" and info.name or nil ), 80 ) .. "\")"
	end
	if d.image ~= nil then parts[ #parts + 1 ] = "image=есть" end
	if d.titlePicture ~= nil then parts[ #parts + 1 ] = "titlePicture=есть" end
	for k, v in pairs( d ) do
		if not KNOWN_DATA[ k ] then parts[ #parts + 1 ] = tostring( k ) .. "=<" .. type( v ) .. ">" end
	end
	if found and type( d.alias ) == "string" then
		found[ d.alias ] = ( d.number ~= nil and d.number ) or ( d.money ~= nil and d.money ) or
			( d.string ~= nil and S( d.string ) ) or true
	end
	return table.concat( parts, " " )
end

-- Печатает реплику; собирает псевдонимы данных в found
local function DumpCue( cue, prefix, found, textLimit )
	if type( cue ) ~= "table" then
		Log( prefix .. "нет (" .. tostring( cue ) .. ")" )
		return
	end
	Log( prefix .. "name=\"" .. Flat( S( cue.name ), 400 ) .. "\" isSpecial=" .. tostring( cue.isSpecial ) )
	local text = ML.Text( cue.text )
	if text ~= "" then Log( prefix .. "  text=\"" .. Flat( text, textLimit or 900 ) .. "\"" ) end
	local keys = Indexed( cue.data )
	for _, k in ipairs( keys ) do
		Log( prefix .. "  data[" .. k .. "] " .. DataText( cue.data[ k ], found ) )
	end
	for k, v in pairs( cue ) do
		if k ~= "name" and k ~= "text" and k ~= "data" and k ~= "isSpecial" then
			Log( prefix .. "  поле " .. tostring( k ) .. "=<" .. type( v ) .. "> " .. Flat( S( v ), 120 ) )
		end
	end
end

local function AliasList( found )
	local names = {}
	for k, _ in pairs( found ) do names[ #names + 1 ] = k end
	table.sort( names )
	return table.concat( names, "," )
end

--------------------------------------------------------------------------------
-- Разговор. Полная запись делается только для нового «вида» разговора
-- (собеседник + реплика + набор полей + набор ответов), повтор — одной строкой:
-- так журнал не раздувается, а запись не просаживает кадры.
--------------------------------------------------------------------------------
local shapeSeen = {}          -- вид разговора -> сколько раз встречался
local hornIds = {}            -- id рогов, найденных в зоне при последнем просмотре списка устройств

local function Interlocutor()
	local objId = Try( "avatar.GetInterlocutor", Fn( avatar, "GetInterlocutor" ) )
	local info = Try( "avatar.GetInteractorInfo", Fn( avatar, "GetInteractorInfo" ) )
	info = type( info ) == "table" and info or nil
	local id = objId or ( info and info.interactorId ) or nil
	local name = id ~= nil and S( Try( "object.GetName", Fn( object, "GetName" ), id ) ) or ""
	return id, name, info
end

-- Рога в зоне видимости: список пересматривается, только если собеседника в нём нет
local function HornList( id )
	if hornIds[ id ] then return nil end
	local devs = Try( "avatar.GetDeviceList", Fn( avatar, "GetDeviceList" ) )
	local total, ids = 0, {}
	hornIds = {}
	if type( devs ) == "table" then
		for _, devId in pairs( devs ) do
			total = total + 1
			if total <= 200 and S( Try( "object.GetName", Fn( object, "GetName" ), devId ) ) == HORN_NAME then
				hornIds[ devId ] = true
				ids[ #ids + 1 ] = N( devId )
			end
		end
	end
	return "устройств в зоне видимости " .. total .. ", рогов " .. #ids .. ": " .. table.concat( ids, " " )
end

function P.OnInteraction()
	talkSeq = talkSeq + 1
	local id, name, info = Interlocutor()
	if id == nil then return end

	-- ограничитель: не чаще DUMPS_PER_10S записей за 10 секунд
	local recent = {}
	for _, t in ipairs( dumpTicks ) do
		if ML.tick - t < 10 then recent[ #recent + 1 ] = t end
	end
	dumpTicks = recent
	if #dumpTicks >= DUMPS_PER_10S then return end

	local cue = Try( "avatar.GetInteractorCue", Fn( avatar, "GetInteractorCue" ) )
	local answers = Try( "avatar.GetInteractorNextCues", Fn( avatar, "GetInteractorNextCues" ) )
	local keys = Indexed( answers )

	-- значения полей реплики и «вид» разговора
	local vals, valText, shape = {}, "", name .. "|" .. ( type( cue ) == "table" and S( cue.name ) or "нет" )
	if type( cue ) == "table" then
		for _, k in ipairs( Indexed( cue.data ) ) do
			local d = cue.data[ k ]
			if type( d ) == "table" and type( d.alias ) == "string" then
				local v = ( d.number ~= nil and N( d.number ) ) or ( d.money ~= nil and N( d.money ) ) or
					( d.string ~= nil and S( d.string ) ) or "?"
				vals[ d.alias ] = v
				valText = valText .. " " .. d.alias .. "=" .. v
				shape = shape .. "|" .. d.alias
			end
		end
	end
	for _, k in ipairs( keys ) do
		local a = answers[ k ]
		shape = shape .. "|>" .. ( type( a ) == "table" and S( a.name ) or "?" )
	end

	-- та же реплика того же собеседника подряд не записывается
	local sig = N( id ) .. "|" .. shape .. "|" .. valText
	if sig == lastSig and ML.tick - lastSigTick < 5 then return end
	lastSig, lastSigTick = sig, ML.tick
	dumpTicks[ #dumpTicks + 1 ] = ML.tick

	local myPos = Try( "avatar.GetPos", Fn( avatar, "GetPos" ) )
	local dir = Try( "avatar.GetDir", Fn( avatar, "GetDir" ) )
	local isHorn = ( name == HORN_NAME ) or vals.product ~= nil or vals.periods ~= nil or vals.total ~= nil
	local count = ( shapeSeen[ shape ] or 0 ) + 1
	shapeSeen[ shape ] = count

	-- короткая строка — всегда
	Log( "разговор " .. talkSeq .. " | " .. TimeText() .. " | id=" .. N( id ) .. " \"" .. name .. "\"" ..
		" | персонаж " .. Pos( myPos ) .. " напр=" .. N( dir ) ..
		" |" .. ( valText ~= "" and valText or " без полей" ) .. " | ответов " .. #keys ..
		" | вид №" .. count .. ( isHorn and " | РОГ" or "" ) )

	if isHorn then
		local list = HornList( id )
		if list then Log( "  " .. list ) end
	end

	-- полная запись — только для нового вида разговора
	if count == 1 then
		local zone = Zone()
		Log( "  новый вид разговора, полная запись | " .. ZoneText( zone ) )
		if info then
			local flags = {}
			for k, v in pairs( info ) do
				if v == true then flags[ #flags + 1 ] = tostring( k ) end
			end
			table.sort( flags )
			Log( "  признаки: " .. table.concat( flags, "," ) )
		end
		local found = {}
		DumpCue( cue, "  реплика: ", found, 1200 )
		for i, k in ipairs( keys ) do
			if i > 40 then break end
			DumpCue( answers[ k ], "  ответ [" .. k .. "]: ", found, 700 )
		end
	end

	if isHorn then
		local what = vals.product and ( vals.product .. ( vals.amount and ( " x" .. vals.amount ) or "" ) ) or "без продукции"
		ML.Chat( "рог: " .. what .. ( vals.periods and ( ", дней: " .. vals.periods ) or "" ) )
	end
end

--------------------------------------------------------------------------------
-- Отчёт при входе персонажем (и по команде /mylabs dump)
--------------------------------------------------------------------------------
function P.Report( reason, countRun )
	Log( "=== MyLabs " .. ML.VERSION .. ": отчёт (" .. tostring( reason ) .. ") | " .. TimeText() .. " ===" )

	-- общая секция настроек: видна ли всем персонажам, целы ли данные
	local g = ML.ReadSection()
	g.probe = type( g.probe ) == "table" and g.probe or {}
	local pr = g.probe
	Log( "настройки: прошлых запусков " .. N( tonumber( pr.runs ) or 0 ) ..
		", прошлый персонаж \"" .. tostring( pr.lastChar ) .. "\" (" .. tostring( pr.lastAt ) .. ")" )
	if countRun then
		runNo = ( tonumber( pr.runs ) or 0 ) + 1
		pr.runs = runNo
		pr.lastChar = ML.MyName()
		pr.lastAt = ML.LocalStamp()
		pr.sightings = nil      -- записи о встречах с рогами больше не ведутся
		ML.WriteSection( g )
	end
	Log( "запуск №" .. runNo )

	-- личность
	local acc = Try( "userMods.GetAccountUniqueId", Fn( userMods, "GetAccountUniqueId" ) )
	if type( acc ) == "string" then
		Log( "аккаунт: первые 8 знаков " .. string.sub( acc, 1, 8 ) .. ", длина " .. #acc )
	else
		Log( "аккаунт: " .. tostring( acc ) )
	end
	local myId = avatar.GetId()
	local sid = Try( "avatar.GetServerId", Fn( avatar, "GetServerId" ) )
	Log( "персонаж: имя=\"" .. ML.MyName() .. "\" id=" .. N( myId ) ..
		" serverId: тип=" .. type( sid ) .. " текст=" .. tostring( sid ) )
	local playerShard = Try( "unit.GetPlayerShardName", Fn( unit, "GetPlayerShardName" ), myId )
	Log( "сервер: mission.GetShardName=\"" .. ML.Shard() .. "\" unit.GetPlayerShardName=\"" .. S( playerShard ) .. "\"" )
	local fac = Try( "unit.GetFactionId", Fn( unit, "GetFactionId" ), myId )
	local facInfo = fac and Try( "FactionId:GetInfo", function() return fac:GetInfo() end )
	if type( facInfo ) == "table" then
		Log( "фракция: sysName=\"" .. tostring( facInfo.sysName ) .. "\" имя=\"" .. S( facInfo.name ) .. "\"" )
	else
		Log( "фракция: нет данных (" .. tostring( fac ) .. ")" )
	end

	-- время
	local l, gl, w = ML.LocalMs(), Try( "mission.GetGlobalDateTimeMs", Fn( mission, "GetGlobalDateTimeMs" ) ), ML.WorldMs()
	Log( "время: местное мс=" .. N( l ) .. " | глобальное мс=" .. N( gl ) .. " | серверное мс=" .. N( w ) )
	if l and w then Log( "время: серверное минус местное = " .. N( ( w - l ) / 1000 ) .. " с" ) end
	if l and type( gl ) == "number" then Log( "время: глобальное минус местное = " .. N( ( gl - l ) / 1000 ) .. " с" ) end

	-- зона и эффекты
	local z = Zone()
	lastZoneKey, lastZoneSys = z.sys .. "/" .. z.sub, z.sys
	Log( "зона: " .. ZoneText( z ) )
	P.Buffs()

	P.Currencies()
	P.Inventory()
	Log( "=== конец отчёта ===" )
end

--------------------------------------------------------------------------------
-- Сундучок хранителя подземелий. Единственное действие аддона, и только по команде:
--   /mylabs chest          — показать сундучки в сумке и варианты награды
--   /mylabs chest coral    — открыть один сундучок и взять коралл (если вариант опознан)
--   /mylabs chest N        — открыть один сундучок с вариантом sysIndex = N
--------------------------------------------------------------------------------
local CHEST_WORDS = { "Сундучок хранител", "Keeper's Chest" }
local CORAL_WORDS = { "оралл", "oral" }

local function HasWord( text, words )
	for _, w in ipairs( words ) do
		if string.find( text, w, 1, true ) then return true end
	end
	return false
end

function P.IsChestName( name )
	return HasWord( name, CHEST_WORDS )
end

local function FindChests()
	local res = {}
	local items = ITEM_CONT_INVENTORY ~= nil and Try( "containerLib.GetItems", Fn( containerLib, "GetItems" ), ITEM_CONT_INVENTORY ) or nil
	if type( items ) ~= "table" then return res end
	for slot, itemId in pairs( items ) do
		local info = Try( "itemLib.GetItemInfo", Fn( itemLib, "GetItemInfo" ), itemId )
		local name = type( info ) == "table" and S( info.name ) or ""
		if HasWord( name, CHEST_WORDS ) then
			local stack = Try( "itemLib.GetStackInfo", Fn( itemLib, "GetStackInfo" ), itemId )
			res[ #res + 1 ] = { id = itemId, slot = slot, name = name,
				count = type( stack ) == "table" and stack.count or nil,
				usable = Try( "itemLib.IsUseItemAndTakeActions", Fn( itemLib, "IsUseItemAndTakeActions" ), itemId ) == true }
		end
	end
	return res
end

local function ChestVariants( itemId )
	local out = {}
	local list = Try( "itemLib.GetUsagesItemInfo", Fn( itemLib, "GetUsagesItemInfo" ), itemId )
	if type( list ) ~= "table" then return out end
	for key, u in pairs( list ) do
		if type( u ) == "table" then
			local cur = CurrencyInfo( u.givenAltCurrency )
			local itemName = ""
			if u.givenItem ~= nil then
				local gi = Try( "itemLib.GetItemInfo(givenItem)", Fn( itemLib, "GetItemInfo" ), u.givenItem )
				itemName = type( gi ) == "table" and S( gi.name ) or ""
			end
			-- описание у всех вариантов одно («Обменять»), различает их только награда
			local label = ( cur and S( cur.name ) ) or ( itemName ~= "" and itemName ) or
				( ( u.givenItem == nil and u.givenAltCurrency == nil ) and "золото (награда без валюты и предмета)" or ML.Text( u.usageDesc ) )
			out[ #out + 1 ] = { key = key, sysIndex = u.sysIndex, label = label, count = u.givenCount,
				consume = u.consumeItems, hasCurrency = cur ~= nil, hasItem = u.givenItem ~= nil }
		end
	end
	table.sort( out, function( a, b ) return ( tonumber( a.sysIndex ) or 0 ) < ( tonumber( b.sysIndex ) or 0 ) end )
	return out
end

function P.Chest( arg )
	-- "coral", "2", "coral 3", "coral all": что взять и сколько сундучков открыть (по умолчанию один)
	local words = {}
	for w in string.gmatch( string.lower( arg or "" ), "%S+" ) do words[ #words + 1 ] = w end
	arg = words[ 1 ] or ""
	local howMany = words[ 2 ]
	local chests = FindChests()
	if #chests == 0 then
		Log( "сундучок: в сумке не найден" )
		ML.Chat( "сундучок хранителя в сумке не найден (если он в почте — сначала заберите)" )
		return
	end
	local c = chests[ 1 ]
	local vars = ChestVariants( c.id )
	Log( "сундучок: id=" .. N( c.id ) .. " слот=" .. N( c.slot ) .. " имя=\"" .. c.name .. "\" штук=" .. N( c.count ) ..
		" выборДействия=" .. tostring( c.usable ) .. " вариантов=" .. #vars .. " всего сундучков в сумке=" .. #chests )
	for _, v in ipairs( vars ) do
		Log( "  сундучок: вариант sysIndex=" .. N( v.sysIndex ) .. " ключ=" .. tostring( v.key ) .. " \"" .. Flat( v.label, 200 ) ..
			"\" количество=" .. N( v.count ) .. " consumeItems=" .. N( v.consume ) ..
			" валюта=" .. tostring( v.hasCurrency ) .. " предмет=" .. tostring( v.hasItem ) )
	end

	local pick = nil
	if arg == "coral" or arg == "коралл" then
		local found = {}
		for _, v in ipairs( vars ) do
			if HasWord( v.label, CORAL_WORDS ) then found[ #found + 1 ] = v end
		end
		if #found == 1 then pick = found[ 1 ] end
		if not pick then
			Log( "сундучок: вариант с кораллом не опознан (подходящих " .. #found .. "), ничего не открыто" )
			ML.Chat( "вариант с кораллом не опознан, сундучок НЕ открыт. Варианты:" )
		end
	elseif tonumber( arg ) ~= nil then
		for _, v in ipairs( vars ) do
			if tonumber( v.sysIndex ) == tonumber( arg ) then pick = v end
		end
		if not pick then ML.Chat( "варианта " .. arg .. " нет, сундучок НЕ открыт. Варианты:" ) end
	else
		ML.Chat( c.name .. ", штук: " .. N( c.count ) .. ". Варианты:" )
	end

	if not pick then
		for _, v in ipairs( vars ) do
			ML.Chat( "  " .. N( v.sysIndex ) .. ": " .. ( v.label ~= "" and v.label or "без названия" ) .. " x" .. N( v.count ) )
		end
		if #vars == 0 then ML.Chat( "  вариантов игра не отдала" ) end
		ML.Chat( "открыть один: /mylabs chest coral или /mylabs chest номер; все сразу: /mylabs chest coral all" )
		return
	end

	-- признак «выбор действия» у сундучка игра отдаёт как false, хотя варианты есть:
	-- он только записывается, открытию не мешает
	local count = 1
	if howMany == "all" or howMany == "все" then
		count = tonumber( c.count ) or 1
	elseif tonumber( howMany ) ~= nil then
		count = math.max( 1, math.min( math.floor( tonumber( howMany ) ), tonumber( c.count ) or 1 ) )
	end
	local use = Fn( avatar, "UseItemAndTakeActions" )
	if not use then
		ML.Chat( "нет функции открытия, сундучок НЕ открыт" )
		return
	end
	Log( ">>> сундучок: открываю штук " .. count .. ", вариант sysIndex=" .. N( pick.sysIndex ) .. " \"" .. Flat( pick.label, 200 ) ..
		"\" выборДействия=" .. tostring( c.usable ) .. " | " .. TimeText() )
	ML.Chat( "открываю сундучков: " .. count .. ", беру: " .. ( pick.label ~= "" and pick.label or ( "вариант " .. N( pick.sysIndex ) ) ) )
	Try( "avatar.UseItemAndTakeActions", use, c.id, count, pick.sysIndex )
end

function P.RunNo()
	return runNo
end
