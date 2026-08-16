local SiteIndex = {
    byId = {},
    sourceById = {},
    ids = {},
}

local SITE_DIRECTORY = "data/sites"

local function isSiteFile(filename)
    return filename ~= "index.lua" and filename:match("%.lua$") ~= nil
end

local function registerDefinition(definition, filename)
    assert(type(definition) == "table",
        ("Invalid site definition in %s"):format(filename))
    assert(type(definition.id) == "string" and definition.id ~= "",
        ("Site definition in %s is missing a valid id"):format(filename))
    assert(not SiteIndex.byId[definition.id],
        ("Duplicate site id '%s' found in %s and %s"):format(
            definition.id,
            SiteIndex.sourceById[definition.id],
            filename
        ))

    SiteIndex.byId[definition.id] = definition
    SiteIndex.sourceById[definition.id] = filename
    SiteIndex.ids[#SiteIndex.ids + 1] = definition.id
end

local filenames = love.filesystem.getDirectoryItems(SITE_DIRECTORY)
table.sort(filenames)

for _, filename in ipairs(filenames) do
    if isSiteFile(filename) then
        local moduleName = (SITE_DIRECTORY .. "/" .. filename)
            :gsub("%.lua$", "")
            :gsub("/", ".")
        local definitions = require(moduleName)

        assert(type(definitions) == "table",
            ("Site file %s must return a table"):format(filename))

        for _, definition in ipairs(definitions) do
            registerDefinition(definition, filename)
        end
    end
end

table.sort(SiteIndex.ids)

function SiteIndex.get(id)
    return SiteIndex.byId[id]
end

function SiteIndex.has(id)
    return SiteIndex.byId[id] ~= nil
end

return SiteIndex
