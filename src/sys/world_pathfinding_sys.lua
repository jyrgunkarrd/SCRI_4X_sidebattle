local WorldPathfindingSystem = {}
WorldPathfindingSystem.__index = WorldPathfindingSystem

local DIRECTIONS = {
    { q = 1, r = 0 },
    { q = 1, r = -1 },
    { q = 0, r = -1 },
    { q = -1, r = 0 },
    { q = -1, r = 1 },
    { q = 0, r = 1 },
}

local function isInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function hexKey(q, r)
    return ("%d:%d"):format(q, r)
end

local function hexDistance(fromQ, fromR, toQ, toR)
    local deltaQ = toQ - fromQ
    local deltaR = toR - fromR
    return math.max(
        math.abs(deltaQ),
        math.abs(deltaR),
        math.abs(deltaQ + deltaR)
    )
end

local function hasHigherPriority(left, right)
    if left.f ~= right.f then
        return left.f < right.f
    end
    if left.h ~= right.h then
        return left.h < right.h
    end
    return left.sequence < right.sequence
end

local function heapPush(heap, node)
    heap[#heap + 1] = node
    local index = #heap
    while index > 1 do
        local parent = math.floor(index / 2)
        if hasHigherPriority(heap[parent], heap[index]) then
            break
        end
        heap[parent], heap[index] = heap[index], heap[parent]
        index = parent
    end
end

local function heapPop(heap)
    if #heap == 0 then
        return nil
    end
    local root = heap[1]
    local last = table.remove(heap)
    if #heap == 0 then
        return root
    end
    heap[1] = last
    local index = 1
    while true do
        local left = index * 2
        local right = left + 1
        local best = index
        if left <= #heap and hasHigherPriority(heap[left], heap[best]) then
            best = left
        end
        if right <= #heap and hasHigherPriority(heap[right], heap[best]) then
            best = right
        end
        if best == index then
            break
        end
        heap[index], heap[best] = heap[best], heap[index]
        index = best
    end
    return root
end

local function reconstructPath(nodes, destinationKey)
    local reversed = {}
    local key = destinationKey
    while key do
        local node = nodes[key]
        reversed[#reversed + 1] = { q = node.q, r = node.r }
        key = node.parentKey
    end

    local path = {}
    for index = #reversed, 1, -1 do
        path[#path + 1] = reversed[index]
    end
    return path
end

function WorldPathfindingSystem.new(options)
    options = options or {}
    local self = setmetatable({}, WorldPathfindingSystem)
    self.isPassable = options.isPassable or function()
        return true
    end
    self.getMovementCost = options.getMovementCost or function()
        return 1
    end
    self.minimumStepCost = options.minimumStepCost or 1
    self.maximumVisitedNodes = options.maximumVisitedNodes or 100000
    assert(type(self.isPassable) == "function", "isPassable must be a function")
    assert(type(self.getMovementCost) == "function",
        "getMovementCost must be a function")
    assert(type(self.minimumStepCost) == "number" and self.minimumStepCost > 0,
        "minimumStepCost must be positive")
    assert(type(self.maximumVisitedNodes) == "number"
        and self.maximumVisitedNodes >= 1,
        "maximumVisitedNodes must be positive")
    return self
end

function WorldPathfindingSystem.distance(fromQ, fromR, toQ, toR)
    return hexDistance(fromQ, fromR, toQ, toR)
end

function WorldPathfindingSystem:findPath(startQ, startR, goalQ, goalR, options)
    assert(isInteger(startQ) and isInteger(startR)
        and isInteger(goalQ) and isInteger(goalR),
        "Path coordinates must be integers")

    local routePassable = options and options.isPassable
    local function canPass(q, r, fromQ, fromR)
        return self.isPassable(q, r, fromQ, fromR)
            and (not routePassable or routePassable(q, r, fromQ, fromR))
    end

    if not canPass(startQ, startR)
        or not canPass(goalQ, goalR) then
        return nil, "blocked"
    end

    local startKey = hexKey(startQ, startR)
    local goalKey = hexKey(goalQ, goalR)
    if startKey == goalKey then
        return { { q = startQ, r = startR } }, 0
    end

    local openHeap = {}
    local closed = {}
    local nodes = {}
    local gScores = { [startKey] = 0 }
    local sequence = 1
    local startH = hexDistance(startQ, startR, goalQ, goalR)
        * self.minimumStepCost
    nodes[startKey] = {
        q = startQ,
        r = startR,
        parentKey = nil,
    }
    heapPush(openHeap, {
        key = startKey,
        q = startQ,
        r = startR,
        g = 0,
        h = startH,
        f = startH,
        sequence = sequence,
    })

    local visitedCount = 0
    while #openHeap > 0 do
        local current = heapPop(openHeap)
        if not closed[current.key]
            and current.g == gScores[current.key] then
            closed[current.key] = true
            visitedCount = visitedCount + 1
            if visitedCount > self.maximumVisitedNodes then
                return nil, "limit"
            end
            if current.key == goalKey then
                return reconstructPath(nodes, goalKey), current.g
            end

            for _, direction in ipairs(DIRECTIONS) do
                local neighborQ = current.q + direction.q
                local neighborR = current.r + direction.r
                local neighborKey = hexKey(neighborQ, neighborR)
                if not closed[neighborKey]
                    and canPass(neighborQ, neighborR,
                        current.q, current.r) then
                    local stepCost = self.getMovementCost(
                        current.q,
                        current.r,
                        neighborQ,
                        neighborR
                    )
                    assert(type(stepCost) == "number"
                        and stepCost >= self.minimumStepCost,
                        "Movement cost must be at least minimumStepCost")
                    local tentativeG = current.g + stepCost
                    if not gScores[neighborKey]
                        or tentativeG < gScores[neighborKey] then
                        gScores[neighborKey] = tentativeG
                        nodes[neighborKey] = {
                            q = neighborQ,
                            r = neighborR,
                            parentKey = current.key,
                        }
                        local h = hexDistance(
                            neighborQ,
                            neighborR,
                            goalQ,
                            goalR
                        ) * self.minimumStepCost
                        sequence = sequence + 1
                        heapPush(openHeap, {
                            key = neighborKey,
                            q = neighborQ,
                            r = neighborR,
                            g = tentativeG,
                            h = h,
                            f = tentativeG + h,
                            sequence = sequence,
                        })
                    end
                end
            end
        end
    end
    return nil, "unreachable"
end

return WorldPathfindingSystem
