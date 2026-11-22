--------------------------------------------------------------------------------
-- MyLabs / Util.lua — строки, журнал, время, виджеты. Файл в Windows-1251.
--------------------------------------------------------------------------------
Global( "ML", {} )

ML.VERSION = "0.9.3"
ML.TAG = "[MyLabs] "
ML.tick = 0                -- секунды с запуска (EVENT_SECOND_TIMER)
ML.DEBUG = false           -- подробный журнал шагов автоматики (/mylabs debug) --@debug

--------------------------------------------------------------------------------
-- Строки
--------------------------------------------------------------------------------
function ML.WS( s )
	return userMods.ToWString( s or "" )
end

function ML.S( v )
	if v == nil then return "" end
	if type( v ) == "string" then return v end
	if type( v ) == "number" or type( v ) == "boolean" then return tostring( v ) end
	-- Ожидаем: на входе может быть другой объект API — тогда пустая строка
	if apitype( v ) == "WString" then return userMods.FromWString( v ) end
	return ""
end

-- Текст реплики: WString или ValuedText (у него свой метод ToWString)
function ML.Text( v )
	if v == nil then return "" end
	if type( v ) == "string" then return v end
	local api = apitype( v )
	if api == "WString" then return userMods.FromWString( v ) end
	if api == "ValuedText" then return userMods.FromWString( v:ToWString() ) end
	-- Ожидаем: другой тип — текста нет
	return ""
end

-- Нижний регистр для латиницы и кириллицы в Windows-1251
function ML.Lower( s )
	return ( string.gsub( s or "", ".", function( c )
		local b = string.byte( c )
		if ( b >= 65 and b <= 90 ) or ( b >= 0xC0 and b <= 0xDF ) then return string.char( b + 32 ) end
		if b == 0xA8 then return string.char( 0xB8 ) end
		return c
	end ) )
end

function ML.Trim( s )
	return ( string.gsub( string.gsub( s or "", "^%s+", "" ), "%s+$", "" ) )
end

-- 1234567 -> "1 234 567"
function ML.Num( v )
	if type( v ) ~= "number" then return "—" end
	local s = string.format( "%.0f", v )
	local neg = string.sub( s, 1, 1 ) == "-"
	if neg then s = string.sub( s, 2 ) end
	local out = ""
	while #s > 3 do
		out = " " .. string.sub( s, -3 ) .. out
		s = string.sub( s, 1, -4 )
	end
	return ( neg and "-" or "" ) .. s .. out
end

function ML.N( v )
	if type( v ) ~= "number" then return tostring( v ) end
	if v == math.floor( v ) and math.abs( v ) < 1e15 then return string.format( "%.0f", v ) end
	return string.format( "%.2f", v )
end

--------------------------------------------------------------------------------
-- Журнал и чат
--------------------------------------------------------------------------------
--@debug
-- Отладочная сборка: журнал в Personal\\Logs\\mods.txt (в обычной сборке этого блока нет)
function ML.Log( text )
	common.LogInfo( "common", ML.WS( ML.TAG .. tostring( text ) ) )
end

function ML.Debug( text )
	if ML.DEBUG then ML.Log( text ) end
end
--@end

function ML.Chat( text, level )
	userMods.SendSelfChatMessage( ML.WS( ML.TAG .. tostring( text ) ), level or "notice" )
end

--------------------------------------------------------------------------------
-- Время: серверные Unix-мс; запасной вариант — часы компьютера
--------------------------------------------------------------------------------
function ML.Now()
	local v = mission.GetWorldTimeMs()
	-- Ожидаем: до связи с сервером мирового времени может не быть (0) — берём часы компьютера
	if type( v ) == "number" and v > 0 then return v end
	v = common.GetLocalDateTimeMs()
	return type( v ) == "number" and v or 0
end

ML.DAY_MS = 86400000

-- Серверное время идёт по UTC; сдвиг до времени компьютера считаем один раз (с точностью до 15 минут)
local tzOffset = nil
local function TzOffset()
	if tzOffset == nil then
		local world = mission.GetWorldTimeMs()
		local loc = common.GetLocalDateTimeMs()
		if type( world ) == "number" and type( loc ) == "number" and world > 0 then
			tzOffset = math.floor( ( loc - world ) / 900000 + 0.5 ) * 900000
			if math.abs( tzOffset ) > 14 * 3600000 then tzOffset = 0 end
		else
			tzOffset = 0
		end
	end
	return tzOffset
end

-- "12.11 в 22:15" по часам компьютера
function ML.Stamp( ms )
	if type( ms ) ~= "number" or ms <= 0 then return "нет данных" end
	local d = common.GetDateTimeFromMs( ms + TzOffset() )
	if type( d ) ~= "table" then return "нет данных" end
	return string.format( "%02d.%02d в %02d:%02d", tonumber( d.d ) or 0, tonumber( d.m ) or 0, tonumber( d.h ) or 0, tonumber( d.min ) or 0 )
end

--------------------------------------------------------------------------------
-- Виджеты: кэш и пропуск повторных вызовов с тем же значением (как в RPL и BAA)
--------------------------------------------------------------------------------
local widgetCache = {}

function ML.W( name )
	local w = widgetCache[ name ]
	if w == nil then
		w = mainForm:GetChildChecked( name, true ) or false
		widgetCache[ name ] = w
	end
	return w or nil
end

function ML.Child( parent, name )
	if not parent then return nil end
	return parent:GetChildChecked( name, false )
end

local memo = setmetatable( {}, { __mode = "k" } )
local function M( w )
	local m = memo[ w ]
	if not m then
		m = {}
		memo[ w ] = m
	end
	return m
end

function ML.Show( w, on )
	if not w then return end
	on = on and true or false
	local m = M( w )
	if m.show ~= on then
		m.show = on
		w:Show( on )
	end
end

function ML.Enable( w, on )
	if not w then return end
	on = on and true or false
	local m = M( w )
	if m.enable ~= on then
		m.enable = on
		w:Enable( on )
	end
end

function ML.Fade( w, a )
	if not w then return end
	local m = M( w )
	if m.fade ~= a then
		m.fade = a
		w:SetFade( a )
	end
end

function ML.SetText( w, s )
	if not w then return end
	s = s or ""
	local m = M( w )
	if m.text ~= s then
		m.text = s
		w:SetVal( "value", ML.WS( s ) )
	end
end

function ML.SetVariant( w, v )
	if not w then return end
	local m = M( w )
	if m.variant ~= v then
		m.variant = v
		w:SetVariant( v )
	end
end

local iconGroup = nil
function ML.Tex( key )
	if iconGroup == nil then
		iconGroup = common.GetAddonRelatedTextureGroup( "Icons", true ) or false
	end
	if iconGroup and iconGroup:HasTexture( key ) then return iconGroup:GetTexture( key ) end
	return nil
end

-- Картинка, полученная от игры (например, значок валюты); tag — метка для пропуска повторов
function ML.SetTexId( w, tag, tex )
	if not w or tex == nil then return false end
	local m = M( w )
	if m.tex == tag then return true end
	w:SetBackgroundTexture( tex )
	m.tex = tag
	return true
end

-- Ширина виджета (для полоски срока)
function ML.SetWidth( w, px )
	if not w then return end
	local m = M( w )
	if m.width == px then return end
	m.width = px
	local pl = w:GetPlacementPlain()
	pl.sizeX = px
	w:SetPlacementPlain( pl )
end

function ML.SetTex( w, key )
	if not w or not key then return end
	local m = M( w )
	if m.tex == key then return end
	local t = ML.Tex( key )
	if t then
		m.tex = key
		w:SetBackgroundTexture( t )
	end
end
