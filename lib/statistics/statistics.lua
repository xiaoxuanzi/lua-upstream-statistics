local json = require( "cjson" )
local shared_dict = ngx.shared.upstream_statistics

local QPS_INTERVAL = 10
local SYMBOL_UPST = '='
local SYMBOL_SERVER = '*'

local _M = {}

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

local function startwith(str, start)

    return string.sub(str, 1, string.len(start)) == start
end

local function trim (s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function incr(dict, k, n)

    local v, err

    n = tonumber(n) or 0

    v, err = dict:incr(k, n)

    if err then
        dict:add( k, 0 )
        v, err = dict:incr( k, n )
        if err then
            ngx.log( ngx.ERR, "Fail to incr: ", k, " err=", err )
        end
    end

    return v, err
end

local function get(dict, k)

    local v, err

    v, err = dict:get(k)

    if err then
        ngx.log( ngx.ERR, "Fail to get: ", k, " err=", err )
    end

    return v
end

local function set(dict, k, v)

    local succ, err = dict:set(k, v)

    if err then
        ngx.log(ngx.ERR, "Fail to set: ", k, " err: ", err)
    end

end

local function set_avg(dict, k_avg, v_now, v_last)

    local v_avg
    if v_now == nil or v_last == nil then
        ngx.log(ngx.ERR, 'Fail to set_avg since values has nil, key: ', k_avg)
        return
    end

    v_avg = (v_now - v_last) / QPS_INTERVAL
    set(shared_dict, k_avg, v_avg)

end

local function list_upst_ip_port_keys()

    local shared_dict_keys = shared_dict:get_keys()

    local all_upst_ip_port_keys = {}
    for _, value in pairs(shared_dict_keys) do
        local key =  split(value, SYMBOL_SERVER)[1]

        if all_upst_ip_port_keys[key] == nil then
            all_upst_ip_port_keys[key] = true
        end
    end

    return all_upst_ip_port_keys

end

function _M.log()

    local upstream_status = ngx.var.upstream_status
    if not upstream_status then
        --ngx.log(ngx.ERR, 'the request is not belong to any upstream')
        return
    end

    local upst_name = ngx.ctx.upstream_name
    if not upst_name then
        --since upstream prematurely closed connection
        --while reading response header from upstream
        --ngx.log(ngx.ERR, 'ngx.ctx.upstream_name is nil')
        return
    end

    -- upstream_addr contains more than 1 addr,
    -- only use one this time
    local upst_addr_table = split(ngx.var.upstream_addr, ',')
    local upstream_addr = upst_addr_table[#upst_addr_table]
    if #upst_addr_table > 1 then
        upstream_addr = trim( upstream_addr )
    end
    local prefix_key = upst_name .. SYMBOL_UPST .. upstream_addr .. SYMBOL_SERVER

    local resp_status = tostring(ngx.var.status):sub(1, 1) .. 'xx'
    incr(shared_dict, prefix_key .. 'req_' .. resp_status, 1)
    incr(shared_dict, prefix_key .. 'req_total', 1)
    --incr(shared_dict, prefix_key .. 'req_time', ngx.var.request_time)
    --incr(shared_dict, prefix_key .. 'req_len', ngx.var.request_length)
    --incr(shared_dict, prefix_key .. 'req_body_sent', ngx.var.body_bytes_sent)

    local upstream_status_num
    local upst_status_table = split(ngx.var.upstream_status, ',')
    local upst_resp_num = #upst_status_table
    if upst_resp_num == 1 then
        upst_status_num = tostring(ngx.var.upstream_status):sub(1, 1)
    else
        upst_status_num = tostring(upst_status_table[upst_resp_num]):sub(2, 2)
    end

    local upstream_status = upst_status_num .. 'xx'
    incr(shared_dict, prefix_key .. 'upst_' .. upstream_status, 1)
    incr(shared_dict, prefix_key .. 'upst_total', 1)

    if upst_status_num ~= '2' then
        return
    end

    local resp_ts
    local resp_len
    if upst_resp_num == 1 then
        resp_ts  = ngx.var.upstream_response_time
        resp_len = ngx.var.upstream_response_length
    else
        local upst_resptime_table = split(ngx.var.upstream_response_time, ',')
        local upst_resplen_table  = split(ngx.var.upstream_response_length, ',')
        resp_ts  = tostring(upst_resptime_table[ upst_resp_num ]):sub(2, -1)
        resp_len = tostring(upst_resplen_table[ upst_resp_num]):sub(2, -1)
    end

    incr(shared_dict, prefix_key .. 'upst_resp_time', resp_ts)
    --incr(shared_dict, prefix_key .. 'upst_resp_len',  resp_len)

end

function _M.upstream_qps()

    local elements = {
        'req_total',
        --'req_time',
        --'req_len',
        --'req_body_sent',

        'upst_total',
        'upst_resp_time',
        --'upst_resp_len',
    }

    local upst_ip_port_keys = list_upst_ip_port_keys()
    local k_now, k_last, k_avg
    local v_now, v_last, v_avg
    local err
    for upst_ip, _ in pairs(upst_ip_port_keys) do

        for _, postfix in pairs(elements) do
            k_now  = upst_ip .. SYMBOL_SERVER .. postfix
            k_last = upst_ip .. SYMBOL_SERVER .. postfix.. '_last'
            k_avg  = upst_ip .. SYMBOL_SERVER .. postfix.. '_avg'

            v_last = get(shared_dict, k_last)
            v_now  = get(shared_dict, k_now)
	    if v_now ~= nil then
	        if v_last == nil then
		    set(shared_dict, k_last, v_now)
		    v_last = v_now
		end

		set_avg(shared_dict, k_avg, v_now, v_last)

		set(shared_dict, k_last, v_now)
	   end
        end
    end

end

function _M.get_statistics()

    local statistics = {

        nginx_info = {
            nginx_version = ngx.var.nginx_version,
            address = ngx.var.server_addr,
            timestamp = ngx.now() * 1000,
            time_iso8601 = ngx.var.time_iso8601,
            pid = ngx.worker.pid()
        },

        upstreams = {}
    }

    local upst_ip_port_keys = list_upst_ip_port_keys()
    local shared_dict_keys = shared_dict:get_keys()

    local upst_name
    local item
    local server
    local ret
    for _, value in pairs(shared_dict_keys) do
        ret = split(value, SYMBOL_UPST)
        upst_name = ret[1]
        ret = split(ret[2], SYMBOL_SERVER)
        server  = ret[1]
        element = ret[2]


        upst_data = statistics['upstreams'][upst_name]
        if not upst_data then
            upst_data = {}
            statistics['upstreams'][upst_name] = upst_data
        end

        if not upst_data[server] then
            upst_data[server] = {
                response = {},
                upstream = {}
            }
        end

        if startwith(element, 'req') then
            upst_data[server]['response'][element] = get(shared_dict, value)
        else
            upst_data[server]['upstream'][element] = get(shared_dict, value)
        end
    end

    local ret = json.encode( statistics )
    ngx.status = ngx.HTTP_OK
    ngx.print( ret )
    ngx.exit(ngx.HTTP_OK)

end

local function timer_work( interval, worker, startafter )
    local timer_work

    timer_work = function (premature)
        if not premature then
            local rst, err_msg = pcall( worker )
            if not rst then
                ngx.log(ngx.ERR, 'timer work:', err_msg)
            end
            ngx.timer.at( interval, timer_work )
        end
    end

    startafter = startafter or interval

    ngx.timer.at( startafter, timer_work )
end

function _M.init_works()

    if ngx.worker.id() == 0 then
        timer_work(QPS_INTERVAL, _M.upstream_qps)
    end

end

return _M
