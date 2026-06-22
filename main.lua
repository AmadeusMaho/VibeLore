local SceneManager = require("scene_manager")
local MenuScene = require("menu_scene")
local GameScene = require("game_scene")

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    love.window.setTitle("Heroes Lore - Clone")

    SceneManager.register("menu", MenuScene)
    SceneManager.register("game", GameScene)
    SceneManager.switch("menu")
end

function love.update(dt)
    SceneManager.update(dt)
end

function love.draw()
    SceneManager.draw()
end

function love.keypressed(key)
    SceneManager.keypressed(key)
end

function love.keyreleased(key)
    SceneManager.keyreleased(key)
end

function love.mousepressed(x, y, button)
    SceneManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    if SceneManager.currentScene and SceneManager.currentScene.mousereleased then
        SceneManager.currentScene.mousereleased(x, y, button)
    end
end
