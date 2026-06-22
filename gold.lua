local Gold = {}
Gold.__index = Gold

local PICKUP_RANGE = 60
local FLOAT_SPEED = 2
local ATTRACT_SPEED = 200

function Gold.new(x, y, amount)
    local self = setmetatable({}, Gold)
    self.x = x
    self.y = y
    self.amount = amount or 1
    self.width = 16
    self.height = 16
    self.alive = true
    self.spawnTimer = 0.3
    self.bobTimer = 0
    self.bobOffset = 0
    return self
end

function Gold:update(dt, playerX, playerY)
    if self.spawnTimer > 0 then
        self.spawnTimer = self.spawnTimer - dt
        return
    end

    self.bobTimer = self.bobTimer + dt
    self.bobOffset = math.sin(self.bobTimer * FLOAT_SPEED) * 3

    local dx = playerX - self.x
    local dy = playerY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < PICKUP_RANGE then
        local nx = dx / dist
        local ny = dy / dist
        self.x = self.x + nx * ATTRACT_SPEED * dt
        self.y = self.y + ny * ATTRACT_SPEED * dt
    end

    if dist < 30 then
        self.alive = false
        return self.amount
    end

    return 0
end

function Gold:draw()
    if self.spawnTimer > 0 then return end

    local drawY = self.y + self.bobOffset

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.ellipse("fill", self.x, self.y + 10, 10, 4)

    love.graphics.setColor(0.15, 0.1, 0.05)
    love.graphics.circle("fill", self.x, drawY + 1, 9)
    love.graphics.circle("fill", self.x, drawY - 1, 9)

    love.graphics.setColor(1, 0.85, 0.1)
    love.graphics.circle("fill", self.x, drawY, 9)

    love.graphics.setColor(1, 0.95, 0.5)
    love.graphics.circle("fill", self.x - 1, drawY - 2, 4)

    love.graphics.setColor(0.85, 0.65, 0.05)
    love.graphics.circle("line", self.x, drawY, 9)
end

return Gold
