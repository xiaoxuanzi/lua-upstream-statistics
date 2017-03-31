local table  = require( "table" )
local string = require( "string" )

local _M = {}

function _M.split( str, pat )

    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local last_end, s, e = 1, 1, 0

    while s do
        s, e = string.find( str, pat, last_end )
        if s then
            table.insert( t, str:sub( last_end, s-1 ) )
            last_end = e + 1
        end
    end

    table.insert( t, str:sub( last_end ) )
    return t
end

function _M.dupdict( tbl, deep, ctbl )

    local t = {}

    if type(tbl) ~= 'table' then
        return tbl
    end

    ctbl = ctbl or {}

    ctbl[tbl] = t

    for k, v in pairs( tbl ) do
        if deep then
            if ctbl[v] ~= nil then
                v = ctbl[v]
            elseif type( v ) == 'table' then
                v = _M.dupdict(v, deep, ctbl)
            end
        end
        t[ k ] = v
    end

    return setmetatable( t, getmetatable(tbl) )
end

return _M
