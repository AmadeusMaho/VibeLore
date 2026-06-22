local Enemy = {}
Enemy.__index = Enemy

Enemy.STATES = {
    IDLE = "idle",
    PATROL = "patrol",
    CHASE = "chase",
    ATTACK = "attack"
}

local ENEMY_SPRITE_SIZE = 64
local ENEMY_SCALE = 2
local DETECT_RANGE = 150
local ATTACK_RANGE = 45
local PATROL_DISTANCE = 80
local IDLE_TIME_MIN = 2
local IDLE_TIME_MAX = 4
local CHASE_SPEED_MULT = 1.3
local ENEMY_FPS = 8

local hitSound
local deathSound

function Enemy.new(x, y, enemyType)
    local self = setmetatable({}, Enemy)
    self.x = x
    self.y = y
    self.width = ENEMY_SPRITE_SIZE * ENEMY_SCALE
    self.height = ENEMY_SPRITE_SIZE * ENEMY_SCALE
    self.speed = 40
    self.health = 5
    self.maxHealth = 5
    self.damage = 2
    self.attackRange = ATTACK_RANGE
    self.attackCooldown = 1.2
    self.attackTimer = 0
    self.type = enemyType or "slime"
    self.spriteSheet = nil
    self.frames = {}
    self.currentFrame = 1
    self.animTimer = 0
    self.alive = true
    self.deathTimer = 0
    self.deathDuration = 0.3
    self.flashTimer = 0
    self.knockbackX = 0
    self.knockbackY = 0

    self.state = Enemy.STATES.IDLE
    self.idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX)
    self.patrolTargetX = x
    self.patrolTargetY = y
    self.patrolSpeed = self.speed
    self.spawnX = x
    self.spawnY = y
    return self
end

function Enemy:loadAssets()
    if not hitSound then
        local ok, src = pcall(love.audio.newSource, "sounds/Hit.wav", "static")
        if ok then hitSound = src end
    end
    if not deathSound then
        local ok, src = pcall(love.audio.newSource, "sounds/EnemyDeath.wav", "static")
        if ok then deathSound = src end
    end

    if love.filesystem.getInfo("sprites/slime.png") then
        self.spriteSheet = love.graphics.newImage("sprites/slime.png")
        self.spriteSheet:setFilter("nearest", "nearest")
        local w = self.spriteSheet:getWidth()
        local h = self.spriteSheet:getHeight()
        local cols = math.floor(w / ENEMY_SPRITE_SIZE)
        local rows = math.floor(h / ENEMY_SPRITE_SIZE)
        for i = 0, cols * rows - 1 do
            local col = i % cols
            local row = math.floor(i / cols)
            self.frames[i + 1] = love.graphics.newQuad(
                col * ENEMY_SPRITE_SIZE, row * ENEMY_SPRITE_SIZE,
                ENEMY_SPRITE_SIZE, ENEMY_SPRITE_SIZE,
                w, h
            )
        end
    end
end

function Enemy:update(dt, playerX, playerY)
    if not self.alive then
        self.deathTimer = self.deathTimer + dt
        return self.deathTimer >= self.deathDuration
    end

    self.flashTimer = math.max(0, self.flashTimer - dt)
    self.attackTimer = math.max(0, self.attackTimer - dt)

    self.animTimer = self.animTimer + dt
    if self.animTimer >= 1 / ENEMY_FPS then
        self.animTimer = 0
        if #self.frames > 0 then
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > #self.frames then
                self.currentFrame = 1
            end
        end
    end

    self.knockbackX = self.knockbackX * 0.85
    self.knockbackY = self.knockbackY * 0.85
    self.x = self.x + self.knockbackX * dt * 60
    self.y = self.y + self.knockbackY * dt * 60

    local dx = playerX - self.x
    local dy = playerY - self.y
    local distToPlayer = math.sqrt(dx * dx + dy * dy)

    if self.state == Enemy.STATES.IDLE then
        self.idleTimer = self.idleTimer - dt
        if distToPlayer < DETECT_RANGE then
            self.state = Enemy.STATES.CHASE
        elseif self.idleTimer <= 0 then
            self:startPatrol()
        end

    elseif self.state == Enemy.STATES.PATROL then
        if distToPlayer < DETECT_RANGE then
            self.state = Enemy.STATES.CHASE
            return
        end

        local pdx = self.patrolTargetX - self.x
        local pdy = self.patrolTargetY - self.y
        local patrolDist = math.sqrt(pdx * pdx + pdy * pdy)

        if patrolDist < 5 then
            self.state = Enemy.STATES.IDLE
            self.idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX)
        else
            local nx = pdx / patrolDist
            local ny = pdy / patrolDist
            self.x = self.x + nx * self.patrolSpeed * dt
            self.y = self.y + ny * self.patrolSpeed * dt
        end

    elseif self.state == Enemy.STATES.CHASE then
        if distToPlayer > DETECT_RANGE * 1.8 then
            self.state = Enemy.STATES.IDLE
            self.idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX)
            return
        end

        if distToPlayer <= ATTACK_RANGE then
            self.state = Enemy.STATES.ATTACK
        else
            local nx = dx / distToPlayer
            local ny = dy / distToPlayer
            self.x = self.x + nx * self.speed * CHASE_SPEED_MULT * dt
            self.y = self.y + ny * self.speed * CHASE_SPEED_MULT * dt
        end

    elseif self.state == Enemy.STATES.ATTACK then
        if distToPlayer > ATTACK_RANGE * 1.5 then
            self.state = Enemy.STATES.CHASE
        end
    end

    return false
end

function Enemy:startPatrol()
    self.state = Enemy.STATES.PATROL
    local angle = math.random() * math.pi * 2
    self.patrolTargetX = self.x + math.cos(angle) * PATROL_DISTANCE
    self.patrolTargetY = self.y + math.sin(angle) * PATROL_DISTANCE
    self.patrolTargetX = math.max(50, math.min(1950, self.patrolTargetX))
    self.patrolTargetY = math.max(50, math.min(1950, self.patrolTargetY))
end

function Enemy:takeDamage(amount, knockbackX, knockbackY)
    self.health = self.health - amount
    self.flashTimer = 0.15
    self.knockbackX = knockbackX or 0
    self.knockbackY = knockbackY or 0
    if hitSound then
        hitSound:stop()
        hitSound:play()
    end
    if self.health <= 0 then
        self.alive = false
        self.deathTimer = 0
        if deathSound then
            deathSound:stop()
            deathSound:play()
        end
    end
end

function Enemy:canAttack()
    return self.alive and self.state == Enemy.STATES.ATTACK and self.attackTimer <= 0
end

function Enemy:doAttack()
    self.attackTimer = self.attackCooldown
    return self.damage
end

function Enemy:isFinished()
    return not self.alive and self.deathTimer >= self.deathDuration
end

function Enemy:draw()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    if not self.alive then
        local alpha = 1 - (self.deathTimer / self.deathDuration)
        if self.spriteSheet and self.frames[1] then
            love.graphics.setColor(1, 0.3, 0.3, alpha)
            love.graphics.draw(self.spriteSheet, self.frames[1], cx, cy, 0, ENEMY_SCALE, ENEMY_SCALE, ENEMY_SPRITE_SIZE / 2, ENEMY_SPRITE_SIZE / 2)
        else
            love.graphics.setColor(1, 0.3, 0.3, alpha)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        end
        return
    end

    if self.spriteSheet and self.frames[self.currentFrame] then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.spriteSheet, self.frames[self.currentFrame], cx, cy, 0, ENEMY_SCALE, ENEMY_SCALE, ENEMY_SPRITE_SIZE / 2, ENEMY_SPRITE_SIZE / 2)
    else
        self:drawPlaceholder()
    end

    self:drawHealthBar()
    self:drawStateIndicator()
end

function Enemy:drawPlaceholder()
    if self.type == "slime" then
        love.graphics.setColor(0.3, 0.8, 0.3)
    elseif self.type == "goblin" then
        love.graphics.setColor(0.8, 0.4, 0.2)
    else
        love.graphics.setColor(0.8, 0.2, 0.2)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("fill", self.x + 20, self.y + 20, 5)
    love.graphics.circle("fill", self.x + 38, self.y + 20, 5)
end

function Enemy:drawHealthBar()
    if self.health >= self.maxHealth then return end
    local barWidth = self.width
    local barHeight = 6
    local barX = self.x
    local barY = self.y - 10
    local healthPercent = self.health / self.maxHealth

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
end

function Enemy:drawStateIndicator()
    if self.state == Enemy.STATES.CHASE then
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.print("!", self.x + self.width / 2 - 3, self.y - 18)
    elseif self.state == Enemy.STATES.ATTACK then
        love.graphics.setColor(1, 0.1, 0.1, 0.9)
        love.graphics.print("!!", self.x + self.width / 2 - 6, self.y - 18)
    end
end

return Enemy
