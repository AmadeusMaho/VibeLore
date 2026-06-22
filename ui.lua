local UI = {}
UI.__index = UI

local dmgFont

function UI.new()
    local self = setmetatable({}, UI)
    self.attackBtn = {
        x = 0, y = 0,
        width = 80, height = 80,
        pressed = false,
        hover = false
    }
    self.damageNumbers = {}
    self.screenShake = 0
    self.shakeIntensity = 0

    if not dmgFont then
        dmgFont = love.graphics.newFont(28)
        dmgFont:setFilter("nearest", "nearest")
    end

    return self
end

function UI:update(dt, player, screenWidth, screenHeight)
    self.attackBtn.x = screenWidth - 110
    self.attackBtn.y = screenHeight - 110

    local mx, my = love.mouse.getPosition()
    self.attackBtn.hover = mx >= self.attackBtn.x and mx <= self.attackBtn.x + self.attackBtn.width and
                           my >= self.attackBtn.y and my <= self.attackBtn.y + self.attackBtn.height

    for i = #self.damageNumbers, 1, -1 do
        local dmg = self.damageNumbers[i]
        dmg.y = dmg.y - 50 * dt
        dmg.timer = dmg.timer - dt
        local life = dmg.timer / dmg.maxTimer
        if life > 0.8 then
            dmg.scale = dmg.scale + 3 * dt
        elseif dmg.scale > 1.0 then
            dmg.scale = dmg.scale - 2 * dt
            if dmg.scale < 1.0 then dmg.scale = 1.0 end
        end
        if dmg.timer <= 0 then
            table.remove(self.damageNumbers, i)
        end
    end

    self.screenShake = math.max(0, self.screenShake - dt)
end

function UI:addDamageNumber(x, y, amount, isEnemy, isCrit)
    table.insert(self.damageNumbers, {
        x = x + math.random(-10, 10),
        y = y,
        amount = amount,
        timer = 0.9,
        maxTimer = 0.9,
        isEnemy = isEnemy,
        isCrit = isCrit or false,
        scale = isCrit and 1.6 or 1.0
    })
end

function UI:shake(intensity, duration)
    self.shakeIntensity = intensity or 5
    self.screenShake = duration or 0.1
end

function UI:getShakeOffset()
    if self.screenShake > 0 then
        return (math.random() - 0.5) * self.shakeIntensity * 2,
               (math.random() - 0.5) * self.shakeIntensity * 2
    end
    return 0, 0
end

function UI:draw(player, enemyCount, score, goldCount, camera)
    self:drawPlayerHealthBar(player)
    self:drawAttackButton()
    self:drawDamageNumbers(camera)
    self:drawEnemyCounter(enemyCount)
    self:drawScore(score)
    self:drawGoldCounter(goldCount)
    self:drawControls()
end

function UI:drawPlayerHealthBar(player)
    local barX = 20
    local barY = 20
    local barWidth = 200
    local barHeight = 20
    local healthPercent = player.health / player.maxHealth

    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, barHeight + 4, 4, 4)

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)

    if healthPercent > 0.5 then
        love.graphics.setColor(0.2, 0.8, 0.2)
    elseif healthPercent > 0.25 then
        love.graphics.setColor(0.8, 0.8, 0.2)
    else
        love.graphics.setColor(0.8, 0.2, 0.2)
    end
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight, 3, 3)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(player.health .. " / " .. player.maxHealth, barX, barY + 2, barWidth, "center")
end

function UI:drawAttackButton()
    local btn = self.attackBtn

    if btn.pressed then
        love.graphics.setColor(0.8, 0.4, 0.1)
    elseif btn.hover then
        love.graphics.setColor(0.6, 0.3, 0.1)
    else
        love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
    end
    love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 10, 10)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 10, 10)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("ATK", btn.x, btn.y + 30, btn.width, "center")
    love.graphics.printf("[SPACE]", btn.x, btn.y + 50, btn.width, "center")
end

function UI:drawDamageNumbers(camera)
    local camX = camera and camera.x or 0
    local camY = camera and camera.y or 0
    local prevFont = love.graphics.getFont()

    for _, dmg in ipairs(self.damageNumbers) do
        local alpha = dmg.timer / dmg.maxTimer
        local screenX = dmg.x - camX
        local screenY = dmg.y - camY

        love.graphics.setFont(dmgFont)

        local text = "-" .. dmg.amount
        if dmg.isCrit then
            text = text .. "!"
        end

        local r, g, b
        if dmg.isCrit then
            r, g, b = 1, 0.85, 0.1
        elseif dmg.isEnemy then
            r, g, b = 1, 0.3, 0.3
        else
            r, g, b = 1, 1, 0.3
        end

        local scale = dmg.scale or 1.0
        local w = dmgFont:getWidth(text)

        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.printf(text, screenX - w / 2 - 1, screenY - 1, w, "center")
        love.graphics.printf(text, screenX - w / 2 + 1, screenY + 1, w, "center")
        love.graphics.printf(text, screenX - w / 2, screenY - 2, w, "center")

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.printf(text, screenX - w / 2, screenY, w, "center")
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1)
end

function UI:drawEnemyCounter(count)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Enemigos: " .. count, 20, 50)
end

function UI:drawScore(score)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Puntos: " .. (score or 0), 20, 70)
end

function UI:drawGoldCounter(goldCount)
    love.graphics.setColor(0.15, 0.1, 0.05, 0.6)
    love.graphics.circle("fill", 30, 97, 10)
    love.graphics.setColor(1, 0.85, 0.1, 0.9)
    love.graphics.circle("fill", 30, 97, 9)
    love.graphics.setColor(1, 0.95, 0.5, 0.9)
    love.graphics.circle("fill", 29, 95, 4)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Oro: " .. (goldCount or 0), 45, 90)
end

function UI:drawControls()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("WASD: Mover | SHIFT: Correr | SPACE/Click: Atacar", 20, love.graphics.getHeight() - 25)
end

function UI:isAttackPressed()
    return self.attackBtn.pressed
end

function UI:mousepressed(x, y, button)
    if button == 1 and self.attackBtn.hover then
        self.attackBtn.pressed = true
        return true
    end
    return false
end

function UI:mousereleased(x, y, button)
    if button == 1 then
        self.attackBtn.pressed = false
    end
end

return UI
