-- BaseBuilding Turtle

-- Digs out rooms 16x16x4, with a staircase spiraling along the edges
-- Should always be started at the top-left corner of the area to dig...

-- No idea how I'm gonna get the stars to work, but the main part should be really easy

local startZ = nil
local startX = nil
local startY = nil

local cobbleSlot = 1
local firstFuelSlot = 13
local numFuelSlots = 3 -- There's really 4... but... it's so much easier on the logic this way


function refuel() 
	-- Fix the inventory.  Let's reserve the last 4 slots all for coal
	-- So first, check those 4 slots and if they have noncoal in them, drop them
	-- Then check all other slots, and if they have coal, try to put them in those 4 slots
	-- Also, discard all cobblestone except slot 1, stack it there
	
	-- There are 16 slots, we want 12-16
	for i=firstFuelSlot,firstFuelSlot+numFuelSlots do
		local data = turtle.getItemDetail(i)
		if data ~= nil then
			print("Found in slot " .. i .. ": ", data.name)
			if data.name ~= "minecraft:coal" then
				turtle.select(i)
				turtle.drop()
				print("Dropping slot " .. i .. " because it's in the coal slot")
			end
		end
	end
	-- Now the rest
	for i=1,firstFuelSlot-1 do
		local data = turtle.getItemDetail(i)
		if data ~= nil then
			print("Found in slot " .. i .. ": ", data.name)
			if data.name == "minecraft:coal" then
				-- Just try them all
				turtle.select(i)
				print("Transferring coal to all fuel slots")
				for j=firstFuelSlot,firstFuelSlot+numFuelSlots do
					turtle.transferTo(j)
				end
			elseif data.name == "minecraft:cobblestone" and i ~= cobbleSlot then
				-- Try to transfer it to cobbleSlot
				turtle.select(i)
				turtle.transferTo(cobbleSlot)
				-- Drop any remainders
				turtle.drop()
			elseif (data.name:find("stone") and i ~= cobbleSlot) or data.name:find("marble") then
				-- Just drop it
				turtle.select(i)
				turtle.drop(i)
			end
		end
	end
	-- And lastly, iterate the fuel slots and refuel
	for i=firstFuelSlot,firstFuelSlot+numFuelSlots do
		turtle.select(i)
		turtle.refuel()
	end
	-- Then reselect slot 1
	turtle.select(cobbleSlot)
end

function safeDig() -- We may have to pause a tick to wait for gravel to fall... 
	while turtle.detect() do turtle.dig() end
end

function safeForward()
	while not turtle.forward() do
		turtle.dig() -- Should be a good failsafe against gravel/sand blocking us after we dig... 
	end
end


turtle.select(firstFuelSlot)
turtle.refuel()
turtle.select(cobbleSlot)

local sz=1
local sx=1
local sy=1
if startZ then sz = startZ startZ = nil end
if startX then sx = startX startX = nil end
if startY then sy = startY startY = nil end

while(true) do

	for z=sz,4 do
		
		for x=sx,16 do -- Same, always already in the first one
			
			for y=sy,16 do -- We're always inside the first one
				
				safeDig()
				--turtle.suck() -- Dig already does this, nice
				safeForward()
				if not turtle.detectDown() and z == 4 then turtle.placeDown() end -- Make sure the floors are filled in
				if not turtle.detectUp() and z == 1 then turtle.placeUp() end -- And the ceilings, which are 1 below the floors
			end
			sy = 1
			-- Reached the end on this side, turn (right/left)...
			if x < 16 then
				if x%2 == 1 then turtle.turnRight() else turtle.turnLeft() end
				safeDig()
				safeForward()
				if x%2 == 1 then turtle.turnRight() else turtle.turnLeft() end
				if not turtle.detectDown() and z == 4 then turtle.placeDown() end -- Make sure the floors are filled in
				if not turtle.detectUp() and z == 1 then turtle.placeUp() end -- And the ceilings, which are 1 below the floors
			end
			-- And, since we don't suck anymore, we can refuel at any point
			refuel()
			-- Ready to iterate again
		end
		sx = 1
		-- We've cleared out a 16x16 area on this level.  
		-- And we are currently in the last block we broke...
		-- So the staircase is to our left.  But, for everything except z==1
		-- We need to do a 180 and go to the opening
		if z > 1 then
			turtle.turnLeft()
			turtle.turnLeft()
			for i=2,z do
				safeForward()
			end
			turtle.turnRight()
			safeForward() -- There should already be nothing there
			turtle.turnLeft()
		else
			turtle.turnLeft()
			safeDig()
			safeForward()
			turtle.turnLeft()
		end
		-- Both situations leave us facing to where we need to dig and go down
		-- Also good to drop items/refuel
		refuel()
		if not turtle.detectDown() then turtle.placeDown() end -- Fill floors
		safeDig()
		safeForward()
		turtle.digUp()
		turtle.digDown()
		turtle.down()
		turtle.digUp() -- Tall stairwell
		if not turtle.detectDown() then turtle.placeDown() end -- Fill floors
		
		if z < 4 then
			-- Figure out how to get back to our starting point.
			turtle.turnLeft()
			safeDig()
			safeForward()
			turtle.turnLeft()
			for temp=1,z do -- We will be [z] blocks from the edge on this side
				safeDig()
				safeForward()
			end
			turtle.turnRight()
			-- And a full 16 blocks from the next edge inclusive, but, we're inclusive on two points
			-- So up to 15, I guess. IDK it works.
			for temp=1,15 do
				safeDig()
				safeForward()
			end
			turtle.turnRight() -- And it's ready to iterate again
		end
	end
	sz = 1
	-- We have successfully dug 16x16x4
	-- And are on our stairwell area, on the 5th block into the stairwell
	
	-- This is a good time to ditch items, since we don't pick things up on the stairwell and they won't fall
	
	refuel()
	
	
	-- Continue the stairwell down.  Our starting point is 2 more blocks forward/down, we did one already
	-- Then we go 3 more blocks to build the stairwell first
	for temp=1,5 do -- This works for both halves
		if not turtle.detectDown() then turtle.placeDown() end -- Fill floors
		safeDig()
		safeForward()
		turtle.digUp()
		turtle.digDown()
		turtle.down()
		turtle.digUp() -- Make them 3 tall
		if not turtle.detectDown() then turtle.placeDown() end -- Fill floors
	end
	-- Go back up the 3 steps to get to our starting height
	turtle.turnRight()
	turtle.turnRight()
	for i=1,3 do
		turtle.up()
		safeForward()
	end
	turtle.turnRight()
	-- Get back to the starting position
	safeDig()
	safeForward()
	turtle.turnLeft()
	-- We are on block 6 and want to be on block 1
	for temp=6,1,-1 do
		safeDig()
		safeForward()
	end
	turtle.turnRight()
	-- And we're ready to iterate again
end




