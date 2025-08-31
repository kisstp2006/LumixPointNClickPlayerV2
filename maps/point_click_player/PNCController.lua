-- Point & Click játék kamera kontroller
-- A kamera simán és folyamatosan az egér irányába forog

-- Kamera beállítások
local camera_sensitivity = 2.0  -- Érzékenység (magasabb = gyorsabb forgás)
local smooth_factor = 5.0       -- Simítás mértéke (magasabb = simább átmenet)
 max_rotation_x = 60       -- Maximum függőleges forgás (fok)
 min_rotation_x = -30      -- Minimum függőleges forgás (fok)

-- Aktuális kamera forgás
local current_rotation_x = 0
local current_rotation_y = 0

-- Forgási sebességek (folyamatos forgáshoz)
local rotation_speed_x = 0
local rotation_speed_y = 0

-- Target forgási sebességek (simításhoz)
local target_speed_x = 0
local target_speed_y = 0

-- Egér pozíció
local mouse_x = 0
local mouse_y = 0
local screen_center_x = 0
local screen_center_y = 0

-- Segéd függvények
function clamp(value, min_val, max_val)
    return math.max(min_val, math.min(max_val, value))
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function degToRad(degrees)
    return degrees * (math.pi / 180)
end

-- Input event kezelő
function onInputEvent(event)
    if event.type == "axis" and event.device.type == "mouse" then
        -- Abszolút egér pozíció használata
        if event.x_abs and event.y_abs then
            mouse_x = event.x_abs
            mouse_y = event.y_abs
            updateCameraRotationFromMouse()
        end
    end
end

-- Kamera forgás frissítése egér pozíció alapján
function updateCameraRotationFromMouse()
    if screen_center_x > 0 and screen_center_y > 0 then
        -- Egér pozíció normalizálása (-1 to 1)
        local normalized_x = (mouse_x - screen_center_x) / screen_center_x
        local normalized_y = (mouse_y - screen_center_y) / screen_center_y
        
        -- Target forgási sebesség számítása az egér pozíció alapján
        target_speed_y = -normalized_x * camera_sensitivity * 90 -- Vízszintes forgási sebesség (fok/sec)
        target_speed_x = -normalized_y * camera_sensitivity * 60  -- Függőleges forgási sebesség (fok/sec)
        
        -- Kis "holt zóna" a képernyő közepén (opcionális)
        local dead_zone = 0.1
        if math.abs(normalized_x) < dead_zone then
            target_speed_y = 0
        end
        if math.abs(normalized_y) < dead_zone then
            target_speed_x = 0
        end
    end
end

-- ImGui egér pozíció polling (ha az event nem működik megfelelően)
function pollMousePosition()
    if ImGui.IsMouseDown then
        -- Kijelző méret lekérdezése
        local display_width = ImGui.GetDisplayWidth()
        local display_height = ImGui.GetDisplayHeight()
        
        if display_width > 0 and display_height > 0 then
            screen_center_x = display_width / 2
            screen_center_y = display_height / 2
            
            -- Sajnos az ImGui API-ban nincs közvetlen GetMousePos
            -- de használhatjuk az IsMouseClicked eseményeket vagy
            -- az event rendszert az egér pozíciójához
        end
    end
end

-- Kamera forgás alkalmazása
function applyCameraRotation(time_delta)
    if this:hasComponent("camera") then
        -- Simított átmenet a target forgási sebességek felé
        local lerp_speed = smooth_factor * time_delta
        rotation_speed_x = lerp(rotation_speed_x, target_speed_x, lerp_speed)
        rotation_speed_y = lerp(rotation_speed_y, target_speed_y, lerp_speed)
        
        -- Folyamatos forgás alkalmazása a simított forgási sebességek alapján
        current_rotation_x = current_rotation_x + rotation_speed_x * time_delta
        current_rotation_y = current_rotation_y + rotation_speed_y * time_delta
        
        -- Függőleges forgás korlátozása
        current_rotation_x = clamp(current_rotation_x, min_rotation_x, max_rotation_x)
        
        -- Euler szögek kvaterniónná konvertálása
        local x_rad = degToRad(current_rotation_x)
        local y_rad = degToRad(current_rotation_y)
        local z_rad = 0
        
        -- Egyszerű euler->kvaternió konverzió
        local cx = math.cos(x_rad * 0.5)
        local sx = math.sin(x_rad * 0.5)
        local cy = math.cos(y_rad * 0.5)
        local sy = math.sin(y_rad * 0.5)
        local cz = math.cos(z_rad * 0.5)
        local sz = math.sin(z_rad * 0.5)
        
        -- Kvaternió számítás (w, x, y, z)
        local w = cx * cy * cz + sx * sy * sz
        local x = sx * cy * cz - cx * sy * sz
        local y = cx * sy * cz + sx * cy * sz
        local z = cx * cy * sz - sx * sy * cz
        
        -- Kamera forgás beállítása
        this.rotation = {x, y, z, w} -- vagy {w, x, y, z} formátum
    end
end

-- Inicializálás
function start()
    LumixAPI.logInfo("=== Point & Click Kamera Kontroller Indítás ===")
    
    -- Kijelző méret inicializálása
    if ImGui.GetDisplayWidth then
        local display_width = ImGui.GetDisplayWidth()
        local display_height = ImGui.GetDisplayHeight()
        screen_center_x = display_width / 2
        screen_center_y = display_height / 2
        
        LumixAPI.logInfo(string.format("Kijelző méret: %dx%d", display_width, display_height))
        LumixAPI.logInfo(string.format("Képernyő közepe: %.1f, %.1f", screen_center_x, screen_center_y))
    end
    
    -- Kamera komponens ellenőrzése
    if this:hasComponent("camera") then
        LumixAPI.logInfo("Kamera komponens megtalálva")
    else
        LumixAPI.logError("Nincs kamera komponens a entitáson!")
    end
    
    -- Egér kurzor engedélyezése
    if this.world.gui then
        local gui_system = this.world.gui:getSystem()
        gui_system:enableCursor(true)
        LumixAPI.logInfo("Egér kurzor engedélyezve")
    end
end

-- Fő frissítési ciklus
function update(time_delta)
    -- Egér pozíció polling (ha az event-based megközelítés nem működik)
    pollMousePosition()
    
    -- Kamera forgás alkalmazása
    applyCameraRotation(time_delta or 1.0/60.0) -- Fallback 60 FPS-re ha nincs time_delta
end

-- Input event handler (automatikusan meghívódik)
function onInput(event)
    onInputEvent(event)
end

-- Debug info (opcionális)
function debugCameraInfo()
    LumixAPI.logInfo(string.format("Mouse: %.1f, %.1f | Target: %.1f, %.1f | Smooth: %.1f, %.1f | Rot: %.1f, %.1f", 
        mouse_x, mouse_y, target_speed_x, target_speed_y, rotation_speed_x, rotation_speed_y, current_rotation_x, current_rotation_y))
end