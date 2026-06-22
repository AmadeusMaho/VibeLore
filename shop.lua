local Inventory = require("inventory")

local Shop = {}

local isOpen = false
local selectedIndex = 1
local shopFont, shopFontSmall, shopFontTitle
local notification = nil
local notifTimer = 0
local soldItems = {}

local shopItems = {
    {
        id = "sword_plus2",
        name = "Espada de Hierro +2",
        type = "Arma",
        description = "Una espada forjada con hierro temperado. Otorga bonus de ataque.",
        color = { 0.7, 0.5, 0.3 },
        damage = 2,
        equipSlot = "weapon",
        rarity = "unusual",
        price = 5,
    },
}

local function getAvailableItems()
    local available = {}
    for _, item in ipairs(shopItems) do
        if not soldItems[item.id] then
            table.insert(available, item)
        end
    end
    return available
end

function Shop.load()
    shopFont = love.graphics.newFont(14)
    shopFontSmall = love.graphics.newFont(11)
    shopFontTitle = love.graphics.newFont(20)
    isOpen = false
    selectedIndex = 1
    notification = nil
    notifTimer = 0
    soldItems = {}
end

function Shop.toggle()
    isOpen = not isOpen
    if isOpen then
        selectedIndex = 1
    end
end

function Shop.getIsOpen()
    return isOpen
end

function Shop.notify(msg)
    notification = msg
    notifTimer = 2.5
end

function Shop.update(dt)
    if notifTimer > 0 then
        notifTimer = notifTimer - dt
        if notifTimer <= 0 then
            notification = nil
        end
    end
end

function Shop.buyItem(item, goldCount)
    if not item then return goldCount, false end

    if goldCount < item.price then
        Shop.notify("No tienes suficiente oro!")
        return goldCount, false
    end

    local bought = {
        id = item.id,
        name = item.name,
        type = item.type,
        description = item.description,
        color = item.color,
        damage = item.damage,
        armor = item.armor,
        hp = item.hp,
        equipSlot = item.equipSlot,
        rarity = item.rarity,
        stackable = false,
    }

    if Inventory.addItem(bought) then
        goldCount = goldCount - item.price
        soldItems[item.id] = true
        Shop.notify("Compraste: " .. item.name)
        return goldCount, true
    else
        Shop.notify("Inventario lleno!")
        return goldCount, false
    end
end

function Shop.keypressed(key, goldCount)
    if not isOpen then return goldCount end

    local available = getAvailableItems()
    local count = #available

    if count == 0 then
        if key == "m" or key == "tab" or key == "escape" then
            isOpen = false
        end
        return goldCount
    end

    if key == "up" or key == "w" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then selectedIndex = count end
    elseif key == "down" or key == "s" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > count then selectedIndex = 1 end
    elseif key == "return" or key == "space" then
        local item = available[selectedIndex]
        if item then
            goldCount = Shop.buyItem(item, goldCount)
            local newAvailable = getAvailableItems()
            if #newAvailable == 0 then
                selectedIndex = 1
            elseif selectedIndex > #newAvailable then
                selectedIndex = #newAvailable
            end
        end
    elseif key == "m" or key == "tab" or key == "escape" then
        isOpen = false
    end

    return goldCount
end

function Shop.draw(goldCount)
    if not isOpen then
        if notification and notifTimer > 0 then
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            local alpha = math.min(1, notifTimer)
            love.graphics.setFont(shopFont)
            love.graphics.setColor(1, 0.85, 0.3, alpha)
            love.graphics.printf(notification, 0, 40, w, "center")
        end
        return
    end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local available = getAvailableItems()
    local count = #available

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local panelW = 520
    local panelH = 380
    local panelX = w / 2 - panelW / 2
    local panelY = h / 2 - panelH / 2

    love.graphics.setColor(0.1, 0.08, 0.06, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.3, 0.25, 0.15, 1)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)

    love.graphics.setFont(shopFontTitle)
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.printf("TIENDA", panelX, panelY + 15, panelW, "center")

    love.graphics.setFont(shopFontSmall)
    love.graphics.setColor(0.8, 0.7, 0.3)
    love.graphics.printf("Oro: " .. goldCount, panelX, panelY + 50, panelW, "center")

    if count == 0 then
        love.graphics.setFont(shopFont)
        love.graphics.setColor(0.45, 0.4, 0.35)
        love.graphics.printf("No hay existencias", panelX, panelY + 150, panelW, "center")
    else
        local listX = panelX + 20
        local listY = panelY + 80
        local itemH = 60
        local gap = 10

        for i, item in ipairs(available) do
            local iy = listY + (i - 1) * (itemH + gap)
            local hover = (i == selectedIndex)

            if hover then
                love.graphics.setColor(0.2, 0.18, 0.12, 1)
            else
                love.graphics.setColor(0.15, 0.12, 0.08, 1)
            end
            love.graphics.rectangle("fill", listX, iy, panelW - 40, itemH, 6, 6)

            if hover then
                love.graphics.setColor(0.5, 0.4, 0.2, 1)
            else
                love.graphics.setColor(0.3, 0.25, 0.15, 1)
            end
            love.graphics.rectangle("line", listX, iy, panelW - 40, itemH, 6, 6)

            if item.color then
                love.graphics.setColor(item.color[1], item.color[2], item.color[3], 1)
                love.graphics.rectangle("fill", listX + 10, iy + 10, 40, 40, 4, 4)
            end

            love.graphics.setFont(shopFont)
            if goldCount >= item.price then
                love.graphics.setColor(0.9, 0.85, 0.7)
            else
                love.graphics.setColor(0.5, 0.3, 0.3)
            end
            love.graphics.printf(item.name, listX + 60, iy + 8, 250, "left")

            love.graphics.setFont(shopFontSmall)
            love.graphics.setColor(0.6, 0.55, 0.4)
            love.graphics.printf(item.description, listX + 60, iy + 30, 250, "left")

            love.graphics.setFont(shopFont)
            if item.damage then
                love.graphics.setColor(0.8, 0.3, 0.3)
                love.graphics.printf("+" .. item.damage .. " ATK", listX + 320, iy + 8, 60, "left")
            end

            love.graphics.setColor(0.9, 0.8, 0.3)
            love.graphics.printf(item.price .. " oro", listX + 390, iy + 8, 80, "right")

            if hover then
                love.graphics.setColor(1, 1, 0.6)
                love.graphics.setFont(shopFontSmall)
                love.graphics.printf("[ENTER] Comprar", listX + 320, iy + 32, 150, "center")
            end
        end
    end

    love.graphics.setFont(shopFontSmall)
    love.graphics.setColor(0.5, 0.45, 0.35)
    love.graphics.printf("W/S: Navegar | ENTER: Comprar | TAB/M: Cerrar", 0, panelY + panelH - 25, panelW, "center")

    if notification and notifTimer > 0 then
        local alpha = math.min(1, notifTimer)
        love.graphics.setFont(shopFont)
        love.graphics.setColor(1, 0.85, 0.3, alpha)
        love.graphics.printf(notification, 0, panelY - 30, w, "center")
    end
end

return Shop
