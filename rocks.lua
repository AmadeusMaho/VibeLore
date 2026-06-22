local Rocks = {}
local Pond = require("pond")

local ROCK_COUNT = 15
local TRUNK_WIDTH = 16
local TRUNK_HEIGHT = 14
local SPAWN_SAFE_RADIUS = 250
local MAP_PADDING = 100

local rockImages = {}
local rocks = {}

function Rocks.load()
    rockImages = {}
    for i = 1, 4 do
        local path = "sprites/Rock" .. i .. ".png"
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            img:setFilter("nearest", "nearest")
            rockImages[#rockImages + 1] = img
        end
    end
end

function Rocks.generate(mapW, mapH, playerX, playerY)
    rocks = {}
    if #rockImages == 0 then return end
    local cx = playerX or mapW / 2
    local cy = playerY or mapH / 2
    local attempts = 0
    while #rocks < ROCK_COUNT and attempts < 500 do
        attempts = attempts + 1
        local x = math.random(MAP_PADDING, mapW - MAP_PADDING)
        local y = math.random(MAP_PADDING, mapH - MAP_PADDING)
        local dx = x - cx
        local dy = y - cy
        if math.sqrt(dx * dx + dy * dy) > SPAWN_SAFE_RADIUS then
            if not Pond.checkCollision(x - TRUNK_WIDTH / 2, y - TRUNK_HEIGHT / 2, TRUNK_WIDTH, TRUNK_HEIGHT) then
                local imgIdx = math.random(1, #rockImages)
                local img = rockImages[imgIdx]
                local w = img:getWidth()
                local h = img:getHeight()
                rocks[#rocks + 1] = {
                    x = x,
                    y = y,
                    img = img,
                    w = w,
                    h = h,
                    trunkW = TRUNK_WIDTH,
                    trunkH = TRUNK_HEIGHT,
                }
            end
        end
    end
end

function Rocks.getAll()
    return rocks
end

function Rocks.checkCollision(x, y, w, h)
    for _, r in ipairs(rocks) do
        local rx = r.x - r.trunkW / 2
        local ry = r.y - r.trunkH / 2
        if x < rx + r.trunkW and x + w > rx and y < ry + r.trunkH and y + h > ry then
            return true
        end
    end
    return false
end

function Rocks.resolveCollision(x, y, w, h)
    local finalX, finalY = x, y
    for _, r in ipairs(rocks) do
        local rx = r.x - r.trunkW / 2
        local ry = r.y - r.trunkH / 2
        if finalX < rx + r.trunkW and finalX + w > rx and finalY < ry + r.trunkH and finalY + h > ry then
            local overlapLeft = (finalX + w) - rx
            local overlapRight = (rx + r.trunkW) - finalX
            local overlapTop = (finalY + h) - ry
            local overlapBottom = (ry + r.trunkH) - finalY
            local minOverlap = math.min(overlapLeft, overlapRight, overlapTop, overlapBottom)
            if minOverlap == overlapLeft then
                finalX = rx - w
            elseif minOverlap == overlapRight then
                finalX = rx + r.trunkW
            elseif minOverlap == overlapTop then
                finalY = ry - h
            else
                finalY = ry + r.trunkH
            end
        end
    end
    return finalX, finalY
end

function Rocks.drawBelow(entityY)
    for _, r in ipairs(rocks) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(r.img, r.x, r.y, 0, 1, 1, r.w / 2, r.h)
    end
end

function Rocks.drawAbove(entityY)
end

return Rocks
