--[[
    Konfident Hunter v4 - WindUI Edition (FIXED)
    
    Podejście do listy:
    - Karty graczy są budowane jako natywne przyciski WindUI (Tab:Button)
    - Każdy konfident = osobny Button z avatarem osadzonym przez Image element
    - Brak hackowania hierarchii GUI → brak problemów z layoutem
    - Lista jest rebuiltowana przy każdej zmianie (usun + dodaj od nowa)
    
    Nowe funkcje:
    - Toggle "Pokaż oznaczenia" (highlight + billboard)
    - Teleport do konfidenta (Dropdown + Input)
    - Spectate przez kliknięcie przycisku (toggle)
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL   = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
-- ========================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer
local Camera       = workspace.CurrentCamera

-- ===== STAN GLOBALNY =====
local currentConfig    = { konfidenci = {}, ustawienia = {} }
local activeMarkers    = {}   -- { [gracz] = Folder }
local spectateTarget   = nil  -- gracz | nil
local pokazOznaczenia  = true -- toggle highlights

-- Referencja do zakładki listy (do rebuildu)
local ListaTab         = nil

-- Mapa gracz → instancja Button WindUI (do update tekstu)
local kartyRefs        = {}   -- { [gracz.Name] = buttonRef }

-- ===== HELPERS =====
local function getUst()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
    }
end

local function czyKonfident(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
end

local function avatarUrl(userId)
    return ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png"):format(userId)
end

-- ===== OZNACZENIA =====
local function usunOznaczenia(gracz)
    local f = activeMarkers[gracz]
    if f then pcall(function() f:Destroy() end); activeMarkers[gracz] = nil end
    local char = gracz.Character
    if char then
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if head then
            local bb = head:FindFirstChild("TekstKonfidenta")
            if bb then pcall(function() bb:Destroy() end) end
        end
    end
end

local function dodajOznaczenia(gracz)
    if not czyKonfident(gracz) then return end
    if not pokazOznaczenia then return end
    local char = gracz.Character
    if not char then return end
    local headPart = char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
                  or char:FindFirstChild("UpperTorso")
    if not headPart then return end
    if activeMarkers[gracz] then usunOznaczenia(gracz) end

    local folder = Instance.new("Folder")
    folder.Name   = "KonfidentMarkery"
    folder.Parent = char
    activeMarkers[gracz] = folder

    local ust = getUst()
    local k   = ust.kolorPodswietlenia or {255, 170, 0}

    local hl = Instance.new("Highlight")
    hl.Name                = "Podswietlenie"
    hl.FillColor           = Color3.fromRGB(k[1], k[2], k[3])
    hl.FillTransparency    = ust.przezroczystosc or 0.4
    hl.OutlineColor        = Color3.fromRGB(k[1], k[2], k[3])
    hl.OutlineTransparency = 0
    hl.Adornee             = char
    hl.Parent              = folder

    local bb = Instance.new("BillboardGui")
    bb.Name        = "TekstKonfidenta"
    bb.AlwaysOnTop = true
    bb.Size        = UDim2.new(0, 220, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Adornee     = headPart
    bb.Parent      = headPart

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = ust.tekstNadGlowa or "Konfident"
    lbl.TextColor3             = Color3.fromRGB(k[1], k[2], k[3])
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Parent                 = bb
end

local function usunWszystkieOznaczenia()
    for gracz in pairs(activeMarkers) do usunOznaczenia(gracz) end
end

local function odswiezWszystkieOznaczenia()
    if pokazOznaczenia then
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer and czyKonfident(gracz) and gracz.Character then
                if not activeMarkers[gracz] then dodajOznaczenia(gracz) end
            end
        end
    else
        usunWszystkieOznaczenia()
    end
end

-- ===== SPECTATE =====
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid")
    if not h then return end
    spectateTarget = gracz
    Camera.CameraType    = Enum.CameraType.Custom
    Camera.CameraSubject = h
end

local function stopSpectate()
    spectateTarget = nil
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChild("Humanoid")
        if h then
            Camera.CameraType    = Enum.CameraType.Custom
            Camera.CameraSubject = h
        end
    end
end

-- ===== TELEPORT =====
local function teleportDo(gracz)
    if not gracz or not gracz.Character then
        WindUI:Notify({ Title = "Teleport", Content = "Gracz nie ma postaci!", Icon = "alert-circle", Duration = 3 })
        return
    end
    local root = gracz.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        WindUI:Notify({ Title = "Teleport", Content = "Brak HumanoidRootPart!", Icon = "alert-circle", Duration = 3 })
        return
    end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    -- Teleport z małym offsetem żeby nie wejść w gracza
    local cf = root.CFrame * CFrame.new(2, 0, 2)
    myRoot.CFrame = cf

    WindUI:Notify({
        Title   = "Teleport",
        Content = "Teleportowano do " .. gracz.Name,
        Icon    = "map-pin",
        Duration = 3,
    })
end

-- ===== POBIERANIE CONFIGU =====
local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("[KH] HttpGet: " .. tostring(result)); return nil end
    local func, err = loadstring(result)
    if not func then warn("[KH] loadstring: " .. tostring(err)); return nil end
    local ok2, config = pcall(func)
    if not ok2 then warn("[KH] pcall: " .. tostring(config)); return nil end
    return config
end

-- ===== LISTA GRACZY (REBUILD przez WindUI Button) =====
-- Trzymamy sekcje żeby je czyścić i odtwarzać
local konfidenciSection = nil
local akcjeSection      = nil
local teleportSection   = nil

-- Zbuduj sekcję z kartami konfidentów
local function rebuildListaSekcje()
    if not ListaTab then return end

    -- Zniszcz stare sekcje
    if konfidenciSection then
        pcall(function() konfidenciSection:Destroy() end)
        konfidenciSection = nil
    end
    kartyRefs = {}

    -- Zbierz obecnych konfidentów na serwerze
    local obecni = {}
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyKonfident(gracz) then
            table.insert(obecni, gracz)
        end
    end

    -- Sekcja konfidentów
    konfidenciSection = ListaTab:Section({
        Title  = ("Konfidenci na serwerze (%d)"):format(#obecni),
        Icon   = "users",
        Opened = true,
    })

    if #obecni == 0 then
        konfidenciSection:Button({
            Title = "Brak konfidentów na serwerze",
            Icon  = "user-x",
            Locked = true,
        })
        return
    end

    for _, gracz in ipairs(obecni) do
        local nazwa = gracz.Name
        local isSpectated = (spectateTarget == gracz)
        local statusTxt  = isSpectated and "👁  Obserwujesz — kliknij aby stop" or "Kliknij aby spectate"
        local ikonka     = isSpectated and "eye-off" or "eye"
        local kolor      = isSpectated and Color3.fromRGB(255, 170, 0) or nil

        local btn = konfidenciSection:Button({
            Title    = nazwa,
            Desc     = statusTxt,
            Icon     = avatarUrl(gracz.UserId),  -- WindUI akceptuje URL jako ikonę
            Color    = kolor,
            Callback = function()
                if spectateTarget == gracz then
                    stopSpectate()
                else
                    if spectateTarget then stopSpectate() end
                    spectateGracza(gracz)
                end
                -- Rebuild żeby zaktualizować status przycisków
                task.wait(0.05)
                rebuildListaSekcje()
            end,
        })

        kartyRefs[nazwa] = btn
    end
end

-- ===== AKTUALIZACJA KONFIG =====
local function aktualizujListe()
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    local nowi = {}
    for _, userId in ipairs(nowaKonfig.konfidenci or {}) do
        nowi[userId] = true
    end

    local starzy = currentConfig.konfidenci or {}

    -- Usuń oznaczenia usuniętych
    for userId in pairs(starzy) do
        if not nowi[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId then usunOznaczenia(gracz) end
            end
        end
    end
    -- Dodaj oznaczenia nowych
    for userId in pairs(nowi) do
        if not starzy[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
    end

    currentConfig          = nowaKonfig
    currentConfig.konfidenci = nowi
    currentConfig.ustawienia = currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
    }

    local n = 0
    for _ in pairs(nowi) do n = n + 1 end
    print(("[KH] ✅ Odświeżono. Konfidenci: %d"):format(n))

    rebuildListaSekcje()
end

-- ===== MONITOROWANIE GRACZY =====
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    gracz.CharacterAdded:Connect(function()
        task.wait(0.3)
        if czyKonfident(gracz) then
            dodajOznaczenia(gracz)
            rebuildListaSekcje()
        end
    end)
    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
        rebuildListaSekcje()
    end)
end

-- ===== AUTO-ODŚWIEŻANIE =====
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
        -- Uzupełnij brakujące highlights
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer then
                if czyKonfident(gracz) and gracz.Character then
                    if pokazOznaczenia and not activeMarkers[gracz] then
                        dodajOznaczenia(gracz)
                    elseif not pokazOznaczenia and activeMarkers[gracz] then
                        usunOznaczenia(gracz)
                    end
                elseif not czyKonfident(gracz) and activeMarkers[gracz] then
                    usunOznaczenia(gracz)
                end
            end
        end
    end
end

-- ===== WIND UI =====
local Window = WindUI:CreateWindow({
    Title         = "KonfidentHunter",
    Icon          = "shield-alert",
    Author        = "v4",
    Folder        = "KonfidentHunter",
    NewElements   = true,
    HideSearchBar = true,
    Topbar = {
        Height      = 44,
        ButtonsType = "Mac",
    },
})

-- ══════════════════════════════════════════
--  ZAKŁADKA: LISTA
-- ══════════════════════════════════════════
ListaTab = Window:Tab({
    Title = "Lista",
    Icon  = "users",
})

-- Sekcja akcji (stała)
local AkcjeSekcja = ListaTab:Section({
    Title  = "Akcje",
    Icon   = "zap",
    Opened = true,
})

-- Toggle oznaczeń
AkcjeSekcja:Toggle({
    Title = "Pokaż oznaczenia (highlight)",
    Desc  = "Highlight i tekst nad głową konfidentów",
    Icon  = "eye",
    Value = true,
    Callback = function(v)
        pokazOznaczenia = v
        odswiezWszystkieOznaczenia()
    end,
})

AkcjeSekcja:Space()

-- Stop spectate
AkcjeSekcja:Button({
    Title = "Stop Spectate",
    Icon  = "video-off",
    Callback = function()
        stopSpectate()
        task.wait(0.05)
        rebuildListaSekcje()
        WindUI:Notify({ Title = "Spectate", Content = "Zatrzymano obserwowanie.", Icon = "video-off", Duration = 2 })
    end,
})

AkcjeSekcja:Space()

-- Odśwież listę
AkcjeSekcja:Button({
    Title = "Odśwież listę",
    Icon  = "refresh-cw",
    Callback = function()
        task.spawn(aktualizujListe)
    end,
})

-- Separator przed listą konfidentów
ListaTab:Space()

-- Lista konfidentów (budowana dynamicznie)
-- konfidenciSection jest budowana przez rebuildListaSekcje()

-- ══════════════════════════════════════════
--  ZAKŁADKA: TELEPORT
-- ══════════════════════════════════════════
local TeleportTab = Window:Tab({
    Title = "Teleport",
    Icon  = "map-pin",
})

-- Sekcja dropdown
local TpDropSekcja = TeleportTab:Section({
    Title  = "Wybierz z listy",
    Icon   = "list",
    Opened = true,
})

-- Dropdown konfidentów (odświeżany przy rebuildzie)
-- Ponieważ WindUI Dropdown nie ma metody :Refresh(), trzymamy całą sekcję
-- i niszczymy ją przy każdym rebuildzie razem z listą

local teleportDropSection = nil
local teleportInputSection = nil

local function rebuildTeleportSekcje()
    -- Zniszcz stare
    if teleportDropSection then
        pcall(function() teleportDropSection:Destroy() end)
        teleportDropSection = nil
    end
    if teleportInputSection then
        pcall(function() teleportInputSection:Destroy() end)
        teleportInputSection = nil
    end

    -- Zbierz obecnych konfidentów
    local obecni = {}
    local opcje  = {}
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyKonfident(gracz) then
            table.insert(obecni, gracz)
            table.insert(opcje, gracz.Name)
        end
    end

    -- Sekcja dropdown
    teleportDropSection = TeleportTab:Section({
        Title  = "Teleport do konfidenta",
        Icon   = "map-pin",
        Opened = true,
    })

    if #opcje == 0 then
        teleportDropSection:Button({
            Title  = "Brak konfidentów na serwerze",
            Icon   = "user-x",
            Locked = true,
        })
    else
        -- Dropdown z listą
        local wybrany = opcje[1]
        teleportDropSection:Dropdown({
            Title  = "Wybierz gracza",
            Values = opcje,
            Value  = 1,
            Callback = function(v)
                wybrany = v
            end,
        })

        teleportDropSection:Space()

        teleportDropSection:Button({
            Title = "Teleportuj →",
            Icon  = "zap",
            Color = Color3.fromRGB(255, 170, 0),
            Callback = function()
                for _, gracz in ipairs(Players:GetPlayers()) do
                    if gracz.Name == wybrany then
                        teleportDo(gracz)
                        return
                    end
                end
                WindUI:Notify({ Title = "Teleport", Content = "Nie znaleziono gracza: " .. tostring(wybrany), Duration = 3 })
            end,
        })
    end

    -- Sekcja wpisz nazwę
    teleportInputSection = TeleportTab:Section({
        Title  = "Wpisz nazwę gracza",
        Icon   = "keyboard",
        Opened = true,
    })

    local wpisanaNazwa = ""
    teleportInputSection:Input({
        Title       = "Nazwa gracza",
        Placeholder = "np. bartos_GTKM",
        Callback    = function(v)
            wpisanaNazwa = v
        end,
    })

    teleportInputSection:Space()

    teleportInputSection:Button({
        Title = "Teleportuj →",
        Icon  = "zap",
        Color = Color3.fromRGB(255, 170, 0),
        Callback = function()
            if wpisanaNazwa == "" then
                WindUI:Notify({ Title = "Teleport", Content = "Wpisz nazwę gracza!", Icon = "alert-circle", Duration = 3 })
                return
            end
            -- Szukaj po pełnej nazwie lub częściowej (case insensitive)
            local cel = nil
            local szukaj = wpisanaNazwa:lower()
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == szukaj then
                    cel = gracz; break
                end
            end
            -- Jeśli nie znaleziono dokładnie, spróbuj częściowe
            if not cel then
                for _, gracz in ipairs(Players:GetPlayers()) do
                    if gracz.Name:lower():find(szukaj, 1, true) then
                        cel = gracz; break
                    end
                end
            end

            if cel then
                teleportDo(cel)
            else
                WindUI:Notify({
                    Title   = "Teleport",
                    Content = "Nie znaleziono gracza: " .. wpisanaNazwa,
                    Icon    = "user-x",
                    Duration = 3,
                })
            end
        end,
    })
end

-- ══════════════════════════════════════════
--  ZAKŁADKA: USTAWIENIA
-- ══════════════════════════════════════════
local UstawTab = Window:Tab({
    Title = "Ustawienia",
    Icon  = "settings",
})

local WizualneSekcja = UstawTab:Section({
    Title  = "Wizualne",
    Icon   = "palette",
    Opened = true,
})

WizualneSekcja:Slider({
    Title = "Przezroczystość podświetlenia",
    Desc  = "0 = pełny kolor, 10 = niewidoczny",
    Step  = 1,
    Value = { Min = 0, Max = 10, Default = 4 },
    Callback = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.przezroczystosc = v / 10
        for _, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChild("Podswietlenie")
            if hl then hl.FillTransparency = v / 10 end
        end
    end,
})

WizualneSekcja:Space()

WizualneSekcja:Input({
    Title       = "Tekst nad głową",
    Placeholder = "Konfident",
    Callback    = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.tekstNadGlowa = (v ~= "" and v or "Konfident")
        for gracz in pairs(activeMarkers) do
            local char = gracz.Character
            if char then
                local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                if head then
                    local bb = head:FindFirstChild("TekstKonfidenta")
                    if bb then
                        local lbl = bb:FindFirstChildOfClass("TextLabel")
                        if lbl then lbl.Text = currentConfig.ustawienia.tekstNadGlowa end
                    end
                end
            end
        end
    end,
})

-- ===== INICJALIZACJA =====
local function inicjuj()
    local config = pobierzKonfiguracje()
    if config then
        local slownik = {}
        for _, userId in ipairs(config.konfidenci or {}) do
            slownik[userId] = true
        end
        currentConfig = config
        currentConfig.konfidenci = slownik
        currentConfig.ustawienia = currentConfig.ustawienia or {
            kolorPodswietlenia = {255, 170, 0},
            przezroczystosc    = 0.4,
            tekstNadGlowa      = "Konfident",
        }
    else
        currentConfig = {
            konfidenci = {},
            ustawienia = { kolorPodswietlenia = {255, 170, 0}, przezroczystosc = 0.4, tekstNadGlowa = "Konfident" },
        }
        warn("[KH] ⚠️ Pusta konfiguracja!")
    end

    local n = 0
    for _ in pairs(currentConfig.konfidenci) do n = n + 1 end
    print(("[KH] 🟢 Start. Konfidenci: %d"):format(n))

    -- Natychmiastowe oznaczenia
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyKonfident(gracz) and gracz.Character then
            dodajOznaczenia(gracz)
        end
    end

    -- Zbuduj obie listy
    rebuildListaSekcje()
    rebuildTeleportSekcje()

    WindUI:Notify({
        Title    = "KonfidentHunter",
        Content  = ("Załadowano. Baza: %d ID."):format(n),
        Icon     = "shield-alert",
        Duration = 5,
    })

    -- Monitorowanie
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer then monitorujGracza(gracz) end
    end

    Players.PlayerAdded:Connect(function(gracz)
        if gracz == LocalPlayer then return end
        monitorujGracza(gracz)
        task.wait(0.4)
        if czyKonfident(gracz) and gracz.Character then dodajOznaczenia(gracz) end
        task.wait(0.1)
        rebuildListaSekcje()
        rebuildTeleportSekcje()
    end)

    Players.PlayerRemoving:Connect(function(gracz)
        task.wait(0.15)
        if spectateTarget == gracz then stopSpectate() end
        rebuildListaSekcje()
        rebuildTeleportSekcje()
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
