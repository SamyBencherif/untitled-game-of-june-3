
local game = require("game")

function love.load()
    game.init()
    game.loadLevel(game.levels.expr5)
end
