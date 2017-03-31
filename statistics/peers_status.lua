local util = require( "statistic.util" )
local upstream  = require("ngx.upstream")

local get_upstreams     = upstream.get_upstreams
local get_primary_peers = upstream.get_primary_peers

local _M = {}

function _M.get_primary_peers_status( upst )

    local peers, err = get_primary_peers(upst)
    if not peers then
        ngx.log(ngx.ERR, 'Get primary peers failed in upstream ' .. upst ..' err: ' .. err)
        return nil
    end

    local status = {}
    local npeers = #peers
    for i = 1, npeers do

        local peer = peers[i]
        status[ i ] = {
            down = peer.down,
            srv_name = peer.name,
            upst_name = upst,
            conns = peer.conns
            --accessed = peer.accessed,
            --checked = peer.checked
        }

    end

    return status

end

function _M.get_all_primary_peers_status()

    local ret = {}
    local peers_stat
    local us = get_upstreams()

    local key
    for _, u in pairs(us) do

        peers_stat = _M.get_primary_peers_status( u )

        if not peers_stat then
            return nil
        end

        for i = 1, #peers_stat do
            key = peers_stat[i].upst_name .. '_' ..peers_stat[i].srv_name 
            ret[ key ] = util.dupdict( peers_stat[i])
        end
    end

    return ret

end

return _M
