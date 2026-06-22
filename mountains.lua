local Mountains = {}
local Pond = require("pond")
local Paths = require("paths")

local MOUNTAIN_COUNT = 8
local SPAWN_SAFE_RADIUS = 350
local MAP_PADDING = 150

local mountains = {}

local mountainColors = {
    { 0.35, 0.33, 0.30 },
    { 0.40, 0.38, 0.35 },
    { 0.30, 0.28, 0.25 },
    { 0.45, 0.42, 0.38 },
}

function Mountains.generate(mapW, mapH, playerX, playerY)
    mountains = {}
    local cx = playerX or mapW / 2
    local cy = playerY or mapH / 2
    local attempts = 0
    while #mountains < MOUNTAIN_COUNT and attempts < 500 do
        attempts = attempts + 1
        local x = math.random(MAP_PADDING, mapW - MAP_PADDING)
        local y = math.random(MAP_PADDING, mapH - MAP_PADDING)
        local dx = x - cx
        local dy = y - cy
        if math.sqrt(dx * dx + dy * dy) > SPAWN_SAFE_RADIUS then
            local tooClose = false
            for _, m in ipairs(mountains) do
                local mdx = x - m.x
                local mdy = y - m.y
                if math.sqrt(mdx * mdx + mdy * mdy) < 200 then
                    tooClose = true
                    break
                end
            end
            if not tooClose then
                if Pond.checkCollision(x - 65, y - 50, 130, 100) then
                    tooClose = true
                end
            end
            if not tooClose then
                if Paths.checkCollision(x - 65, y - 50, 130, 100) then
                    tooClose = true
                end
            end
            if not tooClose then
                local w = math.random(80, 130)
                local h = math.random(60, 100)
                local col = mountainColors[math.random(1, #mountainColors)]
                local peaks = {}
                local numPeaks = math.random(3, 5)
                for i = 1, numPeaks do
                    peaks[#peaks + 1] = {
                        ox = (math.random() - 0.5) * w * 0.6,
                        oy = (math.random() - 0.5) * h * 0.3,
                        rw = math.random(w * 0.3, w * 0.5),
                        rh = math.random(h * 0.4, h * 0.7),
                    }
                end
                mountains[#mountains + 1] = {
                    x = x,
                    y = y,
                    w = w,
                    h = h,
                    col = col,
                    peaks = peaks,
                    trunkW = w * 0.5,
                    trunkH = h * 0.3,
                }
            end
        end
    end
end

function Mountains.getAll()
    return mountains
end

function Mountains.checkCollision(x, y, w, h)
    for _, m in ipairs(mountains) do
        local mx = m.x - m.trunkW / 2
        local my = m.y - m.trunkH / 2
        if x < mx + m.trunkW and x + w > mx and y < my + m.trunkH and y + h > my then
            return true
        end
    end
    return false
end

function Mountains.resolveCollision(x, y, w, h)
    local finalX, finalY = x, y
    for _, m in ipairs(mountains) do
        local mx = m.x - m.trunkW / 2
        local my = m.y - m.trunkH / 2
        if finalX < mx + m.trunkW and finalX + w > mx and finalY < my + m.trunkH and finalY + h > my then
            local overlapLeft = (finalX + w) - mx
            local overlapRight = (mx + m.trunkW) - finalX
            local overlapTop = (finalY + h) - my
            local overlapBottom = (my + m.trunkH) - finalY
            local minOverlap = math.min(overlapLeft, overlapRight, overlapTop, overlapBottom)
            if minOverlap == overlapLeft then
                finalX = mx - w
            elseif minOverlap == overlapRight then
                finalX = mx + m.trunkW
            elseif minOverlap == overlapTop then
                finalY = my - h
            else
                finalY = my + m.trunkH
            end
        end
    end
    return finalX, finalY
end

function Mountains.drawBelow(entityY)
    for _, m in ipairs(mountains) do
        if m.y <= entityY then
            Mountains.drawSingle(m)
        end
    end
end

function Mountains.drawAbove(entityY)
    for _, m in ipairs(mountains) do
        if m.y > entityY then
            Mountains.drawSingle(m)
        end
    end
end

function Mountains.drawSingle(m)
    local r, g, b = m.col[1], m.col[2], m.col[3]
    love.graphics.setColor(r * 0.6, g * 0.6, b * 0.6, 0.4)
    love.graphics.ellipse("fill", m.x, m.y + m.trunkH / 2 + 5, m.w / 2 + 5, m.h / 4 + 3)
    for _, p in ipairs(m.peaks) do
        love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7)
        love.graphics.ellipse("fill", m.x + p.ox, m.y + p.oy, p.rw / 2, p.rh / 2)
    end
    for _, p in ipairs(m.peaks) do
        love.graphics.setColor(r, g, b)
        love.graphics.ellipse("fill", m.x + p.ox, m.y + p.oy - 3, p.rw / 2 * 0.85, p.rh / 2 * 0.85)
    end
    for _, p in ipairs(m.peaks) do
        love.graphics.setColor(r * 1.15, g * 1.15, b * 1.15)
        love.graphics.ellipse("fill", m.x + p.ox - p.rw * 0.15, m.y + p.oy - p.rh * 0.2, p.rw / 2 * 0.5, p.rh / 2 * 0.4)
    end
end

return Mountains
