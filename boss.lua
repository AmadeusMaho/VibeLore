local Boss = {}
Boss.__index = Boss

Boss.STATES = {
    IDLE = "idle",
    CHASE = "chase",
    ATTACK = "attack",
    CAST_AOE = "cast_aoe",
    AOE_ACTIVE = "aoe_active",
    CAST_JUMP = "cast_jump",
    JUMP_WARN = "jump_warn",
    JUMP_LAND = "jump_land",
    JUMP_DELAY = "jump_delay",
}

local BOSS_SPRITE_SIZE = 64
local BOSS_SCALE = 3.2
local DETECT_RANGE = 400
local ATTACK_RANGE = 65
local AOE_RANGE = 350
local AOE_CAST_TIME = 2.5
local AOE_CD = 8
local JUMP_CAST_TIME = 1.0
local JUMP_WARN_TIME = 1.5
local JUMP_WARN_FOLLOW_TIME = 0.5
local JUMP_LAND_TIME = 0.6
local JUMP_DELAY_TIME = 1.0
local JUMP_CD = 15
local JUMP_RADIUS = 300
local JUMP_MAX_COUNT = 3
local JUMP_MIN_RADIUS = 120
local JUMP_MAX_RADIUS = 160
local HITS_TO_TRIGGER_ABILITY = 3
local ABILITY_CHANCE = 0.4
local CHASE_SPEED_MULT = 1.3
local BOSS_FPS = 6
local ABILITY_INTERNAL_CD = 3
local ENRAGE_HP_PERCENT = 0.5
local ENRAGE_SPEED_MULT = 1.15
local ENRAGE_DAMAGE_MULT = 1.15
local ENRAGE_DEFENSE_MULT = 0.85
local ENRAGE_MESSAGE_DURATION = 3.0

function Boss.new(x, y)
    local self = setmetatable({}, Boss)
    self.x = x
    self.y = y
    self.width = 64
    self.height = 64
    self.baseSpeed = 40
    self.speed = self.baseSpeed
    self.health = 150
    self.maxHealth = 150
    self.baseDamage = 10
    self.damage = self.baseDamage
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
    self.castTimer = 0
    self.aoeWarnTimer = 0
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

    self.hitsTaken = 0
    self.jumpCD = 0
    self.jumpCount = 0
    self.jumpTargetX = 0
    self.jumpTargetY = 0
    self.jumpRadius = JUMP_MIN_RADIUS
    self.jumpWarnTimer = 0
    self.jumpLandTimer = 0
    self.jumpDelayTimer = 0
    self.jumpAirDuration = 0.4
    self.abilityCD = 0
    self.firstCastJump = true
    self.enraged = false
    self.enrageTimer = 0
    self._enrageSlimesSpawned = false
    self.damageSound = nil

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

    local ok, snd = pcall(love.audio.newSource, "sounds/bossDamage.wav", "static")
    if ok then
        self.damageSound = snd
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
    self.jumpCD = math.max(0, self.jumpCD - dt)
    self.abilityCD = math.max(0, self.abilityCD - dt)
    self.enrageTimer = math.max(0, self.enrageTimer - dt)

    if not self.enraged and self.health <= self.maxHealth * ENRAGE_HP_PERCENT and self.health > 0 then
        self:triggerEnrage()
    end

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
    self.x = self.x + self.knockbackX * dt * 60
    self.y = self.y + self.knockbackY * dt * 60

    local dx = playerX - (self.x + self.width / 2)
    local dy = playerY - (self.y + self.height / 2)
    local distToPlayer = math.sqrt(dx * dx + dy * dy)

    if dx < 0 then self.facing = -1 else self.facing = 1 end

    if self.state == Boss.STATES.CAST_AOE then
        self.activeFrames = self.idleFrames
        self.castTimer = self.castTimer - dt
        if self.castTimer <= 0 then
            self.state = Boss.STATES.AOE_ACTIVE
            self.aoeWarnTimer = 0.5
            self.aoeTargetX = self.x + self.width / 2
            self.aoeTargetY = self.y + self.height / 2
        end
        return false
    end

    if self.state == Boss.STATES.AOE_ACTIVE then
        self.activeFrames = self.idleFrames
        self.aoeWarnTimer = self.aoeWarnTimer - dt
        if self.aoeWarnTimer <= 0 then
            self.aoeCD = AOE_CD
            self.state = Boss.STATES.CHASE
            return true, { type = "aoe", x = self.aoeTargetX, y = self.aoeTargetY, radius = AOE_RANGE, damage = self.damage * 1.5 }
        end
        return false
    end

    if self.state == Boss.STATES.CAST_JUMP then
        self.castTimer = self.castTimer - dt
        if self.castTimer <= 0 then
            self.state = Boss.STATES.JUMP_WARN
            self.jumpWarnTimer = JUMP_WARN_TIME
            self:pickJumpTarget(playerX, playerY)
        end
        return false
    end

    if self.state == Boss.STATES.JUMP_WARN then
        self.jumpWarnTimer = self.jumpWarnTimer - dt
        local elapsed = JUMP_WARN_TIME - self.jumpWarnTimer
        if elapsed <= JUMP_WARN_FOLLOW_TIME then
            self.jumpTargetX = playerX
            self.jumpTargetY = playerY
        end
        if self.jumpWarnTimer <= 0 then
            self.state = Boss.STATES.JUMP_LAND
            self.jumpLandTimer = JUMP_LAND_TIME
            self.x = self.jumpTargetX - self.width / 2
            self.y = self.jumpTargetY - self.height / 2
        end
        return false
    end

    if self.state == Boss.STATES.JUMP_LAND then
        self.activeFrames = self.attackFrames
        self.jumpLandTimer = self.jumpLandTimer - dt
        if self.jumpLandTimer <= 0 then
            local ldx = playerX - self.jumpTargetX
            local ldy = playerY - self.jumpTargetY
            local ldist = math.sqrt(ldx * ldx + ldy * ldy)
            local dmgData = nil
            if ldist <= self.jumpRadius then
                dmgData = { type = "jump_hit", x = self.jumpTargetX, y = self.jumpTargetY, radius = self.jumpRadius, damage = self.damage * 2 }
            end
            self.jumpCount = self.jumpCount + 1
            if self.jumpCount < JUMP_MAX_COUNT then
                self.state = Boss.STATES.JUMP_DELAY
                self.jumpDelayTimer = JUMP_DELAY_TIME
                return true, dmgData
            else
                self.jumpCD = JUMP_CD
                self.jumpCount = 0
                self.hitsTaken = 0
                self.state = Boss.STATES.CHASE
                return true, dmgData
            end
        end
        return false
    end

    if self.state == Boss.STATES.JUMP_DELAY then
        self.activeFrames = self.idleFrames
        self.jumpDelayTimer = self.jumpDelayTimer - dt
        local elapsed = JUMP_DELAY_TIME - self.jumpDelayTimer
        if elapsed <= JUMP_WARN_FOLLOW_TIME then
            self.jumpTargetX = playerX
            self.jumpTargetY = playerY
        end
        if self.jumpDelayTimer <= 0 then
            self.state = Boss.STATES.JUMP_WARN
            self.jumpWarnTimer = JUMP_WARN_TIME
            self:pickJumpTarget(playerX, playerY)
        end
        return false
    end

    if self.state == Boss.STATES.IDLE then
        self.activeFrames = #self.idleFrames > 0 and self.idleFrames or {}
        self.idleTimer = self.idleTimer - dt
        if distToPlayer < DETECT_RANGE then
            if self.abilityCD <= 0 and self.jumpCD <= 0 and self.hitsTaken >= HITS_TO_TRIGGER_ABILITY and math.random() < ABILITY_CHANCE then
                self:startJumpAbility()
                self.abilityCD = ABILITY_INTERNAL_CD
            elseif self.abilityCD <= 0 and self.aoeCD <= 0 and self.hitsTaken >= HITS_TO_TRIGGER_ABILITY and math.random() < ABILITY_CHANCE then
                self.state = Boss.STATES.CAST_AOE
                self.castTimer = AOE_CAST_TIME
                self.abilityCD = ABILITY_INTERNAL_CD
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

        if self.abilityCD <= 0 and self.jumpCD <= 0 and self.hitsTaken >= HITS_TO_TRIGGER_ABILITY and math.random() < ABILITY_CHANCE then
            self:startJumpAbility()
            self.abilityCD = ABILITY_INTERNAL_CD
            return false
        end

        if self.abilityCD <= 0 and self.aoeCD <= 0 and self.hitsTaken >= HITS_TO_TRIGGER_ABILITY and math.random() < ABILITY_CHANCE and distToPlayer > ATTACK_RANGE then
            self.state = Boss.STATES.CAST_AOE
            self.castTimer = AOE_CAST_TIME
            self.abilityCD = ABILITY_INTERNAL_CD
            return false
        end

        if distToPlayer <= ATTACK_RANGE then
            self.state = Boss.STATES.ATTACK
        else
            local nx = dx / distToPlayer
            local ny = dy / distToPlayer
            self.x = self.x + nx * self.speed * CHASE_SPEED_MULT * dt
            self.y = self.y + ny * self.speed * CHASE_SPEED_MULT * dt
        end

    elseif self.state == Boss.STATES.ATTACK then
        self.activeFrames = #self.attackFrames > 0 and self.attackFrames or self.idleFrames
        if distToPlayer > ATTACK_RANGE * 1.5 then
            self.state = Boss.STATES.CHASE
        end
    end

    return false
end

function Boss:startJumpAbility()
    self.state = Boss.STATES.CAST_JUMP
    self.castTimer = JUMP_CAST_TIME
    self.jumpCount = 0
    self.firstCastJump = false
end

function Boss:pickJumpTarget(playerX, playerY)
    self.jumpTargetX = playerX
    self.jumpTargetY = playerY
    self.jumpRadius = math.random(JUMP_MIN_RADIUS, JUMP_MAX_RADIUS)
end

function Boss:takeDamage(amount, knockbackX, knockbackY)
    if self.introActive then return end
    local finalDamage = amount
    if self.enraged then
        finalDamage = math.floor(amount * ENRAGE_DEFENSE_MULT)
    end
    self.health = self.health - finalDamage
    self.flashTimer = 0.15
    self.knockbackX = knockbackX or 0
    self.knockbackY = knockbackY or 0
    self.hitsTaken = self.hitsTaken + 1

    if self.damageSound then
        self.damageSound:stop()
        self.damageSound:play()
    end

    if self.health <= 0 then
        self.alive = false
        self.deathTimer = 0
    end

    return finalDamage
end

function Boss:triggerEnrage()
    if self.enraged then return end
    self.enraged = true
    self.enrageTimer = ENRAGE_MESSAGE_DURATION
    self.speed = self.baseSpeed * ENRAGE_SPEED_MULT
    self.damage = self.baseDamage * ENRAGE_DAMAGE_MULT
end

function Boss:isEnraged()
    return self.enraged
end

function Boss:getEnrageTimer()
    return self.enrageTimer
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
    return 1 - (self.castTimer / AOE_CAST_TIME)
end

function Boss:getJumpCastProgress()
    if self.state ~= Boss.STATES.CAST_JUMP then return 0 end
    return 1 - (self.castTimer / JUMP_CAST_TIME)
end

function Boss:getJumpDelayProgress()
    if self.state ~= Boss.STATES.JUMP_DELAY then return 0 end
    return 1 - (self.jumpDelayTimer / JUMP_DELAY_TIME)
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

    if self.state == Boss.STATES.CAST_AOE then
        self.activeFrames = self.idleFrames
    end

    if self.state == Boss.STATES.JUMP_WARN then
        love.graphics.setColor(1, 0.2, 0.1, 0.4)
        love.graphics.circle("fill", self.jumpTargetX, self.jumpTargetY, self.jumpRadius)
        love.graphics.setColor(1, 0.3, 0.1, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.jumpTargetX, self.jumpTargetY, self.jumpRadius)
        love.graphics.setLineWidth(1)
        return
    end

    if self.state == Boss.STATES.JUMP_LAND then
        local frame = nil
        if #self.attackFrames > 0 then
            local idx = self.currentFrame
            if idx < 1 then idx = 1 end
            if idx > #self.attackFrames then idx = #self.attackFrames end
            frame = self.attackFrames[idx]
        end
        if frame then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(frame, self.x + self.width / 2, self.y + self.height / 2, 0, self.facing * BOSS_SCALE, BOSS_SCALE, BOSS_SPRITE_SIZE / 2, BOSS_SPRITE_SIZE / 2)
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

    if self.enraged then
        local iconSize = 16
        local iconX = barX + barWidth / 2 - iconSize / 2
        local iconY = barY + barHeight + 4
        local pulse = 0.7 + math.sin(love.timer.getTime() * 4) * 0.3
        love.graphics.setColor(1, 0.2, 0.2, pulse)
        love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 2, 2)
        love.graphics.setColor(1, 1, 1, pulse)
        local smallFont = love.graphics.newFont(10)
        love.graphics.setFont(smallFont)
        love.graphics.printf("!", iconX, iconY + 1, iconSize, "center")
    end

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
    elseif self.state == Boss.STATES.CAST_JUMP then
        local castBarWidth = 200
        local castBarHeight = 8
        local castBarX = love.graphics.getWidth() / 2 - castBarWidth / 2
        local castBarY = barY + barHeight + 6
        local castProgress = self:getJumpCastProgress()

        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", castBarX, castBarY, castBarWidth, castBarHeight, 2, 2)
        love.graphics.setColor(0.8, 0.2, 0.8)
        love.graphics.rectangle("fill", castBarX, castBarY, castBarWidth * castProgress, castBarHeight, 2, 2)
    elseif self.state == Boss.STATES.JUMP_DELAY then
        local castBarWidth = 200
        local castBarHeight = 8
        local castBarX = love.graphics.getWidth() / 2 - castBarWidth / 2
        local castBarY = barY + barHeight + 6
        local castProgress = self:getJumpDelayProgress()

        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", castBarX, castBarY, castBarWidth, castBarHeight, 2, 2)
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.rectangle("fill", castBarX, castBarY, castBarWidth * castProgress, castBarHeight, 2, 2)
    end
end

function Boss:drawAOEIndicator()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    if self.state == Boss.STATES.CAST_AOE then
        local progress = 1 - (self.castTimer / AOE_CAST_TIME)
        local currentRadius = AOE_RANGE * progress
        local alpha = 0.3 + progress * 0.5

        love.graphics.setColor(1, 0.2, 0.1, alpha * 0.3)
        love.graphics.circle("fill", cx, cy, currentRadius)

        love.graphics.setColor(1, 0.4, 0.1, alpha * 0.9)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", cx, cy, currentRadius)
        love.graphics.setLineWidth(1)
    elseif self.state == Boss.STATES.AOE_ACTIVE then
        local alpha = 0.8

        love.graphics.setColor(1, 0.15, 0.1, alpha * 0.4)
        love.graphics.circle("fill", cx, cy, AOE_RANGE)

        love.graphics.setColor(1, 0.3, 0.1, alpha)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", cx, cy, AOE_RANGE)
        love.graphics.setLineWidth(1)
    end
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
