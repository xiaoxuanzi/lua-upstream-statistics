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

**context:** *content_by_lua&#42;*

Get upstream statistics with json format


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

