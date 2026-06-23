local Trees = {}
local Pond = require("pond")

local TREE_COUNT = 17
local TRUNK_WIDTH = 20
local TRUNK_HEIGHT = 22
local SPAWN_SAFE_RADIUS = 250
local MAP_PADDING = 100

local treeImg
local treeFrames
local trees = {}

local FRAME_W = 192
local FRAME_H = 192
local TREE_COLS = 8

function Trees.load()
    if love.filesystem.getInfo("sprites/Tree3.png") then
        treeImg = love.graphics.newImage("sprites/Tree3.png")
        treeImg:setFilter("nearest", "nearest")
        local w = treeImg:getWidth()
        local h = treeImg:getHeight()
        treeFrames = {}
        for c = 0, TREE_COLS - 1 do
            treeFrames[#treeFrames + 1] = love.graphics.newQuad(c * FRAME_W, 0, FRAME_W, FRAME_H, w, h)
        end
    end
end

function Trees.generate(mapW, mapH, playerX, playerY)
    trees = {}
    local cx = playerX or mapW / 2
    local cy = playerY or mapH / 2
    local attempts = 0
    while #trees < TREE_COUNT and attempts < 500 do
        attempts = attempts + 1
        local x = math.random(MAP_PADDING, mapW - MAP_PADDING)
        local y = math.random(MAP_PADDING, mapH - MAP_PADDING)
        local dx = x - cx
        local dy = y - cy
        if math.sqrt(dx * dx + dy * dy) > SPAWN_SAFE_RADIUS then
            local tooClose = false
            for _, t in ipairs(trees) do
                local tdx = x - t.x
                local tdy = y - t.y
                if math.sqrt(tdx * tdx + tdy * tdy) < 120 then
                    tooClose = true
                    break
                end
            end
            if not tooClose then
                if Pond.checkCollision(x - TRUNK_WIDTH / 2, y - TRUNK_HEIGHT / 2, TRUNK_WIDTH, TRUNK_HEIGHT) then
                    tooClose = true
                end
            end
            if not tooClose then
                trees[#trees + 1] = {
                    x = x,
                    y = y,
                    trunkW = TRUNK_WIDTH,
                    trunkH = TRUNK_HEIGHT,
                    frameIdx = 1,
                }
            end
        end
    end
end

function Trees.getAll()
    return trees
end

function Trees.checkCollision(x, y, w, h)
    for _, t in ipairs(trees) do
        local tx = t.x - t.trunkW / 2
        local ty = t.y - t.trunkH - 10
        if x < tx + t.trunkW and x + w > tx and y < ty + t.trunkH and y + h > ty then
            return true, t
        end
    end
    return false
end

function Trees.resolveCollision(x, y, w, h)
    local finalX, finalY = x, y
    for _, t in ipairs(trees) do
        local tx = t.x - t.trunkW / 2
        local ty = t.y - t.trunkH - 10
        if finalX < tx + t.trunkW and finalX + w > tx and finalY < ty + t.trunkH and finalY + h > ty then
            local overlapLeft = (finalX + w) - tx
            local overlapRight = (tx + t.trunkW) - finalX
            local overlapTop = (finalY + h) - ty
            local overlapBottom = (ty + t.trunkH) - finalY
            local minOverlap = math.min(overlapLeft, overlapRight, overlapTop, overlapBottom)
            if minOverlap == overlapLeft then
                finalX = tx - w
            elseif minOverlap == overlapRight then
                finalX = tx + t.trunkW
            elseif minOverlap == overlapTop then
                finalY = ty - h
            else
                finalY = ty + t.trunkH
            end
        end
    end
    return finalX, finalY
end

function Trees.drawBelow(entityY)
    for _, t in ipairs(trees) do
        if t.y <= entityY then
            Trees.drawSingle(t)
        end
    end
end

function Trees.drawAbove(entityY)
    for _, t in ipairs(trees) do
        if t.y > entityY then
            Trees.drawSingle(t)
        end
    end
end

function Trees.drawSingle(t)
    love.graphics.setColor(1, 1, 1)
    if treeImg and treeFrames[t.frameIdx] then
        love.graphics.draw(
            treeImg, treeFrames[t.frameIdx],
            t.x, t.y + t.trunkH / 2,
            0, 1.65, 1.65,
            FRAME_W / 2, FRAME_H
        )
    else
        love.graphics.setColor(0.25, 0.15, 0.05)
        love.graphics.rectangle("fill", t.x - t.trunkW / 2, t.y - t.trunkH / 2, t.trunkW, t.trunkH)
        love.graphics.setColor(0.1, 0.45, 0.1)
        love.graphics.circle("fill", t.x, t.y - 20, 35)
    end
end

return Trees
