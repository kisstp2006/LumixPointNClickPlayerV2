gui = Lumix.Entity.NULL
e = Lumix.Entity.NULL

-- GUI/Console output kapcsoló
use_gui_output = true  -- true = ImGui ablak, false = console log
show_debug_window = true

-- Debug: kiírjuk az aktuális output módot
function printCurrentMode()
    local mode = use_gui_output and "ImGui" or "Console"
    LumixAPI.logInfo("Debug output mód: " .. mode)
end

-- Gyors váltás függvény
function toggleOutputMode()
    use_gui_output = not use_gui_output
    
    -- Töröljük a tárolt adatokat váltáskor
    entity_info = {}
    components_info = {}
    mouse_info = {}
    
    -- Kiírjuk az új módot
    local mode = use_gui_output and "ImGui ablak" or "Console log"
    LumixAPI.logInfo("Output mód váltva: " .. mode)
end

-- Konzol parancs a váltáshoz
function cmd_toggle()
    toggleOutputMode()
end

-- Konzol parancs GUI módra
function cmd_gui()
    use_gui_output = true
    entity_info = {}
    components_info = {}
    mouse_info = {}
    LumixAPI.logInfo("GUI output bekapcsolva")
end

-- Konzol parancs Console módra
function cmd_console()
    use_gui_output = false
    LumixAPI.logInfo("Console output bekapcsolva")
end

-- Egér pozíció tárolása
local mouse_x = 0
local mouse_y = 0
local mouse_abs_x = 0
local mouse_abs_y = 0

-- Információ tároló táblák GUI-hoz
local entity_info = {}
local components_info = {}
local mouse_info = {}

-- Univerzális logolási függvény
function log(message, category)
    category = category or "info"
    
    if use_gui_output then
        -- GUI-ba tárolás
        if category == "entity" then
            table.insert(entity_info, message)
        elseif category == "components" then
            table.insert(components_info, message)
        elseif category == "mouse" then
            table.insert(mouse_info, message)
        else
            table.insert(entity_info, message)
        end
    else
        -- Console logolás
        if category == "error" then
            LumixAPI.logError(message)
        else
            LumixAPI.logInfo(message)
        end
    end
end

-- ImGui debug ablak megjelenítése
function showDebugWindow()
    if not show_debug_window then return end
    
    local window_open=ImGui.Begin("Debug Info", true)
    
    if window_open then
        -- Aktuális mód kijelzése
        local mode_text = use_gui_output and "Aktuális: ImGui Output" or "Aktuális: Console Output"
        
        ImGui.Text(mode_text)
        
        ImGui.Separator()
        
        -- Output módszer váltó
        local changed, new_value = ImGui.Checkbox("ImGui Output használata", use_gui_output)
        if changed then
            use_gui_output = new_value
            -- Töröljük a tárolt adatokat ha váltunk
            entity_info = {}
            components_info = {}
            mouse_info = {}
            
            -- Feedback a váltásról
            local new_mode = use_gui_output and "ImGui" or "Console"
            LumixAPI.logInfo("Output mód váltva: " .. new_mode)
        end
        
        ImGui.SameLine()
        if ImGui.Button("Váltás") then
            toggleOutputMode()
        end
        
        ImGui.Separator()
        
        -- Debug ablak be/ki kapcsoló
        local window_changed, window_value = ImGui.Checkbox("Debug ablak megjelenítése", show_debug_window)
        if window_changed then
            show_debug_window = window_value
        end
        
        ImGui.Separator()
        
        -- Frissítés gomb
        if ImGui.Button("Információ frissítése") then
            -- Töröljük a régi adatokat
            entity_info = {}
            components_info = {}
            mouse_info = {}
            
            -- Újra gyűjtjük az adatokat
            logEntityInfo()
            logComponents() 
            logDetailedEntityInfo()
        end
        
        ImGui.SameLine()
        if ImGui.Button("Console módra váltás") then
            cmd_console()
        end
        
        ImGui.Separator()
        
        -- Csak akkor jelenítjük meg az adatokat, ha GUI output van
        if use_gui_output then
            -- Egér információk
            ImGui.Text("=== Egér Információk ===")
            for _, info in ipairs(mouse_info) do
                ImGui.Text(info)
            end
            
            ImGui.Separator()
            
            -- Entitás információk
            ImGui.Text("=== Entitás Információk ===")
            for _, info in ipairs(entity_info) do
                ImGui.Text(info)
            end
            
            ImGui.Separator()
            
            -- Komponens információk
            ImGui.Text("=== Komponensek ===")
            for _, info in ipairs(components_info) do
                ImGui.Text(info)
            end
        else
            ImGui.Text("Console output mód aktív")
            ImGui.Text("Ellenőrizd a console-t az információkért")
        end
    end
    
    ImGui.End()
    
    if should_close then
        show_debug_window = false
    end
end

-- Input event kezelő függvény
function onInputEvent(event)
    -- Ellenőrizzük hogy ez egér esemény-e
    if event.type == "axis" and event.device.type == "mouse" then
        -- Relatív egér mozgás
        mouse_x = event.x
        mouse_y = event.y
        
        -- Abszolút egér pozíció (ha elérhető)
        mouse_abs_x = event.x_abs
        mouse_abs_y = event.y_abs
        
        -- Egér pozíció frissítése a GUI-ban
        if use_gui_output then
            mouse_info = {} -- Töröljük a régi adatokat
            log(string.format("Relatív: x=%.1f, y=%.1f", mouse_x, mouse_y), "mouse")
            log(string.format("Abszolút: x=%.1f, y=%.1f", mouse_abs_x, mouse_abs_y), "mouse")
        else
            log(string.format("Egér pozíció - Relatív: x=%.1f, y=%.1f | Abszolút: x=%.1f, y=%.1f", 
                mouse_x, mouse_y, mouse_abs_x, mouse_abs_y), "mouse")
        end
    end
    
    -- Egérkattintás esemény
    if event.type == "button" and event.device.type == "mouse" then
        if event.down then
            log(string.format("Egérkattintás - pozíció: x=%.1f, y=%.1f, gomb: %d", 
                event.x, event.y, event.key_id), "mouse")
        end
    end
end

-- Polling módszer az update-ben
function pollMouseInput()
    -- ImGui egér állapot lekérdezés
    local left_down = ImGui.IsMouseDown(0)  -- 0 = bal egérgomb
    local right_down = ImGui.IsMouseDown(1) -- 1 = jobb egérgomb
    local middle_down = ImGui.IsMouseDown(2) -- 2 = középső egérgomb
    
    if left_down then
        log("Bal egérgomb nyomva", "mouse")
    end
    
    -- Egérkattintás ellenőrzése
    if ImGui.IsMouseClicked(0) then
        log("Bal egérgomb kattintás", "mouse")
    end
    
    if ImGui.IsMouseClicked(1) then
        log("Jobb egérgomb kattintás", "mouse")
    end
end

-- GUI rect komponensnél egér ellenőrzés
function checkMouseOverGUI()
    if this:hasComponent("gui_rect") then
        local gui = this.world.gui
        local mouse_pos = {mouse_abs_x, mouse_abs_y}
        
        -- Ellenőrizzük hogy az egér az adott GUI elem felett van-e
        local is_over = gui:isOver(mouse_pos, this)
        
        if is_over then
            log("Egér a GUI elem felett van!", "mouse")
        end
        
        -- Keressük meg melyik GUI elem van az egér alatt
        local gui_entity = gui:getRectAt(mouse_pos)
        if gui_entity then
            log("GUI entitás az egér alatt: " .. tostring(gui_entity), "mouse")
        end
    end
end

-- 3D világban egér pozíció számítás
function getMouseWorldPosition()
    if this:hasComponent("camera") then
        local camera = this.camera
        
        -- Egér koordináták normalizálása (-1 to 1 range)
        local display_width = ImGui.GetDisplayWidth()
        local display_height = ImGui.GetDisplayHeight()
        
        if display_width > 0 and display_height > 0 then
            local normalized_x = (mouse_abs_x / display_width) * 2 - 1
            local normalized_y = (mouse_abs_y / display_height) * 2 - 1
            
            -- Ray létrehozása kamerából
            local mouse_vec = {normalized_x, -normalized_y} -- Y tengely megfordítva
            local ray = camera:getRay(mouse_vec)
            
            if ray then
                log("Ray origin elérhető", "mouse")
                
                -- Raycast a világban
                local hit_entity = this.world.physics:raycast(ray.origin, ray.dir, 1000, this)
                if hit_entity then
                    log("Hit entity: " .. tostring(hit_entity), "mouse")
                end
            end
        end
    end
end

-- Ez a függvény automatikusan meghívódik input eseményekre
function onInput(event)
    onInputEvent(event)
end
function update(dt)
    showDebugWindow()
end