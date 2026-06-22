local Inventory = {}

local MAX_SLOTS = 20
local COLS = 5
local SLOT_SIZE = 64
local SLOT_PAD = 8

local items = {}
local equipment = {
    helmet = nil,
    armor = nil,
    boots = nil,
    ring1 = nil,
    ring2 = nil,
    amulet = nil,
    gloves = nil,
}

local isOpen = false
local selectedSlot = nil
local activeTab = "inventory"
local invFont, invFontSmall, invFontTitle
local openSound, closeSound

local RARITY_COLORS = {
    normal   = { 0.55, 0.55, 0.55 },
    unusual  = { 0.3, 0.8, 0.3 },
    rare     = { 0.3, 0.5, 0.9 },
    epic     = { 0.6, 0.3, 0.8 },
    legendary= { 0.9, 0.6, 0.1 },
    mythic   = { 0.9, 0.35, 0.6 },
    ascended = { 0.85, 0.8, 0.65 },
}

local EQUIP_SLOTS = {
    { id = "helmet",  label = "Casco",    icon = "hat",     x = 0, y = 0 },
    { id = "armor",   label = "Armadura", icon = "chest",   x = 0, y = 0 },
    { id = "gloves",  label = "Guantes",  icon = "hand",    x = 0, y = 0 },
    { id = "amulet",  label = "Amuleto",  icon = "diamond", x = 0, y = 0 },
    { id = "ring1",   label = "Anillo 1", icon = "ring",    x = 0, y = 0 },
    { id = "ring2",   label = "Anillo 2", icon = "ring",    x = 0, y = 0 },
    { id = "boots",   label = "Botas",    icon = "boot",    x = 0, y = 0 },
}

function Inventory.load()
    invFont = love.graphics.newFont(18)
    invFontSmall = love.graphics.newFont(12)
    invFontTitle = love.graphics.newFont(24)

    local ok1, s1 = pcall(love.audio.newSource, "sounds/openinv.wav", "static")
    if ok1 then openSound = s1 end
    local ok2, s2 = pcall(love.audio.newSource, "sounds/closinginv.wav", "static")
    if ok2 then closeSound = s2 end

    items = {}
    for k in pairs(equipment) do equipment[k] = nil end
    isOpen = false
    selectedSlot = nil
    activeTab = "inventory"

    Inventory.addItem({
        id = "test_armor_1",
        name = "Pechera de Hierro",
        type = "Armadura",
        description = "Una armadura basica forjada con hierro.",
        color = { 0.5, 0.5, 0.55 },
        armor = 1,
        equipSlot = "armor",
        rarity = "normal",
        stackable = false,
    })
end

function Inventory.addItem(item)
    if #items >= MAX_SLOTS then return false end
    for i, existing in ipairs(items) do
        if existing.id == item.id and existing.stackable then
            existing.count = (existing.count or 1) + (item.count or 1)
            return true
        end
    end
    if not item.rarity then item.rarity = "normal" end
    item.count = item.count or 1
    items[#items + 1] = item
    return true
end

function Inventory.equipItem(item, slotId)
    if not equipment[slotId] then
        equipment[slotId] = item
        return true
    end
    return false
end

function Inventory.unequipItem(slotId)
    if equipment[slotId] then
        local item = equipment[slotId]
        equipment[slotId] = nil
        if #items < MAX_SLOTS then
            items[#items + 1] = item
        end
        return true
    end
    return false
end

function Inventory.getEquipment()
    return equipment
end

function Inventory.getStatBonus(stat)
    local bonus = 0
    for _, item in pairs(equipment) do
        if item then
            if stat == "damage" and item.damage then bonus = bonus + item.damage end
            if stat == "armor" and item.armor then bonus = bonus + item.armor end
            if stat == "hp" and item.hp then bonus = bonus + item.hp end
        end
    end
    return bonus
end

function Inventory.removeItem(index)
    if index < 1 or index > #items then return false end
    table.remove(items, index)
    if selectedSlot == index then
        selectedSlot = nil
    elseif selectedSlot and selectedSlot > index then
        selectedSlot = selectedSlot - 1
    end
    return true
end

function Inventory.toggle()
    isOpen = not isOpen
    if isOpen then
        if openSound then openSound:play() end
    else
        if closeSound then closeSound:play() end
        selectedSlot = nil
        activeTab = "inventory"
    end
end

function Inventory.getIsOpen()
    return isOpen
end

function Inventory.getItems()
    return items
end

function Inventory.getCount()
    return #items
end

function Inventory.getMaxSlots()
    return MAX_SLOTS
end

function Inventory.setActiveTab(tab)
    activeTab = tab
    selectedSlot = nil
end

function Inventory.getActiveTab()
    return activeTab
end

local function getRarityColor(rarity)
    return RARITY_COLORS[rarity] or RARITY_COLORS.normal
end

local function drawSlotBorder(x, y, w, h, rarity, isSelected)
    local rc = getRarityColor(rarity)
    if isSelected then
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        love.graphics.rectangle("line", x - 1, y - 1, w + 2, h + 2, 5, 5)
        love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, 6, 6)
    else
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.8)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
    end
end

local function drawSlotIcon(x, y, size, iconType)
    local cx = x + size / 2
    local cy = y + size / 2
    local s = size * 0.3

    if iconType == "hat" then
        love.graphics.setColor(0.5, 0.5, 0.55, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.7, cy - s * 0.9, s * 1.4, s * 1.0, 4, 4)
        love.graphics.setColor(0.4, 0.4, 0.45, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.8, cy + s * 0.0, s * 1.6, s * 0.3, 2, 2)
        love.graphics.setColor(0.2, 0.2, 0.25, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.4, cy - s * 0.6, s * 0.8, s * 0.15)
        love.graphics.rectangle("fill", cx - s * 0.2, cy - s * 0.2, s * 0.4, s * 0.5, 1, 1)
    elseif iconType == "chest" then
        love.graphics.setColor(0.4, 0.35, 0.25, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.7, cy - s * 0.8, s * 1.4, s * 1.6, 4, 4)
        love.graphics.setColor(0.3, 0.25, 0.15, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.5, cy - s * 0.3, s, s * 0.15)
    elseif iconType == "hand" then
        love.graphics.setColor(0.4, 0.35, 0.25, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.5, cy - s * 0.6, s, s * 1.2, 4, 4)
        love.graphics.rectangle("fill", cx - s * 0.7, cy - s * 0.6, s * 0.3, s * 0.5, 2, 2)
        love.graphics.rectangle("fill", cx + s * 0.4, cy - s * 0.6, s * 0.3, s * 0.5, 2, 2)
    elseif iconType == "diamond" then
        love.graphics.setColor(0.5, 0.4, 0.6, 0.5)
        love.graphics.polygon("fill", cx, cy - s, cx + s * 0.6, cy, cx, cy + s, cx - s * 0.6, cy)
    elseif iconType == "ring" then
        love.graphics.setColor(0.5, 0.45, 0.2, 0.5)
        love.graphics.circle("line", cx, cy, s * 0.6)
        love.graphics.circle("line", cx, cy, s * 0.4)
        love.graphics.setColor(0.6, 0.2, 0.2, 0.5)
        love.graphics.circle("fill", cx, cy - s * 0.5, s * 0.18)
    elseif iconType == "boot" then
        love.graphics.setColor(0.4, 0.35, 0.25, 0.5)
        love.graphics.rectangle("fill", cx - s * 0.4, cy - s * 0.7, s * 0.8, s * 1.0, 3, 3)
        love.graphics.rectangle("fill", cx - s * 0.5, cy + s * 0.2, s * 1.0, s * 0.4, 2, 2)
    end
end

function Inventory.mousepressed(mx, my)
    if not isOpen then return false end
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local tabW = 160
    local tabH = 30
    local tabY = screenH / 2 - 230
    if my >= tabY and my <= tabY + tabH then
        if mx >= screenW / 2 - tabW and mx <= screenW / 2 then
            activeTab = "inventory"
            selectedSlot = nil
            return true
        elseif mx >= screenW / 2 and mx <= screenW / 2 + tabW then
            activeTab = "equipment"
            selectedSlot = nil
            return true
        end
    end

    if activeTab == "inventory" then
        local totalCols = COLS
        local totalRows = math.ceil(MAX_SLOTS / totalCols)
        local gridW = totalCols * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
        local gridH = totalRows * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
        local startX = screenW / 2 - gridW / 2
        local startY = screenH / 2 - gridH / 2 + 10

        for i = 1, MAX_SLOTS do
            local col = (i - 1) % totalCols
            local row = math.floor((i - 1) / totalCols)
            local sx = startX + col * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
            local sy = startY + row * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
            if mx >= sx and mx <= sx + SLOT_SIZE and my >= sy and my <= sy + SLOT_SIZE then
                if selectedSlot == i and items[i] and items[i].equipSlot then
                    if Inventory.equipItem(items[i], items[i].equipSlot) then
                        table.remove(items, i)
                        selectedSlot = nil
                    end
                else
                    selectedSlot = i
                end
                return true
            end
        end
    elseif activeTab == "equipment" then
        local equipSlotW = 80
        local equipSlotH = 80
        local equipPad = 14

        local panelW = equipSlotW * 3 + equipPad * 2 + 50
        local panelH = equipSlotH * 4 + equipPad * 3 + 70
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        local equipStartX = panelX + 25
        local equipStartY = panelY + 40

        local layout = {
            { id = "helmet",  gx = 1, gy = 0 },
            { id = "armor",   gx = 1, gy = 1 },
            { id = "gloves",  gx = 0, gy = 1 },
            { id = "amulet",  gx = 2, gy = 1 },
            { id = "ring1",   gx = 0, gy = 2 },
            { id = "ring2",   gx = 2, gy = 2 },
            { id = "boots",   gx = 1, gy = 3 },
        }

        for _, slot in ipairs(layout) do
            local sx = equipStartX + slot.gx * (equipSlotW + equipPad)
            local sy = equipStartY + slot.gy * (equipSlotH + equipPad)
            if mx >= sx and mx <= sx + equipSlotW and my >= sy and my <= sy + equipSlotH then
                if selectedSlot == slot.id and equipment[slot.id] then
                    Inventory.unequipItem(slot.id)
                    selectedSlot = nil
                else
                    selectedSlot = slot.id
                end
                return true
            end
        end
    end

    selectedSlot = nil
    return true
end

function Inventory.draw()
    if not isOpen then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setFont(invFontTitle)
    local tabW = 160
    local tabH = 30
    local tabY = screenH / 2 - 230

    local function drawTab(label, isActive, tx)
        if isActive then
            love.graphics.setColor(0.18, 0.15, 0.1, 0.95)
        else
            love.graphics.setColor(0.1, 0.08, 0.06, 0.8)
        end
        love.graphics.rectangle("fill", tx, tabY, tabW, tabH, 6, 6)
        love.graphics.setColor(0.25, 0.2, 0.12, 1)
        love.graphics.rectangle("line", tx, tabY, tabW, tabH, 6, 6)
        if isActive then
            love.graphics.setColor(0.9, 0.8, 0.5)
        else
            love.graphics.setColor(0.5, 0.45, 0.35)
        end
        love.graphics.printf(label, tx, tabY + 4, tabW, "center")
    end

    drawTab("Inventario", activeTab == "inventory", screenW / 2 - tabW)
    drawTab("Equipamiento", activeTab == "equipment", screenW / 2)

    if activeTab == "inventory" then
        local totalCols = COLS
        local totalRows = math.ceil(MAX_SLOTS / totalCols)
        local gridW = totalCols * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
        local gridH = totalRows * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
        local startX = screenW / 2 - gridW / 2
        local startY = screenH / 2 - gridH / 2 + 10

        love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
        love.graphics.rectangle("fill", startX - 12, startY - 10, gridW + 24, gridH + 20, 8, 8)
        love.graphics.setColor(0.25, 0.2, 0.12, 1)
        love.graphics.rectangle("line", startX - 12, startY - 10, gridW + 24, gridH + 20, 8, 8)

        for i = 1, MAX_SLOTS do
            local col = (i - 1) % totalCols
            local row = math.floor((i - 1) / totalCols)
            local sx = startX + col * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
            local sy = startY + row * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD

            love.graphics.setColor(0.18, 0.15, 0.1, 0.9)
            love.graphics.rectangle("fill", sx, sy, SLOT_SIZE, SLOT_SIZE, 4, 4)
            love.graphics.setColor(0.35, 0.28, 0.15, 1)
            love.graphics.rectangle("line", sx, sy, SLOT_SIZE, SLOT_SIZE, 4, 4)

            if items[i] then
                local item = items[i]
                drawSlotBorder(sx, sy, SLOT_SIZE, SLOT_SIZE, item.rarity, i == selectedSlot)

                if item.color then
                    love.graphics.setColor(item.color[1], item.color[2], item.color[3], 1)
                    love.graphics.rectangle("fill", sx + 16, sy + 10, 32, 32, 4, 4)
                end
                if item.equipSlot then
                    love.graphics.setColor(0.3, 0.7, 0.3, 0.8)
                    love.graphics.rectangle("fill", sx + SLOT_SIZE - 14, sy + 2, 12, 12, 2, 2)
                end
                love.graphics.setFont(invFontSmall)
                love.graphics.setColor(0.9, 0.85, 0.7)
                local name = item.name or "?"
                if #name > 8 then name = name:sub(1, 7) .. "." end
                love.graphics.printf(name, sx, sy + SLOT_SIZE - 14, SLOT_SIZE, "center")
                if item.count and item.count > 1 then
                    love.graphics.setColor(1, 1, 0.6)
                    love.graphics.printf("x" .. item.count, sx + SLOT_SIZE - 18, sy + 2, 16, "right")
                end
            end
        end

        if selectedSlot and type(selectedSlot) == "number" and items[selectedSlot] then
            local item = items[selectedSlot]
            local tipX = startX + gridW + 30
            local tipY = startY
            local tipW = 200

            love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
            love.graphics.rectangle("fill", tipX, tipY, tipW, 170, 6, 6)
            local rc = getRarityColor(item.rarity)
            love.graphics.setColor(rc[1], rc[2], rc[3], 1)
            love.graphics.rectangle("line", tipX, tipY, tipW, 170, 6, 6)

            love.graphics.setFont(invFont)
            love.graphics.setColor(rc[1], rc[2], rc[3], 1)
            love.graphics.printf(item.name or "???", tipX + 8, tipY + 8, tipW - 16, "left")

            love.graphics.setFont(invFontSmall)
            love.graphics.setColor(0.6, 0.55, 0.4)
            local rarityName = item.rarity or "normal"
            rarityName = rarityName:sub(1, 1):upper() .. rarityName:sub(2)
            love.graphics.printf(rarityName, tipX + 8, tipY + 30, tipW - 16, "left")

            if item.type then
                love.graphics.setColor(0.6, 0.55, 0.4)
                love.graphics.printf("Tipo: " .. item.type, tipX + 8, tipY + 46, tipW - 16, "left")
            end

            if item.description then
                love.graphics.setColor(0.75, 0.7, 0.55)
                love.graphics.printf(item.description, tipX + 8, tipY + 64, tipW - 16, "left")
            end

            local statY = tipY + 96
            if item.damage then
                love.graphics.setColor(0.8, 0.3, 0.3)
                love.graphics.printf("+" .. item.damage .. " ATK", tipX + 8, statY, tipW - 16, "left")
                statY = statY + 16
            end
            if item.armor then
                love.graphics.setColor(0.3, 0.5, 0.8)
                love.graphics.printf("+" .. item.armor .. " DEF", tipX + 8, statY, tipW - 16, "left")
                statY = statY + 16
            end
            if item.hp then
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.printf("+" .. item.hp .. " HP", tipX + 8, statY, tipW - 16, "left")
                statY = statY + 16
            end
            if item.equipSlot then
                love.graphics.setColor(0.4, 0.8, 0.4)
                love.graphics.printf("Click: Equipar", tipX + 8, statY, tipW - 16, "left")
            end
        end
    elseif activeTab == "equipment" then
        local equipSlotW = 80
        local equipSlotH = 80
        local equipPad = 14

        local panelW = equipSlotW * 3 + equipPad * 2 + 50
        local panelH = equipSlotH * 4 + equipPad * 3 + 70
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        local equipStartX = panelX + 25
        local equipStartY = panelY + 40

        love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
        love.graphics.setColor(0.25, 0.2, 0.12, 1)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

        love.graphics.setFont(invFont)
        love.graphics.setColor(0.85, 0.75, 0.5)
        love.graphics.printf("EQUIPAMIENTO", panelX, panelY + 10, panelW, "center")

        local layout = {
            { id = "helmet",  gx = 1, gy = 0 },
            { id = "armor",   gx = 1, gy = 1 },
            { id = "gloves",  gx = 0, gy = 1 },
            { id = "amulet",  gx = 2, gy = 1 },
            { id = "ring1",   gx = 0, gy = 2 },
            { id = "ring2",   gx = 2, gy = 2 },
            { id = "boots",   gx = 1, gy = 3 },
        }

        for _, slot in ipairs(layout) do
            local slotData = nil
            for _, s in ipairs(EQUIP_SLOTS) do
                if s.id == slot.id then slotData = s break end
            end
            local sx = equipStartX + slot.gx * (equipSlotW + equipPad)
            local sy = equipStartY + slot.gy * (equipSlotH + equipPad)

            love.graphics.setColor(0.18, 0.15, 0.1, 0.9)
            love.graphics.rectangle("fill", sx, sy, equipSlotW, equipSlotH, 6, 6)
            love.graphics.setColor(0.35, 0.28, 0.15, 1)
            love.graphics.rectangle("line", sx, sy, equipSlotW, equipSlotH, 6, 6)

            if slotData then
                drawSlotIcon(sx, sy, equipSlotW, slotData.icon)
                love.graphics.setFont(invFontSmall)
                love.graphics.setColor(0.5, 0.45, 0.35)
                love.graphics.printf(slotData.label, sx, sy + equipSlotH + 2, equipSlotW, "center")
            end

            if equipment[slot.id] then
                local item = equipment[slot.id]
                drawSlotBorder(sx, sy, equipSlotW, equipSlotH, item.rarity, selectedSlot == slot.id)

                if item.color then
                    love.graphics.setColor(item.color[1], item.color[2], item.color[3], 1)
                    love.graphics.rectangle("fill", sx + 16, sy + 10, 48, 42, 4, 4)
                end
                love.graphics.setFont(invFontSmall)
                love.graphics.setColor(0.9, 0.85, 0.7)
                local name = item.name or "?"
                if #name > 8 then name = name:sub(1, 7) .. "." end
                love.graphics.printf(name, sx, sy + equipSlotH - 14, equipSlotW, "center")
            end
        end

        if selectedSlot and equipment[selectedSlot] then
            local item = equipment[selectedSlot]
            local tipX = panelX + panelW + 20
            local tipY = panelY
            local tipW = 200

            love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
            love.graphics.rectangle("fill", tipX, tipY, tipW, 150, 6, 6)
            local rc = getRarityColor(item.rarity)
            love.graphics.setColor(rc[1], rc[2], rc[3], 1)
            love.graphics.rectangle("line", tipX, tipY, tipW, 150, 6, 6)

            love.graphics.setFont(invFont)
            love.graphics.setColor(rc[1], rc[2], rc[3], 1)
            love.graphics.printf(item.name or "???", tipX + 8, tipY + 8, tipW - 16, "left")

            if item.description then
                love.graphics.setFont(invFontSmall)
                love.graphics.setColor(0.75, 0.7, 0.55)
                love.graphics.printf(item.description, tipX + 8, tipY + 32, tipW - 16, "left")
            end

            local statY = tipY + 60
            if item.damage then
                love.graphics.setColor(0.8, 0.3, 0.3)
                love.graphics.printf("+" .. item.damage .. " ATK", tipX + 8, statY, tipW - 16, "left")
                statY = statY + 16
            end
            if item.armor then
                love.graphics.setColor(0.3, 0.5, 0.8)
                love.graphics.printf("+" .. item.armor .. " DEF", tipX + 8, statY, tipW - 16, "left")
                statY = statY + 16
            end
            if item.hp then
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.printf("+" .. item.hp .. " HP", tipX + 8, statY, tipW - 16, "left")
                statY = statY + 16
            end
            love.graphics.setColor(0.8, 0.4, 0.4)
            love.graphics.printf("Click: Desequipar", tipX + 8, statY, tipW - 16, "left")
        end
    end

    love.graphics.setFont(invFontSmall)
    love.graphics.setColor(0.5, 0.45, 0.35)
    love.graphics.printf("TAB: Cerrar | Click: Seleccionar/Equipar", 0, screenH - 30, screenW, "center")
end

return Inventory
