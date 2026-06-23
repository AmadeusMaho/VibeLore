local SceneManager = require("scene_manager")

local MenuScene = {}

local selectedIndex = 1
local options = {"Iniciar", "Salir"}
local menuAlpha = 0
local titleScale = 1
local pulseTimer = 0
local mouseHover = 0

function MenuScene.enter()
    selectedIndex = 1
    menuAlpha = 0
    titleScale = 1
    pulseTimer = 0
    mouseHover = 0
end

function MenuScene.update(dt)
    menuAlpha = math.min(1, menuAlpha + dt * 2)
    pulseTimer = pulseTimer + dt
    titleScale = 1 + math.sin(pulseTimer * 2) * 0.03

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local btnW = 260
    local btnH = 52
    local btnX = w / 2 - btnW / 2
    local startY = h * 0.48
    local gap = 70
    local mx, my = love.mouse.getPosition()

    mouseHover = 0
    for i = 1, #options do
        local by = startY + (i - 1) * gap
        if mx >= btnX and mx <= btnX + btnW and my >= by and my <= by + btnH then
            mouseHover = i
        end
    end
end

function MenuScene.draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    for i = 1, 60 do
        local x = (i * 137.5 + pulseTimer * 20) % w
        local y = (i * 89.3 + pulseTimer * 10) % h
        local alpha = 0.15 + math.sin(pulseTimer + i) * 0.1
        love.graphics.setColor(0.3, 0.5, 0.8, alpha * menuAlpha)
        love.graphics.circle("fill", x, y, 2)
    end

    love.graphics.setColor(0.9, 0.85, 0.6, menuAlpha)
    love.graphics.setFont(love.graphics.newFont(56))
    love.graphics.printf("HEROES LORE", 0, h * 0.22, w, "center")

    love.graphics.setColor(0.6, 0.7, 0.9, menuAlpha * 0.7)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf("Una aventura de accion RPG", 0, h * 0.32, w, "center")

    local btnW = 260
    local btnH = 52
    local btnX = w / 2 - btnW / 2
    local startY = h * 0.48
    local gap = 70

    for i, label in ipairs(options) do
        local by = startY + (i - 1) * gap
        local hover = (i == selectedIndex) or (i == mouseHover)

        if hover then
            love.graphics.setColor(0.25, 0.35, 0.6, menuAlpha)
            love.graphics.rectangle("fill", btnX - 4, by - 4, btnW + 8, btnH + 8, 10, 10)
        end

        love.graphics.setColor(0.12, 0.14, 0.25, menuAlpha)
        love.graphics.rectangle("fill", btnX, by, btnW, btnH, 8, 8)

        if hover then
            love.graphics.setColor(0.4, 0.6, 1, menuAlpha)
        else
            love.graphics.setColor(0.7, 0.75, 0.85, menuAlpha)
        end
        love.graphics.rectangle("line", btnX, by, btnW, btnH, 8, 8)

        love.graphics.setFont(love.graphics.newFont(24))
        if hover then
            love.graphics.setColor(1, 1, 1, menuAlpha)
        else
            love.graphics.setColor(0.85, 0.85, 0.9, menuAlpha)
        end
        love.graphics.printf(label, btnX, by + 10, btnW, "center")
    end

    local activeIdx = mouseHover > 0 and mouseHover or selectedIndex
    local arrowX = btnX - 30
    local arrowY = startY + (activeIdx - 1) * gap + btnH / 2
    love.graphics.setColor(1, 0.85, 0.3, menuAlpha)
    love.graphics.setFont(love.graphics.newFont(28))
    love.graphics.print(">", arrowX, arrowY - 14)

    love.graphics.setColor(0.5, 0.5, 0.6, menuAlpha * 0.6)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf("Usa W/S / Flechas / Click para navegar", 0, h * 0.88, w, "center")
end

function MenuScene.keypressed(key)
    if key == "up" or key == "w" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then selectedIndex = #options end
    elseif key == "down" or key == "s" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #options then selectedIndex = 1 end
    elseif key == "return" or key == "space" then
        local choice = mouseHover > 0 and mouseHover or selectedIndex
        if choice == 1 then
            SceneManager.switch("map_select")
        elseif choice == 2 then
            love.event.quit()
        end
    end
end

function MenuScene.mousepressed(x, y, button)
    if button == 1 and mouseHover > 0 then
        if mouseHover == 1 then
            SceneManager.switch("map_select")
        elseif mouseHover == 2 then
            love.event.quit()
        end
    end
end

return MenuScene
