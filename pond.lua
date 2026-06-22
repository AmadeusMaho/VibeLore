local Pond = {}

local ponds = {}
local POND_COUNT = 3
local MAP_PADDING = 200

function Pond.generate(mapW, mapH, playerX, playerY)
    ponds = {}
    local cx = playerX or mapW / 2
    local cy = playerY or mapH / 2
    for i = 1, POND_COUNT do
        local x, y
        local attempts = 0
        local valid = false
        while not valid and attempts < 300 do
            x = math.random(MAP_PADDING, mapW - MAP_PADDING)
            y = math.random(MAP_PADDING, mapH - MAP_PADDING)
            attempts = attempts + 1
            local dx = x - cx
            local dy = y - cy
            if math.sqrt(dx * dx + dy * dy) > 400 then
                valid = true
            end
        end
        if not valid then break end
        local circles = {}
        local baseR = math.random(80, 140)
        local numCircles = math.random(6, 10)
        for j = 1, numCircles do
            local angle = (j / numCircles) * math.pi * 2
            local dist = math.random(20, 60)
            local r = math.random(40, 80)
            circles[#circles + 1] = {
                ox = math.cos(angle) * dist,
                oy = math.sin(angle) * dist,
                r = r,
            }
        end
        circles[#circles + 1] = { ox = 0, oy = 0, r = baseR }
        ponds[#ponds + 1] = { x = x, y = y, circles = circles, baseR = baseR }
    end
end

function Pond.checkCollision(px, py, pw, ph)
    for _, p in ipairs(ponds) do
        for _, c in ipairs(p.circles) do
            local cx = p.x + c.ox
            local cy = p.y + c.oy
            local closestX = math.max(px, math.min(cx, px + pw))
            local closestY = math.max(py, math.min(cy, py + ph))
            local dx = cx - closestX
            local dy = cy - closestY
            if dx * dx + dy * dy < c.r * c.r then
                return true
            end
        end
    end
    return false
end

function Pond.resolveCollision(x, y, w, h)
    local finalX, finalY = x, y
    for _, p in ipairs(ponds) do
        for _, c in ipairs(p.circles) do
            local cx = p.x + c.ox
            local cy = p.y + c.oy
            local closestX = math.max(finalX, math.min(cx, finalX + w))
            local closestY = math.max(finalY, math.min(cy, finalY + h))
            local dx = cx - closestX
            local dy = cy - closestY
            if dx * dx + dy * dy < c.r * c.r then
                local pushX = finalX + w / 2 - cx
                local pushY = finalY + h / 2 - cy
                local pushDist = math.sqrt(pushX * pushX + pushY * pushY)
                if pushDist > 0 then
                    pushX = pushX / pushDist
                    pushY = pushY / pushDist
                else
                    pushX = 1
                    pushY = 0
                end
                finalX = cx + pushX * (c.r + w / 2 + 2) - w / 2
                finalY = cy + pushY * (c.r + h / 2 + 2) - h / 2
            end
        end
    end
    return finalX, finalY
end

function Pond.draw()
    for _, p in ipairs(ponds) do
        for _, c in ipairs(p.circles) do
            local cx = p.x + c.ox
            local cy = p.y + c.oy
            love.graphics.setColor(0.15, 0.35, 0.55, 1)
            love.graphics.circle("fill", cx, cy, c.r)
        end
        for _, c in ipairs(p.circles) do
            local cx = p.x + c.ox
            local cy = p.y + c.oy
            love.graphics.setColor(0.18, 0.42, 0.65, 1)
            love.graphics.circle("fill", cx, cy, c.r * 0.7)
        end
        for _, c in ipairs(p.circles) do
            local cx = p.x + c.ox
            local cy = p.y + c.oy
            love.graphics.setColor(0.22, 0.5, 0.75, 0.5)
            love.graphics.circle("fill", cx - c.r * 0.2, cy - c.r * 0.2, c.r * 0.3)
        end
    end
end

return Pond
