
-- This is a base turtle implementation that should allow it to pathfind using A* pathfinding
-- Any movement or turning causes it to scan its environment and store data, allowing it to 'remember' where obstacles are
			
-- This is honestly doable.  If I need a refresher later: https://www.raywenderlich.com/3016-introduction-to-a-pathfinding
if not fs.exists("vec3.lua") then shell.run("wget", "https://raw.githubusercontent.com/Dimencia/Minecraft-Turtles/main/vec3.lua", "vec3.lua") end
if not fs.exists("json.lua") then shell.run("wget", "https://raw.githubusercontent.com/Dimencia/Minecraft-Turtles/main/dkjson.lua", "json.lua")	end
if not fs.exists("heap.lua") then shell.run("wget", "https://gist.githubusercontent.com/H2NCH2COOH/1f929775db0a355ca6b6088a4662fe95/raw/1ccc4fc1d99ee6943fc66475f3feac6de8c83c31/heap.lua", "heap.lua") end	
	
vec3 = require("vec3")
json = require("json")
minheap = require("heap")

local logFile = fs.open("Logfile", "w")

function getDisplayString(object)
	local result = ""
	if type(object) == "string" then
		result = result .. object
	elseif type(object) == "table" then
		if object.x then -- IDK how else to make sure it's a vec3
			result = result .. vectorToString(object)
		else
			for k,v in pairs(object) do
				result = result .. getDisplayString(k) .. ":" .. getDisplayString(v) .. " "
			end
		end
	elseif type(object) == "boolean" then
		if object then result = result .. "true" else result = result .. "false" end
	elseif object ~= nil then
		result = result .. object
	else
		result = result .. "nil"
	end
	return result
end


function newPrint(...)
    local result = ""
	for k,v in pairs(arg) do
	    if k ~= "n" then
			result = result .. getDisplayString(v) .. " "
		end
	end
	oldPrint(result)
	logFile.writeLine(result)
	logFile.flush()
end
--if not turtle.methodsOverwritten then -- Unsure if turtle.methodsOverwritten doesn't persist, or if print resets itself, something is wrong
	oldPrint = print -- If you run it, then terminate and run it again, it didn't log anymore.  Guess we have to do this part every time
	print = newPrint
--end

if turtle.methodsOverwritten then
	print("Methods already overwritten, skipping them")
end


	
turtle.occupiedPositions = {} -- The key is the vec3, and the value is true if occupied, or nil/false if not
turtle.initialOrientation = vec3(1,0,0)
turtle.initialPosition = vec3(0,0,0)

turtle.orientations = { vec3(1,0,0),
				 vec3(0,0,1),
				 vec3(-1,0,0),
				 vec3(0,0,-1)} -- Where going higher in the list is turning right
turtle.orientationIndex = 1

turtle.directions = { "east","south","west","north"} -- In the same order as turtle.orientations so turtle.orientationIndex can still be used
-- This could get weird because the turtle.occupiedPositions might be in reference to the wrong x or z sign
-- So for example, we were pointed north, but gave it the vector for east
-- So when I went 'negative x' in the relative implementation, I was really going positive z
-- so anything with coords of like, 10,0,-2  , is actually -2,0,-10
-- Which, seems like I can do newOrientation-oldOrientation and multiply all coords by that
-- But, that fails when it was an opposite direction.  
-- Which we can test for but it's weird that there's an edge case, is there not a better way?  Is this wrong in other cases?
-- I mean it's only 3 cases.  Say I was pointed south instead, then my 'negative x' was negative z, but my positive x should be backwards and isn't

-- So what are our cases?
-- If it went from north to south, reverse all X and Z
-- If it went from east to west, reverse all X and Z...
-- If it went from turtle.initialOrientation of east, and they tell us that's actually north, swap Z and X, and negate Z
-- If it went from east to south, swap Z and X
-- This is hard.  Do it later.  These are unused so far, we do everything relative to our starting orientation

turtle.adjacentVectors = { vec3(1,0,0),
                    vec3(0,1,0),
					vec3(0,0,1),
					vec3(-1,0,0),
					vec3(0,-1,0),
					vec3(0,0,-1)} -- When looking for adjacents, we can iterate over this and add it to the position

turtle.orientation = turtle.initialOrientation 
turtle.position = turtle.initialPosition
turtle.home = turtle.initialPosition

function vectorToString(vec)
	return vec.x .. "," .. vec.y .. "," .. vec.z
end

function SaveData()
	-- Updates our datafile with the turtle's position, orientation, and turtle.occupiedPositions (and maybe more later)
	local dataFile = fs.open("PathData", "w")
	local allData = {position=turtle.position, orientation=turtle.orientation, occupiedPositions=turtle.occupiedPositions, home=turtle.home}
	local dataString = json.encode(allData)
	dataFile.write(dataString)
	dataFile.flush()
	dataFile.close()
end	

function LoadData()
	local f = fs.open("PathData", "r")
	local allData = json.decode(f.readAll())
	if allData and allData.position and allData.orientation and allData.occupiedPositions then
		turtle.position = vec3(allData.position)
		turtle.orientation = vec3(allData.orientation)
		for k,v in ipairs(turtle.orientations) do
			if vectorToString(v) == vectorToString(turtle.orientation) then
				turtle.orientationIndex = k
				break
			end
		end
		if allData.home then
			turtle.home = vec3(allData.home)
		end
		turtle.occupiedPositions = allData.occupiedPositions
	end
	f.close()
end

function stringSplit (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

function hasAnyElements(list)
	for k,v in pairs(list) do
		return true
	end
	return false
end

if fs.exists("PathData") then
	LoadData() -- Load before opening our write handle, which will erase everything
end

SaveData() -- Make sure it's not empty if we don't make it to the next tick

if not turtle.methodsOverwritten then
	local baseDig = turtle.dig
	turtle.dig = function() -- We may have to pause a tick to wait for gravel to fall... 
		baseDig()
		detectBlocks() -- Check all occupied things after we dig
	end

	local baseForward = turtle.forward
	turtle.forward = function()
		detectBlocks()
		if baseForward() then
			local newPosition = turtle.position + turtle.orientation
			print("Moved forward from " .. vectorToString(turtle.position) .. " to " .. vectorToString(newPosition))
			turtle.position = newPosition
			detectBlocks()
			return true
		end
			return false
	end

	local baseUp = turtle.up
	turtle.up = function()
		detectBlocks()
		if baseUp() then
			local newPosition = turtle.position + vec3(0,1,0)
			print("Moved up from " .. vectorToString(turtle.position) .. " to " .. vectorToString(newPosition))
			turtle.position = newPosition
			detectBlocks()
			return true
		end
		return false
	end

	local baseDown = turtle.down
	turtle.down = function()
		detectBlocks()
		if baseDown() then
			local newPosition = turtle.position + vec3(0,-1,0)
			print("Moved down from " .. vectorToString(turtle.position) .. " to " .. vectorToString(newPosition))
			turtle.position = newPosition
			detectBlocks()
			return true
		end
		return false
	end

	local baseTurnLeft = turtle.turnLeft
	turtle.turnLeft = function()
		baseTurnLeft()
		local oldOrientation = turtle.orientation:clone()
		updateTurtleOrientationLeft()
		print("Turned left from " .. vectorToString(oldOrientation) .. " to " .. vectorToString(turtle.orientation))
		detectBlocks()
	end

	local baseTurnRight = turtle.turnRight
	turtle.turnRight = function()
		baseTurnRight()
		local oldOrientation = turtle.orientation:clone()
		updateTurtleOrientationRight()
		print("Turned right from " .. vectorToString(oldOrientation) .. " to " .. vectorToString(turtle.orientation))
		detectBlocks()
	end
end
turtle.methodsOverwritten = true


function updateTurtleOrientationLeft()
	
	turtle.orientationIndex = turtle.orientationIndex-1
	if turtle.orientationIndex < 1 then
		turtle.orientationIndex = #turtle.orientations
	end
	turtle.orientation = turtle.orientations[turtle.orientationIndex]
end

function updateTurtleOrientationRight()
	turtle.orientationIndex = turtle.orientationIndex+1
	if turtle.orientationIndex > #turtle.orientations then
		turtle.orientationIndex = 1
	end
	turtle.orientation = turtle.orientations[turtle.orientationIndex]
end


-- 
-- Pathfinding Stuff Below
--

function turnToAdjacent(adjacentPosition) -- Only use on adjacent ones... 
	print("Calculating turn from " .. vectorToString(turtle.position) .. " to " .. vectorToString(adjacentPosition))
	local newOrientation = adjacentPosition-turtle.position
	newOrientation.y = 0
	-- Now determine how to get from current, to here
	-- First, if it was y only, we're done
	if newOrientation == vec3() or newOrientation == turtle.orientation then return true end
	
	-- Then iteration through turtle.orientations forward, if it's <=2 to the target we can go right, otherwise left
	for i=1,4 do
		local t = turtle.orientationIndex + i
		if t > #turtle.orientations then t = t - #turtle.orientations end
		if turtle.orientations[t] == newOrientation then
			if i < 2 then
				turtle.turnRight()
				return true
			elseif i == 2 then
				turtle.turnRight()
				turtle.turnRight()
				return true
			else
				turtle.turnLeft()
				return true
			end
		end
	end
	return false
end

function detectBlocks()
	-- Detects all blocks and stores the data
	turtle.occupiedPositions[vectorToString(turtle.position+turtle.orientation)] = turtle.detect()
	turtle.occupiedPositions[vectorToString(turtle.position+vec3(0,1,0))] = turtle.detectUp()
	turtle.occupiedPositions[vectorToString(turtle.position+vec3(0,-1,0))] = turtle.detectDown()
	SaveData()
end
			
function ComputeSquare(aSquare, currentSquare, targetPosition)
	aSquare.parent = currentSquare
	aSquare.G = currentSquare.G+1
	aSquare.H = (targetPosition-aSquare.position):len()*1.5
	aSquare.score = aSquare.G + aSquare.H
end
			
function getAdjacentWalkableSquares(currentSquare)
	local results = {}
	for k,v in pairs(turtle.adjacentVectors) do
		local targetVec = currentSquare.position + v
		if not turtle.occupiedPositions[vectorToString(targetVec)] then -- I am unsure that this works, at least not reliably, it's weird
			results[targetVec] = {position=targetVec}
		end
	end
	return results
end

			
function GetPath(targetPosition)
    print("Getting path for turtle position " .. vectorToString(turtle.position))
	local currentSquare = {position=turtle.position,G=0,H=(targetPosition-turtle.position):len()*1.5}
	currentSquare.score = currentSquare.G + currentSquare.H -- Manually set these first, the rest rely on a parent
	
	local openList = { } -- I guess this is a generic object, which has fields .position
	openList[vectorToString(currentSquare.position)] = currentSquare -- This makes it easier to add/remove
	local openHeap = minheap.new()
	openHeap:push(currentSquare,currentSquare.score)
	-- Suppose they also have a .score, .G, and .H, and .parent
	local closedList = {}
	
	local tickCount = 1
	
	local finalMove = nil
	repeat 
		-- Get the square with the lowest score
		local currentSquare = openHeap:pop()
		
		-- Add this to the closed list, no longer consider it for future moves
		closedList[vectorToString(currentSquare.position)] = true
		openList[vectorToString(currentSquare.position)] = nil -- Remove from open list
		
		if currentSquare.position == targetPosition then
			-- We found the path target and put it in the list, we're done. 
			finalMove = currentSquare
			break
		end
		
		local adjacentSquares = getAdjacentWalkableSquares(currentSquare) -- Should never return occupied squares
		-- Returns us a list where the keys are positions, and values just have a position field.  We add more fields to the values
		for pos,aSquare in pairs(adjacentSquares) do 
			if not closedList[vectorToString(pos)] then -- Using vectors as keys doesn't work right, have to convert to string
				if not openList[vectorToString(pos)] then 
					-- Compute G, H, and F, and set them on the square
					ComputeSquare(aSquare, currentSquare, targetPosition)
					-- Add for consideration in next step
					openList[vectorToString(pos)] = aSquare
					openHeap:push(aSquare,aSquare.score)
				elseif openList[vectorToString(pos)] then -- aSquare is already in the list, so it already has these params
					aSquare = openList[vectorToString(pos)] -- Use the existing object
					if currentSquare.G+1 < aSquare.G then
						-- Our path to aSquare is shorter, use our values, replaced into the object - which is already in the heap and list
						ComputeSquare(aSquare, currentSquare, targetPosition)
					end
				end
			end
		end
		tickCount = tickCount + 1
		if tickCount % 1000 == 0 then
			print("Checking 1000th position " .. vectorToString(currentSquare.position) .. " with score " .. currentSquare.score)
			sleep(0.1)
		end
		
	until not hasAnyElements(openList) or currentSquare.score > (currentSquare.position-targetPosition):len()*32
	-- We'll go up to 32 blocks out of the way, per 1 block away in straight-line space
	
	
	local curSquare = finalMove -- We set this above when we found it, start at the end
	-- Each one gets inserted in front of the previous one
	local finalMoves = {}
	while curSquare ~= nil do
		table.insert(finalMoves, 1, curSquare)
		curSquare = curSquare.parent
	end
	return finalMoves
end

function followPath(moveList)
	for k,v in ipairs(moveList) do
		print("Performing move to adjacent square from " .. vectorToString(turtle.position) .. " to " .. vectorToString(v.position))
		local targetVector = v.position - turtle.position
		local success
		
		-- We actually just want to get adjacent to the target position
		-- And then we turn to face it and call it done
		
		if v.position ~= turtle.position and targetVector:len() > 1 then
			if targetVector.y ~= 0 then
				-- Just go up or down
				if targetVector.y > 0 then
					success = turtle.up()
					if not success then turtle.occupiedPositions[vectorToString(v.position)] = true end
				else
					success = turtle.down()
					if not success then turtle.occupiedPositions[vectorToString(v.position)] = true end
				end
			else
				turnToAdjacent(v.position)
				success = turtle.forward()
				if not success then turtle.occupiedPositions[vectorToString(v.position)] = true end
			end
			
			if not success then -- We were blocked for some reason, re-pathfind
				-- Find the target...
				print("Obstacle detected, calculating and following new path")
				--print("Occupied Positions: ", turtle.occupiedPositions)
				-- SO, this is really weird and really annoying.
				-- If this happens, we seem to often path back to the same spot, even though it's occupied
				-- But only sometimes, not always, it's wild.  
				local lastTarget = nil
				for k2, v2 in ipairs(moveList) do
					lastTarget = v2
				end
				local newPath = GetPath(lastTarget.position)
				followPath(newPath)
				return
			end
		end
	end
	print("Path successfully followed, final position: " .. vectorToString(turtle.position))
end

local arg = {...}

turtle.moveTo = function(targetVector)
	local path = GetPath(target)
	followPath(path)
	turnToAdjacent(targetVector)
end
turtle.getPath = GetPath
turtle.followPath = followPath
turtle.turnToAdjacent = turnToAdjacent
turtle.reset = function()
	turtle.position = vec3()
	turtle.orientation = turtle.initialOrientation
	turtle.orientationIndex = 1
	SaveData()
end
turtle.setGPS = function(newPos, newOrientation)
	-- This is used to input the GPS position that the bot's start position is at
	-- Will then convert all turtle.occupiedPositions to match this new GPS position, so the data is globally usable
	-- Also simplifies entering waypoints and etc
	-- newPos should be a vec3
	-- second argument is optionally, "north","south","east","west" to specify its starting direction
	if fs.exists("PathData.bak") then
		shell.run("delete","PathData.bak")
	end
	shell.run("copy","PathData","PathData.bak")
	
	local newOP = {}
	
	for k,v in pairs(turtle.occupiedPositions) do
		-- k is the string vector, v is a boolean
		-- Which is unfortunate when it comes time to edit them, but okay
		local vec = vec3(stringSplit(k,","))
		vec = vec + newPos
		newOP[vectorToString(vec)] = v
	end
	turtle.position = newPos
	turtle.orientation = newOrientation

	turtle.occupiedPositions = newOP
	SaveData()
	print("Positions updated to world positions")
	
	
end

if arg[1] then
	print(arg)
	if arg[1] == "reset" then
		turtle.position = vec3()
		turtle.orientation = turtle.initialOrientation
		turtle.orientationIndex = 1
		SaveData()
	elseif string.lower(arg[1]) == "setgps" and arg[2] then
		-- This is used to input the GPS position that the bot's start position is at
		-- Will then convert all turtle.occupiedPositions to match this new GPS position, so the data is globally usable
		-- Also simplifies entering waypoints and etc
		-- Second argument should be formatted as "x,y,z"
		-- Third argument is optionally, "north","south","east","west" to specify its starting direction
		local newPos = vec3(stringSplit(arg[2],","))
		if fs.exists("PathData.bak") then
			shell.run("delete","PathData.bak")
		end
		shell.run("copy","PathData","PathData.bak")
		
		local newOP = {}
		
		for k,v in pairs(turtle.occupiedPositions) do
			-- k is the string vector, v is a boolean
			-- Which is unfortunate when it comes time to edit them, but okay
			local vec = vec3(stringSplit(k,","))
			vec = vec + newPos
			newOP[vectorToString(vec)] = v
		end
		turtle.position = newPos
		if arg[3] then
			-- TODO: Do this later.  We might have to move everything more based on this, if we do it
			-- Or just, leave it all relative to the orientation it started in, and rely on them to fix orientation when resetting
		end
		turtle.occupiedPositions = newOP
		SaveData()
		print("Positions updated to world positions")
		-- TODO: This didn't quite work.  It seemed like it did, but then it got lost underground for some reason
		-- And couldn't get back to base
		-- It also makes it really hard to debug, rolling back
	end
end

-- K after this is whatever we want it to do...

-- Alright, let's call this a training routine.
-- It should start facing the 'home' chest, which contains coal or fuel, and that's 0,0,0

-- Note that the chest ends up being 1,0,0, when we want to turn to face it while standing at 0,0,0
--repeat
--    if turtle.position ~= turtle.home then
--		print("Returning to base")
--		local path = GetPath(turtle.home)
--		followPath(path)
--	else
--		-- followPath should now just get us adjacent and already turn us...
--		--turnToAdjacent(turtle.home+turtle.initialOrientation)
--		turtle.select(1)
--		turtle.suck()
--		turtle.refuel()
--		-- Generate some random coords.  Stay within 16 or so blocks on each to keep it somewhat reasonable
--		local target
--		repeat
--			target = turtle.home+vec3(math.random(-16,16),math.random(0,16),math.random(-16,16))
--		until not turtle.occupiedPositions[vectorToString(target)]
--		print("Getting path to target")
--		local path = GetPath(target)
--		followPath(path)
--	end
--until 1 == 0
