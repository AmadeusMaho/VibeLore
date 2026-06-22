local Paths = {}

local paths = {}
local pathPoints = {}
local pathCanvas = nil
local dirtImg = nil
local dirtQuads = {}

local TILE_SCALE = 0.13
local TILE_SPACING = 0.045
local SOFT_EDGE_RADIUS = 18

local function catmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    )
end

function Paths.generate(mapW, mapH)
    paths = {
        {
            { x = mapW * 0.1, y = mapH * 0.3 },
            { x = mapW * 0.25, y = mapH * 0.35 },
            { x = mapW * 0.4, y = mapH * 0.28 },
            { x = mapW * 0.55, y = mapH * 0.4 },
            { x = mapW * 0.7, y = mapH * 0.35 },
            { x = mapW * 0.85, y = mapH * 0.5 },
        },
        {
            { x = mapW * 0.3, y = mapH * 0.1 },
            { x = mapW * 0.35, y = mapH * 0.25 },
            { x = mapW * 0.42, y = mapH * 0.45 },
            { x = mapW * 0.5, y = mapH * 0.6 },
            { x = mapW * 0.55, y = mapH * 0.75 },
            { x = mapW * 0.6, y = mapH * 0.9 },
        },
        {
            { x = mapW * 0.15, y = mapH * 0.7 },
            { x = mapW * 0.3, y = mapH * 0.65 },
            { x = mapW * 0.45, y = mapH * 0.72 },
            { x = mapW * 0.6, y = mapH * 0.68 },
            { x = mapW * 0.8, y = mapH * 0.75 },
        },
    }

    pathPoints = {}
    for _, path in ipairs(paths) do
        local segments = #path
        for i = 1, segments - 1 do
            local p0 = path[math.max(1, i - 1)]
            local p1 = path[i]
            local p2 = path[math.min(segments, i + 1)]
            local p3 = path[math.min(segments, i + 2)]
            local t = 0
            while t <= 1 do
                local px = catmullRom(p0.x, p1.x, p2.x, p3.x, t)
                local py = catmullRom(p0.y, p1.y, p2.y, p3.y, t)
                pathPoints[#pathPoints + 1] = { x = px, y = py }
                t = t + 0.05
            end
        end
    end

    if love.filesystem.getInfo("sprites/dirt.jpg") then
        dirtImg = love.graphics.newImage("sprites/dirt.jpg")
        dirtImg:setFilter("nearest", "nearest")
        local w = dirtImg:getWidth()
        local h = dirtImg:getHeight()
        local tileW = w / 3
        for i = 0, 2 do
            dirtQuads[#dirtQuads + 1] = love.graphics.newQuad(i * tileW, 0, tileW, h, w, h)
        end
    end

    pathCanvas = love.graphics.newCanvas(mapW, mapH)
    pathCanvas:setFilter("nearest", "nearest")
    love.graphics.setCanvas(pathCanvas)
    love.graphics.clear(0, 0, 0, 0)

    for _, path in ipairs(paths) do
        local segments = #path
        for i = 1, segments - 1 do
            local p0 = path[math.max(1, i - 1)]
            local p1 = path[i]
            local p2 = path[math.min(segments, i + 1)]
            local p3 = path[math.min(segments, i + 2)]
            local t = 0
            local segIdx = math.random(1, 3)
            while t <= 1 do
                local px = catmullRom(p0.x, p1.x, p2.x, p3.x, t)
                local py = catmullRom(p0.y, p1.y, p2.y, p3.y, t)
                local px2 = catmullRom(p0.x, p1.x, p2.x, p3.x, t + 0.01)
                local py2 = catmullRom(p0.y, p1.y, p2.y, p3.y, t + 0.01)
                local angle = math.atan2(py2 - py, px2 - px)

                for e = 1, 6 do
                    local er = SOFT_EDGE_RADIUS + e * 6
                    local ea = 0.18 / (e * 0.8)
                    local ox = love.math.random(-4, 4)
                    local oy = love.math.random(-4, 4)
                    love.graphics.setColor(0.2, 0.14, 0.07, ea)
                    love.graphics.circle("fill", px + ox, py + oy, er)
                end

                if dirtImg and #dirtQuads > 0 then
                    love.graphics.setColor(1, 1, 1, 0.92)
                    love.graphics.draw(dirtImg, dirtQuads[segIdx], px, py, angle, TILE_SCALE, TILE_SCALE, 320, 320)
                    segIdx = (segIdx % 3) + 1
                else
                    love.graphics.setColor(0.35, 0.25, 0.12, 0.85)
                    love.graphics.circle("fill", px, py, 20)
                end
                t = t + TILE_SPACING
            end
        end
    end

    love.graphics.setCanvas()
end

function Paths.checkCollision(x, y, w, h)
    local margin = 30
    for _, p in ipairs(pathPoints) do
        local closestX = math.max(x, math.min(p.x, x + w))
        local closestY = math.max(y, math.min(p.y, y + h))
        local dx = p.x - closestX
        local dy = p.y - closestY
        if dx * dx + dy * dy < margin * margin then
            return true
        end
    end
    return false
end

function Paths.draw()
    if pathCanvas then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(pathCanvas, 0, 0)
    end
end

return Paths
