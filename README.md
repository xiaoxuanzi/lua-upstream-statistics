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
        server 127.0.0.1:12336 backup;
    }
    
    lua_shared_dict upstream_statistics 10m;
    
    init_by_lua_block{
        local statistics = require("statistics.statistics")
        statistics.init()
    }   

    log_by_lua_block{
        local statistic = require("statistics.statistics")
        statistics.log()
    }

    server {
        ...
        location /upstream_statistics {
            default_type 'text/html';
            content_by_lua_block{
                local st = require("statistics.statistics")
                st.get_statistics()
            }
        }

       location /get {
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
One typical output is
```
nginx_info: {
    address: "192.168.46.15",
    time_iso8601: "2017-04-05T14:39:52+08:00",
    nginx_version: "1.11.2",
    timestamp: 1491374392072,
    pid: 22909
},

nginx_data: {
    upstreams: {
        statistic: {
            test: {
                127.0.0.1:12334: {
                    requests: {
                        total: 1,
                        request_length: 380,
                        request_time: 0.2
                    },
                    responses: {
                        3xx: 0,
                        4xx: 0,
                        5xx: 0,
                        total: 1,
                        body_bytes_sent: 37,
                        1xx: 0,
                        2xx: 1
                    },
                    upstreams: {
                        4xx: 0,
                        -xx: 0,
                        1xx: 0,
                        2xx: 1,
                        3xx: 0,
                        upstream_response_length: 26,
                        5xx: 0,
                        total: 1,
                        upstream_response_time: 0.2
                    }
                }
            }
        },

        health_status: {
            test: {
                127.0.0.1:12335: {
                    conns: 0,
                    srv_name: "127.0.0.1:12335",
                    status: "up",
                    upst_name: "test"
                },
                127.0.0.1:12334: {
                    conns: 0,
                    srv_name: "127.0.0.1:12334",
                    status: "up",
                    upst_name: "test"
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
test

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

