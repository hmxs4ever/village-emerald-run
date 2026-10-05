-- Village Emerald Run
-- REFramework autorun for Resident Evil 4.
-- Rings, boost, one gate, a timed stretch, and an emerald.
-- Does not disable weapons. Does not read Sonic Frontiers.

local MOD = "Village Emerald Run"

local RINGS = {
    { id = "ring_1", kind = "ring", distance_m = 6, radius_m = 1.6 },
    { id = "ring_2", kind = "ring", distance_m = 12, radius_m = 1.6 },
    { id = "ring_3", kind = "ring", distance_m = 18, radius_m = 1.6 },
    { id = "gate", kind = "gate", distance_m = 24, radius_m = 3.0 },
    { id = "ring_4", kind = "ring", distance_m = 32, radius_m = 1.6 },
    { id = "ring_5", kind = "ring", distance_m = 40, radius_m = 1.6 },
    { id = "emerald", kind = "emerald", distance_m = 48, radius_m = 2.5 },
}

local VK_SHIFT = 16
local VK_F6 = 117
local VK_F7 = 118
local BOOST_MPS = 9.0

local state = {
    planted = false,
    origin = nil,
    forward = nil,
    points = {},
    collected = {},
    gate_open = false,
    finished = false,
    timer = 0,
    last_clock = os.clock(),
    status = "Stand in the clearing and press F6 to plant the course.",
    pitch = "not requested",
    f6_was = false,
    f7_was = false,
}

local function vec(x, y, z)
    return Vector3f.new(x, y, z)
end

local function flat_forward(axis)
    if axis == nil then
        return vec(0, 0, 1)
    end
    local x = axis.x or 0
    local z = axis.z or 1
    local len = math.sqrt(x * x + z * z)
    if len < 0.001 then
        return vec(0, 0, 1)
    end
    return vec(x / len, 0, z / len)
end

local function get_body()
    local manager = sdk.get_managed_singleton(sdk.game_namespace("CharacterManager"))
    if manager == nil then
        return nil, nil
    end
    local ctx = manager:call("getPlayerContextRef")
    if ctx == nil then
        return nil, nil
    end
    local body = ctx:call("get_BodyGameObject")
    if body == nil then
        return nil, nil
    end
    local transform = body:call("get_Transform")
    return body, transform
end

local function read_pos(transform)
    local pos = transform:call("get_Position")
    if pos == nil then
        return nil
    end
    return vec(pos.x, pos.y, pos.z)
end

local function place_course(origin, forward)
    state.origin = origin
    state.forward = forward
    state.points = {}
    state.collected = {}
    state.gate_open = false
    state.finished = false
    state.timer = 0
    state.pitch = "not requested"
    for i, row in ipairs(RINGS) do
        state.points[i] = {
            id = row.id,
            kind = row.kind,
            radius_m = row.radius_m,
            pos = vec(
                origin.x + forward.x * row.distance_m,
                origin.y + 1.1,
                origin.z + forward.z * row.distance_m
            ),
        }
    end
    state.planted = true
    state.status = "Course planted. Hold Shift to boost. Shoot as usual."
end

local function dist_xz(a, b)
    local dx = a.x - b.x
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

local function try_pitch_up()
    local ok, err = pcall(function()
        local mgr = sdk.get_managed_singleton(sdk.game_namespace("SoundManager"))
        if mgr == nil then
            state.pitch = "SoundManager missing; chapter track left as-is"
            return
        end
        local called = false
        for _, name in ipairs({ "set_MasterPitch", "set_Pitch", "set_BgmPitch" }) do
            local method = mgr:get_type_definition():get_method(name)
            if method ~= nil then
                mgr:call(name, 1.35)
                state.pitch = "requested 1.35 via " .. name
                called = true
                break
            end
        end
        if not called then
            state.pitch = "no pitch method; chapter track left as-is"
        end
    end)
    if not ok then
        state.pitch = "pitch hook failed; chapter track left as-is"
    end
end

local function on_collect(point)
    if state.collected[point.id] then
        return
    end
    state.collected[point.id] = true
    if point.kind == "gate" and not state.gate_open then
        state.gate_open = true
        state.timer = 0
        state.status = "Gate crossed. Timer running."
        try_pitch_up()
    elseif point.kind == "emerald" and state.gate_open and not state.finished then
        state.finished = true
        state.status = string.format("Emerald. Time %.2fs", state.timer)
    elseif point.kind == "ring" then
        state.status = "Ring."
    end
end

local function boost(transform, pos, dt)
    if not reframework:is_key_down(VK_SHIFT) then
        return
    end
    if state.forward == nil then
        return
    end
    local step = BOOST_MPS * dt
    local next_pos = vec(
        pos.x + state.forward.x * step,
        pos.y,
        pos.z + state.forward.z * step
    )
    pcall(function()
        transform:call("set_Position", next_pos)
    end)
end

re.on_frame(function()
    if reframework:get_game_name() ~= "re4" then
        state.status = "This script only runs in Resident Evil 4."
        return
    end

    local now = os.clock()
    local dt = now - state.last_clock
    state.last_clock = now
    if dt < 0 or dt > 0.1 then
        dt = 0.016
    end

    local _, transform = get_body()
    if transform == nil then
        return
    end
    local pos = read_pos(transform)
    if pos == nil then
        return
    end

    local f6 = reframework:is_key_down(VK_F6)
    if f6 and not state.f6_was then
        local axis = transform:call("get_AxisZ")
        place_course(pos, flat_forward(axis))
    end
    state.f6_was = f6

    local f7 = reframework:is_key_down(VK_F7)
    if f7 and not state.f7_was and state.planted then
        state.collected = {}
        state.gate_open = false
        state.finished = false
        state.timer = 0
        state.pitch = "not requested"
        state.status = "Run reset. Course still planted."
    end
    state.f7_was = f7

    if not state.planted then
        return
    end

    if state.gate_open and not state.finished then
        state.timer = state.timer + dt
    end

    boost(transform, pos, dt)

    for _, point in ipairs(state.points) do
        if dist_xz(pos, point.pos) <= point.radius_m then
            on_collect(point)
        end
    end
end)

re.on_draw_ui(function()
    if imgui.begin_window(MOD, true, 0) then
        imgui.text(state.status)
        imgui.text("F6 plant   Shift boost   F7 reset")
        imgui.text("Aim and fire are unchanged.")
        if state.planted then
            local rings = 0
            for _, point in ipairs(state.points) do
                if point.kind == "ring" and state.collected[point.id] then
                    rings = rings + 1
                end
            end
            imgui.text(string.format("Rings %d/5", rings))
            imgui.text(state.gate_open and "Gate: crossed" or "Gate: ahead")
            imgui.text(string.format("Time %.2f", state.timer))
            imgui.text("Track: " .. state.pitch)
            imgui.text(state.finished and "Emerald: taken" or "Emerald: ahead")
        end
    end
    imgui.end_window()
end)

re.on_frame(function()
    if draw == nil or not state.planted then
        return
    end
    for _, point in ipairs(state.points) do
        local label = "RING"
        local color = 0xFF33CCFF
        if point.kind == "gate" then
            label = "GATE"
            color = 0xFFFFCC44
        elseif point.kind == "emerald" then
            label = "EMERALD"
            color = 0xFF44FF88
        end
        if state.collected[point.id] and point.kind == "ring" then
            label = "RING x"
            color = 0xFF888888
        end
        pcall(function()
            draw.world_text(label, point.pos, color)
        end)
    end
end)
