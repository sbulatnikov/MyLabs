--------------------------------------------------------------------------------
-- MyLabs / Util.lua
-- Общие помощники: строки, журнал, чат. Файл в Windows-1251.
-- Версия 0.1 — наблюдатель: ничего не нажимает и не выбирает в игре,
-- только пишет в Personal\Logs\mods.txt то, что отдаёт игра.
--------------------------------------------------------------------------------
Global( "ML", {} )

ML.VERSION = "0.1.5"
ML.TAG = "[MyLabs] "
ML.tick = 0                -- секунды с запуска (EVENT_SECOND_TIMER)

--------------------------------------------------------------------------------
-- Строки
--------------------------------------------------------------------------------
function ML.WS( s )
	return userMods.ToWString( s or "" )
end

-- WString или что угодно -> обычная строка
function ML.S( v )
	if v == nil then return "" end
	if type( v ) == "string" then return v end
	if type( v ) == "number" or type( v ) == "boolean" then return tostring( v ) end
	local ok, r = pcall( userMods.FromWString, v )
	if ok and type( r ) == "string" then return r end
	return tostring( v )
end

-- Текст реплики: WString или ValuedText (у него свой метод ToWString)
function ML.Text( v )
	if v == nil then return "" end
	if type( v ) == "string" then return v end
	local ok, r = pcall( userMods.FromWString, v )
	if ok and type( r ) == "string" then return r end
	local ok2, w = pcall( function() return v:ToWString() end )
	if ok2 and w ~= nil then
		local ok3, r3 = pcall( userMods.FromWString, w )
		if ok3 and type( r3 ) == "string" then return r3 end
	end
	return "<" .. type( v ) .. ">"
end

-- Число без экспоненты: целые — как есть, дробные — два знака
function ML.N( v )
	if type( v ) ~= "number" then return tostring( v ) end
	if v == math.floor( v ) and math.abs( v ) < 1e15 then return string.format( "%.0f", v ) end
	return string.format( "%.2f", v )
end

-- Одна строка журнала: без переводов строк, не длиннее limit
function ML.Flat( s, limit )
	s = string.gsub( tostring( s or "" ), "[\r\n\t]+", " " )
	limit = limit or 700
	if #s > limit then s = string.sub( s, 1, limit ) .. " ...(" .. tostring( #s ) .. ")" end
	return s
end

--------------------------------------------------------------------------------
-- Журнал и чат
--------------------------------------------------------------------------------
-- Строка в Personal\Logs\mods.txt (стандартный журнал дополнений)
function ML.Log( text )
	pcall( common.LogInfo, "common", ML.WS( ML.TAG .. tostring( text ) ) )
end

function ML.Chat( text, level )
	pcall( userMods.SendSelfChatMessage, ML.WS( ML.TAG .. tostring( text ) ), level or "notice" )
end

-- Вызов с защитой: ошибка Lua попадает в журнал, а не ломает обработчик.
-- Возвращает результат функции или nil.
local failed = {}
-- Аргументы передаются как есть (...): игра строго считает их число,
-- лишний nil — уже ошибка «wrong params count».
function ML.Try( name, f, ... )
	if type( f ) ~= "function" then
		if not failed[ name ] then
			failed[ name ] = true
			ML.Log( "нет функции " .. name )
		end
		return nil
	end
	local ok, r = pcall( f, ... )
	if not ok then
		if not failed[ name ] then
			failed[ name ] = true
			ML.Log( "ошибка " .. name .. ": " .. tostring( r ) )
		end
		return nil
	end
	return r
end

-- Функция библиотеки по имени: ML.Fn( avatar, "GetPos" ) -> функция или nil
function ML.Fn( lib, name )
	if type( lib ) == "table" or type( lib ) == "userdata" then
		local ok, f = pcall( function() return lib[ name ] end )
		if ok and type( f ) == "function" then return f end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Время
--------------------------------------------------------------------------------
-- Серверное время, мс (mission.GetWorldTimeMs, с 16.0.01); nil, если функции нет
function ML.WorldMs()
	local v = ML.Try( "mission.GetWorldTimeMs", ML.Fn( mission, "GetWorldTimeMs" ) )
	return type( v ) == "number" and v or nil
end

function ML.LocalMs()
	local v = ML.Try( "common.GetLocalDateTimeMs", ML.Fn( common, "GetLocalDateTimeMs" ) )
	return type( v ) == "number" and v or nil
end

-- "13.11.2026 12:45:07" по часам компьютера
function ML.LocalStamp()
	local d = ML.Try( "common.GetLocalDateTime", ML.Fn( common, "GetLocalDateTime" ) )
	if type( d ) ~= "table" then return "?" end
	return string.format( "%02d.%02d.%04d %02d:%02d:%02d",
		tonumber( d.d ) or 0, tonumber( d.m ) or 0, tonumber( d.y ) or 0,
		tonumber( d.h ) or 0, tonumber( d.min ) or 0, tonumber( d.s ) or 0 )
end

-- Время в Unix-мс -> "13.11.2026 12:45:07" (в часовом поясе клиента)
function ML.StampFromMs( ms )
	if type( ms ) ~= "number" then return "?" end
	local d = ML.Try( "common.GetDateTimeFromMs", ML.Fn( common, "GetDateTimeFromMs" ), ms )
	if type( d ) ~= "table" then return ML.N( ms ) end
	return string.format( "%02d.%02d.%04d %02d:%02d:%02d",
		tonumber( d.d ) or 0, tonumber( d.m ) or 0, tonumber( d.y ) or 0,
		tonumber( d.h ) or 0, tonumber( d.min ) or 0, tonumber( d.s ) or 0 )
end

--------------------------------------------------------------------------------
-- Персонаж
--------------------------------------------------------------------------------
function ML.MyName()
	if not avatar.IsExist() then return "" end
	return ML.S( ML.Try( "object.GetName", object.GetName, avatar.GetId() ) )
end

function ML.Shard()
	return ML.S( ML.Try( "mission.GetShardName", ML.Fn( mission, "GetShardName" ) ) )
end

--------------------------------------------------------------------------------
-- Общая секция настроек (одна на все персонажи аккаунта и компьютера).
-- Пишется целиком, поэтому перед записью читается заново.
--------------------------------------------------------------------------------
function ML.ReadSection()
	local ok, g = pcall( userMods.GetGlobalConfigSection, "MyLabs" )
	return ( ok and type( g ) == "table" ) and g or {}
end

function ML.WriteSection( g )
	local ok, err = pcall( userMods.SetGlobalConfigSection, "MyLabs", g )
	if not ok then ML.Log( "не удалось записать настройки: " .. tostring( err ) ) end
	return ok
end
