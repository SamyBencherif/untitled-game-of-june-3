
local game = require("game")

function love.load()
    game.init()
    game.loadLevel(game.levels.level1)
end
