use lib 'lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();

run_tests();

__DATA__

=== TEST 1:
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            ngx.req.read_body();
            ngx.print(ngx.req.get_body_data());
       ';
    }

    location /t {
        content_by_lua '
    	    local http = require "resty.http.simple"
            local client = http:new()
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo", body="yaowei"})
            local res, err = client:receive()
    	    ngx.say(err)
	        ngx.say(res.body)  
            ngx.say(res.status)
        ';
    }
--- request
GET /t
--- response_body
nil
yaowei
200
--- no_error_log
[error]


=== TEST 2: basic without content length
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            ngx.say("foobar")
        ';
    }

    location /t {
        content_by_lua '
	        local http = require "resty.http.simple"
            local client = http:new()
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
	        local res, err = client:receive()
	        ngx.say(err)
    	    ngx.say(res.body)  
            ngx.say(res.status)
	        ngx.say(res.headers["Content-Length"])         
            ngx.say(res.headers["Transfer-Encoding"])
        ';
    }
--- request
GET /t
--- response_body
nil
foobar

200
nil
chunked
--- no_error_log
[error]



=== TEST 3: basic without content length and HTTP/1.0
--- http_config eval: $::HttpConfig
--- config
    lua_http10_buffering off;
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            ngx.say("foobar")
        ';
    }

    location /t {
        content_by_lua '
	        local http = require "resty.http.simple"
            local client = http:new()
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
	        local res, err = client:receive()
    	    ngx.say(res.body)  
            ngx.say(res.status)
	        ngx.say(string.len(res.body))         
        ';
    }
--- request
GET /t
--- response_body
foobar

200
7
--- no_error_log
[error]


