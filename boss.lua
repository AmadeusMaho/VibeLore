local Boss = {}
Boss.__index = Boss

Boss.STATES = {
    IDLE = "idle",
    CHASE = "chase",
    ATTACK = "attack",
    CAST_AOE = "cast_aoe",
    AOE_ATTACK = "aoe_attack"
}

local BOSS_SPRITE_SIZE = 64
local BOSS_SCALE = 2.5
local DETECT_RANGE = 400
local ATTACK_RANGE = 55
local AOE_RANGE = 120
local AOE_CAST_TIME = 2.0
local AOE_CD = 15
local CHASE_SPEED_MULT = 1.3
local BOSS_FPS = 6

function Boss.new(x, y)
    local self = setmetatable({}, Boss)
    self.x = x
    self.y = y
    self.width = 50
    self.height = 50
    self.speed = 40
    self.health = 200
    self.maxHealth = 200
    self.damage = 10
    self.attackRange = ATTACK_RANGE
    self.attackCooldown = 1.5
    self.attackTimer = 0
    self.type = "boss_slime"
    self.alive = true
    self.deathTimer = 0
    self.deathDuration = 1.0
    self.flashTimer = 0
    self.knockbackX = 0
    self.knockbackY = 0
    self.state = Boss.STATES.IDLE
    self.idleTimer = 0.5
    self.aoeCD = 3
    self.aoeTimer = 0
    self.aoeTargetX = 0
    self.aoeTargetY = 0
    self.aoeIndicator = { active = false, x = 0, y = 0, radius = AOE_RANGE, timer = 0 }
    self.spawnX = x
    self.spawnY = y
    self.animTimer = 0
    self.currentFrame = 1
    self.bounceTimer = 0
    self.introTimer = 2.0
    self.introActive = true
    self.screenFlash = 1.0
    self._killCounted = false

    self.idleFrames = {}
    self.moveFrames = {}
    self.attackFrames = {}

    self.activeFrames = self.idleFrames
    self.facing = 1

    return self
end

function Boss:loadAssets()
    local function loadSingle(path)
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            img:setFilter("nearest", "nearest")
            return img
        end
        return nil
    end

    for i = 1, 4 do
        local img = loadSingle("sprites/slimeboss/KingSlime_Idle" .. i .. ".png")
        if img then
            self.idleFrames[#self.idleFrames + 1] = img
        end
    end

    for i = 1, 3 do
        local img = loadSingle("sprites/slimeboss/KingSlime_Moving" .. i .. ".png")
        if img then
            self.moveFrames[#self.moveFrames + 1] = img
        end
    end

    for i = 1, 5 do
        local img = loadSingle("sprites/slimeboss/KingSlimeAttack" .. i .. ".png")
        if img then
            self.attackFrames[#self.attackFrames + 1] = img
        end
    end

    if #self.idleFrames > 0 then
        self.activeFrames = self.idleFrames
    end
end

function Boss:update(dt, playerX, playerY, resolveFunc)
    self.bounceTimer = self.bounceTimer + dt

    if self.introActive then
        self.introTimer = self.introTimer - dt
        self.screenFlash = math.max(0, self.screenFlash - dt * 0.8)
        if self.introTimer <= 0 then
            self.introActive = false
            self.screenFlash = 0
        end
        return false
    end

    if not self.alive then
        self.deathTimer = self.deathTimer + dt
        return self.deathTimer >= self.deathDuration
    end

    self.flashTimer = math.max(0, self.flashTimer - dt)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.aoeCD = math.max(0, self.aoeCD - dt)

    self.animTimer = self.animTimer + dt
    if self.animTimer >= 1 / BOSS_FPS then
        self.animTimer = 0
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.activeFrames then
            self.currentFrame = 1
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

    local dx = playerX - (self.x + self.width / 2)
    local dy = playerY - (self.y + self.height / 2)
    local distToPlayer = math.sqrt(dx * dx + dy * dy)

    if dx < 0 then self.facing = -1 else self.facing = 1 end

    if self.state == Boss.STATES.CAST_AOE then
        self.activeFrames = self.idleFrames
        self.aoeTimer = self.aoeTimer - dt
        self.aoeIndicator.timer = AOE_CAST_TIME - self.aoeTimer
        self.aoeIndicator.x = playerX
        self.aoeIndicator.y = playerY
        if self.aoeTimer <= 0 then
            self.state = Boss.STATES.AOE_ATTACK
            self.aoeTargetX = playerX
            self.aoeTargetY = playerY
            self.aoeIndicator.active = true
        end
        return false
    end

    if self.state == Boss.STATES.AOE_ATTACK then
        self.aoeIndicator.active = false
        self.aoeCD = AOE_CD
        self.state = Boss.STATES.CHASE
        return true, { type = "aoe", x = self.aoeTargetX, y = self.aoeTargetY, radius = AOE_RANGE, damage = self.damage * 1.5 }
    end

    if self.state == Boss.STATES.IDLE then
        self.activeFrames = #self.idleFrames > 0 and self.idleFrames or {}
        self.idleTimer = self.idleTimer - dt
        if distToPlayer < DETECT_RANGE then
            if self.aoeCD <= 0 and distToPlayer > ATTACK_RANGE then
                self.state = Boss.STATES.CAST_AOE
                self.aoeTimer = AOE_CAST_TIME
                self.aoeIndicator = { active = true, x = playerX, y = playerY, radius = AOE_RANGE, timer = 0 }
            else
                self.state = Boss.STATES.CHASE
            end
        elseif self.idleTimer <= 0 then
            self.state = Boss.STATES.CHASE
        end

    elseif self.state == Boss.STATES.CHASE then
        self.activeFrames = #self.moveFrames > 0 and self.moveFrames or self.idleFrames

        if distToPlayer > DETECT_RANGE * 2 then
            self.state = Boss.STATES.IDLE
            self.idleTimer = 1
            return false
        end

        if self.aoeCD <= 0 and distToPlayer > ATTACK_RANGE and distToPlayer < AOE_RANGE * 2 then
            self.state = Boss.STATES.CAST_AOE
            self.aoeTimer = AOE_CAST_TIME
            self.aoeIndicator = { active = true, x = playerX, y = playerY, radius = AOE_RANGE, timer = 0 }
            return false
        end

        if distToPlayer <= ATTACK_RANGE then
            self.state = Boss.STATES.ATTACK
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

    elseif self.state == Boss.STATES.ATTACK then
        self.activeFrames = #self.attackFrames > 0 and self.attackFrames or self.idleFrames
        if distToPlayer > ATTACK_RANGE * 1.5 then
            self.state = Boss.STATES.CHASE
        end
    end

    return false
end

function Boss:takeDamage(amount, knockbackX, knockbackY)
    if self.introActive then return end
    self.health = self.health - amount
    self.flashTimer = 0.15
    self.knockbackX = knockbackX or 0
    self.knockbackY = knockbackY or 0
    if self.health <= 0 then
        self.alive = false
        self.deathTimer = 0
    end
end

function Boss:canAttack()
    return self.alive and not self.introActive and self.state == Boss.STATES.ATTACK and self.attackTimer <= 0
end

function Boss:doAttack()
    self.attackTimer = self.attackCooldown
    return self.damage
end

function Boss:isFinished()
    return not self.alive and self.deathTimer >= self.deathDuration
end

function Boss:getIntroProgress()
    if not self.introActive then return 1 end
    return 1 - (self.introTimer / 2.0)
end

function Boss:getAOECastProgress()
    if self.state ~= Boss.STATES.CAST_AOE then return 0 end
    return 1 - (self.aoeTimer / AOE_CAST_TIME)
end

function Boss:draw()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    if not self.alive then
        local alpha = 1 - (self.deathTimer / self.deathDuration)
        if #self.idleFrames > 0 then
            love.graphics.setColor(1, 0.3, 0.3, alpha)
            love.graphics.draw(self.idleFrames[1], cx, cy, 0, self.facing * BOSS_SCALE, BOSS_SCALE, BOSS_SPRITE_SIZE / 2, BOSS_SPRITE_SIZE / 2)
        else
            love.graphics.setColor(0.2, 0.6, 0.2, alpha)
            love.graphics.ellipse("fill", cx, cy + 8, self.width / 2 + 10, self.height / 2 - 5)
        end
        return
    end

    local frame = nil
    if #self.activeFrames > 0 then
        local idx = self.currentFrame
        if idx < 1 then idx = 1 end
        if idx > #self.activeFrames then idx = #self.activeFrames end
        frame = self.activeFrames[idx]
    end

    if frame then
        if self.flashTimer > 0 then
            love.graphics.setColor(1, 0.4, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.draw(frame, cx, cy, 0, self.facing * BOSS_SCALE, BOSS_SCALE, BOSS_SPRITE_SIZE / 2, BOSS_SPRITE_SIZE / 2)
    else
        self:drawFallback(cx, cy)
    end
end

function Boss:drawFallback(cx, cy)
    local bounce = 0
    if self.state == Boss.STATES.CHASE then
        bounce = math.sin(self.bounceTimer * 8) * 5
    end

    if self.flashTimer > 0 then
        love.graphics.setColor(1, 0.4, 0.4)
    else
        love.graphics.setColor(0.2, 0.7, 0.2)
    end
    love.graphics.ellipse("fill", cx, cy + 10 + bounce, self.width / 2 + 12, self.height / 2 - 2)

    love.graphics.setColor(0.15, 0.55, 0.15)
    love.graphics.ellipse("fill", cx, cy + 18 + bounce, self.width / 2 + 5, 12)

    love.graphics.setColor(1, 1, 1)
    love.graphics.ellipse("fill", cx - 14, cy - 4 + bounce, 11, 13)
    love.graphics.ellipse("fill", cx + 14, cy - 4 + bounce, 11, 13)

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.ellipse("fill", cx - 14, cy - 2 + bounce, 7, 9)
    love.graphics.ellipse("fill", cx + 14, cy - 2 + bounce, 7, 9)

    love.graphics.setColor(0.9, 0.75, 0.1)
    love.graphics.polygon("fill",
        cx - 20, cy - 18 + bounce,
        cx - 12, cy - 36 + bounce,
        cx, cy - 26 + bounce,
        cx + 12, cy - 36 + bounce,
        cx + 20, cy - 18 + bounce
    )
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.circle("fill", cx, cy - 30 + bounce, 4)
end

function Boss:drawHealthBar()
    if not self.alive then return end

    local barWidth = 400
    local barHeight = 18
    local barX = love.graphics.getWidth() / 2 - barWidth / 2
    local barY = 50
    local healthPercent = math.max(0, self.health / self.maxHealth)

    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", barX - 3, barY - 22, barWidth + 6, barHeight + 30, 4, 4)

    local font = love.graphics.newFont(14)
    love.graphics.setFont(font)
    love.graphics.setColor(0.9, 0.3, 0.2)
    love.graphics.printf("REY SLIME", barX, barY - 18, barWidth, "center")

    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)

    love.graphics.setColor(0.85, 0.15, 0.15)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight, 3, 3)

    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight / 2, 3, 3)

    if self.state == Boss.STATES.CAST_AOE then
        local castBarWidth = 200
        local castBarHeight = 8
        local castBarX = love.graphics.getWidth() / 2 - castBarWidth / 2
        local castBarY = barY + barHeight + 6
        local castProgress = self:getAOECastProgress()

        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", castBarX, castBarY, castBarWidth, castBarHeight, 2, 2)
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.rectangle("fill", castBarX, castBarY, castBarWidth * castProgress, castBarHeight, 2, 2)
    end
end

function Boss:drawAOEIndicator()
    if self.state ~= Boss.STATES.CAST_AOE then return end

    local progress = self:getAOECastProgress()
    local alpha = 0.2 + progress * 0.4

    love.graphics.setColor(1, 0.2, 0.1, alpha * 0.25)
    love.graphics.circle("fill", self.aoeIndicator.x, self.aoeIndicator.y, self.aoeIndicator.radius * progress)

    love.graphics.setColor(1, 0.3, 0.1, alpha * 0.7)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.aoeIndicator.x, self.aoeIndicator.y, self.aoeIndicator.radius * progress)
    love.graphics.setLineWidth(1)
end

function Boss.drawIntro(progress)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    local alpha = 0
    if progress < 0.2 then
        alpha = progress / 0.2
    elseif progress < 0.7 then
        alpha = 1
    else
        alpha = 1 - (progress - 0.7) / 0.3
    end

    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)

    if progress > 0.1 and progress < 0.85 then
        local textAlpha = 1
        if progress < 0.2 then
            textAlpha = (progress - 0.1) / 0.1
        elseif progress > 0.75 then
            textAlpha = (0.85 - progress) / 0.1
        end

        local font = love.graphics.newFont(36)
        love.graphics.setFont(font)
        love.graphics.setColor(0.9, 0.2, 0.1, textAlpha)
        love.graphics.printf("REY SLIME", 0, h / 2 - 30, w, "center")

        local subFont = love.graphics.newFont(16)
        love.graphics.setFont(subFont)
        love.graphics.setColor(0.8, 0.7, 0.4, textAlpha)
        love.graphics.printf("Ha aparecido el jefe!", 0, h / 2 + 20, w, "center")
    end
end

return Boss
