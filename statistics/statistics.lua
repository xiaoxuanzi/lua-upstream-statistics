local json = require( "cjson" )

local statistic_key = 'upstream-statistics'
local store_data    = ngx.shared.upstream_statistics

local INIT_VAL = 'MRD_INTIT_VAL'

local _M = {}

function _M.init()

    local val = INIT_VAL
    local succ, err, f = store_data:set(statistic_key, val)
    if not succ then
        ngx.log(ngx.ERR, 'init store data failed, err: ' .. err)
    end

end

function split( str, pat )

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

function dupdict( tbl, deep, ctbl )

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
                v = dupdict(v, deep, ctbl)
            end
        end
        t[ k ] = v
    end

    return setmetatable( t, getmetatable(tbl) )
end

local function new_data()
    return {
        --zones = {},
        upstreams = {}
    }
end

local function new_item()
    -- use in upstream or other
    return {

        requests = {
            request_time = 0,--the delay of upst server response
            request_length = 0,
            total = 0
        },

        responses = {
            ['1xx'] = 0,
            ['2xx'] = 0,
            ['3xx'] = 0,
            ['4xx'] = 0,
            ['5xx'] = 0,
            total = 0,

            body_bytes_sent = 0
        },

        upstreams = {
            ['1xx'] = 0,
            ['2xx'] = 0,
            ['3xx'] = 0,
            ['4xx'] = 0,
            ['5xx'] = 0,
            ['-xx'] = 0,
            total = 0,
            upstream_response_time = 0,
            upstream_response_length = 0
        },

        --[[
        --status = {
        --  dowm = true
        --  ups_name = 'test'
        --  conns = 1234
        --  accessed = ts
        --  checked = ts
        --}
        --]]

    }
end

local function set_dict_data( dict, key, data )

    local err, json_data = pcall(json.encode, data )
    if not err then
        ngx.log(ngx.ERR, 'set dict data faled, since json decode, err: ', err)
        return
    end

    local succ, err, f = dict:set(key, json_data )
    if not succ then
        ngx.log(ngx.ERR, 'set dict data failed, err: ' .. err)
    end

end

local function get_dict_data( dict, key )

    local val, err = dict:get( key )

    if not val then
        return nil, err
    end

    if val == INIT_VAL then
        return val, nil
    end

    local err, data = pcall( json.decode, val )
    if not err then
        ngx.log(ngx.ERR, 'get statistic failed, err : ' .. err)

        return nil, err
    end

    return data, nil

end

local function fill_item(upst, data)

    local requests = upst.requests

    requests['request_time'] = requests[ 'request_time' ] + data.request_time
    requests['request_length'] =requests['request_length'] + data.request_length
    requests.total = requests.total + 1

    local statuskey = tostring(data.status):sub(1, 1) .. 'xx'
    local responses = upst.responses

    responses.total = responses.total + 1
    responses[statuskey] = responses[statuskey] + 1
    responses['body_bytes_sent'] =
        responses['body_bytes_sent'] + data.body_bytes_sent

    local upst_status_table = split(data.upstream_status, ',')
    local upst_resp_servers = #upst_status_table

    local upstreams = upst.upstreams
    local upst_status_num 
    local upst_statuskey
    local resp_ts 
    local resp_len

    upstreams.total = upstreams.total + 1

    if upst_resp_servers == 1 then
        upst_status_num = tostring(data.upstream_status):sub(1, 1)
    else
        upst_status_num = tostring(upst_status_table[ upst_resp_servers ]):sub(2, 2)
    end

    upst_statuskey = upst_status_num .. 'xx'
    upstreams[upst_statuskey] = upstreams[upst_statuskey] + 1

    if upst_statuskey == '-xx' then
        upstreams['-xx'] = upstreams['-xx'] + 1
        --ngx.log(ngx.ERR, 'status : ', data.status)
        return
    end

    if upst_status_num ~= '2' then
        return
    end

    if upst_resp_servers == 1 then
        resp_ts = data.upstream_response_time
        resp_len = data.upstream_response_length
    else
        local upst_resptime_table = split(data.upstream_response_time, ',')
        local upst_resplen_table  = split(data.upstream_response_length, ',')
        resp_ts  = tostring(upst_resptime_table[ upst_resp_servers ]):sub(2, -1)
        resp_len = tostring(upst_resplen_table[ upst_resp_servers]):sub(2, -1)
    end

    upstreams['upstream_response_time'] =
                    upstreams['upstream_response_time'] + resp_ts
    upstreams['upstream_response_length'] =
                    upstreams['upstream_response_length'] + resp_len

end

local function pretty_upst_peers_data(name, data, store)

    local upst_name
    local ser_addr
    local upst_ser_table
    local upst_data

    upst_ser_table = split(name, '_')
    upst_name, ser_addr = upst_ser_table[1], upst_ser_table[2]
    upst_data = store[upst_name]
    if not upst_data then
        upst_data = {}
        store[upst_name] = upst_data
    end

    upst_data[ser_addr]= dupdict(data, true)

end

function _M.log()

    local upstream_status = ngx.var.upstream_status
    if not upstream_status then
        --ngx.log(ngx.ERR, 'the request is not belong to any upstream')
        return
    end

    local data, err = get_dict_data( store_data, statistic_key )
    if not data then
        ngx.log(ngx.ERR, 'get dict data failed, err: '.. err)
        return
    end

    if data == INIT_VAL then
        data = new_data()
    end

    local upstream_addr = ngx.var.upstream_addr
    local skey = ngx.var.uri
    skey = string.gsub(skey, '/', '-')
    skey = string.sub(skey, 2)

    local key = skey .. '_' .. upstream_addr

    local http_data = {
        status = ngx.var.status,
        body_bytes_sent = ngx.var.body_bytes_sent,
        request_length  = ngx.var.request_length,
        request_time    = ngx.var.request_time,
        upstream_status = ngx.var.upstream_status,
        upstream_response_time   = ngx.var.upstream_response_time,
        upstream_response_length = ngx.var.upstream_response_length,
    }

    if not data.upstreams[ key ] then
        data.upstreams[ key ] = new_item()
    end

    local upstream = data.upstreams[ key ]

    fill_item(upstream, http_data)

    set_dict_data( store_data, statistic_key, data )

end

function _M.get_statistics()

    local _ret = {

        nginx_info = {
            nginx_version = ngx.var.nginx_version,
            address = ngx.var.server_addr,
            timestamp = ngx.now() * 1000,
            time_iso8601 = ngx.var.time_iso8601,
            pid = ngx.worker.pid()
        },

        nginx_data = {
            upstreams = {
                statistic = {},
                health_status = {}
            }
        }
    }

    local upstreams, err = get_dict_data(store_data, statistic_key)
    if not upstreams then
        ngx.log(ngx.ERR, 'get statistic failed, err: ' .. err)
        ngx.exit(500)
    end

    if upstreams == INIT_VAL then

        ngx.print( 'There is no data yet, please try later!' )
        ngx.exit(ngx.HTTP_OK)

    end

    local status
    local store

    for zone, v in pairs( upstreams ) do

        if zone == 'upstreams' then

            store = _ret.nginx_data[zone]
            for k1, v1 in pairs( v ) do
                pretty_upst_peers_data(k1, v1, store['statistic'])
            end

        end
        -- process other zone if any
    end

    local ret = json.encode( _ret )
    ngx.status = ngx.HTTP_OK
    ngx.print( ret )
    ngx.exit(ngx.HTTP_OK)
end

return _M
