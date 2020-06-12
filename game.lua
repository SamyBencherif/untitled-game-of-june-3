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

  ----------
 --          -  
--   Notes    -   
 --          -  
  ----------

 -- Design levels using image editors
 -- Add story-line triggers and effects in code
 -- Anticipating voice, text, and lighting effects

-------------------------------            -------------------------------
-----------------------------  1. IMPORTS    -----------------------------
-------------------------------            -------------------------------

local sprites = require("packages/cargo").init("sprites")
local levels = require("packages/cargo").init("levels")

-------------------------------            -------------------------------
-----------------------------  2. CONSTANTS  -----------------------------
-------------------------------            -------------------------------

-- notes: Rendering functions are configured to draw in tex pixels.
--        A tex pixel the smallest unit used in textures.
--
--        Screen pixels are the smallest visible unit.
--        They are used occasionally (for text and motion smoothing).
--
--        Physics units are smaller than screen pixels. Each pixel
--        corresponds to 2 meters in the Box2D engine. Objects were
--        oversized to help mitigate visible gaps.

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

local default_bounce_count = 10

-------------------------------            -------------------------------  
-----------------------------     STATE      -----------------------------  
-------------------------------            -------------------------------  

local game = {
    blocks = {};
    entities = {}
}

-------------------------------            -------------------------------  
-----------------------------    UTILITY     -----------------------------  
-------------------------------            -------------------------------  

function setLCActive(lc, state)
    for i,e in pairs(game.entities) do
        -- found something other than self with same linker code
        if lc == e.linker_code then

            -- initiate functions take args like this:
            -- initiate( entity_to_initiate, entity_causing_initiation )

            -- and deinitiate is the same

            if state then
                if (e.initiate) then e.initiate(e) end
            else
                if (e.deinitiate) then e.deinitiate(e) end
            end
        end
    end
end

function castLaser(sx,sy,dx,dy,remainingBounces)
    -- simulated particle to figure out laser segment
    local simParticle = {
        x = sx + dx;
        y = sy + dy;
    }

    local foundObj

    -- move particle forward until it hits something
    -- (arbitrary 300px limit)
    for i=1,300 do
        simParticle.x = simParticle.x + dx
        simParticle.y = simParticle.y + dy

        foundObj = getObjAtPoint(simParticle)
        if foundObj then
            break
        end
    end

    renderLaserSeg(
        sx + dx,
        sy + dy,
        simParticle.x,
        simParticle.y
    )

    -- call onReceiveLaser event if the object has it
    if foundObj.onReceiveLaser and remainingBounces > 0 then
        foundObj.onReceiveLaser(foundObj, simParticle, {dx=dx; dy=dy}, remainingBounces)
    end

end

function getPlacementInfo(imgData, x, y)
    local placement_configs = {
        floor = {
           rotation = 0;
           x_offset = 0;
           y_offset = 0;
           rect_transform = function(x,y,w,h)
               return {x=x; y=y; w=w; h=h}
           end;
           beam_o = {x=5; y=3};
           beam_v = {x=0; y=-1};
        },
        lwall = {
           rotation = math.pi/2;
           x_offset = 11;
           y_offset = 0;
           rect_transform = function(x,y,w,h)
               return {x=11-y; y=x; w=h; h=w}
           end;
           beam_o = {x=7; y=5};
           beam_v = {x=1; y=0};
        },
        rwall = {
           rotation = -math.pi/2;
           x_offset = 0;
           y_offset = 11;
           rect_transform = function(x,y,w,h)
               return {x=y; y=x; w=h; h=w}
           end;
           beam_o = {x=3; y=5};
           beam_v = {x=-1; y=0};
        },
        ceil = {
           rotation = math.pi;
           x_offset = 11;
           y_offset = 11;
           rect_transform = function(x,y,w,h)
               return {x=x; y=11-y; w=w; h=h}
           end;
           beam_o = {x=5; y=7};
           beam_v = {x=0; y=1};
        },

    }

    -- poll surrounding blocks to help determine placement

    local neighborhood = 0

    -- block to the right 1000 8
    local r,g,b = imgData:getPixel(x+1, y)
    if level_item(r, g, b, "block") then
        neighborhood = neighborhood + 1
    end
    neighborhood = neighborhood * 2 

    -- block to the left 0100 4
    local r,g,b = imgData:getPixel(x-1, y)
    if level_item(r, g, b, "block") then
        neighborhood = neighborhood + 1
    end
    neighborhood = neighborhood * 2

    -- block above 0010 2
    local r,g,b = imgData:getPixel(x, y-1)
    if level_item(r, g, b, "block") then
        neighborhood = neighborhood + 1
    end
    neighborhood = neighborhood * 2

    -- block below 0001 1
    local r,g,b = imgData:getPixel(x, y+1)
    if level_item(r, g, b, "block") then
        neighborhood = neighborhood + 1
    end

    -- now choose a specific placement configuration
    local pc
    local linker_code

    if ( neighborhood == 1 or neighborhood == 13 ) then 

        pc = placement_configs.floor

        -- save linker code
        local r,g,b = imgData:getPixel(x, y-1)
        linker_code = r*256*256 + g*256 + b

    elseif ( neighborhood == 2 or neighborhood == 14 ) then

        pc = placement_configs.ceil

        -- save linker code
        local r,g,b = imgData:getPixel(x, y+1)
        linker_code = r*256*256 + g*256 + b

    elseif ( neighborhood == 4 or neighborhood == 7 ) then

        pc = placement_configs.lwall

        -- save linker code
        local r,g,b = imgData:getPixel(x+1, y)
        linker_code = r*256*256 + g*256 + b

    elseif ( neighborhood == 8 or neighborhood == 11 ) then

        pc = placement_configs.rwall

        -- save linker code
        local r,g,b = imgData:getPixel(x-1, y)
        linker_code = r*256*256 + g*256 + b

    else

        pc = placement_configs.floor

        -- save linker code
        local r,g,b = imgData:getPixel(x, y-1)
        linker_code = r*256*256 + g*256 + b

        print("Error: Invalid entity at ("..x..", "..y.."). Unable to resolve placement.")
    end

    return {pc = pc; linker_code = linker_code}
end

function control_point(x, y, visual)

    -- visual control point override
    visual = false

    local hot = false

    if getObjAtPoint({x=x; y=y}, --[[ exclude_player ]] true) then
        -- color control point red
        love.graphics.setColor(1,0,0)
        hot = true
    else
        -- color control point blue
        love.graphics.setColor(0,0,1)
    end

    -- render control point
    if visual then
        love.graphics.rectangle("fill", x, y, 1, 1) 
    end

    -- restore default color
    love.graphics.setColor(1,1,1)

    return hot
end

function getObjAtPoint(screen_point, exclude_player)

    local point = scrToPhy(screen_point.x, screen_point.y)

    -- first check all blocks
    for i,b in pairs(game.blocks) do

        -- blocks are of type Body
        for j,fix in pairs(b:getFixtures()) do
            local s = fix:getShape()
            if s:testPoint(b:getX(), b:getY(), 0, point.x, point.y) then

                -- return pseudo-game object for block
                return { type="block" ; body = b }

                -- We treat blocks like game objects only when the laser interacts with it
                -- to conserve memory.
            end
        end
    end
    
    -- then check entities
    for i,e in pairs(game.entities) do
        local b = e.body
        for j,fix in pairs(b:getFixtures()) do
            local s = fix:getShape()
            if s:testPoint(b:getX(), b:getY(), 0, point.x, point.y) then
                return e
            end
        end
    end

    if exclude_player then
        return nil
    end

    -- then check player
    local b = game.player.body
    for j,fix in pairs(b:getFixtures()) do
        local s = fix:getShape()
        if s:testPoint(b:getX(), b:getY(), 0, point.x, point.y) then
            return game.player
        end
    end

    return nil
end

function renderFixtures(b)
    love.graphics.setColor(0,0,1,.3)
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
    love.graphics.setColor(1,1,1,1)
end

-- renders laser path
function renderLaserSeg(x1, y1, x2, y2)
    love.graphics.setColor(0,0,0)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.setColor(1,1,1)
end

function phyToScr(px,py) 
    return {
        x = px/phyUPP-game.player.body:getX()/phyUPP+playerScrnX();
        y = py/phyUPP-game.player.body:getY()/phyUPP+playerScrnY()
    }
end

function scrToPhy(sx,sy) 
    return {
        x = (sx - playerScrnX() + game.player.body:getX()/phyUPP) * phyUPP;
        y = (sy - playerScrnY() + game.player.body:getY()/phyUPP) * phyUPP
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
    if r == 20 and g == 35 and b == 133 and name == "sphere" then return true end
    if r == 204 and g == 154 and b == 45 and name == "button" then return true end
    if r == 141 and g == 40 and b == 40 and name == "ulaser" then return true end
    if r == 233 and g == 34 and b == 75 and name == "ilaser" then return true end
    if r == 101 and g == 51 and b == 16 and name == "catcher" then return true end
    if r == 21 and g == 127 and b == 49 and name == "door" then return true end

    if r == 255 and g == 255 and b == 255 and name == "empty" then return true end

    -- all linker control blocks are considered empties (ie not entities)
    if r == 255 and g == 255 and b == 255 and name == "empty" then return true end
    if r == 243 and g == 216 and b == 240 and name == "empty" then return true end
    if r == 234 and g == 178 and b == 228 and name == "empty" then return true end
    if r == 227 and g == 139 and b == 218 and name == "empty" then return true end
    if r == 217 and g == 28 and b == 203 and name == "empty" then return true end
    if r == 191 and g == 23 and b == 178 and name == "empty" then return true end
    if r == 168 and g == 19 and b == 156 and name == "empty" then return true end
    if r == 129 and g == 12 and b == 120 and name == "empty" then return true end

    -- linker control block colors repeated:
    -- 243 216 240
    -- 234 178 228
    -- 227 139 218
    -- 217 28 203
    -- 191 23 178
    -- 168 19 156
    -- 129 12 120

    return false
end

function dist(x1,y1,x2,y2)
    return math.sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))
end

-------------------------------            -------------------------------  
-----------------------------     EVENTS     -----------------------------  
-------------------------------            -------------------------------  

function game.draw(dt)
    love.graphics.scale(texUPP, texUPP)

    -- BLOCK RENDERER
    for i,b in pairs(game.blocks) do
        local pos = phyToScr(b:getX(), b:getY())
        love.graphics.draw(sprites.block, pos.x, pos.y)
    end

    -- draw entities
    for i,e in pairs(game.entities) do
        e.render(e)
    end

    -- draw the player (and overlays)
    -- renderFixtures(game.player.body)
    game.player.render()
end

function game.input(dt)
    if game.player.input then 
        game.player.input()
    else
        print("Error: Map does not include player spawn point.")
    end
    game.player.t = game.player.t + dt
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
    love.keyreleased = game.keyreleased

    -- create player
    -- PLAYER DEFINITION (partial)
    local player_body = love.physics.newBody(game.world, 0*phyUPP, 0*phyUPP, "dynamic")

    -- main collider
    local player_shape = love.physics.newRectangleShape(5.5*phyUPP, 5.5*phyUPP, 5*phyUPP, 11*phyUPP)
    local player_fixture = love.physics.newFixture(player_body, player_shape)
    -- set player feet to have high friction
    player_fixture:setFriction(2)

    -- extra collider for arms
    local player_shape2 = love.physics.newRectangleShape(5.5*phyUPP, 5*phyUPP, 7*phyUPP, 2*phyUPP)
    local player_fixture2 = love.physics.newFixture(player_body, player_shape2)

    player_body:setFixedRotation(true)
    -- PLAYER PROPERTIES
    game.player = {
        body = player_body;
        t = 0;
        type = "player"
    }

end

function game.keypressed(key, scancode, isrepeat)
    if isrepeat then return end

    if key == "lshift" then
        game.player.shiftHeld = true
    end

    game.player.keydown(key, scancode)
end

function game.keyreleased(key, scancode)
    if key == "lshift" then
        game.player.shiftHeld = false
    end
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
                    

                    ------------------------------------------------
                    --                                            --
                    --   HELD-ITEM ACTION                         --
                    --                                            --
                    ------------------------------------------------
                    -- TODO this is more "action-loop" type code, you may want to organize it that way
                    if game.player.helditem then

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

                    ------------------------------------------------
                    --                                            --
                    --   RENDER PLAYER                            --
                    --                                            --
                    ------------------------------------------------
                    local spr = sprites.player

                    vx, vy = game.player.body:getLinearVelocity( )
                    vxa = math.abs(vx)

                    -- if player is moving faster than a crawl (and on the ground)
                    if vxa > 4 and game.player.isGrounded then
                        local anim_dur = .3
                        if game.player.t % anim_dur > anim_dur/2 then
                            spr = sprites.player_2
                        end
                    end

                    if game.player.direction == "right" then
                        love.graphics.draw(spr, playerScrnX()+11, playerScrnY(), 0, -1, 1) 
                    else
                        love.graphics.draw(spr, playerScrnX(), playerScrnY(), 0, 1, 1) 
                    end

                    ------------------------------------------------
                    --                                            --
                    --   RENDER COLLIDERS (DEBUG)                 --
                    --                                            --
                    ------------------------------------------------
                    local renderColliders = false

                    -- full entity collider debug
                    if renderColliders then
                        for i,e in pairs(game.entities) do
                            renderFixtures(e.body)
                        end
                    end

                    -- full entity collider debug
                    if renderColliders then
                        for i,b in pairs(game.blocks) do
                            renderFixtures(b)
                        end
                    end

                    -- player collider debug
                    if renderColliders then
                        renderFixtures(game.player.body)
                    end

                    ------------------------------------------------
                    --                                            --
                    --   RENDER TEXT                              --
                    --                                            --
                    ------------------------------------------------

                    -- draw rectangle to put text in
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 7.5)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 7)

                    -- draw text itself
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print("Welcome to this untitled Game.", 1, 0, 0, .4)
                    love.graphics.setColor(1, 1, 1)


                    ------------------------------------------------
                    --                                            --
                    --   RENDER CONTROL POINTS (DEBUG)            --
                    --                                            --
                    ------------------------------------------------

                    -- is player grounded?
                    game.player.isGrounded = nil or
                        -- ground under feet
                        control_point(playerScrnX()+5, playerScrnY()+12, --[[ visual ]] true) or
                        -- ground under left arm
                        control_point(playerScrnX()+2, playerScrnY()+7, --[[ visual ]] true) or 
                        -- ground under right arm
                        control_point(playerScrnX()+9, playerScrnY()+7, --[[ visual ]] true)


                    -- if either of these is active, disable climbing
                    game.player.noClimb = nil or
                        control_point(playerScrnX()+1, playerScrnY()+2, --[[ visual ]] true) or
                        control_point(playerScrnX()+10, playerScrnY()+2, --[[ visual ]] true)

                end
                
                ------------------------------------------------
                --                                            --
                --   PLAYER INPUT                             --
                --                                            --
                ------------------------------------------------

                game.player.keydown = function(key, scode)

                    local helditem = game.player.helditem

                    -- E to pick up / activate items
                    if key == "e" then

                        if helditem then
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

                                return

                            end
                        end
                    elseif key == "q" and helditem and helditem.setDirection then
                        local newAngle

                        if game.player.shiftHeld then
                            newAngle = helditem.angle - 1
                        else
                            newAngle = helditem.angle + 1
                        end

                        helditem.setDirection(helditem, newAngle)
                    end

                end -- (keydown)

                -- Player movement

                game.player.input = function()

                    local moveLeft = love.keyboard.isDown("left") or love.keyboard.isDown("a")
                    local moveRight = love.keyboard.isDown("right") or love.keyboard.isDown("d")

                    local velX, velY = game.player.body:getLinearVelocity()

                    local maxVel

                    -- ground speed vs air speed
                    if game.player.isGrounded then
                        maxVel = 1000
                    else
                        maxVel = 300
                    end

                    -- apply force in direction of arrow keys

                    if moveLeft then
                        game.player.direction = "left"

                        if math.abs(velX) < maxVel then
                            game.player.body:applyForce(-50000,0)
                        end
                    end

                    if moveRight then
                        game.player.direction = "right"

                        if math.abs(velX) < maxVel then
                            game.player.body:applyForce(50000,0)
                        end
                    end

                    -- patch clipping and enable climbing
                    if moveLeft or moveRight then
                        local currY = game.player.body:getY()

                        -- note: noClimb is set in the control points section
                        --       whenever an obstacle is too tall for the player
                        --       to climb

                        if not game.player.noClimb then
                            if math.abs(velX) < 3 then
                                -- if x vel is crawling, climb up
                                game.player.body:setY( currY - 3 )
                            else
                                -- if x vel is fast, just hover slightly (to prevent clipping)
                                game.player.body:setY( currY - 1 )
                            end
                        end

                        -- note: this patch works by hovering the player slightly whenever he walks
                        --       this causes the ground to look like it is vibrating slightly
                        --       but it keeps the player from getting stuck (because of overlapping 
                        --       colliders)

                        -- note: this is also a partial implementation of the climbing behavior
                        --       I will use a pair of control points to disallow climbing a certain 
                        --       height
                    end

                    if (love.keyboard.isDown("up") or love.keyboard.isDown("w"))
                            and game.player.isGrounded then

                        game.player.body:applyForce(0,-50000)

                    end

                end
                
            elseif level_item(r, g, b, "cube") then
                local cube_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "dynamic")
                local cube_shape = love.physics.newRectangleShape(5*phyUPP, 7.5*phyUPP, 10*phyUPP, 7*phyUPP)
                local cube_fixture = love.physics.newFixture(cube_body, cube_shape)
                cube_body:setFixedRotation(true)
                cube_body:setSleepingAllowed(false)
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
                    end;
                    onReceiveLaser = function(ent, point, deltas, remainingBounces)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        castLaser(pos.x-3, pos.y+7, -1, 0, remaingBounces-1)
                    end
                }
            elseif level_item(r, g, b, "sphere") then
                local sphere_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "dynamic")
                local sphere_shape = love.physics.newRectangleShape(5.5*phyUPP, 4.5*phyUPP, 7*phyUPP, 9*phyUPP)
                local sphere_fixture = love.physics.newFixture(sphere_body, sphere_shape)
                sphere_body:setFixedRotation(true)
                sphere_body:setSleepingAllowed(false)
                --         
                --     SPHERE DEFINITION
                --                 
                --          ||   
                --         _||_ 
                --        / _| \
                --       | |_|  |
                --        \|___/ 
                --
                game.entities[#game.entities+1] = {
                    type = "sphere";
                    pickupable = true;
                    body = sphere_body;
                    sprite = sprites.sphere;
                    renderAngle = 0;
                    renderOffset = {x=0; y=0};
                    castDelta = {x=0, y=-1};
                    castOrigin = {x=5.5; y=1};
                    fixture = sphere_fixture;
                    angle = 0; -- 4*radians/pi (ie 0 is 0deg, 1 is 45deg, 2 is 90deg, etc)
                    render = function(ent)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        local o = ent.renderOffset
                        love.graphics.draw(ent.sprite, pos.x+o.x*11, pos.y+o.y*11, ent.renderAngle)
                    end;
                    onReceiveLaser = function(ent, point, deltas, remainingBounces)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        castLaser(
                            pos.x + ent.castOrigin.x, 
                            pos.y + ent.castOrigin.y, 
                            ent.castDelta.x, 
                            ent.castDelta.y, 
                            remainingBounces-1
                        )
                    end;
                    setDirection = function(ent, angle)
                        angle = angle % 8
                        
                        -- set the box collider
                        -- ANGLE(S)  |  X  |  Y  |  W  |  H
                        -- -----------------------------------
                        --        0    5.5   4.5    7     9
                        --        1     6     ?     8     ?
                        --        2    6.5    ?     9     ?
                        local boxTable = {
                            {5.5,4.5,7,9},  -- 0
                            {6.0,5.0,8,8},  -- 1
                            {6.5,5.5,9,7},  -- 2
                            {6.0,6.0,8,8},  -- 3
                            {5.5,6.5,7,9},  -- 4
                            {5.0,6.0,8,8},  -- 5
                            {4.5,5.5,9,7},  -- 6
                            {5.0,5.0,8,8},  -- 7
                        }
                        ent.fixture:destroy()
                        local sphere_shape = love.physics.newRectangleShape(
                            boxTable[angle+1][1]*phyUPP,
                            boxTable[angle+1][2]*phyUPP, 
                            boxTable[angle+1][3]*phyUPP,
                            boxTable[angle+1][4]*phyUPP
                        )
                        ent.fixture = love.physics.newFixture(ent.body, sphere_shape)

                        -- set render offset
                        -- ANGLE(S) |  OFFSET 
                        -- -------------------
                        -- 0, 1    =>  (0,0)
                        -- 2, 3    =>  (1,0)
                        -- 4, 5    =>  (1,1)
                        -- 6, 7    =>  (0,1)
                        local offsetTableX = {0,0,1,1,1,1,0,0}
                        local offsetTableY = {0,0,0,0,1,1,1,1}
                        ent.renderOffset = {
                            x = offsetTableX[angle+1];
                            y = offsetTableY[angle+1]
                        }

                        -- set render angle
                        ent.renderAngle = math.floor(angle / 2) * math.pi / 2

                        -- set the sprite
                        if angle % 2 == 1 then
                            ent.sprite = sprites.sphere_d
                        else
                            ent.sprite = sprites.sphere
                        end

                        -- set cast origin
                        local castOriginTable = {
                            {x=5.5; y=1  };  -- 0
                            {x=9.5; y=2  };  -- 1
                            {x=10 ; y=5.5};  -- 2
                            {x=9.5; y=9  };  -- 3
                            {x=5.5; y=10 };  -- 4
                            {x=1.5; y=9  };  -- 5
                            {x=1  ; y=5.5};  -- 6
                            {x=1.5; y=2  };  -- 7
                        }
                        ent.castOrigin = castOriginTable[angle+1]

                        -- set cast delta
                        local castDeltaTable = {
                            {x=0;y=-1};
                            {x=1;y=-1};
                            {x=1;y=0};
                            {x=1;y=1};
                            {x=0;y=1};
                            {x=-1;y=1};
                            {x=-1;y=0};
                            {x=-1;y=-1};
                        }
                        ent.castDelta = castDeltaTable[angle+1]

                        -- set the angle
                        ent.angle = angle
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

                -- save linker code
                local r,g,b = imgData:getPixel(x, y-1)
                local linker_code = r*256*256 + g*256 + b

                local btn_entity = {
                    type = "button";
                    body = btn_body;

                    -- number of entities keeping btn pushed
                    push_count = 0;
                    linker_code = linker_code;

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

                        self.push_count = self.push_count + 1

                        -- only trigger when btn is first pushed down
                        -- (for example player and cube on button should only result in one trigger)
                        if (self.push_count == 1) then
                            setLCActive(self.linker_code, true)
                        end

                    end;
                    collideExit  = function (self_fix, other_fix, coll)

                        local self = self_fix:getUserData()

                        self.push_count = self.push_count - 1

                        if (self.push_count == 0) then
                            self.sprite = sprites.button

                            setLCActive(self.linker_code, false)
                        end

                    end
                }                                  

                btn_trigger_fix:setUserData(btn_entity)

                game.entities[#game.entities+1] = btn_entity
            elseif level_item(r, g, b, "ulaser") or level_item(r, g, b, "ilaser") then
                -- 
                --     (UN)INITIATED LASER DEFINITION
                --         
                --           X
                --           | 
                --           | 
                --           | 
                --      ____/ \____
                --     /___________\
                --         
                --         
                local initiated = level_item(r, g, b, "ilaser")

                -- get information concerning gameobject's orientation
                local p_info = getPlacementInfo(imgData, x, y)
                local pc = p_info.pc
                local linker_code = p_info.linker_code

                local emitter_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")

                local rect = pc.rect_transform(5.5, 7, 9, 6)
                local emitter_shape = love.physics.newRectangleShape(rect.x*phyUPP, 
                                                    rect.y*phyUPP, rect.w*phyUPP, rect.h*phyUPP)

                local emitter_fixture = love.physics.newFixture(emitter_body, emitter_shape)
                emitter_body:setFixedRotation(true)

                game.entities[#game.entities+1] = {
                    type = "emitter";
                    body = emitter_body;
                    initial_state = initiated;
                    initiated = initiated;
                    linker_code = linker_code;
                    render = function(ent)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        love.graphics.draw(sprites.emitter, pos.x + pc.x_offset, 
                                            pos.y + pc.y_offset, pc.rotation)

                        if (ent.initiated) then
                            -- LASER BEAM DEFINITION
                            --         |
                            --         |-<>-- ==================O
                            --         |
                            --

                            castLaser(
                                pos.x + pc.beam_o.x, 
                                pos.y + pc.beam_o.y, 
                                pc.beam_v.x, 
                                pc.beam_v.y, 
                                default_bounce_count
                            )
                        end
                    end;

                    -- An "ilaser" is one that starts on and gets turned off by the button
                    -- A "ulaser" is one that starts off and gets turned on by the button
                    initiate = function(ent)
                        ent.initiated = not ent.initial_state
                    end;
                    deinitiate = function(ent)
                        ent.initiated = ent.initial_state
                    end 
                }

            elseif level_item(r, g, b, "catcher") then
                -- 
                --     CATCHER DEFINITION
                --         ______  
                --        |/    \|
                --        |      |
                --        |_    _|    
                --     \============/
                --         

                -- get information concerning gameobject's orientation
                local p_info = getPlacementInfo(imgData, x, y)
                local pc = p_info.pc
                local linker_code = p_info.linker_code

                local catcher_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")

                local rect = pc.rect_transform(5.5, 7, 9, 6)
                local catcher_shape = love.physics.newRectangleShape(rect.x*phyUPP, 
                                                    rect.y*phyUPP, rect.w*phyUPP, rect.h*phyUPP)

                local emitter_fixture = love.physics.newFixture(catcher_body, catcher_shape)
                catcher_body:setFixedRotation(true)

                game.entities[#game.entities+1] = {
                    type = "catcher";
                    body = catcher_body;

                    linker_code = linker_code;
                    sprite = sprites.catcher;

                    framesWithoutLaser = 2;

                    render = function(ent)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 
                        love.graphics.draw(ent.sprite, pos.x + pc.x_offset, 
                                            pos.y + pc.y_offset, pc.rotation)

                        if ent.framesWithoutLaser == 1 then
                            ent.onLostLaser(ent)
                        end

                        ent.framesWithoutLaser = ent.framesWithoutLaser + 1
                    end;
                    
                    onLostLaser = function(ent)
                        ent.sprite = sprites.catcher
                        setLCActive(ent.linker_code, false)
                    end;

                    onReceiveLaser = function(ent, collisionPoint, beamDirection, remainingBounces)
                        ent.sprite = sprites.catcher_active
                        setLCActive(ent.linker_code, true)
                        ent.framesWithoutLaser = 0
                    end
                }

            elseif level_item(r, g, b, "door") then
                local obj_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")
                local obj_shape = love.physics.newRectangleShape(5.5*phyUPP, 0*phyUPP, 11*phyUPP, 22*phyUPP)
                local obj_fixture = love.physics.newFixture(obj_body, obj_shape)
                obj_body:setFixedRotation(true)
                --
                --     DOOR DEFINITION
                --
                --    |==================|
                --    ||             || ||
                --    || |============| ||
                --    || ||          || ||
                --    || ||          || ||
                --    || ||    __    || ||
                --    || ||   //\\   || ||
                --    || ||   |  |   || ||
                --    || ||   \\//   || ||
                --    || ||          || ||
                --    || ||          || ||
                --    || ||          || ||
                --    || |============| ||
                --    || ||             ||
                --    |==================|
                --         

                -- save linker code
                local r,g,b = imgData:getPixel(x, y-1)
                local linker_code = r*256*256 + g*256 + b

                game.entities[#game.entities+1] = {
                    type = "door";
                    body = obj_body;
                    linker_code = linker_code;
                    -- initiated means "activated" or "open"
                    render = function(ent)
                        local pos = phyToScr(ent.body:getX(), ent.body:getY()) 

                        if ent.initiated then
                            
                            -- draw the door open-like

                            -- draw the top half of the door
                            love.graphics.draw(sprites.doorpane, pos.x, pos.y-22)
                            -- draw bottom half of door
                            love.graphics.draw(sprites.doorpane, pos.x+11, pos.y+21, math.pi)
                        else
                            love.graphics.draw(sprites.door, pos.x, pos.y-11)
                        end

                    end;
                    initiate = function(ent)
                        -- disable the door's collider
                        for i,f in pairs(ent.body:getFixtures()) do
                            f:setSensor(true)
                        end

                        -- let the renderer know to draw door open
                        ent.initiated = true
                    end;
                    deinitiate = function(ent)

                        -- enable the door's collider
                        for i,f in pairs(ent.body:getFixtures()) do
                            f:setSensor(false)
                        end

                        -- let the renderer know to draw door closed
                        ent.initiated = false
                    end
                }
            elseif not level_item(r, g, b, "empty") then

                -- For objects that appear in level file but are not defined yet

                local obj_body = love.physics.newBody(game.world, 10*phyUPP*x, 10*phyUPP*y, "static")
                local obj_shape = love.physics.newRectangleShape(5.5*phyUPP, 5.5*phyUPP, 5*phyUPP, 9*phyUPP)
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
