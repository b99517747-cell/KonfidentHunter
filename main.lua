-- ===== KONFIGURACJA =====
local REFRESH_TIME   = 60
local CONFIG_URL     = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
local DOMYSLNY_KLUCZ = "P"
local DISCORD_URL    = "https://discord.gg/YjTWGZYD"
-- ========================

local WindUI      = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/download/1.6.64-fix/main.lua"
))()

local Players     = game:GetService("Players")
local TweenSvc    = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ===================================================
--  THUMBNAIL CACHE
-- ===================================================

local thumbCache = {}

local function getThumb(userId)
    if thumbCache[userId] then return thumbCache[userId] end
    local url = ""
    pcall(function()
        url = Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.AvatarBust,
            Enum.ThumbnailSize.Size100x100
        ) or ""
    end)
    if url ~= "" then thumbCache[userId] = url end
    return url
end

-- Pobierz username przez API (omija skrypty ukrywające DisplayName w grze)
local function getRealUsername(userId)
    local name = ""
    pcall(function()
        name = Players:GetNameFromUserIdAsync(userId)
    end)
    if name == "" then
        -- fallback: szukaj w Players
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == userId then name = p.Name; break end
        end
    end
    return name ~= "" and name or ("ID:"..tostring(userId))
end

-- ===================================================
--  STAN GLOBALNY
-- ===================================================

local currentConfig   = { konfidenci = {}, ustawienia = {} }
local activeMarkers   = {}
local spectateTarget  = nil
local pokazOznaczenia = true
local currentKeybind  = DOMYSLNY_KLUCZ
local monitorowani    = {}

local MainTab         = nil
local ListaTab        = nil
local TeleportTab     = nil
local teleportFilter  = ""

-- Sekcje list
local konfidenciSection   = nil
local teleportListSection = nil

-- Rebuild throttle
local rebuildQueued = false

-- Referencje do Paragraph statystyk (aktualizowane przez :SetTitle/:SetDesc)
local statBazaEl   = nil
local statSerwerEl = nil

-- Lokalna kopia listy graczy na serwerze (szybsze usuwanie)
local obecniNaSerwer = {}  -- [gracz] = true

-- ===================================================
--  SYSTEM ALERTÓW
-- ===================================================

local alertGui

local function stworzAlertGui()
    if alertGui then pcall(function() alertGui:Destroy() end) end
    local gui = Instance.new("ScreenGui")
    gui.Name = "KH_Alert"; gui.ResetOnSpawn = false
    gui.DisplayOrder = 999; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function() gui.Parent = gethui() end)
    if not ok then ok = pcall(function() gui.Parent = game:GetService("CoreGui") end) end
    if not ok then gui.Parent = LocalPlayer.PlayerGui end
    alertGui = gui
end

local AW, AH, AM, AB = 320, 80, 20, 20

local function pokazAlert(tytul, tresc, kolor)
    kolor = kolor or Color3.fromRGB(255,170,0)
    if not alertGui or not alertGui.Parent then stworzAlertGui() end
    local off = -(AH+AM+AB)
    local sPos = UDim2.new(1, AM, 1, off)
    local tPos = UDim2.new(1, -(AW+AM), 1, off)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0,AW,0,AH); f.Position = sPos
    f.BackgroundColor3 = Color3.fromRGB(18,18,22)
    f.BorderSizePixel = 0; f.ZIndex = 10; f.Parent = alertGui
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,14)
    local st = Instance.new("UIStroke",f)
    st.Color = Color3.fromRGB(55,55,65); st.Thickness = 1
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local ib = Instance.new("Frame",f)
    ib.Size = UDim2.new(0,40,0,40); ib.Position = UDim2.new(0,14,0.5,-20)
    ib.BackgroundColor3 = Color3.fromRGB(
        math.clamp(math.floor(kolor.R*255*0.18),0,255),
        math.clamp(math.floor(kolor.G*255*0.18),0,255),
        math.clamp(math.floor(kolor.B*255*0.18),0,255))
    ib.BorderSizePixel = 0; ib.ZIndex = 11
    Instance.new("UICorner",ib).CornerRadius = UDim.new(1,0)
    local il = Instance.new("TextLabel",ib)
    il.Size = UDim2.new(1,0,1,0); il.BackgroundTransparency = 1
    il.Text = "!"; il.TextSize = 20; il.Font = Enum.Font.GothamBold
    il.TextColor3 = kolor; il.TextXAlignment = Enum.TextXAlignment.Center
    il.TextYAlignment = Enum.TextYAlignment.Center; il.ZIndex = 12
    local tl = Instance.new("TextLabel",f)
    tl.Size = UDim2.new(1,-68,0,22); tl.Position = UDim2.new(0,64,0,14)
    tl.BackgroundTransparency = 1; tl.Text = tytul
    tl.TextColor3 = Color3.fromRGB(235,235,235); tl.Font = Enum.Font.GothamBold
    tl.TextSize = 15; tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.TextTruncate = Enum.TextTruncate.AtEnd; tl.ZIndex = 11
    local cl = Instance.new("TextLabel",f)
    cl.Size = UDim2.new(1,-68,0,30); cl.Position = UDim2.new(0,64,0,36)
    cl.BackgroundTransparency = 1; cl.Text = tresc
    cl.TextColor3 = Color3.fromRGB(155,155,170); cl.Font = Enum.Font.Gotham
    cl.TextSize = 13; cl.TextXAlignment = Enum.TextXAlignment.Left
    cl.TextWrapped = true; cl.ZIndex = 11
    local pb = Instance.new("Frame",f)
    pb.Size = UDim2.new(1,0,0,2); pb.Position = UDim2.new(0,0,1,-2)
    pb.BackgroundColor3 = Color3.fromRGB(40,40,50); pb.BorderSizePixel = 0; pb.ZIndex = 11
    local pg = Instance.new("Frame",pb)
    pg.Size = UDim2.new(1,0,1,0); pg.BackgroundColor3 = kolor
    pg.BorderSizePixel = 0; pg.ZIndex = 12
    local CZAS = 4
    local tin = TweenSvc:Create(f, TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out), {Position=tPos})
    tin:Play()
    local tpg = TweenSvc:Create(pg, TweenInfo.new(CZAS,Enum.EasingStyle.Linear), {Size=UDim2.new(0,0,1,0)})
    tin.Completed:Connect(function() tpg:Play() end)
    task.delay(CZAS+0.3, function()
        local tout = TweenSvc:Create(f, TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.In), {Position=sPos})
        tout:Play()
        tout.Completed:Connect(function() pcall(function() f:Destroy() end) end)
    end)
end

-- ===================================================
--  HELPERS
-- ===================================================

local function getUst()
    return currentConfig.ustawienia or { kolorPodswietlenia={255,170,0}, przezroczystosc=0.4, tekstNadGlowa="Konfident" }
end

local function czyKonfident(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
end

local function liczbaKonfidentow()
    local n = 0
    for _ in pairs(currentConfig.konfidenci or {}) do n = n + 1 end
    return n
end

local function konfidenciNaSerwerzeLista()
    local lista = {}
    for g in pairs(obecniNaSerwer) do
        if czyKonfident(g) then table.insert(lista, g) end
    end
    -- sortuj po nazwie dla stabilnego porządku
    table.sort(lista, function(a,b) return a.Name < b.Name end)
    return lista
end

local function kopiujDo(t)
    local ok = pcall(function() setclipboard(t) end)
    return ok
end

local function pobierzJobId()
    local ok, r = pcall(function() return game.JobId end)
    if ok and r and r ~= "" then return r end; return ""
end

local function pobierzGameId()
    local ok, r = pcall(function() return tostring(game.PlaceId) end)
    if ok and r then return r end; return ""
end

local function hashLista(lista)
    local ids = {}
    for _, g in ipairs(lista) do table.insert(ids, tostring(g.UserId)) end
    table.sort(ids)
    return table.concat(ids, ",") .. (spectateTarget and "|S:"..spectateTarget.UserId or "")
end

-- ===================================================
--  OZNACZENIA
-- ===================================================

local function usunOznaczenia(gracz)
    local f = activeMarkers[gracz]
    if f then pcall(function() f:Destroy() end); activeMarkers[gracz] = nil end
    local char = gracz.Character
    if char then
        local h = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if h then local bb = h:FindFirstChild("TekstKonfidenta"); if bb then pcall(function() bb:Destroy() end) end end
    end
end

local function dodajOznaczenia(gracz)
    if not czyKonfident(gracz) or not pokazOznaczenia then return end
    local char = gracz.Character; if not char then return end
    local hp = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
    if not hp then return end
    if activeMarkers[gracz] then usunOznaczenia(gracz) end
    local folder = Instance.new("Folder"); folder.Name = "KonfidentMarkery"; folder.Parent = char
    activeMarkers[gracz] = folder
    local ust = getUst(); local k = ust.kolorPodswietlenia or {255,170,0}
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(k[1],k[2],k[3]); hl.FillTransparency = ust.przezroczystosc or 0.4
    hl.OutlineColor = Color3.fromRGB(k[1],k[2],k[3]); hl.OutlineTransparency = 0
    hl.Adornee = char; hl.Parent = folder
    local bb = Instance.new("BillboardGui")
    bb.Name = "TekstKonfidenta"; bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0,220,0,40); bb.StudsOffset = Vector3.new(0,2.5,0)
    bb.Adornee = hp; bb.Parent = hp
    local lbl = Instance.new("TextLabel",bb)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = ust.tekstNadGlowa or "Konfident"
    lbl.TextColor3 = Color3.fromRGB(k[1],k[2],k[3]); lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold; lbl.TextStrokeTransparency = 0
end

local function usunWszystkieOznaczenia()
    for g in pairs(activeMarkers) do usunOznaczenia(g) end
end

local function odswiezWszystkieOznaczenia()
    if pokazOznaczenia then
        for g in pairs(obecniNaSerwer) do
            if czyKonfident(g) and g.Character and not activeMarkers[g] then dodajOznaczenia(g) end
        end
    else usunWszystkieOznaczenia() end
end

-- ===================================================
--  SPECTATE / TELEPORT
-- ===================================================

local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid"); if not h then return end
    spectateTarget = gracz; Camera.CameraType = Enum.CameraType.Custom; Camera.CameraSubject = h
end

local function stopSpectate()
    spectateTarget = nil
    local char = LocalPlayer.Character
    if char then local h = char:FindFirstChild("Humanoid"); if h then Camera.CameraType = Enum.CameraType.Custom; Camera.CameraSubject = h end end
end

local function teleportDo(gracz)
    if not gracz or not gracz.Character then
        WindUI:Notify({ Title="Teleport", Content="Brak postaci!", Icon="alert-circle", Duration=3 }); return
    end
    local root = gracz.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
    local mc = LocalPlayer.Character; local mr = mc and mc:FindFirstChild("HumanoidRootPart"); if not mr then return end
    mr.CFrame = root.CFrame * CFrame.new(2,0,2)
    WindUI:Notify({ Title="Teleport", Content="Teleportowano do "..gracz.Name, Icon="map-pin", Duration=3 })
end

-- ===================================================
--  KONFIGURACJA
-- ===================================================

local function pobierzKonfiguracje()
    local ok, r = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("[KH] HttpGet: "..tostring(r)); return nil end
    local fn, e = loadstring(r); if not fn then warn("[KH] loadstring: "..tostring(e)); return nil end
    local ok2, cfg = pcall(fn); if not ok2 then warn("[KH] pcall: "..tostring(cfg)); return nil end
    return cfg
end

-- ===================================================
--  AKTUALIZACJA STATYSTYK (Paragraph :SetTitle/:SetDesc)
-- ===================================================

local function aktualizujStatystyki()
    local baza  = liczbaKonfidentow()
    local naS   = #konfidenciNaSerwerzeLista()
    if statBazaEl then
        pcall(function() statBazaEl:SetTitle("Kont w bazie konfidentów: " .. tostring(baza)) end)
    end
    if statSerwerEl then
        pcall(function() statSerwerEl:SetTitle("Konfidentów na tym serwerze: " .. tostring(naS)) end)
    end
end

-- ===================================================
--  REBUILD LISTY — Paragraph z Thumbnail dla każdego gracza
-- ===================================================

local function rebuildLista()
    if not ListaTab then return end
    pcall(function()
        if konfidenciSection then
            pcall(function() konfidenciSection:Destroy() end)
            konfidenciSection = nil
        end
        local obecni = konfidenciNaSerwerzeLista()
        konfidenciSection = ListaTab:Section({
            Title  = ("Konfidenci na serwerze (%d)"):format(#obecni),
            Icon   = "users",
            Opened = true,
        })
        if #obecni == 0 then
            konfidenciSection:Paragraph({ Title = "Brak konfidentów na serwerze", Desc = "Nikt z listy nie jest tutaj" })
        else
            for _, g in ipairs(obecni) do
                local gracz   = g
                local isSpect = (spectateTarget == gracz)
                konfidenciSection:Button({
                    Title    = gracz.Name,
                    Desc     = "ID: " .. tostring(gracz.UserId) .. (isSpect and " • Obserwujesz" or ""),
                    Icon     = "user",
                    Color    = isSpect and Color3.fromRGB(255, 170, 0) or nil,
                    Callback = function()
                        if spectateTarget == gracz then stopSpectate()
                        else if spectateTarget then stopSpectate() end; spectateGracza(gracz) end
                        rebuildLista()
                    end,
                })
            end
        end
    end)
end

local function rebuildTeleport()
    if not TeleportTab then return end
    pcall(function()
        if teleportListSection then
            pcall(function() teleportListSection:Destroy() end)
            teleportListSection = nil
        end
        local obecni   = konfidenciNaSerwerzeLista()
        local filtered = {}
        if teleportFilter ~= "" then
            local sz = teleportFilter:lower()
            for _, g in ipairs(obecni) do if g.Name:lower():find(sz,1,true) then table.insert(filtered,g) end end
        else
            filtered = obecni
        end
        teleportListSection = TeleportTab:Section({
            Title  = ("Wyniki (%d)"):format(#filtered),
            Icon   = "map-pin",
            Opened = true,
        })
        if #obecni == 0 then
            teleportListSection:Paragraph({ Title="Brak konfidentów na serwerze", Desc="Nikt z listy nie jest tutaj" })
        elseif #filtered == 0 then
            teleportListSection:Paragraph({ Title="Brak wyników", Desc="Nie znaleziono: "..teleportFilter })
        else
            for _, g in ipairs(filtered) do
                local gracz = g
                teleportListSection:Button({
                    Title    = gracz.Name,
                    Desc     = "ID: " .. tostring(gracz.UserId),
                    Icon     = "map-pin",
                    Callback = function() teleportDo(gracz) end,
                })
            end
        end
    end)
end

-- ===================================================
--  SCHEDULE REBUILD
-- ===================================================

local function scheduleRebuild()
    if rebuildQueued then return end
    rebuildQueued = true
    task.defer(function()
        rebuildQueued = false
        task.spawn(rebuildLista)
        task.spawn(rebuildTeleport)
        task.spawn(aktualizujStatystyki)
    end)
end

-- ===================================================
--  SYNC BAZY CO 60s
-- ===================================================

local function syncBazy()
    task.spawn(function()
        local cfg = pobierzKonfiguracje(); if not cfg then return end
        local nowi = {}
        for _, uid in ipairs(cfg.konfidenci or {}) do nowi[uid] = true end
        local starzy = currentConfig.konfidenci or {}
        for uid in pairs(starzy) do
            if not nowi[uid] then
                for _, g in ipairs(Players:GetPlayers()) do if g.UserId == uid then usunOznaczenia(g) end end
            end
        end
        for uid in pairs(nowi) do
            if not starzy[uid] then
                for _, g in ipairs(Players:GetPlayers()) do if g.UserId == uid and g.Character then dodajOznaczenia(g) end end
            end
        end
        currentConfig = cfg
        currentConfig.konfidenci = nowi
        currentConfig.ustawienia = currentConfig.ustawienia or { kolorPodswietlenia={255,170,0}, przezroczystosc=0.4, tekstNadGlowa="Konfident" }
         
        print(("[KH] Sync bazy. Kont: %d"):format(liczbaKonfidentow()))
        scheduleRebuild()
    end)
end

-- ===================================================
--  MONITOROWANIE GRACZY
-- ===================================================

local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    if monitorowani[gracz] then return end
    monitorowani[gracz] = true
    gracz.CharacterAdded:Connect(function()
        task.wait(0.3)
        if czyKonfident(gracz) then dodajOznaczenia(gracz) end
         
        scheduleRebuild()
    end)
    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
         
        scheduleRebuild()
    end)
end

-- ===================================================
--  WIND UI — OKNO
-- ===================================================

local myNick = LocalPlayer.Name
local myId   = LocalPlayer.UserId

local Window = WindUI:CreateWindow({
    Title         = "KonfidentHunter",
    Icon          = "shield-alert",
    Author        = "v1",
    Folder        = "KonfidentHunter",
    NewElements   = true,
    HideSearchBar = true,
    ToggleKey     = Enum.KeyCode[DOMYSLNY_KLUCZ],
    Topbar        = { Height = 44, ButtonsType = "Mac" },
})

-- ===================================================
--  ZAKŁADKA: MAIN
-- ===================================================

MainTab = Window:Tab({ Title = "Main", Icon = "info" })
MainTab:Select()

-- LOGO / BANNER
MainTab:Image({
    Image       = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/banner.png",
    AspectRatio = "16:9",
    Radius      = 12,
})
MainTab:Space()

-- SEKCJA: Statystyki (tworzona raz, nigdy nie niszczona)
local StatSekcja = MainTab:Section({ Title = "Statystyki", Icon = "server", Opened = true })

statBazaEl = StatSekcja:Paragraph({
    Title = "Kont w bazie konfidentów: 0",
})

statSerwerEl = StatSekcja:Paragraph({
    Title = "Konfidentów na tym serwerze: 0",
})

StatSekcja:Space()

StatSekcja:Button({
    Title    = "Odśwież statystyki",
    Icon     = "refresh-cw",
    Justify  = "Between",
    Callback = function()
        aktualizujStatystyki()
        WindUI:Notify({ Title="Statystyki", Content="Zaktualizowano!", Icon="check-circle", Duration=2 })
    end,
})

-- SEKCJA: Serwer — kopiowanie
local SerwSekcja = MainTab:Section({ Title = "Serwer", Icon = "server", Opened = true })

SerwSekcja:Button({
    Title    = "Kopiuj Job ID",
    Desc     = "ID instancji serwera",
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local id = pobierzJobId()
        if id ~= "" then
            local ok = kopiujDo(id)
            WindUI:Notify({ Title=ok and "Skopiowano!" or "Błąd", Content=ok and id:sub(1,28).."..." or "Nie udało się", Icon=ok and "check-circle" or "alert-circle", Duration=3 })
        else WindUI:Notify({ Title="Błąd", Content="Brak Job ID", Icon="alert-circle", Duration=3 }) end
    end,
})

SerwSekcja:Button({
    Title    = "Kopiuj Game ID",
    Desc     = "Place ID gry",
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local id = pobierzGameId()
        if id ~= "" then
            local ok = kopiujDo(id)
            WindUI:Notify({ Title=ok and "Skopiowano!" or "Błąd", Content=ok and ("Place ID: "..id) or "Nie udało się", Icon=ok and "check-circle" or "alert-circle", Duration=3 })
        end
    end,
})

SerwSekcja:Button({
    Title    = "Kopiuj link do serwera",
    Desc     = "roblox://experiences/start?...",
    Icon     = "link",
    Justify  = "Between",
    Callback = function()
        local gid, jid = pobierzGameId(), pobierzJobId()
        if gid ~= "" and jid ~= "" then
            local link = ("roblox://experiences/start?placeId=%s&gameInstanceId=%s"):format(gid,jid)
            local ok = kopiujDo(link)
            WindUI:Notify({ Title=ok and "Skopiowano!" or "Błąd", Content=ok and "Link w schowku" or "Nie udało się", Icon=ok and "check-circle" or "alert-circle", Duration=3 })
        else WindUI:Notify({ Title="Błąd", Content="Brak Game/Job ID", Icon="alert-circle", Duration=3 }) end
    end,
})

-- ===================================================
--  ZAKŁADKA: LISTA
-- ===================================================

ListaTab = Window:Tab({ Title = "Lista", Icon = "users" })

local AkcjeSekcja = ListaTab:Section({ Title = "Akcje", Icon = "zap", Opened = true })
AkcjeSekcja:Toggle({
    Title    = "Pokaż oznaczenia",
    Desc     = "Highlight i tekst nad głową konfidentów",
    Value    = true,
    Callback = function(v) pokazOznaczenia = v; odswiezWszystkieOznaczenia() end,
})
ListaTab:Space()
ListaTab:Button({
    Title    = "Odśwież listę",
    Desc     = "Wymusza sync z bazą",
    Icon     = "refresh-cw",
    Justify  = "Between",
    Callback = function() syncBazy() end,
})
ListaTab:Space()

-- ===================================================
--  ZAKŁADKA: TELEPORT
-- ===================================================

TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })
TeleportTab:Section({ Title = "Szukaj", Icon = "search", Opened = true }):Input({
    Title       = "Nick konfidenta",
    Placeholder = "np. bartos_GTKM",
    Callback    = function(v)
        teleportFilter = v or ""
        task.spawn(rebuildTeleport)
    end,
})
TeleportTab:Space()

-- ===================================================
--  ZAKŁADKA: DISCORD
-- ===================================================

Window:Tab({ Title = "Discord", Icon = "message-circle" })
    :Section({ Title = "Dołącz", Icon = "link", Opened = true })
    :Button({
        Title    = "Kopiuj link do Discorda",
        Desc     = DISCORD_URL,
        Icon     = "copy",
        Justify  = "Between",
        Callback = function()
            local ok = kopiujDo(DISCORD_URL)
            WindUI:Notify({ Title="Discord", Content=ok and "Link skopiowany!" or DISCORD_URL, Icon=ok and "check-circle" or "message-circle", Duration=ok and 3 or 6 })
        end,
    })

-- ===================================================
--  ZAKŁADKA: USTAWIENIA
-- ===================================================

local UstawTab = Window:Tab({ Title = "Ustawienia", Icon = "settings" })
UstawTab:Section({ Title = "Klawisz GUI", Icon = "keyboard", Opened = true }):Keybind({
    Title    = "Otwórz / zamknij GUI",
    Icon     = "command",
    Value    = DOMYSLNY_KLUCZ,
    Callback = function(v)
        if not v or v == "" then return end
        currentKeybind = v
        pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
        WindUI:Notify({ Title="Keybind", Content="Klawisz: "..v, Icon="keyboard", Duration=3 })
    end,
})
UstawTab:Space()
local WizSekcja = UstawTab:Section({ Title = "Wizualne", Icon = "palette", Opened = true })
WizSekcja:Slider({
    Title    = "Przezroczystość podświetlenia",
    Desc     = "0 = pełny kolor, 10 = niewidoczny",
    Step     = 1,
    Value    = { Min=0, Max=10, Default=4 },
    Callback = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.przezroczystosc = v/10
        for _, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChildOfClass("Highlight")
            if hl then pcall(function() hl.FillTransparency = v/10 end) end
        end
    end,
})
WizSekcja:Space()
WizSekcja:Input({
    Title       = "Tekst nad głową",
    Placeholder = "Konfident",
    Callback    = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.tekstNadGlowa = v ~= "" and v or "Konfident"
        for gracz in pairs(activeMarkers) do
            local char = gracz.Character
            if char then
                local h = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                if h then local bb = h:FindFirstChild("TekstKonfidenta"); if bb then
                    local lbl = bb:FindFirstChildOfClass("TextLabel")
                    if lbl then pcall(function() lbl.Text = currentConfig.ustawienia.tekstNadGlowa end) end
                end end
            end
        end
    end,
})

-- ===================================================
--  INICJALIZACJA
-- ===================================================

local function inicjuj()
    stworzAlertGui()

    -- Zaznacz siebie jako obecnego na serwerze
    for _, g in ipairs(Players:GetPlayers()) do
        if g ~= LocalPlayer then obecniNaSerwer[g] = true end
    end

    task.spawn(function()
        local cfg = pobierzKonfiguracje()
        if cfg then
            local d = {}
            for _, uid in ipairs(cfg.konfidenci or {}) do d[uid] = true end
            currentConfig = cfg; currentConfig.konfidenci = d
            currentConfig.ustawienia = currentConfig.ustawienia or { kolorPodswietlenia={255,170,0}, przezroczystosc=0.4, tekstNadGlowa="Konfident" }
        else
            currentConfig = { konfidenci={}, ustawienia={ kolorPodswietlenia={255,170,0}, przezroczystosc=0.4, tekstNadGlowa="Konfident" } }
            warn("[KH] Pusta konfiguracja!")
        end

        local bazaLiczba = liczbaKonfidentow()
        print(("[KH] Start. Kont w bazie: %d"):format(bazaLiczba))

        -- Thumbnails i oznaczenia dla obecnych graczy
        for g in pairs(obecniNaSerwer) do
            task.spawn(function() getThumb(g.UserId) end)
            if czyKonfident(g) and g.Character then dodajOznaczenia(g) end
        end

         
        scheduleRebuild()

        -- Powiadomienia z opóźnieniami
        task.delay(2.8, function()
            local naS = #konfidenciNaSerwerzeLista()
            if naS > 0 then
                pokazAlert("UWAGA! Konfident na serwerze!", ("%d konfident(ów) jest tutaj!"):format(naS), Color3.fromRGB(255,60,60))
            elseif bazaLiczba > 0 then
                pokazAlert("KonfidentHunter aktywny", ("Załadowano %d kont. Brak konfidentów."):format(bazaLiczba), Color3.fromRGB(255,170,0))
            end
        end)

        -- Monitorowanie
        for g in pairs(obecniNaSerwer) do monitorujGracza(g) end

        Players.PlayerAdded:Connect(function(gracz)
            if gracz == LocalPlayer then return end
            obecniNaSerwer[gracz] = true
            monitorujGracza(gracz)
            task.spawn(function() getThumb(gracz.UserId) end)
            task.wait(0.5)
            if czyKonfident(gracz) then
                pokazAlert("Konfident dołączył!", gracz.Name.." wbił na serwer!", Color3.fromRGB(255,60,60))
                if gracz.Character then dodajOznaczenia(gracz) end
            end
             
            scheduleRebuild()
        end)

        Players.PlayerRemoving:Connect(function(gracz)
            -- Usuń z lokalnej mapy NATYCHMIAST, bez task.wait
            obecniNaSerwer[gracz]     = nil
            monitorowani[gracz]       = nil
            thumbCache[gracz.UserId]  = nil
            usunOznaczenia(gracz)
            if spectateTarget == gracz then stopSpectate() end
            if czyKonfident(gracz) then
                pokazAlert("Konfident opuścił serwer", gracz.Name.." wyszedł.", Color3.fromRGB(100,180,100))
            end
            -- Wymuś rebuild z nową listą
             
            scheduleRebuild()
        end)

        -- Auto-sync co 60s
        task.spawn(function()
            while true do
                task.wait(REFRESH_TIME)
                syncBazy()
            end
        end)
    end)
end

inicjuj()
