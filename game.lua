------------------------                          ------------------------
----------------------    Untitled Game             ----------------------
----------------------                              ----------------------
----------------------          By Samy Bencherif   ----------------------
------------------------                          ------------------------

----   TABLE OF CONTENTS
----
----      1. IMPORTS
----      2. CONSTANTS
----         STATE
----         UTILITY
----         EVENTS
----         DEFINITIONS
----

-------------------------------            -------------------------------
-----------------------------  1. IMPORTS    -----------------------------
-------------------------------            -------------------------------

local sprites = require("packages/cargo").init("sprites")
local levels = require("packages/cargo").init("levels")

-------------------------------            -------------------------------
-----------------------------  2. CONSTANTS  -----------------------------
-------------------------------            -------------------------------

-- number of screen pixels per texture pixel
local texUPP = 5

-- number of physics units per texture pixel
local phyUPP = 10

-- player position on screen in texture pixels
function playerScrnX() return love.graphics.getWidth()/texUPP/2-3.5 end
function playerScrnY() return love.graphics.getHeight()/texUPP/2-5.5 end

-- gravity force
local gravity = 1000

-- reach distance in tex pix
local reach = 15

-------------------------------            -------------------------------  
-----------------------------     STATE      -----------------------------  
-------------------------------            -------------------------------  


local game = {
    blocks = {};
    entities = {}
}
-------------------------------            -------------------------------  
-----------------------------   UTILITY      -----------------------------  
-------------------------------            -------------------------------  

function renderFixtures(b)
    love.graphics.setColor(0,0,1)
    for i,f in pairs(b:getFixtures()) do
        local s = f:getShape()
        for x=0,10 do
            for y=0,10 do
                if s:testPoint( 0, 0, 0, (x+.5)*phyUPP, (y+.5)*phyUPP) then
                local p = phyToScr(b:getX(), b:getY())
                    love.graphics.rectangle( 'fill', p.x+x, p.y+y, 1, 1 )
                end
            end
        end
    end
    love.graphics.setColor(1,1,1)
end

function phyToScr(px,py) 
    return {
        x = px/phyUPP-game.player.body:getX()/phyUPP+playerScrnX();
        y = py/phyUPP-game.player.body:getY()/phyUPP+playerScrnY()
    }
end

function level_item(r, g, b, name)
    -- convert 0..1 to 0..255
    r = r * 255
    r = math.floor(r + .5)
    
    g = g * 255
    g = math.floor(g + .5)

    b = b * 255
    b = math.floor(b + .5)

    if r == 0 and g == 0 and b == 0 and name == "block" then return true end
    if r == 235 and g == 226 and b == 20 and name == "player" then return true end
    if r == 45 and g == 49 and b == 204 and name == "cube" then return true end
    if r == 204 and g == 154 and b == 45 and name == "button" then return true end
    if r == 255 and g == 255 and b == 255 and name == "empty" then return true end
    return false
end

function dist(x1,y1,x2,y2)
    return math.sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))
end

-------------------------------            -------------------------------  
-----------------------------     EVENTS     -----------------------------  
-------------------------------            -------------------------------  

function game.draw()
    love.graphics.scale(texUPP, texUPP)

    -- draw static blocks
    for i,b in pairs(game.blocks) do
        local pos = phyToScr(b:getX(), b:getY())
        love.graphics.draw(sprites.block, pos.x, pos.y)
    end

    -- draw entities
    for i,e in pairs(game.entities) do
        e.render(e)
    end

    -- draw the player (and overlays)
    game.player.render()
end

function game.input(dt)
    game.player.input()
end

function game.update(dt)
    game.world:update(dt)
    game.input(dt)
end

function game.init()
    -- set graphics parameters
    love.graphics.setBackgroundColor(1,1,1,1)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- create physics world
    game.world = love.physics.newWorld(0, gravity, true)
    game.world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    -- register delegate functions
    love.draw = game.draw
    love.update = game.update
    love.keypressed = game.keypressed

    -- create player
    local player_body = love.physics.newBody(game.world, 12*phyUPP, 20*phyUPP, "dynamic")
    local player_shape = love.physics.newRectangleShape(5.5*phyUPP, 5.5*phyUPP, 7*phyUPP, 11*phyUPP)
    local player_fixture = love.physics.newFixture(player_body, player_shape)
    player_body:setFixedRotation(true)
    game.player = {}
    game.player.body = player_body

end

function game.keypressed(key, scancode, isrepeat )
    if isrepeat then return end
    game.player.keydown(key, scode)
end

-- if there is a collideEnter handler, call it
function pushColl(fix, other_fix, coll)
    if not fix:getUserData() then return end
    if not fix:getUserData().collideEnter then return end
    fix:getUserData().collideEnter(fix, other_fix, coll)
end

-- if there is a collideExit handler, call it
function pushCollE(fix, other_fix, coll)
    if not fix:getUserData() then return end
    if not fix:getUserData().collideExit then return end
    fix:getUserData().collideExit(fix, other_fix, coll)
end

-- this function is called when any collision occurs
function beginContact(a, b, coll)
    pushColl(a,b,coll)
    pushColl(b,a,coll)
end
 
function endContact(a, b, coll)
    pushCollE(a,b,coll)
    pushCollE(b,a,coll)
end
 
function preSolve(a, b, coll)
end
 
function postSolve(a, b, coll, normalimpulse, tangentimpulse)
end

-------------------------------               -------------------------------
-----------------------------    DEFINITIONS    -----------------------------
-------------------------------               -------------------------------
function game.loadLevel(lvl)
    
    -- create canvas size of lvl
    local width = lvl:getPixelWidth()
    local height = lvl:getPixelHeight()
    local canvas = love.graphics.newCanvas(
        width,
        height
    )

    -- draw image onto canvas
    love.graphics.setCanvas(canvas)
    love.graphics.draw(lvl)
    love.graphics.setCanvas()

    -- get imgData from canvas
    local imgData = canvas:newImageData()

    -- we can discard these objects now
    lvl:release()
    canvas:release()

    -- poll image data and populate physics world
    for x=0,width-1 do
        for y=0,height-1 do

            local r,g,b,a  = imgData:getPixel(x,y)

            -- level_item tells us if the r,g,b values from the image correspond to a type of gameobject

            if level_item(r, g, b, "block") then
                --
                --   BLOCK  DEFINITION 
                --
                --         +-------+
                --         | \ V / |
                --         | -> <- |
                --         | / ^ \ |
                --         +-------+
                --
                local box_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")
                local box_shape = love.physics.newRectangleShape(5.5*phyUPP, 5.5*phyUPP, 11*phyUPP, 11*phyUPP)
                local box_fixture = love.physics.newFixture(box_body, box_shape)
                game.blocks[#game.blocks+1] = box_body
            elseif level_item(r, g, b, "player") then
                -- we already made a player, so we'll just set her position 
                game.player.body:setX(10*phyUPP*x)
                game.player.body:setY(10*phyUPP*y)
                
                --
                --   PLAYER DEFINITION (partially defined in init)
                --
                --         ##
                --       ######
                --         ####
                --       ######
                --     #########
                --   #############
                --       ######
                --       ######
                --       ######
                --      ###  ###
                --      ###  ###
                --       ##  ## 
                --
                -- and also, set up a rendering function here
                game.player.render = function()
                    
                    -- TODO this is more "action-loop" type code, you may want to organize it that way`
                    if game.player.helditem then

                        -- how far cube should move up
                        local delta = game.player.helditem.body:getY() - game.player.body:getY()

                        -- if the cube needs to be lifted higher
                        if (delta > 0) then
                            -- amnt of force to use
                            local boost = gravity*math.max(0, delta)

                            -- apply intended force while counteracting gravity
                            game.player.helditem.body:applyForce(0, -(gravity + boost))

                        -- else the cube is already in the air
                        else
                            game.player.helditem.body:setLinearVelocity(0,0)
                            
                            if game.player.direction == "right" then
                                -- hold the cube (11,-2) pixels offset from player
                                game.player.helditem.body:setX(game.player.body:getX() + 11*phyUPP)
                            else
                                -- hold the cube (-11,-2) pixels offset from player
                                game.player.helditem.body:setX(game.player.body:getX() - 11*phyUPP)
                            end

                            game.player.helditem.body:setY(game.player.body:getY() - 2*phyUPP)
                        end

                    end

                    -- draw player
                    if game.player.direction == "right" then
                        love.graphics.draw(sprites.player, playerScrnX()+11, playerScrnY(), 0, -1, 1) 
                    else
                        love.graphics.draw(sprites.player, playerScrnX(), playerScrnY(), 0, 1, 1) 
                    end

                    -- draw rectangle to house text
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 8)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 7)

                    -- draw text itself
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print("Press E to pick up this item.", 1, 0, 0, .4)
                    love.graphics.setColor(1, 1, 1)
                end
                
                game.player.keydown = function(key, scode)

                    if key == "e" then

                        if game.player.helditem then
                            game.player.helditem = nil
                            return
                        end

                        for i,e in pairs(game.entities) do

                            -- pick up an object if it is in reach
                            if e.pickupable and 
                                dist(e.body:getX(), 
                                     e.body:getY(), 
                                     game.player.body:getX(), 
                                     game.player.body:getY())/phyUPP <= reach then

                                game.player.helditem = e
                                print("Picked up item "..e.type)

                                return

                            end
                        end
                    end
                end

                -- immediate mode input handling
                game.player.input = function()

                    if love.keyboard.isDown("right") then
                        game.player.body:applyForce(50000,0)
                        game.player.direction = "right"
                    end
                    if love.keyboard.isDown("left") then
                        game.player.body:applyForce(-50000,0)
                        game.player.direction = "left"
                    end
                    if love.keyboard.isDown("up") then
                        game.player.body:applyForce(0,-50000)
                    end

                end
            elseif level_item(r, g, b, "cube") then
                local cube_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "dynamic")
                local cube_shape = love.physics.newRectangleShape(5*phyUPP, 7.5*phyUPP, 10*phyUPP, 7*phyUPP)
                local cube_fixture = love.physics.newFixture(cube_body, cube_shape)
                cube_body:setFixedRotation(true)
                --         
                --     CUBE DEFINITION
                --          ______
                --         |\      \
                --         |_\ _____\
                --       ====)|  _| |
                --          \'| |_| |
                --           \|_|___|
                --
                game.entities[#game.entities+1] = {
                    type = "cube";
                    pickupable = true;
                    body = cube_body;
                    sprite = sprites.box;
                    render = function(ent)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        love.graphics.draw(ent.sprite, pos.x, pos.y)
                    end       
                }
            elseif level_item(r, g, b, "button") then
                --
                --     BUTTON DEFINITION
                --                   
                --            /########\
                --            ##########
                --         ///\########/\\\
                --       ////############\\\\
                --       \\================//
                --         
                local btn_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")
                local btn_base_shape = love.physics.newRectangleShape(5.5*phyUPP, 9*phyUPP, 7*phyUPP, 2*phyUPP)

                local btn_trigger_shape = love.physics.newRectangleShape(5.5*phyUPP, 7.5*phyUPP, 5*phyUPP, 1*phyUPP)

                love.physics.newFixture(btn_body, btn_base_shape)
                local btn_trigger_fix = love.physics.newFixture(btn_body, btn_trigger_shape)
                btn_trigger_fix:setSensor(true)

                btn_body:setFixedRotation(true)

                local btn_entity = {
                    type = "button";
                    body = btn_body;
                    sprite = sprites.button;
                    render = function (ent)

                        -- render sprite
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        love.graphics.draw(ent.sprite, pos.x, pos.y)

                        -- render fixtures shapes
                        --renderFixtures(ent.body)
                    end;
                    collideEnter = function (self_fix, other_fix, coll)

                        local self = self_fix:getUserData()
                        self.sprite = sprites.button_pushed

                        print("BTN PUSHED!")

                    end
                }                                  

                btn_trigger_fix:setUserData(btn_entity)

                game.entities[#game.entities+1] = btn_entity
            elseif level_item(r, g, b, "") then
            elseif not level_item(r, g, b, "empty") then

                -- For objects that appear in level file but are not defined yet

                local obj_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")
                local obj_shape = love.physics.newRectangleShape( 5*phyUPP, 9*phyUPP)
                local obj_fixture = love.physics.newFixture(obj_body, obj_shape)
                obj_body:setFixedRotation(true)
                --
                --     MYSTERY OBJ DEFINITION
                --         
                --       ##########
                --       ########## 
                --              ###  
                --         ########  
                --         ########  
                --         ###       
                --                   
                --         ###
                --         ###
                --         
                game.entities[#game.entities+1] = {
                    type = "unknown";
                    body = obj_body;
                    render = function(ent)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        love.graphics.draw(sprites.unknown, pos.x, pos.y)
                    end
                }
            end
        end
    end

end

game.levels = levels

return game
