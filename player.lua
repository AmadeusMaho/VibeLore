local Player = {}
Player.__index = Player

local SPRITE_SIZE = 192
local WALK_FPS = 10
local ATTACK_FPS = 10

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.x = x or 400
    self.y = y or 300
    self.width = 192
    self.height = 192
    self.speed = 150
    self.health = 100
    self.maxHealth = 100
    self.attackDamage = 2
    self.attackRange = 120
    self.attackCooldown = 0.5
    self.critChance = 0.02
    self.critMultiplier = 2
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
    return self
end

function Player:loadAssets()
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

function Player:update(dt, canMove)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self:updateAttackAngle()

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

    self.x = self.x + dx * self.speed * sprintMult * dt
    self.y = self.y + dy * self.speed * sprintMult * dt

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

function Player:updateAttackAngle()
    local mx, my = love.mouse.getPosition()
    local cx = love.graphics.getWidth() / 2
    local cy = love.graphics.getHeight() / 2
    self.attackAngle = math.atan2(my - cy, mx - cx)
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

function Player:getAttackHitbox()
    if not self.isAttacking then return nil end
    local mx, my = self:getAttackMarkerPos()
    return {x = mx - 40, y = my - 40, width = 80, height = 80}
end

function Player:getAttackMarkerPos()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2
    return cx + math.cos(self.attackAngle) * self.attackRange,
           cy + math.sin(self.attackAngle) * self.attackRange
end

function Player:takeDamage(amount)
    self.health = math.max(0, self.health - amount)
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
        love.graphics.setColor(1, 1, 1)
        local scaleX = 1
        if self.facing == "left" then
            scaleX = -1
        end
        love.graphics.draw(sheet, frames[self.currentFrame], cx, cy, 0, scaleX, 1, SPRITE_SIZE / 2, SPRITE_SIZE / 2)
    else
        self:drawPlaceholder(cx, cy)
    end

    self:drawAttackMarker()
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
    love.graphics.setColor(1, 0.3, 0.3, 0.7)
    love.graphics.circle("line", mx, my, 25)
    love.graphics.setColor(1, 0.3, 0.3, 0.3)
    love.graphics.circle("fill", mx, my, 25)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(mx - 8, my, mx + 8, my)
    love.graphics.line(mx, my - 8, mx, my + 8)
    love.graphics.setLineWidth(1)
end

return Player
