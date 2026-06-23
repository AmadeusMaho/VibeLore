local SceneManager = require("scene_manager")

local MapSelectionScene = {}
MapSelectionScene.__index = MapSelectionScene

local selectedWorld = 1
local selectedLevel = 1
local currentZone = 1

local zones = {
    { name = "Bosque Oscuro", icon = "tree", color = {0.15, 0.45, 0.2}, levels = {
        { id = "1-1", name = "Pradera", unlocked = true },
        { id = "1-2", name = "Claro", unlocked = false },
        { id = "1-3", name = "Templo", unlocked = false },
        { id = "1-4", name = "Ruinas", unlocked = false },
        { id = "1-5", name = "Guardian", unlocked = false },
    }},
    { name = "Montañas", icon = "mountain", color = {0.5, 0.4, 0.3}, levels = {
        { id = "2-1", name = "Paso", unlocked = false },
        { id = "2-2", name = "Cueva", unlocked = false },
        { id = "2-3", name = "Cumbre", unlocked = false },
        { id = "2-4", name = "Nieve", unlocked = false },
        { id = "2-5", name = "Golem", unlocked = false },
    }},
    { name = "Pantano", icon = "swamp", color = {0.2, 0.35, 0.5}, levels = {
        { id = "3-1", name = "Humedal", unlocked = false },
        { id = "3-2", name = "Ruinas", unlocked = false },
        { id = "3-3", name = "Abismo", unlocked = false },
        { id = "3-4", name = "Niebla", unlocked = false },
        { id = "3-5", name = "Hydra", unlocked = false },
    }},
    { name = "Desierto", icon = "desert", color = {0.6, 0.5, 0.25}, levels = {
        { id = "4-1", name = "Dunas", unlocked = false },
        { id = "4-2", name = "Oasis", unlocked = false },
        { id = "4-3", name = "Piramide", unlocked = false },
        { id = "4-4", name = "Sarcofago", unlocked = false },
        { id = "4-5", name = "Faraon", unlocked = false },
    }},
    { name = "Inframundo", icon = "underworld", color = {0.45, 0.2, 0.5}, levels = {
        { id = "5-1", name = "Entrada", unlocked = false },
        { id = "5-2", name = "Lago", unlocked = false },
        { id = "5-3", name = "Trono", unlocked = false },
        { id = "5-4", name = "Abaddon", unlocked = false },
        { id = "5-5", name = "Sombra", unlocked = false },
    }},
}

local selectedNode = 1
local particles = {}
local NODE_SIZE = 28
local PATH_Y = 380
local NODE_SPACING = 180

local function drawIcon(x, y, icon, size, color)
    love.graphics.setColor(color[1], color[2], color[3])
    if icon == "tree" then
        love.graphics.setColor(0.35, 0.2, 0.1)
        love.graphics.rectangle("fill", x - 2, y + size * 0.2, 4, size * 0.5)
        love.graphics.setColor(0.15, 0.5, 0.2)
        love.graphics.polygon("fill", x, y - size * 0.4, x - size * 0.35, y + size * 0.25, x + size * 0.35, y + size * 0.25)
        love.graphics.polygon("fill", x, y - size * 0.6, x - size * 0.25, y, x + size * 0.25, y)
    elseif icon == "mountain" then
        love.graphics.setColor(0.5, 0.45, 0.4)
        love.graphics.polygon("fill", x, y - size * 0.5, x - size * 0.45, y + size * 0.3, x + size * 0.45, y + size * 0.3)
        love.graphics.setColor(0.7, 0.7, 0.65)
        love.graphics.polygon("fill", x, y - size * 0.5, x - size * 0.12, y - size * 0.2, x + size * 0.12, y - size * 0.2)
        love.graphics.setColor(0.4, 0.38, 0.35)
        love.graphics.polygon("fill", x + size * 0.25, y - size * 0.3, x - size * 0.05, y + size * 0.3, x + size * 0.55, y + size * 0.3)
    elseif icon == "swamp" then
        love.graphics.setColor(0.15, 0.4, 0.3)
        for i = 0, 2 do
            local ox = (i - 1) * size * 0.25
            love.graphics.ellipse("fill", x + ox, y + size * 0.15, size * 0.15, size * 0.06)
        end
        love.graphics.setColor(0.2, 0.55, 0.35)
        love.graphics.polygon("fill", x - size * 0.15, y - size * 0.15, x - size * 0.35, y + size * 0.2, x + size * 0.05, y + size * 0.2)
        love.graphics.polygon("fill", x + size * 0.1, y - size * 0.25, x - size * 0.1, y + size * 0.15, x + size * 0.3, y + size * 0.15)
    elseif icon == "desert" then
        love.graphics.setColor(0.7, 0.6, 0.35)
        love.graphics.ellipse("fill", x, y + size * 0.15, size * 0.45, size * 0.12)
        love.graphics.setColor(0.8, 0.65, 0.3)
        love.graphics.polygon("fill", x, y - size * 0.35, x - size * 0.2, y + size * 0.2, x + size * 0.2, y + size * 0.2)
        love.graphics.setColor(0.95, 0.85, 0.4)
        love.graphics.circle("fill", x + size * 0.3, y - size * 0.35, size * 0.12)
    elseif icon == "underworld" then
        love.graphics.setColor(0.5, 0.15, 0.15)
        love.graphics.polygon("fill", x, y - size * 0.45, x - size * 0.3, y + size * 0.3, x + size * 0.3, y + size * 0.3)
        love.graphics.setColor(0.8, 0.2, 0.1)
        love.graphics.polygon("fill", x - size * 0.08, y - size * 0.15, x - size * 0.18, y + size * 0.1, x + size * 0.02, y + size * 0.1)
        love.graphics.polygon("fill", x + size * 0.08, y - size * 0.25, x - size * 0.02, y, x + size * 0.18, y)
    end
end

function MapSelectionScene.enter()
    selectedNode = 1
    currentZone = 1
    particles = {}
end

function MapSelectionScene.exit()
end

function MapSelectionScene.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        p.alpha = math.max(0, p.life / p.maxLife)
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end

    if love.math.random() < 0.3 then
        particles[#particles + 1] = {
            x = love.math.random(0, love.graphics.getWidth()),
            y = love.graphics.getHeight() + 5,
            vx = love.math.random(-15, 15),
            vy = love.math.random(-40, -20),
            size = love.math.random(1, 3),
            alpha = 1,
            life = love.math.random(3, 6),
            maxLife = 6,
            color = {0.3 + love.math.random() * 0.3, 0.4 + love.math.random() * 0.3, 0.8 + love.math.random() * 0.2},
        }
    end
end

function MapSelectionScene.draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local zone = zones[currentZone]
    local col = zone.color

    love.graphics.setColor(0.06, 0.09, 0.14)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    for _, p in ipairs(particles) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.alpha * 0.4)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    local titleFont = love.graphics.newFont(34)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.printf(zone.name, 0, 20, screenW, "center")

    local selectorY = 80
    local selectorBtnSize = 50
    local totalSelectorW = #zones * (selectorBtnSize + 12)
    local selectorStartX = screenW / 2 - totalSelectorW / 2

    for zi, z in ipairs(zones) do
        local zx = selectorStartX + (zi - 1) * (selectorBtnSize + 12) + selectorBtnSize / 2
        local zy = selectorY + selectorBtnSize / 2
        local isActive = zi == currentZone

        if isActive then
            love.graphics.setColor(z.color[1] * 0.3, z.color[2] * 0.3, z.color[3] * 0.3)
            love.graphics.rectangle("fill", zx - selectorBtnSize / 2 - 3, zy - selectorBtnSize / 2 - 3, selectorBtnSize + 6, selectorBtnSize + 6, 8, 8)
            love.graphics.setColor(z.color[1], z.color[2], z.color[3])
            love.graphics.rectangle("fill", zx - selectorBtnSize / 2, zy - selectorBtnSize / 2, selectorBtnSize, selectorBtnSize, 6, 6)
        else
            love.graphics.setColor(z.color[1] * 0.35, z.color[2] * 0.35, z.color[3] * 0.35, 0.6)
            love.graphics.rectangle("fill", zx - selectorBtnSize / 2, zy - selectorBtnSize / 2, selectorBtnSize, selectorBtnSize, 6, 6)
            love.graphics.setColor(z.color[1] * 0.6, z.color[2] * 0.6, z.color[3] * 0.6)
            love.graphics.rectangle("line", zx - selectorBtnSize / 2, zy - selectorBtnSize / 2, selectorBtnSize, selectorBtnSize, 6, 6)
        end

        drawIcon(zx, zy - 2, z.icon, 22, isActive and {1, 1, 1} or {z.color[1] * 0.7, z.color[2] * 0.7, z.color[3] * 0.7})
    end

    love.graphics.setColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.4)
    love.graphics.setLineWidth(3)
    love.graphics.line(60, PATH_Y, screenW - 60, PATH_Y)
    love.graphics.setLineWidth(1)

    local totalPathW = (#zone.levels - 1) * NODE_SPACING
    local pathStartX = screenW / 2 - totalPathW / 2

    for li, level in ipairs(zone.levels) do
        local lx = pathStartX + (li - 1) * NODE_SPACING
        local nodeIdx = li
        local isSelected = nodeIdx == selectedNode

        if li < #zone.levels then
            love.graphics.setColor(col[1] * 0.4, col[2] * 0.4, col[3] * 0.4, 0.5)
            love.graphics.setLineWidth(3)
            love.graphics.line(lx + NODE_SIZE + 5, PATH_Y, lx + NODE_SPACING - NODE_SIZE - 5, PATH_Y)
            love.graphics.setLineWidth(1)
        end

        if level.unlocked then
            if isSelected then
                love.graphics.setColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25)
                love.graphics.circle("fill", lx, PATH_Y, NODE_SIZE + 10)
                love.graphics.setColor(col[1], col[2], col[3])
                love.graphics.circle("fill", lx, PATH_Y, NODE_SIZE)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle("line", lx, PATH_Y, NODE_SIZE)
            else
                love.graphics.setColor(col[1] * 0.6, col[2] * 0.6, col[3] * 0.6)
                love.graphics.circle("fill", lx, PATH_Y, NODE_SIZE)
                love.graphics.setColor(col[1], col[2], col[3])
                love.graphics.circle("line", lx, PATH_Y, NODE_SIZE)
            end

            local idFont = love.graphics.newFont(18)
            love.graphics.setFont(idFont)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(level.id, lx - NODE_SIZE, PATH_Y - 10, NODE_SIZE * 2, "center")

            local nameFont = love.graphics.newFont(12)
            love.graphics.setFont(nameFont)
            love.graphics.setColor(0.7, 0.75, 0.8)
            love.graphics.printf(level.name, lx - 50, PATH_Y + NODE_SIZE + 8, 100, "center")
        else
            love.graphics.setColor(0.15, 0.15, 0.18)
            love.graphics.circle("fill", lx, PATH_Y, NODE_SIZE)
            love.graphics.setColor(0.25, 0.25, 0.3)
            love.graphics.circle("line", lx, PATH_Y, NODE_SIZE)

            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.printf("?", lx - NODE_SIZE, PATH_Y - 10, NODE_SIZE * 2, "center")

            local nameFont = love.graphics.newFont(12)
            love.graphics.setFont(nameFont)
            love.graphics.setColor(0.35, 0.35, 0.4)
            love.graphics.printf(level.name, lx - 50, PATH_Y + NODE_SIZE + 8, 100, "center")
        end
    end

    local selLevel = zone.levels[selectedNode]
    if selLevel and selLevel.unlocked then
        local infoY = screenH - 70
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", screenW / 2 - 160, infoY - 8, 320, 50, 8, 8)

        local infoFont = love.graphics.newFont(16)
        love.graphics.setFont(infoFont)
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.printf(selLevel.id .. " - " .. selLevel.name, screenW / 2 - 150, infoY, 300, "center")

        local hintFont = love.graphics.newFont(11)
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.printf("Presiona Enter para jugar", screenW / 2 - 150, infoY + 22, 300, "center")
    end

    local navFont = love.graphics.newFont(13)
    love.graphics.setFont(navFont)
    love.graphics.setColor(0.5, 0.55, 0.6)
    love.graphics.printf("Click en icono: Cambiar zona  |  A/D: Mover  |  Enter: Jugar  |  Escape: Volver", 0, screenH - 30, screenW, "center")
end

function MapSelectionScene.keypressed(key)
    local rows = #zones[currentZone].levels
    local cols = #zones

    if key == "escape" then
        SceneManager.switch("menu")
        return
    end

    if key == "d" or key == "right" then
        selectedNode = math.min(rows, selectedNode + 1)
    elseif key == "a" or key == "left" then
        selectedNode = math.max(1, selectedNode - 1)
    elseif key == "q" then
        currentZone = math.max(1, currentZone - 1)
        selectedNode = 1
    elseif key == "e" then
        currentZone = math.min(cols, currentZone + 1)
        selectedNode = 1
    elseif key == "return" or key == "space" then
        local zone = zones[currentZone]
        local level = zone.levels[selectedNode]
        if level.unlocked then
            selectedWorld = currentZone
            selectedLevel = selectedNode
            SceneManager.switch("game")
        end
        return
    end
end

function MapSelectionScene.keyreleased(key)
end

function MapSelectionScene.wheelmoved(x, y)
    if y > 0 then
        currentZone = math.max(1, currentZone - 1)
        selectedNode = 1
    elseif y < 0 then
        currentZone = math.min(#zones, currentZone + 1)
        selectedNode = 1
    end
end

function MapSelectionScene.mousepressed(x, y, button)
    if button == 1 then
        local selectorY = 80
        local selectorBtnSize = 50
        local totalSelectorW = #zones * (selectorBtnSize + 12)
        local selectorStartX = love.graphics.getWidth() / 2 - totalSelectorW / 2

        for zi, z in ipairs(zones) do
            local zx = selectorStartX + (zi - 1) * (selectorBtnSize + 12) + selectorBtnSize / 2
            local zy = selectorY + selectorBtnSize / 2
            local dx = x - zx
            local dy = y - zy
            if math.abs(dx) <= selectorBtnSize / 2 + 5 and math.abs(dy) <= selectorBtnSize / 2 + 5 then
                currentZone = zi
                selectedNode = 1
                return
            end
        end

        local zone = zones[currentZone]
        local screenW = love.graphics.getWidth()
        local totalPathW = (#zone.levels - 1) * NODE_SPACING
        local pathStartX = screenW / 2 - totalPathW / 2

        for li, level in ipairs(zone.levels) do
            local lx = pathStartX + (li - 1) * NODE_SPACING
            local dx = x - lx
            local dy = y - PATH_Y
            if math.sqrt(dx * dx + dy * dy) <= NODE_SIZE + 5 then
                selectedNode = li
                if level.unlocked then
                    selectedWorld = currentZone
                    selectedLevel = li
                    SceneManager.switch("game")
                end
                return
            end
        end
    end
end

function MapSelectionScene.mousereleased(x, y, button)
end

function MapSelectionScene.getSelectedWorld()
    return selectedWorld
end

function MapSelectionScene.getSelectedLevel()
    return selectedLevel
end

return MapSelectionScene
