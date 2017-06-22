Name
====

lua-upstream-statistics - Provides statistics for each backend server in nginx upstreams

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Description](#description)
* [Methods](#methods)
* [Installation](#installation)
* [TODO](#todo)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

This library  is already production ready.

Synopsis
========

```nginx
http {
    lua_package_path "/path/to/lua-upstream-statistics/lib/?.lua;;";

    upstream test {
        server 127.0.0.1:12334;
        server 127.0.0.1:12335;
    }
    
    lua_shared_dict upstream_statistics 10m;

    init_by_lua_block{
        local statistics = require("statistics.statistics")
        statistics.init()
    }

    init_worker_by_lua_block{
        local statistics = require("statistics.statistics")
        statistics.init_works()
    }

    log_by_lua_block{
        local statistic = require("statistics.statistics")
        statistics.log()
    }

    server {
        ...
        location =/statistics {
            default_type 'text/html';
            content_by_lua_block{
                local st = require("statistics.statistics")
                st.get_statistics()
            }
        }

       location /test {
            default_type 'text/html';
            access_by_lua_block{
                ngx.ctx.upstream_name = 'test'
            }
            proxy_pass http://test;
        }

    }
}
```

Description
===========

This library provides statistics for each backend server in nginx upstreams.

[Back to TOC](#table-of-contents)

Methods
=======
init
-------------
**syntax:** `statistics.init()`

**context:** *init_by_lua&#42;*

Initialize global variables to store upstream statistic 

log
-------------
**syntax:** `statistics.log()`

**context:** *log_by_lua&#42;*

Gather upstream data 

get_statistics
-------------
**syntax:** `statistics.get_statistics()`

**context:** *any*

Get upstream statistics with json format.
One typical output is:
```
{
    nginx_info: {
        address: "192.168.46.110",
        time_iso8601: "2017-06-22T09:30:25+08:00",
        nginx_version: "1.11.2",
        timestamp: 1498095025252,
        pid: 25625
    },
    upstream_statistics: {
        test: {
            127.0.0.1:12334: {
                responses: {
                    1xx: 0,
                    2xx: 3,
                    3xx: 0,
                    4xx: 0,
                    5xx: 0,
                    total_now: 3,
                    total_last: 3,
                    qps: 0,
                    body_bytes_sent_now: 30,
                    body_bytes_sent_last: 30,
                    body_bytes_sent_avg: 0,
                    request_length_now: 1236,
                    request_length_last: 1236,
                    request_length_avg: 0,
                    request_time_now: 3.005,
                    request_time_last: 3.005
                    request_time_avg: 0,
                }
                upstreams: {
                    -xx: 0,
                    1xx: 0,
                    2xx: 3,
                    3xx: 0
                    4xx: 0,
                    5xx: 0,
                    total_now: 3,
                    total_last: 3,
                    qps: 0,
                    upstream_response_length_now: 30,
                    upstream_response_length_last: 30,
                    upstream_response_length_avg: 0,
                    upstream_response_time_last: 3.005,
                    upstream_response_time_now: 3.005,
                    upstream_response_time_avg: 0,
                }
            }
        }
    }
}

```

Installation
============
Copy the statistics directory to a location which is in the seaching path of lua require module 

[Back to TOC](#table-of-contents)

TODO
====
Use Test::Nginx to test

[Back to TOC](#table-of-contents)

Author
======

xiaoxuanzi xiaoximou@gmail.com

[Back to TOC](#table-of-contents)

Copyright and License
=====================
The MIT License (MIT)
Copyright (c) 2017 xiaoxuanzi xiaoximou@gmail.com

[Back to TOC](#table-of-contents)

See Also
========
* the ngx_lua module: https://github.com/openresty/lua-nginx-module

[Back to TOC](#table-of-contents)

