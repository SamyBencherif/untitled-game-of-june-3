
local game = require("game")

function love.load()
    game.init()

    -- These values were aquired from a default Spectacle layout
    -- for convenient development
    -- width = 560, height=949, x=1120, y=45

    love.window.setMode(560, 949)
    love.window.setPosition(1120, 45)
    game.loadLevel(game.levels.expr8)
end
