
local game = require("game")

function love.load()
    game.init()

    -- These values were aquired from a default Spectacle layout
    -- for convenient development
    -- love.window.setMode(560, 949)
    -- love.window.setPosition(1120, 45)

    game.loadLevel(game.levels.expr9)
end
