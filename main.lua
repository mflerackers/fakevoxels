require "class"

local Renderer = class()
function Renderer:__init()
end

function Renderer:start()
end

function Renderer:draw(image, quad, x, y, angle, sx, sy, ox, oy)
    love.graphics.draw(image, quad, x, y, angle, sx, sy, ox, oy)
end

function Renderer:finish()
end

local SimpleBatchRenderer = class()
function SimpleBatchRenderer:__init(image, count)
    self.spriteBatch = love.graphics.newSpriteBatch(image, count or 1000)
end

function SimpleBatchRenderer:start()
    self.spriteBatch:clear()
end

function SimpleBatchRenderer:draw(image, quad, x, y, angle, sx, sy, ox, oy)
    self.spriteBatch:add(quad, x, y, angle, sx, sy, ox, oy)
end

function SimpleBatchRenderer:finish()
    love.graphics.draw(self.spriteBatch)
end

local MultiBatchRenderer = class()
function MultiBatchRenderer:__init(images, count)
    self.spriteBatches = {}
    for _, image in ipairs(images) do
        self.spriteBatches[image] = love.graphics.newSpriteBatch(image, count or 1000)
        print("created batch for " .. tostring(image) .. " - " .. tostring(self.spriteBatches[image]))
    end
    self.spriteBatch = nil
end

function MultiBatchRenderer:start(images)
    for image, spriteBatch in pairs(self.spriteBatches) do
        spriteBatch:clear()
    end
end

function MultiBatchRenderer:draw(image, quad, x, y, angle, sx, sy, ox, oy)
    local spriteBatch = self.spriteBatches[image]
    assert(spriteBatch ~= nil, "Sprite batch not found for " .. tostring(image))
    if spriteBatch ~= self.spriteBatch then
        if self.spritebatch then
            love.graphics.draw(self.spriteBatch)
            self.spriteBatch:clear()
        end
        self.spriteBatch = spriteBatch
    end
    self.spriteBatch:add(quad, x, y, angle, sx, sy, ox, oy)
end

function MultiBatchRenderer:finish()
    for _, spriteBatch in pairs(self.spriteBatches) do
        love.graphics.draw(spriteBatch)
    end
end

local Camera = class()
function Camera:__init(x, y, angle)
    self.x = x or 0
    self.y = y or 0
    self.angle = angle or 0
    -- The position of the camera on the screen, default is center
    self.screenX = love.graphics.getWidth() * 0.5
    self.screenY = love.graphics.getHeight() * 0.5

    self:recalc(true)
end

function Camera:setAngle(angle)
    self.angle = angle
    self:recalc(true)
end

function Camera:setPosition(x, y)
    self.x = x
    self.y = y 
    self:recalc(false)
end

function Camera:recalc(angleChanged)
    --[[
        Cached values which don't change unless we change the camera
        The offset values are needed to rotate around the camera
        position rather than around the origin, and to place it in the center of the screen
        This is the only place we actually calculate a cosine and sine
    ]]
    if angleChanged then
        self.cos = math.cos(self.angle)
        self.sin = math.sin(self.angle)
    end

    self.offsetX = self.screenX - self.cos * self.x + self.sin * self.y
    self.offsetY = self.screenY - self.sin * self.x - self.cos * self.y

    self._offsetX = self.x - self.cos * self.screenX - self.sin * self.screenY
    self._offsetY = self.y + self.sin * self.screenX - self.cos * self.screenY

     -- Transform screen rect to world
    local leftTopX, leftTopY = self:inverseTransform(0, 0)
    local rightTopX, rightTopY = self:inverseTransform(love.graphics.getWidth(), 0)
    local rightBottomX, rightBottomY = self:inverseTransform(love.graphics.getWidth(), love.graphics.getHeight())
    local leftBottomX, leftBottomY = self:inverseTransform(0, love.graphics.getHeight())
    self.minX, self.minY = math.min(leftTopX, rightTopX, rightBottomX, leftBottomX), math.min(leftTopY, rightTopY, rightBottomY, leftBottomY)
    self.maxX, self.maxY = math.max(leftTopX, rightTopX, rightBottomX, leftBottomX), math.max(leftTopY, rightTopY, rightBottomY, leftBottomY)
end

function Camera:transform(x, y)
    --[[
        Transform from world to screen, for drawing objects
    ]]
    return x * self.cos - y * self.sin + self.offsetX,
           x * self.sin + y * self.cos + self.offsetY
end

function rotate(x, y, cos, sin)
    return x * cos - y * sin, 
           x * sin + y * cos
end

function reverseRotate(x, y, cos, sin)
    --[[
        cos(-a) = cos(a)
        sin(-a) = -sin(a)
    ]]
    return x * cos + y * sin, 
         - x * sin + y * cos
end

function Camera:inverseTransform(x, y)
    --[[ 
        Transform from screen to world, for picking or placing objects
    ]]
    return  x * self.cos + y * self.sin + self._offsetX,
           -x * self.sin + y * self.cos + self._offsetY
end

renderer = nil
camera = Camera(love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.5)

-- FakeVoxel class
local FakeVoxel = class()
function FakeVoxel:__init(image)
    
    self.image = image

    -- Create all layers, for now we assume that an object has w/h layers
    local width = self.image:getWidth()
    local height = self.image:getHeight()
    self.layers = {}
    for i = 0, width / height - 1 do
        table.insert(self.layers, love.graphics.newQuad(i * height, 0, height, height, width, height))
    end

    -- Origin for rotation, default is center
    self.ox = height * 0.5
    self.oy = height * 0.5
end

function FakeVoxel:draw(x, y, angle)
    local offset = y
    for _, layer in ipairs(self.layers) do
        renderer:draw(self.image, layer, x, offset, angle + camera.angle, 4, 4, self.ox, self.oy)
        offset = offset -4
    end
end

-- FakeVoxelObject class
local FakeVoxelObject = class()
function FakeVoxelObject:__init(voxels, x, y)
    self.x = x
    self.y = y
    self.angle = 0
    self.voxels = voxels
end

function FakeVoxelObject:setPosition(x, y)
    self.x, self.y = x, y
end

function FakeVoxelObject:update(dt)
    --self.angle = self.angle + dt * math.pi * 0.25
end

function FakeVoxelObject:transform()
   self._x, self._y = camera:transform(self.x, self.y)
end

function FakeVoxelObject:draw()
    self.voxels:draw(self._x, self._y, self.angle)
end

tree = nil
house = nil

function love.load()

    tree = love.graphics.newImage("tree.png")
    house = love.graphics.newImage("house.png")

    -- We want sharp, pixeled textures
    tree:setFilter("nearest", "nearest")
    house:setFilter("nearest", "nearest")

    --renderer = Renderer(tree)
    --renderer = SimpleBatchRenderer(tree)
    renderer = MultiBatchRenderer({tree, house})

    tree = FakeVoxel(tree)
    house = FakeVoxel(house)
end

function love.update(dt)
    if love.keyboard.isDown("a") then
        camera:setAngle(camera.angle - math.pi * dt)
    elseif love.keyboard.isDown("d") then
        camera:setAngle(camera.angle + math.pi * dt)
    end
    if love.keyboard.isDown("w") then
        camera:setPosition(camera.x - camera.sin * 100 * dt, 
            camera.y - camera.cos * 100 * dt)
    elseif love.keyboard.isDown("s") then
        camera:setPosition(camera.x + camera.sin * 100 * dt, 
            camera.y + camera.cos * 100 * dt)
    end
    for _, object in ipairs(objects) do
        object:update(dt)
    end

    if object then
        object:update(dt)
    end
end

function love.draw()

    renderer:start()

   -- New list of objects to draw
    local drawList = {}
    -- Transform all objects which are not clipped
    for _, object in ipairs(objects) do
        if object.x >= camera.minX and object.x <= camera.maxX and object.y >=camera.minY and object.y <= camera.maxY then
            object:transform()
            table.insert(drawList, object)
        end
    end
    -- Sort objects on draw depth
    table.sort(drawList, function(a, b) return a._y < b._y end)
    -- Draw objects
    for _, object in ipairs(drawList) do
        object:draw()
    end
    
    renderer:finish()

    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end

function love.mousepressed(x, y, button, istouch)
    
end

function love.mousemoved(x, y, dx, dy, istouch)
    
end

function love.mousereleased(x, y, button, istouch)

end

objects = {}

function love.keypressed(key, scancode, isrepeat)
    local x, y = love.mouse.getPosition()
    if key == "t" then
        x, y = camera:inverseTransform(x, y)
        table.insert(objects, FakeVoxelObject(tree, x, y))
    elseif key == "h" then
        x, y = camera:inverseTransform(x, y)
        table.insert(objects, FakeVoxelObject(house, x, y))
    elseif key == "escape" then
        love.event.quit()
    end
end
