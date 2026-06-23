local SceneManager = {}
SceneManager.scenes = {}
SceneManager.currentScene = nil

function SceneManager.register(name, scene)
    SceneManager.scenes[name] = scene
end

function SceneManager.switch(name)
    if SceneManager.currentScene and SceneManager.currentScene.exit then
        SceneManager.currentScene.exit()
    end

    SceneManager.currentScene = SceneManager.scenes[name]
    if SceneManager.currentScene and SceneManager.currentScene.enter then
        SceneManager.currentScene.enter()
    end
end

function SceneManager.update(dt)
    if SceneManager.currentScene and SceneManager.currentScene.update then
        SceneManager.currentScene.update(dt)
    end
end

function SceneManager.draw()
    if SceneManager.currentScene and SceneManager.currentScene.draw then
        SceneManager.currentScene.draw()
    end
end

function SceneManager.keypressed(key)
    if SceneManager.currentScene and SceneManager.currentScene.keypressed then
        SceneManager.currentScene.keypressed(key)
    end
end

function SceneManager.keyreleased(key)
    if SceneManager.currentScene and SceneManager.currentScene.keyreleased then
        SceneManager.currentScene.keyreleased(key)
    end
end

function SceneManager.mousepressed(x, y, button)
    if SceneManager.currentScene and SceneManager.currentScene.mousepressed then
        SceneManager.currentScene.mousepressed(x, y, button)
    end
end

function SceneManager.wheelmoved(x, y)
    if SceneManager.currentScene and SceneManager.currentScene.wheelmoved then
        SceneManager.currentScene.wheelmoved(x, y)
    end
end

return SceneManager
