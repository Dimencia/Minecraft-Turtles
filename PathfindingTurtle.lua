
-- This is a base turtle implementation that should allow it to pathfind using A* pathfinding
-- Any movement or turning causes it to scan its environment and store data, allowing it to 'remember' where obstacles are
			
-- This is honestly doable.  If I need a refresher later: https://www.raywenderlich.com/3016-introduction-to-a-pathfinding
if not fs.exists("vec3.lua") then shell.run("wget", "https://raw.githubusercontent.com/Dimencia/Minecraft-Turtles/main/vec3.lua", "vec3.lua") end
if not fs.exists("json.lua") then shell.run("wget", "https://raw.githubusercontent.com/Dimencia/Minecraft-Turtles/main/dkjson.lua", "json.lua")	end
	
vec3 = require("vec3")
json = require("json")

logFile = fs.open("Logfile", "w")

-- First, check if we've already overwritten these funcs


function newPrint(params)
	oldPrint(getDisplayString(params))
	logFile.writeLine(getDisplayString(params))
	logFile.flush()
end
if not turtle.methodsOverwritten then
	oldPrint = print
	print = newPrint
end



function getDisplayString(object)
	local result = ""
	if type(object) == "string" then
		result = result .. object
	elseif type(object) == "table" then
		if object.x then -- IDK how else to make sure it's a vec3
			result = result .. vectorToString(object)
		else
			result = result .. "{"
			for k,v in pairs(object) do
				result = result .. getDisplayString(k) .. ":" .. getDisplayString(v)
			end
			result = result .. "}"
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
	
occupiedPositions = {} -- The key is the vec3, and the value is true if occupied, or nil/false if not
local initialOrientation = vec3(1,0,0)
local initialPosition = vec3(0,0,0)

orientations = { vec3(1,0,0),
				 vec3(0,0,1),
				 vec3(-1,0,0),
				 vec3(0,0,-1)} -- Where going higher in the list is turning right
orientationIndex = 1

turtle.orientation = initialOrientation 
turtle.relativePos = initialPosition

function vectorToString(vec)
	return vec.x .. "," .. vec.y .. "," .. vec.z
end

function SaveData()
	-- Updates our datafile with the turtle's position, orientation, and occupiedPositions (and maybe more later)
	local dataFile = fs.open("PathData", "w")
	local allData = {position=turtle.relativePos, orientation=turtle.orientation, occupiedPositions=occupiedPositions}
	local dataString = json.encode(allData)
	dataFile.write(dataString)
	dataFile.flush()
	dataFile.close()
end	

function LoadData()
	local f = fs.open("PathData", "r")
	local allData = json.decode(f.readAll())
	if allData and allData.position and allData.orientation and allData.occupiedPositions then
		turtle.relativePos = vec3(allData.position)
		turtle.orientation = vec3(allData.orientation)
		for k,v in ipairs(orientations) do
			if vectorToString(v) == vectorToString(turtle.orientation) then
				orientationIndex = k
				break
			end
		end
		
		occupiedPositions = allData.occupiedPositions
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

if fs.exists("PathData") then
	LoadData() -- Load before opening our write handle, which will erase everything
end

SaveData() -- Make sure it's not empty if we don't make it to the next tick

if not turtle.methodsOverwritten then
	baseDig = turtle.dig
	turtle.dig = function() -- We may have to pause a tick to wait for gravel to fall... 
		baseDig()
		detectBlocks() -- Check all occupied things after we dig
	end

	baseForward = turtle.forward
	turtle.forward = function()
		detectBlocks()
		if baseForward() then
			local newPosition = turtle.relativePos + turtle.orientation
			print("Moved forward from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(newPosition))
			turtle.relativePos = newPosition
			detectBlocks()
			return true
		end
			return false
	end

	baseUp = turtle.up
	turtle.up = function()
		detectBlocks()
		if baseUp() then
			local newPosition = turtle.relativePos + vec3(0,1,0)
			print("Moved up from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(newPosition))
			turtle.relativePos = newPosition
			detectBlocks()
			return true
		end
		return false
	end

	baseDown = turtle.down
	turtle.down = function()
		detectBlocks()
		if baseDown() then
			local newPosition = turtle.relativePos + vec3(0,-1,0)
			print("Moved down from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(newPosition))
			turtle.relativePos = newPosition
			detectBlocks()
			return true
		end
		return false
	end

	baseTurnLeft = turtle.turnLeft
	turtle.turnLeft = function()
		baseTurnLeft()
		local oldOrientation = turtle.orientation:clone()
		updateTurtleOrientationLeft()
		print("Turned left from " .. vectorToString(oldOrientation) .. " to " .. vectorToString(turtle.orientation))
		detectBlocks()
	end

	baseTurnRight = turtle.turnRight
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
	
	orientationIndex = orientationIndex-1
	if orientationIndex < 1 then
		orientationIndex = #orientations
	end
	turtle.orientation = orientations[orientationIndex]
end

function updateTurtleOrientationRight()
	orientationIndex = orientationIndex+1
	if orientationIndex > #orientations then
		orientationIndex = 1
	end
	turtle.orientation = orientations[orientationIndex]
end

function turnToAdjacent(adjacentPosition) -- Only use on adjacent ones... 
	print("Calculating turn from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(adjacentPosition))
	local newOrientation = adjacentPosition-turtle.relativePos
	newOrientation.y = 0
	-- Now determine how to get from current, to here
	-- First, if it was y only, we're done
	if newOrientation == vec3() or newOrientation == turtle.orientation then return true end
	
	-- Then iteration through orientations forward, if it's <=2 to the target we can go right, otherwise left
	for i=1,4 do
		local t = orientationIndex + i
		if t > #orientations then t = t - #orientations end
		if orientations[t] == newOrientation then
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
	occupiedPositions[vectorToString(turtle.relativePos+turtle.orientation)] = turtle.detect()
	occupiedPositions[vectorToString(turtle.relativePos+vec3(0,1,0))] = turtle.detectUp()
	occupiedPositions[vectorToString(turtle.relativePos+vec3(0,-1,0))] = turtle.detectDown()
	SaveData()
end
			
function ComputeSquare(aSquare, currentSquare, targetPosition)
	aSquare.parent = currentSquare
	aSquare.G = currentSquare.G+1
	aSquare.H = (targetPosition-aSquare.position):len()
	aSquare.score = aSquare.G + aSquare.H
	aSquare.count = pathCount
	pathCount = pathCount + 1
end
	

function lowestScoreSort(t,a,b) -- This is a special sort func, that we use to sort the keys so we can iterate properly
    -- And we sort the keys based on the values in the table t
	-- So actually, we should be more careful here.  We want it to finish a branch and try it
	-- So on ties, which are very common, it should prioritize the most recently added one
	-- Which is hard to judge.  But at least the most recently added 6, which would be the ones with the highest G
	
	-- So I've added a count param that we increment everytime we recalculate
	if t[a].score == t[b].score then
		return t[a].count > t[b].count
	else
		return t[a].score < t[b].score
	end
end		

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

			
function getAdjacentWalkableSquares(currentSquare)
	local results = {}
	for x=-1,1 do
		for z=-1,1 do
			local y = 0
			if not (x == 0 and z == 0) and (x == 0 or z == 0)  then
				-- Positions like 1,0,1, -1,0,-1, etc are all invalid, at least one param must be 0, but not all of them
				local targetPos = currentSquare.position + vec3(x,y,z)
				
				if not occupiedPositions[vectorToString(targetPos)] then
					results[targetPos] = {position=targetPos} 
				end
			end
		
		end
	end
	-- Y is handled seperately, since x and z must both be 0 for y of -1 and 1
	local x = 0
	local z = 0
	for y=-1,1,2 do
		local targetPos = currentSquare.position + vec3(x,y,z)
		if not occupiedPositions[vectorToString(targetPos)] then 
			results[targetPos] = {position=targetPos} 
		end
	end
	
	return results
end

function listLen(list)
	local count = 0
	for k,v in pairs(list) do
		if v ~= nil then count = count + 1 end
	end
	return count
end

openList = {}
closedList = {}
pathCount = 1
			
function GetPath(targetPosition)
    print("Getting path for turtle position " .. vectorToString(turtle.relativePos))
	if turtle.position then print ("Also, it lists a regular position of " .. vectorToString(turtle.position)) end
	local currentSquare = {position=turtle.relativePos,G=0,H=(targetPosition-turtle.relativePos):len(),count = 0}
	currentSquare.score = currentSquare.G + currentSquare.H -- Manually set these first, the rest rely on a parent
	
	pathCount = 1
	openList = { } -- I guess this is a generic object, which has fields .position
	openList[vectorToString(currentSquare.position)] = currentSquare -- This makes it easier to add/remove
	-- Suppose they also have a .score, .G, and .H, and .parent
	--closedList = {}
	
	tickCount = 1
	
	local finalMove = nil
	repeat 
		-- Get the square with the lowest score
		local currentSquare
		for k,v in spairs(openList,lowestScoreSort) do -- I have no idea how else to do this
			currentSquare = v
			break
		end
		
		-- Add this to the closed list, kind of assuming we're going to move there.  Sort of.  Remove from open.
		--closedList[vectorToString(currentSquare.position)] = currentSquare
		-- Skip the closed list, we never really use it.
		openList[vectorToString(currentSquare.position)] = nil -- Remove from open list
		
		if currentSquare.position == targetPosition then
			-- We found the path target and put it in the list, we're done. 
			finalMove = currentSquare
			break
		end
		
		local adjacentSquares = getAdjacentWalkableSquares(currentSquare) -- This will be a fun func
		
		for pos,aSquare in pairs(adjacentSquares) do 
			if not openList[vectorToString(pos)] then -- Syntax?
				-- Compute G, H, and F
				ComputeSquare(aSquare, currentSquare, targetPosition)
				-- Add for consideration in next step
				openList[vectorToString(pos)] = aSquare
			elseif openList[vectorToString(pos)] then -- aSquare is already in the list, so it already has these params
			    aSquare = openList[vectorToString(pos)]
				if currentSquare.G+1 < aSquare.G then
					-- Our path to aSquare is shorter, use our values
					ComputeSquare(aSquare, currentSquare, targetPosition)
				end
			end
			--print("Adjacent square " .. vectorToString(aSquare.position) .. " has score " .. aSquare.score)
		end
		
		tickCount = tickCount + 1
		if tickCount % 100 == 0 then
			print("Checking 100th position " .. vectorToString(currentSquare.position) .. " with score " .. currentSquare.score)
			sleep(0.1)
		end
		
	until listLen(openList) == 0 
	
	-- Okay so, find the last element in closedList, it was just added.  Or the first, due to insert?
	-- Going to assume first
	local curSquare = finalMove
	-- Each one gets inserted in front of the previous one
	local finalMoves = {}
	while curSquare ~= nil do
		table.insert(finalMoves, 1, curSquare)
		curSquare = curSquare.parent
	end
	return finalMoves -- Will have to figure out how to parse these into instructions, but, it's a path.  The shortest one, even. 
end

function followPath(moveList)
	for k,v in ipairs(moveList) do
		print("Performing move to adjacent square from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(v.position))
		local targetVector = v.position - turtle.relativePos
		local success
		if v.position ~= turtle.relativePos then
			if targetVector.y ~= 0 then
				-- Just go up or down
				if targetVector.y > 0 then
					success = turtle.up()
					if not success then occupiedPositions[vectorToString(v.position)] = true end
				else
					success = turtle.down()
					if not success then occupiedPositions[vectorToString(v.position)] = true end
				end
			else
				turnToAdjacent(v.position)
				success = turtle.forward()
				if not success then occupiedPositions[vectorToString(v.position)] = true end
			end
			
			if not success then -- We were blocked for some reason, re-pathfind
				-- Find the target...
				print("Obstacle detected, calculating and following new path")
				print("Occupied Positions: ", occupiedPositions)
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
	print("Path successfully followed, final position: " .. vectorToString(turtle.relativePos))
end


-- K after this is whatever we want it to do...

-- Alright, let's call this a training routine.
-- It should start facing the 'home' chest, which contains coal or fuel, and that's 0,0,0

-- Note that the chest ends up being 1,0,0, when we want to turn to face it while standing at 0,0,0
repeat
	turnToAdjacent(vec3(1,0,0))
	turtle.select(1)
	turtle.suck()
	turtle.refuel()
	-- Generate some random coords.  Stay within 16 or so blocks on each to keep it somewhat reasonable
	local target = vec3(math.random(0,16),math.random(0,16),math.random(0,16))
	print("Getting path to target")
	local path = GetPath(targetVec)
	followPath(path)
	print("Returning to base")
	target = vec3()
	path = GetPath(targetVec)
	followPath(path)
until 1 == 0
