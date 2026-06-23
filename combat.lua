local Combat = {}

function Combat.checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function Combat.resolveAttack(player, enemies, boss, chargedDamage)
    local hitbox = player:getAttackHitbox()
    if not hitbox then return {} end

    local hitEnemies = {}
    for _, enemy in ipairs(enemies) do
        if enemy.alive and not player.hitEnemiesThisSwing[enemy] and Combat.checkCollision(hitbox, enemy) then
            player.hitEnemiesThisSwing[enemy] = true
            local kbx = 0
            local kby = 0
            local dx = enemy.x - player.x
            local dy = enemy.y - player.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                kbx = (dx / dist) * 25
                kby = (dy / dist) * 25
            end

            local baseDmg = chargedDamage or math.floor(player.attackDamage + love.math.random(0, 1))
            local isCrit = math.random() < player.critChance
            local dmg = baseDmg
            if isCrit then
                dmg = math.floor(baseDmg * player.critMultiplier)
            end

            enemy:takeDamage(dmg, kbx, kby)
            table.insert(hitEnemies, {enemy = enemy, damage = dmg, isCrit = isCrit})
        end
    end

    if boss and boss.alive and not boss.introActive and not player.hitEnemiesThisSwing[boss] and Combat.checkCollision(hitbox, boss) then
        player.hitEnemiesThisSwing[boss] = true
        local kbx = 0
        local kby = 0
        local dx = boss.x - player.x
        local dy = boss.y - player.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            kbx = (dx / dist) * 25
            kby = (dy / dist) * 25
        end

        local baseDmg = chargedDamage or math.floor(player.attackDamage + love.math.random(0, 1))
        local isCrit = math.random() < player.critChance
        local dmg = baseDmg
        if isCrit then
            dmg = math.floor(baseDmg * player.critMultiplier)
        end

        boss:takeDamage(dmg, kbx, kby)
        table.insert(hitEnemies, {enemy = boss, damage = dmg, isCrit = isCrit})
    end

    return hitEnemies
end

function Combat.checkEnemyAttacks(player, enemies)
    local totalDamage = 0
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            if enemy.state == "charge_attack" then
                local dx = player.x + player.width / 2 - (enemy.x + enemy.width / 2)
                local dy = player.y + player.height / 2 - (enemy.y + enemy.height / 2)
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < enemy.attackRange + 40 then
                    local chargeDmg = math.random(3, 10)
                    totalDamage = totalDamage + chargeDmg
                    enemy.state = "chase"
                    enemy.isCharging = false
                end
            elseif enemy:canAttack() then
                local dx = player.x + player.width / 2 - (enemy.x + enemy.width / 2)
                local dy = player.y + player.height / 2 - (enemy.y + enemy.height / 2)
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < enemy.attackRange + 20 then
                    totalDamage = totalDamage + enemy:doAttack()
                end
            end
        end
    end
    return totalDamage
end

return Combat
