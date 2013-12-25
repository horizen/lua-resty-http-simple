Name
====

lua-resty-http -simple- Simple Lua HTTP client driver for ngx_lua

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [connect](#connect)
    * [set_timeout](#set_timeout)
    * [set_keepalive](#set_keepalive)
    * [get_reused_times](#get_reused_times)
    * [close](#close)
    * [send_req](#send_req)
    * [receive](#receive)
    * [request](#request)

* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======
This library is considered production ready.

Description
===========
This Lua library is a simple Http client driver for ngx_lua module
This Lua library takes advantage of ngx_lua's cosocket API, which ensures
100% nonblocking behavior.

Synopsis
=======

    server {
      location /test {
        content_by_lua '
          local http   = require "resty.http.simple"
		  local client = http:new()
		  client:settimeout(100)
		  
		  local ok, err = connect("www.google.com", 80)
		  if not ok then
		      ngx.say("connect error: ", err)
		      return
		  end
		  
		  local bytes, err = client:send_req( {
		      method = "GET",
		      path = "/search",
		      args = {q = "openresty"},
		      version = 1,
		  	  headers = {Cookie = "foo=bar"}
		  })
		  if not bytes then
		      ngx.say("send request error:" ,err)
		      return
		  end
		  
		  local res, err = client:receive()
		  if not res then
		      ngx.say("receive error: ", err)
		      return
		  end

          if res.status >= 200 and res.status < 300 then
              ngx.say(res.body)
          else
              ngx.say("Query returned a non-200 response: " .. res.status)
          end
          
          if res.keepalive then
          	  client:set_keepalive(60000, 10)
          else
          	  client:close()
          end
        ';
      }
    }

[Back to TOC](#table-of-contents)

Methods
=======

new
---
`syntax: client, err = http:new()`

Creates a http object. In case of failures, returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

connect
-------
`syntax: ok, err = client:connect(host, port, options_table?)`

Attempts to connect to the remote host and port that the http server is listening.

Before actually resolving the host name and connecting to the remote backend, this method will always look up the connection pool for matched idle connections created by previous calls of this method.

An optional Lua table can be specified as the last argument to this method to specify various connect options:

* `pool`

    Specifies a custom name for the connection pool being used. If omitted, then the connection pool name will be generated from the string template `<host>:<port>` or `<unix-socket-path>`.

[Back to TOC](#table-of-contents)

set_timeout
----------
`syntax: client:set_timeout(time)`

Sets the timeout (in ms) protection for subsequent operations, including the `connect` method.

[Back to TOC](#table-of-contents)

set_keepalive
------------
`syntax: ok, err = client:set_keepalive(max_idle_timeout, pool_size)`

Puts the current Http connection immediately into the ngx_lua cosocket connection pool.

You can specify the max idle timeout (in ms) when the connection is in the pool and the maximal size of the pool every nginx worker process.

In case of success, returns `1`. In case of errors, returns `nil` with a string describing the error.

Only call this method in the place you would have called the `close` method instead. Calling this method will immediately turn the current socket object into the `closed` state. Any subsequent operations other than `connect()` on the current objet will return the `closed` error.

[Back to TOC](#table-of-contents)

get_reused_times
----------------
`syntax: times, err = client:get_reused_times()`

This method returns the (successfully) reused times for the current connection. In case of error, it returns `nil` and a string describing the error.

If the current connection does not come from the built-in connection pool, then this method always returns `0`, that is, the connection has never been reused (yet). If the connection comes from the connection pool, then the return value is always non-zero. So this method can also be used to determine if the current connection comes from the pool.

[Back to TOC](#table-of-contents)

close
-----
`syntax: ok, err = client:close()`

Closes the current http connection and returns the status.

In case of success, returns `1`. In case of errors, returns `nil` with a string describing the error.

[Back to TOC](#table-of-contents)

send_req
----------
`syntax: bytes, err = client:send_req(opts)`

Sends the query to the http server without waiting for its replies.

Returns the bytes successfully sent out in success and otherwise returns `nil` and a string describing the error.

You should use the [receive](#receive) method to read the http response afterwards.

An Lua `opts` table can be specified to declare various options:

* `method`
: Specifies the request method, defaults to `GET`.
* `path`
: Specifies the path, defaults to `'/'`.
* `args`
: Specifies query parameters. Accepts either a string or a Lua table.
* `headers`
: Specifies request headers. Accepts a Lua table. 
* `version`
: Sets the HTTP version. Use `0` for HTTP/1.0 and `1` for
HTTP/1.1. Defaults to `1`.

[Back to TOC](#table-of-contents)

receive
-----------
`syntax: res, err = client:receive()`

Reads the response returned from the Http server.

Returns a `res` object containing three attributes:

* `res.status` (number)
: The resonse status, e.g. 200
* `res.headers` (table)
: A Lua table with response headers. 
* `res.body` (string)
: The plain response body
* `res.keepalive` (boolean)
: The connection keepalive properties; true for support keepalive set and false not

**Note** All headers (request and response) are noramlized for
capitalization - e.g., Accept-Encoding, ETag, Foo-Bar, Baz - in the
normal HTTP "standard."

[Back to TOC](#table-of-contents)

request
---
`syntax: res, err = client:request(opts)`

The opts arg is the same of the arg of client:send_req(opts)
This method is combined client:send_req and client:receive


Licence
=======

Started life as a fork of
[lua-resty-http](https://github.com/bsm/lua-resty-http) - Copyright (c) 2013 Black Square Media Ltd

This code is covered by MIT License. 

Copyright (C) 2013, by Brian Akins <brian@akins.org>.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
