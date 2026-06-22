local Enemy = {}
Enemy.__index = Enemy

Enemy.STATES = {
    IDLE = "idle",
    PATROL = "patrol",
    CHASE = "chase",
    ATTACK = "attack",
    CHARGE = "charge",
    CHARGE_ATTACK = "charge_attack"
}

local ENEMY_SPRITE_SIZE = 64
local ENEMY_SCALE = 2
local DETECT_RANGE = 150
local ATTACK_RANGE = 45
local CHARGE_RANGE = 250
local CHARGE_CAST_TIME = 1.0
local CHARGE_CD = 10
local CHARGE_SPEED_MULT = 7
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
    self.width = 40
    self.height = 40
    self.speed = 40
    self.health = math.random(8, 10)
    self.maxHealth = self.health
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
    self.chargeCD = math.random(0, 3)
    self.chargeTimer = 0
    self.chargeTargetX = 0
    self.chargeTargetY = 0
    self.isCharging = false
    self.attackSpriteSheet = nil
    self.attackFrames = {}
    self.damageSpriteSheet = nil
    self.damageFrames = {}
    self.damageAnimTimer = 0
    self.isDamageAnim = false
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
        self:loadFrames(self.spriteSheet, self.frames)
    end
    if love.filesystem.getInfo("sprites/slimeattack.png") then
        self.attackSpriteSheet = love.graphics.newImage("sprites/slimeattack.png")
        self.attackSpriteSheet:setFilter("nearest", "nearest")
        self:loadFrames(self.attackSpriteSheet, self.attackFrames)
    end
    if love.filesystem.getInfo("sprites/slimedamage.png") then
        self.damageSpriteSheet = love.graphics.newImage("sprites/slimedamage.png")
        self.damageSpriteSheet:setFilter("nearest", "nearest")
        self:loadFrames(self.damageSpriteSheet, self.damageFrames)
    end
end

function Enemy:loadFrames(sheet, frames)
    local w = sheet:getWidth()
    local h = sheet:getHeight()
    local cols = math.floor(w / ENEMY_SPRITE_SIZE)
    local rows = math.floor(h / ENEMY_SPRITE_SIZE)
    for i = 0, cols * rows - 1 do
        local col = i % cols
        local row = math.floor(i / cols)
        frames[i + 1] = love.graphics.newQuad(
            col * ENEMY_SPRITE_SIZE, row * ENEMY_SPRITE_SIZE,
            ENEMY_SPRITE_SIZE, ENEMY_SPRITE_SIZE,
            w, h
        )
    end
end

function Enemy:update(dt, playerX, playerY, resolveFunc)
    if not self.alive then
        self.deathTimer = self.deathTimer + dt
        return self.deathTimer >= self.deathDuration
    end

    self.flashTimer = math.max(0, self.flashTimer - dt)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.chargeCD = math.max(0, self.chargeCD - dt)

    if self.isDamageAnim then
        self.damageAnimTimer = self.damageAnimTimer - dt
        if self.damageAnimTimer <= 0 then
            self.isDamageAnim = false
            self.currentFrame = 1
        end
    end

    self.animTimer = self.animTimer + dt
    if self.animTimer >= 1 / ENEMY_FPS then
        self.animTimer = 0
        local activeFrames = self.frames
        if self.isDamageAnim and #self.damageFrames > 0 then
            activeFrames = self.damageFrames
        elseif self.state == Enemy.STATES.CHARGE_ATTACK and #self.attackFrames > 0 then
            activeFrames = self.attackFrames
        end
        if #activeFrames > 0 then
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > #activeFrames then
                if self.isDamageAnim then
                    self.isDamageAnim = false
                    self.currentFrame = 1
                else
                    self.currentFrame = 1
                end
            end
        end
    end

    self.knockbackX = self.knockbackX * 0.85
    self.knockbackY = self.knockbackY * 0.85
    local kbNewX = self.x + self.knockbackX * dt * 60
    local kbNewY = self.y + self.knockbackY * dt * 60
    if resolveFunc then
        self.x, self.y = resolveFunc(kbNewX, kbNewY, self.width, self.height)
    else
        self.x, self.y = kbNewX, kbNewY
    end

    local dx = playerX - self.x
    local dy = playerY - self.y
    local distToPlayer = math.sqrt(dx * dx + dy * dy)

    if self.state == Enemy.STATES.IDLE then
        self.idleTimer = self.idleTimer - dt
        if distToPlayer < DETECT_RANGE then
            if self.chargeCD <= 0 and distToPlayer < CHARGE_RANGE and distToPlayer > ATTACK_RANGE * 2 then
                self.state = Enemy.STATES.CHARGE
                self.chargeTimer = CHARGE_CAST_TIME
                self.isCharging = true
            else
                self.state = Enemy.STATES.CHASE
            end
        elseif self.idleTimer <= 0 then
            self:startPatrol()
        end

    elseif self.state == Enemy.STATES.PATROL then
        if distToPlayer < DETECT_RANGE then
            if self.chargeCD <= 0 and distToPlayer < CHARGE_RANGE and distToPlayer > ATTACK_RANGE * 2 then
                self.state = Enemy.STATES.CHARGE
                self.chargeTimer = CHARGE_CAST_TIME
                self.isCharging = true
            else
                self.state = Enemy.STATES.CHASE
            end
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
            local patNewX = self.x + nx * self.patrolSpeed * dt
            local patNewY = self.y + ny * self.patrolSpeed * dt
            if resolveFunc then
                self.x, self.y = resolveFunc(patNewX, patNewY, self.width, self.height)
            else
                self.x, self.y = patNewX, patNewY
            end
        end

    elseif self.state == Enemy.STATES.CHASE then
        if distToPlayer > DETECT_RANGE * 1.8 then
            self.state = Enemy.STATES.IDLE
            self.idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX)
            return
        end

        if self.chargeCD <= 0 and distToPlayer < CHARGE_RANGE and distToPlayer > ATTACK_RANGE * 2 then
            self.state = Enemy.STATES.CHARGE
            self.chargeTimer = CHARGE_CAST_TIME
            self.isCharging = true
            return
        end

        if distToPlayer <= ATTACK_RANGE then
            self.state = Enemy.STATES.ATTACK
        else
            local nx = dx / distToPlayer
            local ny = dy / distToPlayer
            local chNewX = self.x + nx * self.speed * CHASE_SPEED_MULT * dt
            local chNewY = self.y + ny * self.speed * CHASE_SPEED_MULT * dt
            if resolveFunc then
                self.x, self.y = resolveFunc(chNewX, chNewY, self.width, self.height)
            else
                self.x, self.y = chNewX, chNewY
            end
        end

    elseif self.state == Enemy.STATES.CHARGE then
        self.chargeTimer = self.chargeTimer - dt
        if self.chargeTimer <= 0 then
            self.state = Enemy.STATES.CHARGE_ATTACK
            self.chargeTargetX = playerX
            self.chargeTargetY = playerY
            self.chargeCD = CHARGE_CD
        end

    elseif self.state == Enemy.STATES.CHARGE_ATTACK then
        local cdx = self.chargeTargetX - self.x
        local cdy = self.chargeTargetY - self.y
        local cdist = math.sqrt(cdx * cdx + cdy * cdy)

        if cdist < 10 then
            self.isCharging = false
            self.state = Enemy.STATES.CHASE
        else
            local nx = cdx / cdist
            local ny = cdy / cdist
            local caNewX = self.x + nx * self.speed * CHARGE_SPEED_MULT * dt
            local caNewY = self.y + ny * self.speed * CHARGE_SPEED_MULT * dt
            if resolveFunc then
                self.x, self.y = resolveFunc(caNewX, caNewY, self.width, self.height)
            else
                self.x, self.y = caNewX, caNewY
            end
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
    if #self.damageFrames > 0 then
        self.isDamageAnim = true
        self.damageAnimTimer = 0.3
        self.currentFrame = 1
    end
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
        local sheet = self.spriteSheet
        local frames = self.frames
        if self.isDamageAnim and self.damageSpriteSheet and #self.damageFrames > 0 then
            sheet = self.damageSpriteSheet
            frames = self.damageFrames
        elseif self.state == Enemy.STATES.CHARGE_ATTACK and self.attackSpriteSheet and #self.attackFrames > 0 then
            sheet = self.attackSpriteSheet
            frames = self.attackFrames
        end
        if frames[self.currentFrame] then
            love.graphics.draw(sheet, frames[self.currentFrame], cx, cy, 0, ENEMY_SCALE, ENEMY_SCALE, ENEMY_SPRITE_SIZE / 2, ENEMY_SPRITE_SIZE / 2)
        else
            love.graphics.draw(self.spriteSheet, self.frames[1], cx, cy, 0, ENEMY_SCALE, ENEMY_SCALE, ENEMY_SPRITE_SIZE / 2, ENEMY_SPRITE_SIZE / 2)
        end
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
    local cx = self.x + self.width / 2
    local cy = self.y - 20

    if self.state == Enemy.STATES.CHASE then
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.print("!", cx - 3, cy)
    elseif self.state == Enemy.STATES.ATTACK then
        love.graphics.setColor(1, 0.1, 0.1, 0.9)
        love.graphics.print("!!", cx - 6, cy)
    elseif self.state == Enemy.STATES.CHARGE then
        local chargePct = 1 - (self.chargeTimer / CHARGE_CAST_TIME)
        love.graphics.setColor(1, 0.5, 0, 0.9)
        love.graphics.rectangle("fill", cx - 15, cy - 4, 30 * chargePct, 4, 2, 2)
        love.graphics.setColor(1, 0.2, 0, 0.7)
        love.graphics.rectangle("line", cx - 15, cy - 4, 30, 4, 2, 2)
        love.graphics.setColor(1, 0.8, 0, 0.9)
        love.graphics.print("!!", cx - 6, cy - 16)
    elseif self.state == Enemy.STATES.CHARGE_ATTACK then
        love.graphics.setColor(1, 0.2, 0, 0.9)
        love.graphics.print(">>>", cx - 10, cy - 16)
    end
end

return Enemy
