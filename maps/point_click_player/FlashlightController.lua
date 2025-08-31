-- Universal Mouse Look 2D Rotation Script
-- Rotates any entity to face the mouse cursor position
-- Works with any object - just attach this script to it

-- Configuration
local ROTATION_PLANE = "xz"  -- "xz" for top-down (Y-axis rotation), "xy" for side-view (Z-axis rotation)
local ROTATION_SPEED = 10    -- Smooth rotation speed (0 = instant, higher = smoother)
local OFFSET_ANGLE = 0        -- Additional rotation offset in radians
local DEBUG_MODE = false      -- Show debug information

-- Internal variables
local camera_entity = nil
local target_rotation = {x = 0, y = 0, z = 0, w = 1}
local mouse_x = 0
local mouse_y = 0
local camera_search_attempts = 0
local max_search_attempts = 60  -- Try to find camera for 1 second (60 frames)

function onInputEvent(event)
    -- Track mouse movement
    if event.type == "axis" and event.device.type == "mouse" then
        mouse_x = event.x_abs
        mouse_y = event.y_abs
        updateRotation(mouse_x, mouse_y)
    end
end

function updateRotation(mx, my)
    -- Try to find camera if we don't have one
    if not camera_entity and camera_search_attempts < max_search_attempts then
        findCamera()
        camera_search_attempts = camera_search_attempts + 1
        if not camera_entity then
            return
        end
    end
    
    if not camera_entity then
        return
    end
    
    local camera = camera_entity.camera
    if not camera then
        -- Camera component was removed, try to find it again
        camera_entity = nil
        camera_search_attempts = 0
        return
    end
    
    -- Get viewport dimensions
    local viewport_width = ImGui.GetDisplayWidth()
    local viewport_height = ImGui.GetDisplayHeight()
    
    -- Normalize mouse coordinates to 0-1 range
    local normalized_x = mx / viewport_width
    local normalized_y = my / viewport_height
    
    -- Get ray from camera through mouse position
    local ray = camera:getRay({normalized_x, normalized_y})
    
    if not ray or not ray.origin or not ray.dir then
        return
    end
    
    -- Get entity position
    local entity_pos = this.position
    
    -- Calculate intersection point based on rotation plane
    local target_pos = {}
    
    if ROTATION_PLANE == "xz" then
        -- Top-down view: intersect ray with XZ plane at entity's Y position
        if math.abs(ray.dir[2]) > 0.0001 then  -- Avoid division by zero
            local t = (entity_pos[2] - ray.origin[2]) / ray.dir[2]
            if t > 0 then
                target_pos[1] = ray.origin[1] + ray.dir[1] * t
                target_pos[2] = entity_pos[2]
                target_pos[3] = ray.origin[3] + ray.dir[3] * t
            else
                return
            end
        else
            return
        end
    elseif ROTATION_PLANE == "xy" then
        -- Side view: intersect ray with XY plane at entity's Z position
        if math.abs(ray.dir[3]) > 0.0001 then  -- Avoid division by zero
            local t = (entity_pos[3] - ray.origin[3]) / ray.dir[3]
            if t > 0 then
                target_pos[1] = ray.origin[1] + ray.dir[1] * t
                target_pos[2] = ray.origin[2] + ray.dir[2] * t
                target_pos[3] = entity_pos[3]
            else
                return
            end
        else
            return
        end
    end
    
    -- Calculate direction from entity to target
    local dx = target_pos[1] - entity_pos[1]
    local dy = target_pos[2] - entity_pos[2]
    local dz = target_pos[3] - entity_pos[3]
    
    -- Calculate rotation angle based on plane
    local angle = 0
    
    if ROTATION_PLANE == "xz" then
        -- Rotate around Y axis
        angle = math.atan2(dx, dz) + OFFSET_ANGLE
        target_rotation = eulerToQuaternion(0, angle, 0)
    elseif ROTATION_PLANE == "xy" then
        -- Rotate around Z axis
        angle = math.atan2(dy, dx) + OFFSET_ANGLE
        target_rotation = eulerToQuaternion(0, 0, angle)
    end
end

function findCamera()
    local world = this.world
    
    -- Method 1: Try to get active camera from renderer module
    local renderer = world.renderer
    if renderer then
        -- Try common camera entity names
        local camera_names = {"camera", "main_camera", "Camera", "MainCamera", "player_camera", "PlayerCamera"}
        for _, name in ipairs(camera_names) do
            local entity = world:findEntityByName(name)
            if entity and entity.camera then
                camera_entity = entity
                if DEBUG_MODE then
                    LumixAPI.logInfo("Mouse Look: Found camera named '" .. name .. "'")
                end
                return
            end
        end
    end
    
    -- Method 2: Look for any entity with a camera component
    -- This requires iterating through entities (if supported by your Lumix version)
    -- Note: This is a fallback method and may need adjustment based on your API
    
    -- Method 3: Try to get camera from Editor if in editor mode
    if Editor and Editor.scene_view then
        -- This gets the editor camera, which might work for testing
        -- Note: This won't work in the final game, only in editor
        if DEBUG_MODE then
            LumixAPI.logInfo("Mouse Look: Using editor camera (editor mode only)")
        end
    end
end

function eulerToQuaternion(pitch, yaw, roll)
    -- Convert Euler angles to quaternion
    local cp = math.cos(pitch * 0.5)
    local sp = math.sin(pitch * 0.5)
    local cy = math.cos(yaw * 0.5)
    local sy = math.sin(yaw * 0.5)
    local cr = math.cos(roll * 0.5)
    local sr = math.sin(roll * 0.5)
    
    return {
        x = sp * cy * cr - cp * sy * sr,
        y = cp * sy * cr + sp * cy * sr,
        z = cp * cy * sr - sp * sy * cr,
        w = cp * cy * cr + sp * sy * sr
    }
end

function quaternionSlerp(q1, q2, t)
    -- Spherical linear interpolation between two quaternions
    if not q1 or not q2 then
        return q1 or q2 or {x = 0, y = 0, z = 0, w = 1}
    end
    
    local dot = q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w
    
    -- If the dot product is negative, negate one quaternion to take the shorter path
    if dot < 0 then
        q2 = {x = -q2.x, y = -q2.y, z = -q2.z, w = -q2.w}
        dot = -dot
    end
    
    -- If quaternions are very close, use linear interpolation
    if dot > 0.9995 then
        local result = {
            x = q1.x + t * (q2.x - q1.x),
            y = q1.y + t * (q2.y - q1.y),
            z = q1.z + t * (q2.z - q1.z),
            w = q1.w + t * (q2.w - q1.w)
        }
        -- Normalize
        local len = math.sqrt(result.x * result.x + result.y * result.y + result.z * result.z + result.w * result.w)
        if len > 0 then
            result.x = result.x / len
            result.y = result.y / len
            result.z = result.z / len
            result.w = result.w / len
        end
        return result
    end
    
    -- Calculate interpolation factors
    local theta_0 = math.acos(dot)
    local theta = theta_0 * t
    local sin_theta = math.sin(theta)
    local sin_theta_0 = math.sin(theta_0)
    
    local s0 = math.cos(theta) - dot * sin_theta / sin_theta_0
    local s1 = sin_theta / sin_theta_0
    
    return {
        x = s0 * q1.x + s1 * q2.x,
        y = s0 * q1.y + s1 * q2.y,
        z = s0 * q1.z + s1 * q2.z,
        w = s0 * q1.w + s1 * q2.w
    }
end

function update(dt)
    -- Apply rotation
    if ROTATION_SPEED > 0 then
        -- Smooth rotation using slerp
        local current_rot = this.rotation
        local t = math.min(1.0, dt * ROTATION_SPEED)
        this.rotation = quaternionSlerp(current_rot, target_rotation, t)
    else
        -- Instant rotation
        this.rotation = target_rotation
    end
    
    -- Keep trying to find camera if we don't have one
    if not camera_entity and camera_search_attempts < max_search_attempts then
        findCamera()
        camera_search_attempts = camera_search_attempts + 1
    end
end

function init()
    -- Find camera on initialization
    findCamera()
    
    -- Initialize target rotation to current rotation
    if this.rotation then
        target_rotation = this.rotation
    end
    
    -- Log initialization
    if DEBUG_MODE then
        LumixAPI.logInfo("Mouse Look Script initialized on entity: " .. (this.name or "unnamed"))
    end
end

-- Optional: Draw debug visualization
function onGUI()
    if not DEBUG_MODE then
        return
    end
    
    ImGui.Text("=== Mouse Look Debug ===")
    
    if camera_entity then
        ImGui.Text("Camera: " .. (camera_entity.name or "found"))
    else
        ImGui.Text("Camera: NOT FOUND (" .. camera_search_attempts .. " attempts)")
    end
    
    ImGui.Text(string.format("Mouse: %.1f, %.1f", mouse_x, mouse_y))
    ImGui.Text(string.format("Mode: %s plane", ROTATION_PLANE))
    ImGui.Text(string.format("Speed: %.1f", ROTATION_SPEED))
    
    if target_rotation then
        ImGui.Text(string.format("Target Rot: %.2f, %.2f, %.2f, %.2f", 
            target_rotation.x, target_rotation.y, target_rotation.z, target_rotation.w))
    end
    
    -- Configuration controls
    ImGui.Separator()
    local changed, new_speed = ImGui.DragFloat("Rotation Speed", ROTATION_SPEED)
    if changed then
        ROTATION_SPEED = new_speed
    end
    
    local changed2, new_offset = ImGui.DragFloat("Offset Angle", OFFSET_ANGLE)
    if changed2 then
        OFFSET_ANGLE = new_offset
    end
end

-- Error handling
function onDestroy()
    if DEBUG_MODE then
        LumixAPI.logInfo("Mouse Look Script destroyed")
    end
end