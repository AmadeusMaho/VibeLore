local Player = {}
Player.__index = Player

local Inventory = require("inventory")

local SPRITE_SIZE = 192
local WALK_FPS = 10
local ATTACK_FPS = 10
local playerHitSound

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.x = x or 400
    self.y = y or 300
    self.width = 40
    self.height = 40
    self.speed = 150
    self.health = 100
    self.maxHealth = 100
    self.attackDamage = 2
    self.attackRange = 120
    self.attackCooldown = 0.5
    self.critChance = 0.02
    self.critMultiplier = 1.5
    self.armor = 0
    self.level = 1
    self.xp = 0
    self.xpToNext = 5
    self.statPoints = 0
    self.strength = 0
    self.agility = 0
    self.intelligence = 0
    self.constitution = 0
    self.mana = 0
    self.maxMana = 0
    self.magicDamage = 0
    self.attackTimer = 0
    self.isAttacking = false
    self.attackDuration = 0.4
    self.attackAnimTimer = 0
    self.facing = "down"
    self.attackAngle = 0
    self.walkSheet = nil
    self.attackSheet = nil
    self.walkFrames = {}
    self.attackFrames = {}
    self.currentFrame = 1
    self.animTimer = 0
    self.state = "idle"
    self.isMoving = false
    self.hitEnemiesThisSwing = {}
    self.justLeveledUp = false
    self.flashTimer = 0
    self.isCharging = false
    self.chargeTime = 0
    self.maxChargeTime = 1.0
    self.chargeDamageMultiplier = 3.0
    self.mouseHeld = false
    self.isDashing = false
    self.dashSpeed = 500
    self.dashDuration = 0.15
    self.dashTimer = 0
    self.dashCooldown = 0.5
    self.dashCooldownTimer = 0
    self.dashDirection = {x = 0, y = 0}
    self.invincible = false
    return self
end

function Player:loadAssets()
    if not playerHitSound then
        local ok, src = pcall(love.audio.newSource, "sounds/HitPlayer.wav", "static")
        if ok then playerHitSound = src end
    end

    local walkPath = "sprites/player_walk.png"
    local attackPath = "sprites/player_attack.png"

    if love.filesystem.getInfo(walkPath) then
        self.walkSheet = love.graphics.newImage(walkPath)
        self.walkSheet:setFilter("nearest", "nearest")
        self:generateFrames(self.walkSheet, self.walkFrames)
    end

    if love.filesystem.getInfo(attackPath) then
        self.attackSheet = love.graphics.newImage(attackPath)
        self.attackSheet:setFilter("nearest", "nearest")
        self:generateFrames(self.attackSheet, self.attackFrames)
    end
end

function Player:generateFrames(sheet, frames)
    local w = sheet:getWidth()
    local h = sheet:getHeight()
    local count = math.floor(w / SPRITE_SIZE)
    for i = 0, count - 1 do
        frames[i + 1] = love.graphics.newQuad(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE, w, h)
    end
end

function Player:update(dt, canMove, resolveFunc, cameraX, cameraY, zoom)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.flashTimer = math.max(0, self.flashTimer - dt)
    self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - dt)
    self:updateAttackAngle(cameraX or 0, cameraY or 0, zoom or 1)

    if self.isDashing then
        self.dashTimer = self.dashTimer - dt
        local newX = self.x + self.dashDirection.x * self.dashSpeed * dt
        local newY = self.y + self.dashDirection.y * self.dashSpeed * dt
        if resolveFunc then
            self.x, self.y = resolveFunc(newX, newY, self.width, self.height)
        else
            self.x, self.y = newX, newY
        end
        if self.dashTimer <= 0 then
            self.isDashing = false
            self.invincible = false
        end
        return
    end

    if self.isAttacking then
        self.attackAnimTimer = self.attackAnimTimer - dt
        self.animTimer = self.animTimer + dt
        if self.animTimer >= 1 / ATTACK_FPS then
            self.animTimer = 0
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > #self.attackFrames then
                self.currentFrame = 1
                self.isAttacking = false
                self.state = "idle"
            end
        end
        return
    end

    if self.isCharging then
        self.chargeTime = math.min(self.maxChargeTime, self.chargeTime + dt)
        self.state = "idle"
        self.currentFrame = 1
        self.animTimer = 0
        self.isMoving = false
        return
    end

    if not canMove then return end

    local dx, dy = 0, 0
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        dy = -1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        dy = 1
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        dx = -1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        dx = 1
    end

    self.isMoving = (dx ~= 0 or dy ~= 0)

    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707
        dy = dy * 0.707
    end

    local sprintMult = 1.0
    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        sprintMult = 1.4
    end

    local newX = self.x + dx * self.speed * sprintMult * dt
    local newY = self.y + dy * self.speed * sprintMult * dt
    if resolveFunc then
        self.x, self.y = resolveFunc(newX, newY, self.width, self.height)
    else
        self.x, self.y = newX, newY
    end

    if self.isMoving then
        if math.abs(dx) > math.abs(dy) then
            self.facing = dx > 0 and "right" or "left"
        else
            self.facing = dy > 0 and "down" or "up"
        end
        self.state = "walk"
        self.animTimer = self.animTimer + dt
        if self.animTimer >= 1 / WALK_FPS then
            self.animTimer = 0
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > #self.walkFrames then
                self.currentFrame = 1
            end
        end
    else
        self.state = "idle"
        self.currentFrame = 1
        self.animTimer = 0
    end
end

function Player:updateAttackAngle(cameraX, cameraY, zoom)
    local mx, my = love.mouse.getPosition()
    local zoom = zoom or 1
    local playerScreenX = (self.x + self.width / 2 - cameraX) * zoom
    local playerScreenY = (self.y + self.height / 2 - cameraY) * zoom
    self.attackAngle = math.atan2(my - playerScreenY, mx - playerScreenX)
    local dx = mx - playerScreenX
    local dy = my - playerScreenY
    self.attackDist = math.min(self.attackRange, math.sqrt(dx * dx + dy * dy) / zoom)
end

function Player:attack()
    if self.attackTimer > 0 or self.isAttacking then return false end
    self.isAttacking = true
    self.attackTimer = self.attackCooldown
    self.attackAnimTimer = self.attackDuration
    self.currentFrame = 1
    self.animTimer = 0
    self.state = "attack"
    self.hitEnemiesThisSwing = {}
    return true
end

function Player:startCharge()
    if self.attackTimer > 0 or self.isAttacking or self.isCharging then return end
    self.isCharging = true
    self.chargeTime = 0
    self.state = "idle"
end

function Player:releaseCharge()
    if not self.isCharging then return 0 end
    local chargeRatio = math.min(1, self.chargeTime / self.maxChargeTime)
    local damageMultiplier = 1 + (self.chargeDamageMultiplier - 1) * chargeRatio
    local totalDamage = math.floor(self.attackDamage * damageMultiplier)
    self.isCharging = false
    self.chargeTime = 0
    self:attack()
    return totalDamage
end

function Player:getChargeRatio()
    if not self.isCharging then return 0 end
    return math.min(1, self.chargeTime / self.maxChargeTime)
end

function Player:startDash()
    if self.isDashing or self.dashCooldownTimer > 0 or self.isAttacking then return false end
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        dy = -1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        dy = 1
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        dx = -1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        dx = 1
    end
    if dx == 0 and dy == 0 then
        dx = math.cos(self.attackAngle)
        dy = math.sin(self.attackAngle)
    else
        local len = math.sqrt(dx * dx + dy * dy)
        dx = dx / len
        dy = dy / len
    end
    self.isDashing = true
    self.dashTimer = self.dashDuration
    self.dashCooldownTimer = self.dashCooldown
    self.dashDirection = {x = dx, y = dy}
    self.invincible = true
    self.isCharging = false
    self.chargeTime = 0
    return true
end

function Player:getAttackHitbox()
    if not self.isAttacking then return nil end
    local mx, my = self:getAttackMarkerPos()
    return {x = mx - 40, y = my - 40, width = 80, height = 80}
end

function Player:getAttackMarkerPos()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2
    local dist = self.attackDist or self.attackRange
    return cx + math.cos(self.attackAngle) * dist,
           cy + math.sin(self.attackAngle) * dist
end

function Player:takeDamage(amount)
    if self.invincible then return end
    self.health = math.max(0, self.health - amount)
    if playerHitSound then
        playerHitSound:stop()
        playerHitSound:play()
    end
end

function Player:gainXP(amount)
    self.xp = self.xp + amount
    self.justLeveledUp = false
    while self.xp >= self.xpToNext do
        self.xp = self.xp - self.xpToNext
        self.level = self.level + 1
        self.xpToNext = 5 * self.level
        self.statPoints = self.statPoints + 3
        self.justLeveledUp = true
    end
    self:recalcStats()
end

function Player:recalcStats()
    self.attackDamage = 2 + self.level - 1 + math.floor(self.strength * 0.5) + Inventory.getStatBonus("damage")
    self.speed = 150 * (1 + self.agility * 0.001)
    self.maxHealth = 100 + (self.level - 1) * 10 + self.constitution * 10 + Inventory.getStatBonus("hp")
    self.maxMana = self.intelligence * 1
    self.magicDamage = self.intelligence
    self.armor = (self.level - 1) + math.floor(self.strength * 0.5) + Inventory.getStatBonus("armor")
    if self.health > self.maxHealth then self.health = self.maxHealth end
    if self.mana > self.maxMana then self.mana = self.maxMana end
end

function Player:allocateStat(stat)
    if self.statPoints <= 0 then return false end
    if stat == "str" then
        self.strength = self.strength + 1
    elseif stat == "agi" then
        self.agility = self.agility + 1
    elseif stat == "int" then
        self.intelligence = self.intelligence + 1
    elseif stat == "con" then
        self.constitution = self.constitution + 1
    end
    self.statPoints = self.statPoints - 1
    self:recalcStats()
    return true
end

function Player:isDead()
    return self.health <= 0
end

function Player:draw()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    local sheet = nil
    local frames = nil

    if self.state == "attack" and self.attackSheet then
        sheet = self.attackSheet
        frames = self.attackFrames
    elseif self.walkSheet then
        sheet = self.walkSheet
        frames = self.walkFrames
    end

    if sheet and frames and frames[self.currentFrame] then
        if self.flashTimer > 0 then
            love.graphics.setColor(1, 0.3, 0.3)
        elseif self.isDashing then
            love.graphics.setColor(0.5, 0.8, 1, 0.7)
        elseif self.isCharging then
            local ratio = self:getChargeRatio()
            love.graphics.setColor(1, 1 - ratio * 0.5, 1 - ratio)
        else
            love.graphics.setColor(1, 1, 1)
        end
        local scaleX = 1
        if self.facing == "left" then
            scaleX = -1
        end
        love.graphics.draw(sheet, frames[self.currentFrame], cx, cy, 0, scaleX, 1, SPRITE_SIZE / 2, SPRITE_SIZE / 2)
    else
        self:drawPlaceholder(cx, cy)
    end

    self:drawAttackMarker()
    self:drawChargeIndicator()
end

function Player:drawPlaceholder(cx, cy)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.setColor(0.2, 0.5, 1)
    love.graphics.rectangle("fill", -self.width / 2, -self.height / 2, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
    local ox, oy = 0, 0
    if self.facing == "down" then oy = 20
    elseif self.facing == "up" then oy = -20
    elseif self.facing == "left" then ox = -20
    elseif self.facing == "right" then ox = 20 end
    love.graphics.circle("fill", ox, oy, 8)
    love.graphics.pop()
end

function Player:drawAttackMarker()
    if self.state ~= "attack" then return end
    local mx, my = self:getAttackMarkerPos()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    love.graphics.setColor(1, 0.3, 0.3, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx, cy, mx, my)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 0.3, 0.3, 0.7)
    love.graphics.circle("line", mx, my, 20)
    love.graphics.setColor(1, 0.3, 0.3, 0.3)
    love.graphics.circle("fill", mx, my, 20)

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(mx - 6, my, mx + 6, my)
    love.graphics.line(mx, my - 6, mx, my + 6)
    love.graphics.setLineWidth(1)
end

function Player:drawChargeIndicator()
    if not self.isCharging then return end
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2
    local ratio = self:getChargeRatio()

    local barW = 40
    local barH = 5
    local barX = cx - barW / 2
    local barY = cy - self.height / 2 - 12

    love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barW + 2, barH + 2, 2, 2)

    love.graphics.setColor(0.8, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", barX, barY, barW * ratio, barH, 2, 2)

    love.graphics.setColor(1, 0.3, 0.3, 0.8)
    love.graphics.rectangle("line", barX, barY, barW, barH, 2, 2)

    local dirLen = 20 + ratio * 15
    local dirX = cx + math.cos(self.attackAngle) * (self.width / 2 + 5)
    local dirY = cy + math.sin(self.attackAngle) * (self.height / 2 + 5)
    local endX = dirX + math.cos(self.attackAngle) * dirLen
    local endY = dirY + math.sin(self.attackAngle) * dirLen

    love.graphics.setColor(1, 0.2, 0.2, 0.6 + ratio * 0.4)
    love.graphics.setLineWidth(2 + ratio * 2)
    love.graphics.line(dirX, dirY, endX, endY)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 0.2, 0.2, 0.3 + ratio * 0.3)
    love.graphics.circle("fill", endX, endY, 4 + ratio * 4)
end

return Player
