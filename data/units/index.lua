local UnitIndex = {
    byId = {},
    sourceById = {},
    ids = {},
}

local UNIT_DIRECTORY = "data/units"

local function isUnitFile(filename)
    return filename ~= "index.lua" and filename:match("%.lua$") ~= nil
end

local function registerDefinition(definition, filename)
    assert(type(definition) == "table", ("Invalid unit definition in %s"):format(filename))
    assert(type(definition.id) == "string" and definition.id ~= "",
        ("Unit definition in %s is missing a valid id"):format(filename))
    assert(not UnitIndex.byId[definition.id],
        ("Duplicate unit id '%s' found in %s and %s"):format(
            definition.id,
            UnitIndex.sourceById[definition.id],
            filename
        ))

    UnitIndex.byId[definition.id] = definition
    UnitIndex.sourceById[definition.id] = filename
    UnitIndex.ids[#UnitIndex.ids + 1] = definition.id
end

local filenames = love.filesystem.getDirectoryItems(UNIT_DIRECTORY)
table.sort(filenames)

for _, filename in ipairs(filenames) do
    if isUnitFile(filename) then
        local moduleName = (UNIT_DIRECTORY .. "/" .. filename)
            :gsub("%.lua$", "")
            :gsub("/", ".")
        local definitions = require(moduleName)

        assert(type(definitions) == "table",
            ("Unit file %s must return a table"):format(filename))

        for _, definition in ipairs(definitions) do
            registerDefinition(definition, filename)
        end
    end
end

table.sort(UnitIndex.ids)

function UnitIndex.get(id)
    return UnitIndex.byId[id]
end

function UnitIndex.has(id)
    return UnitIndex.byId[id] ~= nil
end

return UnitIndex
