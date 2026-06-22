function love.conf(t)
    t.identity = "love2d_project"
    t.version = "11.4"

    t.window.title = "Love2D Project"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 400
    t.window.minheight = 300

    t.modules.joystick = false
    t.modules.physics = false
end
