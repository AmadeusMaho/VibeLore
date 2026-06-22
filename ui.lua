local UI = {}
UI.__index = UI

local dmgFont
local levelUpFont
local smallFont
local tinyFont
local statFont
local iconSword
local iconShield
local iconCrit

local function generateIcons()
    if iconSword then return end

    local function makeIcon(drawFn)
        local c = love.graphics.newCanvas(14, 14)
        love.graphics.setCanvas(c)
        love.graphics.clear(0, 0, 0, 0)
        drawFn()
        love.graphics.setCanvas()
        c:setFilter("nearest", "nearest")
        return c
    end

    iconSword = makeIcon(function()
        love.graphics.setColor(0.8, 0.75, 0.6)
        love.graphics.rectangle("fill", 6, 1, 2, 8)
        love.graphics.setColor(0.55, 0.35, 0.2)
        love.graphics.rectangle("fill", 6, 9, 2, 4)
        love.graphics.setColor(0.8, 0.75, 0.6)
        love.graphics.rectangle("fill", 4, 5, 6, 2)
    end)

    iconShield = makeIcon(function()
        love.graphics.setColor(0.3, 0.4, 0.8)
        love.graphics.rectangle("fill", 3, 2, 8, 10)
        love.graphics.setColor(0.5, 0.6, 1.0)
        love.graphics.rectangle("fill", 5, 4, 4, 6)
        love.graphics.setColor(1, 1, 0.5)
        love.graphics.rectangle("fill", 6, 6, 2, 2)
    end)

    iconCrit = makeIcon(function()
        love.graphics.setColor(1, 0.8, 0.1)
        love.graphics.polygon("fill", 7, 1, 9, 5, 13, 5, 10, 8, 11, 13, 7, 10, 3, 10, 1, 6, 5, 6)
    end)

    iconStr = makeIcon(function()
        love.graphics.setColor(0.9, 0.3, 0.2)
        love.graphics.rectangle("fill", 5, 2, 4, 10)
        love.graphics.rectangle("fill", 3, 5, 8, 3)
        love.graphics.setColor(1, 0.5, 0.3)
        love.graphics.rectangle("fill", 6, 3, 2, 8)
    end)

    iconAgi = makeIcon(function()
        love.graphics.setColor(0.3, 0.8, 0.3)
        love.graphics.polygon("fill", 7, 1, 12, 8, 9, 7, 12, 13, 7, 7, 2, 8, 5, 1)
    end)

    iconInt = makeIcon(function()
        love.graphics.setColor(0.4, 0.5, 1.0)
        love.graphics.rectangle("fill", 5, 1, 4, 2)
        love.graphics.rectangle("fill", 6, 3, 2, 6)
        love.graphics.rectangle("fill", 5, 9, 4, 2)
        love.graphics.rectangle("fill", 6, 11, 2, 2)
    end)

    iconCon = makeIcon(function()
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.rectangle("fill", 3, 3, 8, 8)
        love.graphics.setColor(1, 0.85, 0.4)
        love.graphics.rectangle("fill", 5, 5, 4, 4)
    end)
end

function UI.new()
    local self = setmetatable({}, UI)
    self.attackBtn = {
        x = 0, y = 0,
        width = 80, height = 80,
        pressed = false,
        hover = false
    }
    self.damageNumbers = {}
    self.xpNumbers = {}
    self.screenShake = 0
    self.shakeIntensity = 0
    self.levelUpPopup = nil
    self.levelUpSound = nil
    self.charScreenOpen = false
    self.damageVignette = 0

    if not self.levelUpSound then
        local ok, src = pcall(love.audio.newSource, "sounds/levelup.ogg", "static")
        if ok then self.levelUpSound = src end
    end

    if not dmgFont then
        dmgFont = love.graphics.newFont(18)
        dmgFont:setFilter("nearest", "nearest")
    end
    if not levelUpFont then
        levelUpFont = love.graphics.newFont(16)
        levelUpFont:setFilter("nearest", "nearest")
    end
    if not smallFont then
        smallFont = love.graphics.newFont(13)
        smallFont:setFilter("nearest", "nearest")
    end
    if not tinyFont then
        tinyFont = love.graphics.newFont(11)
        tinyFont:setFilter("nearest", "nearest")
    end
    if not statFont then
        statFont = love.graphics.newFont(14)
        statFont:setFilter("nearest", "nearest")
    end

    generateIcons()

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

    for i = #self.xpNumbers, 1, -1 do
        local xp = self.xpNumbers[i]
        xp.y = xp.y - 35 * dt
        xp.timer = xp.timer - dt
        if xp.timer <= 0 then
            table.remove(self.xpNumbers, i)
        end
    end

    self.screenShake = math.max(0, self.screenShake - dt)
    self.damageVignette = math.max(0, self.damageVignette - dt)

    if self.levelUpPopup then
        self.levelUpPopup.timer = self.levelUpPopup.timer - dt
        if self.levelUpPopup.timer <= 0 then
            self.levelUpPopup = nil
        end
    end
end

function UI:showLevelUp(level)
    self.levelUpPopup = {
        level = level,
        timer = 2.5
    }
    if self.levelUpSound then
        self.levelUpSound:stop()
        self.levelUpSound:play()
    end
end

function UI:triggerDamageVignette()
    self.damageVignette = 0.4
end

function UI:drawDamageVignette()
    if self.damageVignette <= 0 then return end
    local alpha = self.damageVignette / 0.4 * 0.35
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local cx = screenW / 2
    local cy = screenH / 2

    for i = 1, 8 do
        local a = alpha * (1 - i / 10)
        love.graphics.setColor(0.8, 0.05, 0.05, a)
        love.graphics.rectangle("fill", -i * 8, -i * 8, screenW + i * 16, screenH + i * 16)
    end

    love.graphics.setColor(0.9, 0.1, 0.1, alpha * 0.5)
    love.graphics.rectangle("line", 0, 0, screenW, screenH)
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

function UI:addXPNumber(x, y, amount)
    table.insert(self.xpNumbers, {
        x = x + math.random(-8, 8),
        y = y,
        amount = amount,
        timer = 1.0,
        maxTimer = 1.0
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
    self:drawXPBar(player)
    self:drawAttackButton()
    self:drawDamageNumbers(camera)
    self:drawXPNumbers(camera)
    self:drawLevelUpPopup()
    self:drawCharScreen(player)
    self:drawDamageVignette()
    self:drawEnemyCounter(enemyCount)
    self:drawScore(score)
    self:drawGoldCounter(goldCount)
    self:drawControls()
end

function UI:drawLevelUpPopup()
    if not self.levelUpPopup then return end

    local popup = self.levelUpPopup
    local alpha = math.min(1, popup.timer / 0.5)
    if popup.timer < 0.5 then
        alpha = popup.timer / 0.5
    end

    local screenW = love.graphics.getWidth()
    local cx = screenW / 2
    local y = 60

    love.graphics.setFont(levelUpFont)

    local title = "¡Subiste de nivel!"
    local tw = levelUpFont:getWidth(title)

    love.graphics.setColor(0, 0, 0, alpha * 0.75)
    love.graphics.rectangle("fill", cx - tw / 2 - 24, y - 10, tw + 48, 52, 8, 8)

    love.graphics.setColor(0.2, 0.1, 0.0, alpha)
    love.graphics.printf(title, cx - tw / 2, y, tw, "center")
    love.graphics.setColor(1, 0.85, 0.1, alpha)
    love.graphics.printf(title, cx - tw / 2 - 1, y - 1, tw, "center")

    love.graphics.setFont(smallFont)
    local iconY = y + 27
    local groupW = 56
    local totalW = groupW * 3
    local startX = cx - totalW / 2

    local function drawStatGroup(x, icon, label, iconTint)
        love.graphics.setColor(iconTint[1], iconTint[2], iconTint[3], alpha)
        love.graphics.draw(icon, x, iconY)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(label, x + 17, iconY + 1)
    end

    drawStatGroup(startX, iconSword, "+1", {0.6, 0.7, 1.0})
    drawStatGroup(startX + groupW, iconShield, "+1", {0.6, 0.7, 1.0})
    drawStatGroup(startX + groupW * 2, iconCrit, "+0.2%", {1, 0.85, 0.1})
end

function UI:drawPlayerHealthBar(player)
    local barX = 20
    local barY = 15
    local barWidth = 200
    local barHeight = 18
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
    love.graphics.printf(player.health .. " / " .. player.maxHealth, barX, barY + 1, barWidth, "center")
end

function UI:drawXPBar(player)
    local barX = 20
    local barY = 37
    local barWidth = 200
    local barHeight = 10
    local xpPercent = player.xp / player.xpToNext

    love.graphics.setColor(0.1, 0.1, 0.3, 0.8)
    love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, barHeight + 4, 3, 3)

    love.graphics.setColor(0.15, 0.15, 0.25)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 2, 2)

    love.graphics.setColor(0.2, 0.5, 1.0)
    love.graphics.rectangle("fill", barX, barY, barWidth * xpPercent, barHeight, 2, 2)

    love.graphics.setColor(0.4, 0.7, 1.0)
    love.graphics.rectangle("fill", barX, barY, barWidth * xpPercent, barHeight / 2, 2, 2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Lv." .. player.level .. "  " .. player.xp .. "/" .. player.xpToNext, barX, barY - 1, barWidth, "center")

    local statsY = barY + barHeight + 4
    love.graphics.setFont(smallFont)

    love.graphics.setColor(0.6, 0.7, 1.0, 0.85)
    love.graphics.draw(iconSword, barX, statsY)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(player.attackDamage, barX + 16, statsY)

    love.graphics.setColor(0.6, 0.7, 1.0, 0.85)
    love.graphics.draw(iconShield, barX + 40, statsY)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(player.armor, barX + 56, statsY)

    love.graphics.setColor(1, 0.85, 0.1, 0.85)
    love.graphics.draw(iconCrit, barX + 80, statsY)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(string.format("%.1f%%", player.critChance * 100), barX + 96, statsY)
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

function UI:drawXPNumbers(camera)
    local camX = camera and camera.x or 0
    local camY = camera and camera.y or 0
    local prevFont = love.graphics.getFont()

    love.graphics.setFont(dmgFont)

    for _, xp in ipairs(self.xpNumbers) do
        local alpha = xp.timer / xp.maxTimer
        local screenX = xp.x - camX
        local screenY = xp.y - camY
        local text = "+" .. xp.amount .. " XP"
        local w = dmgFont:getWidth(text)

        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.printf(text, screenX - w / 2 - 1, screenY - 1, w, "center")
        love.graphics.printf(text, screenX - w / 2 + 1, screenY + 1, w, "center")

        love.graphics.setColor(0.3, 0.6, 1.0, alpha)
        love.graphics.printf(text, screenX - w / 2, screenY, w, "center")
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1)
end

function UI:drawEnemyCounter(count)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Enemigos: " .. count, 140, 68)
end

function UI:drawScore(score)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Puntos: " .. (score or 0), 140, 82)
end

function UI:drawGoldCounter(goldCount)
    love.graphics.setColor(0.15, 0.1, 0.05, 0.6)
    love.graphics.circle("fill", 150, 102, 6)
    love.graphics.setColor(1, 0.85, 0.1, 0.9)
    love.graphics.circle("fill", 150, 102, 5)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Oro: " .. (goldCount or 0), 160, 96)
end

function UI:drawControls()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("WASD: Mover | SHIFT: Correr | SPACE/Click: Atacar | C: Stats | TAB: Inventario", 20, love.graphics.getHeight() - 25)
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

function UI:toggleCharScreen()
    self.charScreenOpen = not self.charScreenOpen
end

function UI:isCharScreenOpen()
    return self.charScreenOpen
end

function UI:drawCharScreen(player)
    if not self.charScreenOpen then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local cx = screenW / 2
    local cy = screenH / 2
    local bw = 260
    local bh = 300

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", cx - bw / 2, cy - bh / 2, bw, bh, 8, 8)
    love.graphics.setColor(0.3, 0.25, 0.15)
    love.graphics.rectangle("line", cx - bw / 2, cy - bh / 2, bw, bh, 8, 8)

    love.graphics.setFont(levelUpFont)
    love.graphics.setColor(1, 0.85, 0.1)
    love.graphics.printf("PERSONAJE", cx - bw / 2, cy - bh / 2 + 10, bw, "center")

    love.graphics.setFont(statFont)
    local leftX = cx - bw / 2 + 15
    local rightX = cx + 10
    local y = cy - bh / 2 + 40

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Nivel: " .. player.level, leftX, y)
    love.graphics.print("Puntos: " .. player.statPoints, rightX, y)
    y = y + 20

    love.graphics.setColor(0.9, 0.3, 0.2)
    love.graphics.draw(iconStr, leftX, y)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Fuerza: " .. player.strength, leftX + 18, y + 1)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("+" .. string.format("%.1f", player.strength * 0.5) .. " ATK", rightX, y + 1)
    y = y + 24

    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.draw(iconAgi, leftX, y)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Agilidad: " .. player.agility, leftX + 18, y + 1)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("+" .. player.agility * 15 .. " SPD", rightX, y + 1)
    y = y + 24

    love.graphics.setColor(0.4, 0.5, 1.0)
    love.graphics.draw(iconInt, leftX, y)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Inteligencia: " .. player.intelligence, leftX + 18, y + 1)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("+" .. player.intelligence .. " MP", rightX, y + 1)
    y = y + 24

    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.draw(iconCon, leftX, y)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Constitucion: " .. player.constitution, leftX + 18, y + 1)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("+" .. player.constitution * 10 .. " HP", rightX, y + 1)
    y = y + 30

    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("fill", leftX, y, bw - 30, 1)
    y = y + 10

    love.graphics.setFont(tinyFont)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Presiona 1/2/3/4 para asignar puntos", leftX, y)
    love.graphics.print("Presiona C para cerrar", leftX, y + 14)
end

function UI:handleCharInput(key, player)
    if not self.charScreenOpen then return false end
    if key == "1" then return player:allocateStat("str")
    elseif key == "2" then return player:allocateStat("agi")
    elseif key == "3" then return player:allocateStat("int")
    elseif key == "4" then return player:allocateStat("con")
    end
    return false
end

return UI
