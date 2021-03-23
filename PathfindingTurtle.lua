
-- This is a base turtle implementation that should allow it to pathfind using A* pathfinding
-- Any movement or turning causes it to scan its environment and store data, allowing it to 'remember' where obstacles are
			
-- This is honestly doable.  If I need a refresher later: https://www.raywenderlich.com/3016-introduction-to-a-pathfinding
if not fs.exists("vec3.lua") then shell.run("wget", "https://raw.githubusercontent.com/Dimencia/Minecraft-Turtles/main/vec3.lua", "vec3.lua") end
if not fs.exists("json.lua") then shell.run("wget", "https://raw.githubusercontent.com/Dimencia/Minecraft-Turtles/main/dkjson.lua", "json.lua")	end
	
local vec3 = require("vec3")
local json = require("json")

	
local occupiedPositions = {} -- The key is the vec3, and the value is true if occupied, or nil/false if not
local initialOrientation = vec3(1,0,0)
local initialPosition = vec3(0,0,0)

turtle.orientation = initialOrientation 
turtle.relativePos = initialPosition

function SaveData()
	-- Updates our datafile with the turtle's position, orientation, and occupiedPositions (and maybe more later)
	local stringOccupiedPositions = {}
	for k,v in pairs(occupiedPositions) do
		stringOccupiedPositions[vectorToString(k)] = v
	end
	local allData = {position=turtle.relativePos, orientation=turtle.orientation, occupiedPositions=stringOccupiedPositions}
	local dataString = json.encode(allData)
	dataFile.write(dataString)
	dataFile.flush()
end	

function LoadData()
	local f = fs.open("PathData", "r")
	local allData = json.decode(f.readAll())
	if allData and allData.position and allData.orientation and allData.occupiedPositions then
		turtle.relativePos = vec3(allData.position)
		turtle.orientation = vec3(allData.orientation)
		local stringOccupiedPositions = allData.occupiedPositions
		occupiedPositions = {}
		for k,v in pairs(stringOccupiedPositions) do
			occupiedPositions[vec3(stringSplit(k,","))] = v
		end
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

dataFile = fs.open("PathData", "w")
SaveData() -- Make sure it's not empty if we don't make it to the next tick

local baseDig = turtle.dig
turtle.dig = function() -- We may have to pause a tick to wait for gravel to fall... 
	baseDig()
	detectBlocks() -- Check all occupied things after we dig
end

local baseForward = turtle.forward
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

local baseUp = turtle.up
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

local baseDown = turtle.down
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

local baseTurnLeft = turtle.turnLeft
turtle.turnLeft = function()
	baseTurnLeft()
	local oldOrientation = turtle.orientation
	updateTurtleOrientationLeft()
	print("Turned left from " .. vectorToString(oldOrientation) .. " to " .. vectorToString(turtle.orientation))
	detectBlocks()
end

local baseTurnRight = turtle.turnRight
turtle.turnRight = function()
	baseTurnRight()
	local oldOrientation = turtle.orientation
	updateTurtleOrientationRight()
	print("Turned right from " .. vectorToString(oldOrientation) .. " to " .. vectorToString(turtle.orientation))
	detectBlocks()
end


function updateTurtleOrientationLeft()
	-- Orientation is interesting... we can only turn left or right, so Y can be ignored completely
	-- But basically, x = !x, z = !z
	-- Sort of.
	-- Default orientation is 1,0,0
	-- Turning right should give us a positive z, so 0,0,1
	-- And turning left gives us a negative one, 0,0,-1
	-- So I guess left negates it...
	local x = turtle.orientation.x
	local z = turtle.orientation.z
	turtle.orientation.z = -x
	turtle.orientation.x = -z
end

function updateTurtleOrientationRight()
	local x = turtle.orientation.x
	local z = turtle.orientation.z
	turtle.orientation.z = x
	turtle.orientation.x = z
end

function turnToAdjacent(adjacentPosition) -- Only use on adjacent ones... 
	print("Calculating turn from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(adjacentPosition))
	local newOrientation = adjacentPosition-turtle.relativePos
	newOrientation.y = 0
	-- Now determine how to get from current, to here
	-- First, if it was y only, we're done
	if newOrientation == vec3() or newOrientation == turtle.orientation then return true end
	-- There's only like 4 cases here, I guess I can do them manually
	if newOrientation.z == turtle.orientation.x and newOrientation.x == turtle.orientation.z then
		-- Unsure if the and is necessary or meaningful
		-- But this means it's just to the right
		turtle.turnRight()
		return true
	elseif newOrientation.z == -turtle.orientation.x then
		turtle.turnLeft()
		return true
	else -- It doesn't matter, we do a 180
		turtle.turnRight()
		turtle.turnRight()
		return true
	end
end

function detectBlocks()
	-- Detects all blocks and stores the data
	if turtle.detect() then occupiedPositions[turtle.relativePos+turtle.orientation] = true else occupiedPositions[turtle.relativePos+turtle.orientation] = false end
	if turtle.detectUp() then occupiedPositions[turtle.relativePos+turtle.orientation+vec3(0,1,0)] = true else occupiedPositions[turtle.relativePos+turtle.orientation+vec3(0,1,0)] = false end
	if turtle.detectDown() then occupiedPositions[turtle.relativePos+turtle.orientation+vec3(0,-1,0)] = true else occupiedPositions[turtle.relativePos+turtle.orientation+vec3(0,-1,0)] = false end
	SaveData()
end
			
function ComputeSquare(aSquare, currentSquare, targetPosition)
	aSquare.parent = currentSquare
	aSquare.G = currentSquare.G+1
	aSquare.H = (targetPosition-aSquare.position):len()
	aSquare.score = aSquare.G + aSquare.H
end
	

function lowestScoreSort(t,a,b) -- This is a special sort func, that we use to sort the keys so we can iterate properly
    -- And we sort the keys based on the values in the table t
	return t[a].score ~= nil and t[b].score ~= nil and t[a].score < t[b].score
end		

function vectorToString(vec)
	return vec.x .. "," .. vec.y .. "," .. vec.z
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
			if not (x == 0 and z == 0) and (x == 0 or z == 0) then
				-- Positions like 1,0,1, -1,0,-1, etc are all invalid, at least one param must be 0, but not all of them
				local targetPos = currentSquare.position + vec3(x,y,z)
				results[targetPos] = {position=targetPos} 
			end
		
		end
	end
	-- Y is handled seperately, since x and z must both be 0 for y of -1 and 1
	local x = 0
	local z = 0
	for y=-1,1,2 do
		local targetPos = currentSquare.position + vec3(x,y,z)
		if not occupiedPositions[targetPos] then 
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
			
function GetPath(targetPosition)
    print("Getting path for turtle position " .. vectorToString(turtle.relativePos))
	if turtle.position then print ("Also, it lists a regular position of " .. vectorToString(turtle.position)) end
	local currentSquare = {position=turtle.relativePos,G=0,H=(targetPosition-turtle.relativePos):len()}
	currentSquare.score = currentSquare.G + currentSquare.H -- Manually set these first, the rest rely on a parent
	
	openList = { } -- I guess this is a generic object, which has fields .position
	openList[currentSquare.position] = currentSquare -- This makes it easier to add/remove
	-- Suppose they also have a .score, .G, and .H, and .parent
	closedList = {}
	
	tickCount = 0
	
	local finalMove = nil
	repeat 
		-- Get the square with the lowest score
		local currentSquare
		for k,v in spairs(openList,lowestScoreSort) do -- I have no idea how else to do this
			currentSquare = v
			break
		end
		
		
		-- Add this to the closed list, kind of assuming we're going to move there.  Sort of.  Remove from open.
		closedList[currentSquare.position] = currentSquare
		openList[currentSquare.position] = nil -- Remove from open list
		
		if currentSquare.position == targetPosition then
			-- We found the path target and put it in the list, we're done. 
			finalMove = currentSquare
			break
		end
		
		print("Checking position " .. vectorToString(currentSquare.position) .. " with score " .. currentSquare.score)
		
		local adjacentSquares = getAdjacentWalkableSquares(currentSquare) -- This will be a fun func
		
		for pos,aSquare in pairs(adjacentSquares) do 
			if not openList[pos] then -- Syntax?
				-- Compute G, H, and F
				ComputeSquare(aSquare, currentSquare, targetPosition)
				-- Add for consideration in next step
				openList[pos] = aSquare
			elseif openList[pos] then -- aSquare is already in the list, so it already has these params
				if currentSquare.G+1 < aSquare.G then
					-- Our path to aSquare is shorter, use our values
					ComputeSquare(aSquare, currentSquare, targetPosition)
				end
			end
			--print("Adjacent square " .. vectorToString(aSquare.position) .. " has score " .. aSquare.score)
		end
		print(listLen(openList) .. " remaining entries in open list")
		tickCount = tickCount + 1
		--coroutine.yield()
		
	until listLen(openList) == 0 
	
	-- Okay so, find the last element in closedList, it was just added.  Or the first, due to insert?
	-- Going to assume first
	local curSquare = finalMove
	-- Each one gets inserted in front of the previous one
	local finalMoves = {}
	while curSquare ~= nil do
		table.insert(finalMoves,1, curSquare)
		curSquare = curSquare.parent
	end
	
	return finalMoves -- Will have to figure out how to parse these into instructions, but, it's a path.  The shortest one, even. 
end

function followPath(moveList)
	for k,v in ipairs(moveList) do
		print("Performing move to adjacent square from " .. vectorToString(turtle.relativePos) .. " to " .. vectorToString(v.position))
		local targetVector = v.position - turtle.relativePos
		local success
		if targetVector.y ~= 0 then
			-- Just go up or down
			if targetVector.y > 0 then
				success = turtle.up()
				if not success then occupiedPositions[v.position] = true end
			else
				success = turtle.down()
				if not success then occupiedPositions[v.position] = true end
			end
		else
			turnToAdjacent(v.position)
			success = turtle.forward()
			if not success then occupiedPositions[v.position] = true end
		end
		
		if not success then -- We were blocked for some reason, re-pathfind
			-- Find the target...
			print("Obstacle detected, calculating and following new path")
			local lastTarget = nil
			for k2, v2 in pairs(moveList) do
				lastTarget = v2
			end
			local newPath = GetPath(lastTarget.position)
			followPath(newPath)
			return
		end
	end
	print("Path successfully followed, final position: " .. vectorToString(turtle.relativePos))
end


-- K after this is whatever we want it to do...

-- For testing purposes, let's just have it move -15x and 1 Y (cuz I know the start point is down 1...)
local targetVec = vec3(-15,1,0)
print("Getting path to target")
local path = GetPath(targetVec)
-- And, follow the path.  Or try.
followPath(path)
