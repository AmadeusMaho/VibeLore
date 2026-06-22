local Player = require("player")
local Enemy = require("enemy")
local Combat = require("combat")
local Gold = require("gold")
local UI = require("ui")
local Trees = require("trees")

local GameScene = {}
GameScene.__index = GameScene

local MAP_WIDTH = 2000
local MAP_HEIGHT = 2000
local MAX_ENEMIES = 4
local SPAWN_RADIUS = 400

local player
local enemies
local goldItems
local goldCount
local ui
local score
local gameOver
local camera
local groundTiles
local spawnTimer
local spawnInterval
local aliveEnemies
local grassCanvas
local bgMusic
local crtShader
local gameCanvas

function GameScene.new()
    local self = setmetatable({}, GameScene)
    return self
end

function GameScene.enter()
    player = Player.new(MAP_WIDTH / 2, MAP_HEIGHT / 2)
    player:loadAssets()
    enemies = {}
    goldItems = {}
    goldCount = 0
    ui = UI.new()
    score = 0
    gameOver = false

    camera = {
        x = 0,
        y = 0,
        smoothing = 8,
        zoom = 1.0
    }

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local viewW = screenW / camera.zoom
    local viewH = screenH / camera.zoom
    camera.x = player.x + player.width / 2 - viewW / 2
    camera.y = player.y + player.height / 2 - viewH / 2

    groundTiles = {}
    generateGround()
    Trees.load()
    Trees.generate(MAP_WIDTH, MAP_HEIGHT, MAP_WIDTH / 2, MAP_HEIGHT / 2)
    spawnInitialEnemies()

    spawnTimer = 0
    spawnInterval = 3.0

    generateGrassTexture()
    generateCursor()
    loadMusic()

    local ok, shader = pcall(love.graphics.newShader, "shaders/crt.glsl")
    if ok then crtShader = shader end

    gameCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    gameCanvas:setFilter("nearest", "nearest")
end

local GRASS_TILE = 256

function generateGrassTexture()
    grassCanvas = love.graphics.newCanvas(GRASS_TILE, GRASS_TILE)
    love.graphics.setCanvas(grassCanvas)

    love.graphics.setColor(0.22, 0.35, 0.12)
    love.graphics.rectangle("fill", 0, 0, GRASS_TILE, GRASS_TILE)

    for i = 1, 800 do
        local x = love.math.random(0, GRASS_TILE)
        local y = love.math.random(0, GRASS_TILE)
        local r = love.math.random(2, 6)
        local g = 0.3 + love.math.random() * 0.15
        local b = 0.08 + love.math.random() * 0.08
        love.graphics.setColor(0.15 + love.math.random() * 0.12, g, b, 0.6)
        love.graphics.circle("fill", x, y, r)
    end

    for i = 1, 400 do
        local x = love.math.random(0, GRASS_TILE)
        local y = love.math.random(0, GRASS_TILE)
        love.graphics.setColor(0.18, 0.28 + love.math.random() * 0.1, 0.08, 0.3)
        love.graphics.rectangle("fill", x, y, love.math.random(3, 8), love.math.random(1, 3))
    end

    love.graphics.setCanvas()
    grassCanvas:setFilter("nearest", "nearest")
end

function generateCursor()
    local size = 32
    local imgData = love.image.newImageData(size, size)

    imgData:mapPixel(function(x, y, r, g, b, a)
        if x >= 12 and x <= 19 and y >= 2 and y <= 7 then
            return 0.6, 0.5, 0.4, 1
        elseif x >= 13 and x <= 18 and y >= 3 and y <= 6 then
            return 0.8, 0.75, 0.65, 1
        elseif x >= 14 and x <= 17 and y >= 8 and y <= 21 then
            return 0.55, 0.35, 0.2, 1
        elseif x >= 15 and x <= 16 and y >= 9 and y <= 20 then
            return 0.45, 0.28, 0.15, 1
        elseif x >= 8 and x <= 23 and y >= 8 and y <= 10 then
            return 0.8, 0.75, 0.6, 1
        elseif x >= 9 and x <= 22 and y >= 9 and y <= 9 then
            return 0.7, 0.65, 0.5, 1
        else
            return 0, 0, 0, 0
        end
    end)

    local hotspotX, hotspotY = 16, 2
    local ok, cursor = pcall(love.mouse.newCursor, imgData, hotspotX, hotspotY)
    if ok then
        love.mouse.setCursor(cursor)
    else
        love.mouse.setVisible(false)
    end
end

function loadMusic()
    local info = love.filesystem.getInfo("sounds/music.ogg")
    if info then
        bgMusic = love.audio.newSource("sounds/music.ogg", "stream")
        bgMusic:setLooping(true)
        bgMusic:setVolume(0.5)
        bgMusic:play()
    end
end

function generateGround()
    groundTiles = {}
    for i = 1, 200 do
        table.insert(groundTiles, {
            x = math.random(0, MAP_WIDTH),
            y = math.random(0, MAP_HEIGHT),
            size = math.random(30, 80),
            shade = math.random() * 0.06
        })
    end
end

function spawnInitialEnemies()
    for i = 1, MAX_ENEMIES do
        spawnEnemyNearPlayer()
    end
end

function spawnEnemyNearPlayer()
    local angle = math.random() * math.pi * 2
    local dist = 300 + math.random(200)
    local x = player.x + math.cos(angle) * dist
    local y = player.y + math.sin(angle) * dist

    x = math.max(50, math.min(MAP_WIDTH - 50, x))
    y = math.max(50, math.min(MAP_HEIGHT - 50, y))

    local enemyW = 128
    local enemyH = 128
    if Trees.checkCollision(x, y, enemyW, enemyH) then
        return
    end

    local types = {"slime", "goblin", "skeleton"}
    local enemyType = types[math.random(#types)]

    local enemy = Enemy.new(x, y, enemyType)
    enemy:loadAssets()

    local waveBonus = math.floor(score / 100)
    enemy.health = enemy.health + waveBonus * 5
    enemy.maxHealth = enemy.health
    enemy.speed = enemy.speed + waveBonus * 3

    table.insert(enemies, enemy)
end

function updateCamera(dt)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local zoom = camera.zoom

    local viewW = screenW / zoom
    local viewH = screenH / zoom

    local targetX = player.x + player.width / 2 - viewW / 2
    local targetY = player.y + player.height / 2 - viewH / 2

    targetX = math.max(0, math.min(MAP_WIDTH - viewW, targetX))
    targetY = math.max(0, math.min(MAP_HEIGHT - viewH, targetY))

    camera.x = targetX
    camera.y = targetY
end

function GameScene.update(dt)
    if gameOver then
        if love.keyboard.isDown("r") then
            GameScene.enter()
        end
        return
    end

    updateCamera(dt)

    local canMove = not player.isAttacking
    player:update(dt, canMove, Trees.resolveCollision, camera.x, camera.y, camera.zoom)
    player.x = math.max(0, math.min(MAP_WIDTH - player.width, player.x))
    player.y = math.max(0, math.min(MAP_HEIGHT - player.height, player.y))

    for i = #enemies, 1, -1 do
        local shouldRemove = enemies[i]:update(dt, player.x, player.y, Trees.resolveCollision)
        if shouldRemove then
            table.remove(enemies, i)
        else
            local e = enemies[i]
            e.x = math.max(0, math.min(MAP_WIDTH - e.width, e.x))
            e.y = math.max(0, math.min(MAP_HEIGHT - e.height, e.y))
        end
    end

    local hitEnemies = Combat.resolveAttack(player, enemies)
    for _, hit in ipairs(hitEnemies) do
        ui:addDamageNumber(hit.enemy.x, hit.enemy.y, hit.damage, true, hit.isCrit)
        ui:shake(hit.isCrit and 5 or 3, hit.isCrit and 0.12 or 0.08)
        if not hit.enemy.alive then
            score = score + 10
            local goldAmount = math.random(1, 3)
            table.insert(goldItems, Gold.new(hit.enemy.x, hit.enemy.y, goldAmount))
            player:gainXP(1)
            ui:addXPNumber(hit.enemy.x + 30, hit.enemy.y - 20, 1)
            if player.justLeveledUp then
                ui:showLevelUp(player.level)
                player.justLeveledUp = false
            end
        end
    end

    local damage = Combat.checkEnemyAttacks(player, enemies)
    if damage > 0 then
        local finalDamage = math.max(0, damage - player.armor)
        if finalDamage > 0 then
            player:takeDamage(finalDamage)
            player.flashTimer = 0.7
            ui:addDamageNumber(player.x, player.y, finalDamage, false)
            ui:shake(5, 0.15)
            ui:triggerDamageVignette()
        end
    end

    aliveEnemies = 0
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            aliveEnemies = aliveEnemies + 1
        end
    end

    spawnTimer = spawnTimer + dt
    if aliveEnemies < MAX_ENEMIES and spawnTimer >= spawnInterval then
        spawnEnemyNearPlayer()
        spawnTimer = 0
    end

    for i = #goldItems, 1, -1 do
        local gained = goldItems[i]:update(dt, player.x + player.width / 2, player.y + player.height / 2)
        if gained > 0 then
            goldCount = goldCount + gained
        end
        if not goldItems[i].alive then
            table.remove(goldItems, i)
        end
    end

    ui:update(dt, player, love.graphics.getWidth(), love.graphics.getHeight())

    if player:isDead() then
        gameOver = true
    end
end

function GameScene.draw()
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.push()
    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)

    love.graphics.setColor(1, 1, 1)
    if grassCanvas then
        for tx = 0, MAP_WIDTH, GRASS_TILE do
            for ty = 0, MAP_HEIGHT, GRASS_TILE do
                love.graphics.draw(grassCanvas, tx, ty)
            end
        end
    else
        love.graphics.setColor(0.15, 0.2, 0.1)
        love.graphics.rectangle("fill", 0, 0, MAP_WIDTH, MAP_HEIGHT)
    end

    love.graphics.setColor(0.18, 0.25, 0.12)
    love.graphics.rectangle("line", 10, 10, MAP_WIDTH - 20, MAP_HEIGHT - 20)

    local entityY = player.y + player.height / 2
    Trees.drawBelow(entityY)

    player:draw()

    for _, enemy in ipairs(enemies) do
        enemy:draw()
    end

    Trees.drawAbove(entityY)

    for _, gold in ipairs(goldItems) do
        gold:draw()
    end

    love.graphics.pop()

    ui:draw(player, aliveEnemies, score, goldCount, camera)

    if gameOver then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight() / 2 - 40, love.graphics.getWidth(), "center")

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Puntos: " .. score, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("Presiona R para reiniciar", 0, love.graphics.getHeight() / 2 + 40, love.graphics.getWidth(), "center")
    end

    love.graphics.setCanvas()

    if crtShader then
        crtShader:send("time", love.timer.getTime())
        love.graphics.setShader(crtShader)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, 0, 0)
    if crtShader then
        love.graphics.setShader()
    end
end

function GameScene.keypressed(key)
    if key == "escape" then
        if ui:isCharScreenOpen() then
            ui:toggleCharScreen()
        else
            love.event.quit()
        end
        return
    end

    if key == "c" then
        ui:toggleCharScreen()
        return
    end

    if ui:isCharScreenOpen() then
        ui:handleCharInput(key, player)
        return
    end

    if key == "r" and gameOver then
        GameScene.enter()
        return
    end

    if key == "space" then
        if player:attack() then
            local hitEnemies = Combat.resolveAttack(player, enemies)
            for _, hit in ipairs(hitEnemies) do
                ui:addDamageNumber(hit.enemy.x, hit.enemy.y, hit.damage, true, hit.isCrit)
                ui:shake(hit.isCrit and 5 or 3, hit.isCrit and 0.12 or 0.08)
                if not hit.enemy.alive then
                    score = score + 10
                    local goldAmount = math.random(1, 3)
                    table.insert(goldItems, Gold.new(hit.enemy.x, hit.enemy.y, goldAmount))
                    player:gainXP(1)
                    ui:addXPNumber(hit.enemy.x + 30, hit.enemy.y - 20, 1)
                    if player.justLeveledUp then
                        ui:showLevelUp(player.level)
                        player.justLeveledUp = false
                    end
                end
            end
        end
    end
end

function GameScene.keyreleased(key)
end

function GameScene.mousepressed(x, y, button)
    ui:mousepressed(x, y, button)
end

function GameScene.mousereleased(x, y, button)
    ui:mousereleased(x, y, button)
end

return GameScene
