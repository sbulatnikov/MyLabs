--------------------------------------------------------------------------------
-- MyLabs / UI.lua — кнопка на экране, окно «список — карточка», выпадающий список.
-- Окно ничего не считает само: всё берётся из ML.Core.
--------------------------------------------------------------------------------
ML.UI = {}
local UI = ML.UI
local C = ML.Core
local W, Child, Show, Enable, Fade, SetText, SetVariant, SetTex = ML.W, ML.Child, ML.Show, ML.Enable, ML.Fade, ML.SetText,
	ML.SetVariant, ML.SetTex
local Num = ML.Num

local ui = {}
UI.sel = nil                 -- ключ персонажа, открытого в карточке
local list = {}              -- ключи персонажей в порядке строк списка
local shown = {}             -- номера рогов (в данных) в порядке строк таблицы
local menu = nil             -- открытый выпадающий список: { kind = horn|chest, slot, items, anchor }
local dirty = true
local MAX_HORNS, MAX_CHARS, MAX_ITEMS = 12, 12, 8
local PRODUCTION_DAYS = 15
local VAR_NORMAL, VAR_OPEN, VAR_ATTENTION = 0, 1, 2

--------------------------------------------------------------------------------
-- Инициализация
--------------------------------------------------------------------------------
function UI.Init()
	ui.window = W( "MLWindow" )
	ui.host = W( "MLHost" )
	ui.button = W( "MLButton" )
	ui.badge = W( "MLBadge" )
	ui.badgeText = W( "MLBadgeText" )
	ui.ready = W( "ReadyBadge" )
	ui.readyText = Child( ui.ready, "ReadyBadgeText" )
	ui.readyNone = W( "ReadyBadgeNone" )
	SetText( Child( ui.readyNone, "ReadyBadgeNoneText" ), "Готовых нет" )

	SetText( W( "CharsTitle" ), "Персонажи" )
	ui.charsCount = W( "CharsCount" )
	ui.chars = {}
	for i = 1, MAX_CHARS do
		local row = W( "CharRow" .. i )
		local r = { row = row, dot = Child( row, "CharDot" ), fac = Child( row, "CharFac" ), name = Child( row, "CharName" ),
			visits = Child( row, "CharVisits" ),
			ok = Child( row, "CharPillOk" ), warn = Child( row, "CharPillWarn" ), time = Child( row, "CharTime" ) }
		r.okText = Child( r.ok, "CharPillOkText" )
		r.warnText = Child( r.warn, "CharPillWarnText" )
		ui.chars[ i ] = r
	end

	ui.cardFac = W( "CardFac" )
	ui.cardName = W( "CardName" )
	ui.here = W( "HereBadge" )
	SetText( Child( ui.here, "HereBadgeText" ), "Вы здесь" )
	ui.seen = W( "CardSeen" )
	ui.cardVisits = W( "CardVisits" )
	ui.chips = {}
	for i, r in ipairs( ML.RESOURCES ) do
		local chip = W( "Chip" .. i )
		ui.chips[ i ] = { chip = chip, icon = Child( chip, "ChipIcon" ), value = Child( chip, "ChipValue" ) }
		SetTex( ui.chips[ i ].icon, r.icon )
	end

	SetText( W( "HornsTitle" ), "Рога изобилия" )
	ui.hornsCount = W( "HornsCount" )
	SetText( W( "ColNo" ), "№" )
	SetText( W( "ColRun" ), "Запущен" )
	SetText( W( "ColAssign" ), "Назначен" )
	SetText( W( "ColLeft" ), "Осталось" )
	ui.hornsHint = W( "HornsHint" )
	SetText( ui.hornsHint, "Заговорите с рогом — он появится здесь" )
	ui.horns = {}
	for i = 1, MAX_HORNS do
		local row = W( "HornRow" .. i )
		local btn = Child( row, "AssignBtn" )
		local bar = Child( row, "HornBar" )
		local r = { row = row, no = Child( row, "HornNo" ), runIcon = Child( row, "RunIcon" ), runName = Child( row, "RunName" ),
			runDim = Child( row, "RunNameDim" ), arrow = Child( row, "Arrow" ), btn = btn, btnIcon = Child( btn, "AssignIcon" ),
			btnName = Child( btn, "AssignName" ), time = Child( row, "HornTime" ), bar = bar, barFill = Child( bar, "HornBarFill" ),
			ok = Child( row, "HornPillOk" ), warn = Child( row, "HornPillWarn" ), mute = Child( row, "HornPillMute" ) }
		r.okText = Child( r.ok, "HornPillOkText" )
		r.warnText = Child( r.warn, "HornPillWarnText" )
		r.muteText = Child( r.mute, "HornPillMuteText" )
		r.noText = Child( r.no, "HornNoText" )
		ui.horns[ i ] = r
	end
	local fill = ui.horns[ 1 ].barFill
	ui.barWidth = fill and fill:GetPlacementPlain().sizeX or 96

	SetText( W( "ChestTitle" ), "Сундучок хранителя" )
	ui.chestBtn = W( "ChestBtn" )
	ui.chestIcon = Child( ui.chestBtn, "ChestBtnIcon" )
	ui.chestName = Child( ui.chestBtn, "ChestBtnName" )
	ui.chestNote = W( "ChestNote" )

	SetText( W( "NewTitle" ), "Новый Рог Изобилия" )
	SetText( W( "NewColNeed" ), "Нужно" )
	SetText( W( "NewColHave" ), "Есть" )
	SetText( W( "NewColLack" ), "Не хватает" )
	ui.newBadge = {}
	for _, kind in ipairs( { "Ok", "Warn", "Mute" } ) do
		local b = W( "NewBadge" .. kind )
		ui.newBadge[ kind ] = { w = b, text = Child( b, "NewBadge" .. kind .. "Text" ) }
	end
	ui.newRows = {}
	for i = 1, 2 do
		local row = W( "NewRow" .. i )
		ui.newRows[ i ] = { row = row, icon = Child( row, "NewIcon" ), name = Child( row, "NewName" ), need = Child( row, "NewNeed" ),
			have = Child( row, "NewHave" ), lackWarn = Child( row, "NewLackWarn" ), lackOk = Child( row, "NewLackOk" ) }
	end
	SetTex( ui.newRows[ 1 ].icon, "RES_CORAL" )
	SetText( ui.newRows[ 1 ].name, "Коралл" )
	SetTex( ui.newRows[ 2 ].icon, "RES_EMBRIUM" )
	SetText( ui.newRows[ 2 ].name, "Эмбриум на обмен" )

	ui.menu = W( "Menu" )
	ui.catcher = W( "MenuCatcher" )
	ui.items = {}
	for i = 1, MAX_ITEMS do
		local it = W( "MenuItem" .. i )
		local owner = Child( it, "MenuOwner" )
		ui.items[ i ] = { w = it, icon = Child( it, "MenuIcon" ), name = Child( it, "MenuName" ), dim = Child( it, "MenuNameDim" ),
			owner = owner, ownerText = Child( owner, "MenuOwnerText" ) }
	end

	Show( ui.window, false )
	Show( ui.menu, false )
	Show( ui.catcher, false )
end

--------------------------------------------------------------------------------
-- Вспомогательное
--------------------------------------------------------------------------------
local function Days( n )
	return tostring( n ) .. " дн."
end

-- 1 000 000 в плашку ресурса не помещается: миллионы пишутся коротко
local function Short( v )
	if type( v ) ~= "number" then return "—" end
	if v >= 1000000 then
		local m = v / 1000000
		if m == math.floor( m ) then return string.format( "%d млн", m ) end
		return ( string.gsub( string.format( "%.2f млн", m ), "%.", "," ) )
	end
	return Num( v )
end

local function FacIcon( ch )
	if ch.fac == "League" then return "FAC_LEAGUE" end
	if ch.fac == "Empire" then return "FAC_EMPIRE" end
	return "FAC_NONE"
end

local function Product( key )
	if key == "none" then return "Не запускать", "RES_NONE" end
	local p = key and ML.PRODUCT[ key ]
	if p then return p.name, p.icon end
	return nil, nil
end

-- назначение отличается от того, что рог делает сейчас
local function Differs( h )
	if h.assign == nil then return false end
	if h.st == "busy" or h.st == "done" then return h.assign ~= h.prod end
	if h.st == "free" then return h.assign ~= "none" end
	return false
end

local function HornCount( ch )
	return math.min( MAX_HORNS, math.max( ch.hornCount or 0, #( ch.horns or {} ) ) )
end

local function BuildList()
	list = {}
	local db = ML.db
	if C.me and db.chars[ C.me ] then list[ 1 ] = C.me end
	for _, key in ipairs( db.order ) do
		if key ~= C.me and db.chars[ key ] and #list < MAX_CHARS then list[ #list + 1 ] = key end
	end
	if not UI.sel or not db.chars[ UI.sel ] then UI.sel = list[ 1 ] end
end

--------------------------------------------------------------------------------
-- Отрисовка
--------------------------------------------------------------------------------
local function RenderButton( now )
	local total = C.ReadyTotal( now )
	UI.readyTotal = total
	Show( ui.badge, total > 0 )
	if total > 0 then SetText( ui.badgeText, tostring( total ) ) end
	SetVariant( ui.button, ui.window:IsVisible() and 1 or 0 )
end

local function RenderChars( now )
	SetText( ui.charsCount, tostring( #list ) )
	for i = 1, MAX_CHARS do
		local r, key = ui.chars[ i ], list[ i ]
		local ch = key and ML.db.chars[ key ]
		Show( r.row, ch ~= nil )
		if ch then
			SetVariant( r.row, key == UI.sel and 1 or 0 )
			Show( r.dot, key == C.me )
			SetTex( r.fac, FacIcon( ch ) )
			SetText( r.name, ch.name )
			local visits, visitsMax = C.Visits( ch, now )
			SetText( r.visits, visits and ( visits .. "/" .. visitsMax ) or "" )
			local ready, attention, soonest, known = C.Summary( ch, now )
			Show( r.ok, ready > 0 )
			Show( r.warn, ready == 0 and attention > 0 )
			local text = ""
			if ready > 0 then
				SetText( r.okText, "Готово: " .. ready )
			elseif attention > 0 then
				SetText( r.warnText, "Ждут: " .. attention )
			elseif soonest then
				text = Days( soonest )
			elseif known == 0 then
				text = "нет данных"
			else
				text = "—"
			end
			SetText( r.time, text )
		end
	end
end

-- Строка окна показывает рог, с которым персонаж уже разговаривал. slot — номер рога в данных.
local function RenderHorn( r, slot, ch, now )
	local h = slot and ch.horns[ slot ]
	Show( r.row, h ~= nil )
	if not h then return end
	SetText( r.noText, tostring( slot ) )
	local pillOk, pillWarn, pillMute, timeText, bar = nil, nil, nil, "", nil
	local dimText = nil

	if h.st == "busy" or h.st == "done" then
		local name, icon = Product( h.prod )
		SetTex( r.runIcon, icon or "RES_NONE" )
		SetText( r.runName, name or ( h.prodName ~= nil and h.prodName ~= "" and h.prodName ) or "?" )
		local left = h.st == "done" and 0 or C.DaysLeft( h, now )
		if left == 0 then
			pillOk = "Готов"
		elseif left == nil then
			pillMute = h.broken and "Чинится" or "Занят"
		else
			timeText = Days( left )
			bar = math.max( 0, math.min( 1, ( PRODUCTION_DAYS - left ) / PRODUCTION_DAYS ) )
		end
	else
		dimText = "Не запущен"
		if h.assign and h.assign ~= "none" then pillWarn = "Свободен" else pillMute = "Свободен" end
	end

	local running = dimText == nil
	Show( r.runIcon, running )
	Show( r.runName, running )
	Show( r.runDim, not running )
	if dimText then SetText( r.runDim, dimText ) end

	local differs = Differs( h )
	SetTex( r.arrow, differs and "ARROW_ON" or "ARROW_OFF" )
	local name, icon = Product( h.assign )
	Show( r.btnIcon, icon ~= nil )
	if icon then SetTex( r.btnIcon, icon ) end
	SetText( r.btnName, name or "Не выбрано" )
	local open = menu and menu.kind == "horn" and menu.slot == slot
	SetVariant( r.btn, open and VAR_OPEN or ( differs and VAR_ATTENTION or VAR_NORMAL ) )

	SetText( r.time, timeText )
	Show( r.bar, bar ~= nil )
	if bar then ML.SetWidth( r.barFill, math.max( 2, math.floor( ui.barWidth * bar + 0.5 ) ) ) end
	Show( r.ok, pillOk ~= nil )
	Show( r.warn, pillWarn ~= nil )
	Show( r.mute, pillMute ~= nil )
	if pillOk then SetText( r.okText, pillOk ) end
	if pillWarn then SetText( r.warnText, pillWarn ) end
	if pillMute then SetText( r.muteText, pillMute ) end
end

local function RenderNewHorn( ch )
	local nh = C.NewHorn( ch )
	local kind, text
	if nh.state == "all" then kind, text = "Mute", "Все рога построены"
	elseif nh.state == "nodata" then kind, text = "Mute", "Цена неизвестна"
	elseif nh.state == "ok" then kind, text = "Ok", "Можно строить"
	elseif nh.state == "embrium" then kind, text = "Ok", "Можно строить за Эмбриум"
	else kind, text = "Warn", "Ресурсов не хватает" end
	for k, b in pairs( ui.newBadge ) do
		Show( b.w, k == kind )
		if k == kind then SetText( b.text, text ) end
	end
	local known = nh.state == "ok" or nh.state == "embrium" or nh.state == "lack"
	local function Row( r, need, have, lack )
		SetText( r.need, known and Num( need ) or "—" )
		SetText( r.have, Num( have ) )
		local warn = known and lack > 0
		Show( r.lackWarn, warn )
		Show( r.lackOk, not warn )
		if warn then SetText( r.lackWarn, Num( lack ) ) else SetText( r.lackOk, known and "0" or "—" ) end
	end
	Row( ui.newRows[ 1 ], nh.cost, nh.coral, nh.lack or 0 )
	Row( ui.newRows[ 2 ], nh.embNeed, nh.embHave, known and math.max( 0, nh.embNeed - ( nh.embHave or 0 ) ) or 0 )
end

local function RenderCard( now )
	local ch = ML.db.chars[ UI.sel ]
	if not ch then return end
	SetTex( ui.cardFac, FacIcon( ch ) )
	SetText( ui.cardName, ch.name )
	local here = UI.sel == C.me
	Show( ui.here, here )
	Show( ui.seen, not here )
	if not here then SetText( ui.seen, "данные от " .. ML.Stamp( ch.seen ) ) end
	local visits, visitsMax = C.Visits( ch, now )
	SetText( ui.cardVisits, visits and ( "Посещения лабиринтов: " .. visits .. " из " .. visitsMax ) or "" )

	local res = ch.res or {}
	for i, r in ipairs( ML.RESOURCES ) do
		SetText( ui.chips[ i ].value, ch.resAt and Short( res[ r.k ] or 0 ) or "—" )
		-- значок валюты от самой игры (нужен для «Платы наёмникам»: своей картинки у аддона нет)
		if r.k == "mercs" and C.resImage[ r.k ] ~= nil then ML.SetTexId( ui.chips[ i ].icon, "@" .. r.k, C.resImage[ r.k ] ) end
	end

	-- строки появляются по мере разговоров: показываем только рога, о которых уже что-то известно
	shown = {}
	for i, h in ipairs( ch.horns ) do
		if h.st and #shown < MAX_HORNS then shown[ #shown + 1 ] = i end
	end
	local total = HornCount( ch )
	local count = ""
	if #shown > 0 then
		count = ( total > #shown ) and ( #shown .. " из " .. total ) or tostring( #shown )
	end
	SetText( ui.hornsCount, count )
	Show( ui.hornsHint, #shown == 0 )
	for i = 1, MAX_HORNS do RenderHorn( ui.horns[ i ], shown[ i ], ch, now ) end

	local choice = C.ChestChoice( ch.chest )
	SetTex( ui.chestIcon, choice and choice.icon or "RES_NONE" )
	SetText( ui.chestName, choice and choice.name or "Не открывать" )
	SetVariant( ui.chestBtn, ( menu and menu.kind == "chest" ) and VAR_OPEN or VAR_NORMAL )
	SetText( ui.chestNote, ch.chestGot and ( "открыт " .. ML.Stamp( ch.chestGot ) ) or "" )

	RenderNewHorn( ch )
end

local function RenderMenu()
	Show( ui.menu, menu ~= nil )
	Show( ui.catcher, menu ~= nil )
	if not menu then return end
	for i = 1, MAX_ITEMS do
		local it, d = ui.items[ i ], menu.items[ i ]
		Show( it.w, d ~= nil )
		if d then
			SetVariant( it.w, d.selected and 1 or 0 )
			SetTex( it.icon, d.icon )
			Fade( it.icon, d.owner and 0.35 or 1 )
			Show( it.name, not d.owner )
			Show( it.dim, d.owner ~= nil )
			SetText( d.owner and it.dim or it.name, d.name )
			Show( it.owner, d.owner ~= nil )
			if d.owner then SetText( it.ownerText, tostring( d.owner ) ) end
		end
	end
end

function UI.Render()
	if not ui.window then return end
	dirty = false
	local now = ML.Now()
	RenderButton( now )
	if not ui.window:IsVisible() then return end
	BuildList()
	local total = UI.readyTotal or 0
	Show( ui.ready, total > 0 )
	Show( ui.readyNone, total == 0 )
	if total > 0 then SetText( ui.readyText, "Готово: " .. total ) end
	RenderChars( now )
	RenderCard( now )
	RenderMenu()
end

-- данные изменились: окно перерисуется на ближайшем секундном такте (не чаще раза в секунду)
function UI.Invalidate()
	dirty = true
end

local sinceRender = 0
function UI.OnSecond()
	sinceRender = sinceRender + 1
	if dirty or sinceRender >= 60 then
		sinceRender = 0
		UI.Render()
	end
end

function UI.ShowWindow( on )
	if on and not ui.window:IsVisible() then UI.sel = C.me end
	if not on then
		menu = nil
	end
	Show( ui.window, on )
	UI.Render()
end

function UI.ToggleWindow()
	UI.ShowWindow( not ui.window:IsVisible() )
end

--------------------------------------------------------------------------------
-- Выпадающий список
--------------------------------------------------------------------------------
-- положение виджета внутри окна: сумма сдвигов по цепочке родителей
local function OffsetInWindow( w )
	local x, y = 0, 0
	local p = w
	for _ = 1, 8 do
		if not p or p:GetName() == "MLWindow" then break end
		local pl = p:GetPlacementPlain()
		x, y = x + ( pl.posX or 0 ), y + ( pl.posY or 0 )
		p = p:GetParent()
	end
	return x, y
end

local function PlaceMenu( anchor, count )
	local x, y = OffsetInWindow( anchor )
	local ap = anchor:GetPlacementPlain()
	local first = ui.items[ 1 ].w:GetPlacementPlain()
	local h = first.posY * 2 + first.sizeY * count
	local win = ui.window:GetPlacementPlain()
	local top = y + ap.sizeY + 2
	if top + h > win.sizeY - 6 then top = y - h - 2 end      -- вниз не помещается — раскрываем вверх
	local pl = ui.menu:GetPlacementPlain()
	pl.posX, pl.posY, pl.sizeY = x, top, h
	ui.menu:SetPlacementPlain( pl )
end

local function OpenMenu( kind, slot, anchor )
	local ch = ML.db.chars[ UI.sel ]
	if not ch then return end
	local items = {}
	if kind == "horn" then
		local h = ch.horns[ slot ]
		if not h then return end
		for _, key in ipairs( C.Menu( ch ) ) do
			local name, icon = Product( key )
			items[ #items + 1 ] = { key = key, name = name, icon = icon, selected = h.assign == key, owner = C.TakenBy( ch, key, slot ) }
		end
		items[ #items + 1 ] = { key = "none", name = "Не запускать", icon = "RES_NONE", selected = h.assign == "none" }
	else
		for _, c in ipairs( ML.CHEST_CHOICES ) do
			items[ #items + 1 ] = { key = c.k, name = c.name, icon = c.icon, selected = ch.chest == c.k }
		end
		items[ #items + 1 ] = { key = "none", name = "Не открывать", icon = "RES_NONE", selected = not C.ChestChoice( ch.chest ) }
	end
	while #items > MAX_ITEMS do table.remove( items, #items - 1 ) end
	menu = { kind = kind, slot = slot, items = items }
	PlaceMenu( anchor, #items )
	UI.Render()
end

function UI.CloseMenu()
	if not menu then return end
	menu = nil
	UI.Render()
end

local function RowIndex( w, prefix )
	local p = w
	for _ = 1, 4 do
		if not p then return nil end
		local n = tonumber( string.match( p:GetName() or "", "^" .. prefix .. "(%d+)$" ) or "" )
		if n then return n end
		p = p:GetParent()
	end
	return nil
end

function UI.OnAssign( params )
	local i = params.widget and RowIndex( params.widget, "HornRow" )
	local slot = i and shown[ i ]
	if not slot then return end
	if menu and menu.kind == "horn" and menu.slot == slot then return UI.CloseMenu() end
	OpenMenu( "horn", slot, ui.horns[ i ].btn )
end

function UI.OnChest()
	if menu and menu.kind == "chest" then return UI.CloseMenu() end
	OpenMenu( "chest", nil, ui.chestBtn )
end

function UI.OnMenuPick( params )
	local i = params.widget and RowIndex( params.widget, "MenuItem" )
	local d = menu and i and menu.items[ i ]
	if not d then return end
	if d.owner then return end                       -- Коралл/Гранит уже у другого рога: в строке виден его номер
	if menu.kind == "horn" then
		C.Assign( UI.sel, menu.slot, d.key )
	else
		C.SetChest( UI.sel, d.key )
	end
	menu = nil
	UI.Render()
end

function UI.OnChar( params )
	local i = params.widget and RowIndex( params.widget, "CharRow" )
	local key = i and list[ i ]
	if not key then return end
	UI.sel = key
	menu = nil
	UI.Render()
end
