local Bushes = {}
local Trees = require("trees")
local Rocks = require("rocks")
local Pond = require("pond")

local BUSH_COUNT = 14
local SPAWN_SAFE_RADIUS = 250
local MAP_PADDING = 100
local FRAME_W = 128
local FRAME_H = 128
local BUSH_COLS = 8
local MIN_DIST = 60

local bushImages = {}
local bushes = {}

function Bushes.load()
    bushImages = {}
    for i = 1, 2 do
        local path = "sprites/bushe" .. i .. ".png"
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            img:setFilter("nearest", "nearest")
            local w = img:getWidth()
            local h = img:getHeight()
            local frames = {}
            for c = 0, BUSH_COLS - 1 do
                frames[#frames + 1] = love.graphics.newQuad(c * FRAME_W, 0, FRAME_W, FRAME_H, w, h)
            end
            bushImages[#bushImages + 1] = { img = img, frames = frames }
        end
    end
end

function Bushes.generate(mapW, mapH, playerX, playerY)
    bushes = {}
    if #bushImages == 0 then return end
    local cx = playerX or mapW / 2
    local cy = playerY or mapH / 2
    local treeList = Trees.getAll()
    local attempts = 0
    while #bushes < BUSH_COUNT and attempts < 500 do
        attempts = attempts + 1
        local x = math.random(MAP_PADDING, mapW - MAP_PADDING)
        local y = math.random(MAP_PADDING, mapH - MAP_PADDING)
        local dx = x - cx
        local dy = y - cy
        if math.sqrt(dx * dx + dy * dy) > SPAWN_SAFE_RADIUS then
            local tooClose = false
            for _, t in ipairs(treeList) do
                local tdx = x - t.x
                local tdy = y - t.y
                if math.sqrt(tdx * tdx + tdy * tdy) < MIN_DIST then
                    tooClose = true
                    break
                end
            end
            if not tooClose then
                local rocksList = Rocks.getAll()
                for _, r in ipairs(rocksList) do
                    local rdx = x - r.x
                    local rdy = y - r.y
                    if math.sqrt(rdx * rdx + rdy * rdy) < MIN_DIST then
                        tooClose = true
                        break
                    end
                end
            end
            if not tooClose then
                if Pond.checkCollision(x - FRAME_W / 2, y - FRAME_H, FRAME_W, FRAME_H) then
                    tooClose = true
                end
            end
            if not tooClose then
                local imgData = bushImages[math.random(1, #bushImages)]
                local frameIdx = math.random(1, #imgData.frames)
                bushes[#bushes + 1] = {
                    x = x,
                    y = y,
                    img = imgData.img,
                    quad = imgData.frames[frameIdx],
                }
            end
        end
    end
end

function Bushes.getAll()
    return bushes
end

function Bushes.drawBelow(entityY)
    for _, b in ipairs(bushes) do
        if b.y <= entityY then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(b.img, b.quad, b.x, b.y, 0, 1, 1, FRAME_W / 2, FRAME_H)
        end
    end
end

function Bushes.drawAbove(entityY)
    for _, b in ipairs(bushes) do
        if b.y > entityY then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(b.img, b.quad, b.x, b.y, 0, 1, 1, FRAME_W / 2, FRAME_H)
        end
    end
end

return Bushes
