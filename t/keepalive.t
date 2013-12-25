use lib 'lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * ( 3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();

run_tests();

__DATA__

=== TEST 1: not set keepalive
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            ngx.say("ok");
        ';
    }

    location /t {
        content_by_lua '
    	    local http = require "resty.http.simple"
            local client, err = http:new()
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:close()

            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
        ';
    }
--- request
GET /t
--- response_body
0
0
--- no_error_log
[error]

=== TEST 2: connection pool
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            ngx.exit(ngx.HTTP_OK);
        ';
    }

    location /t {
        content_by_lua '
	        local http = require "resty.http.simple"
            local client = http:new()
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:set_keepalive(60000, 10)

            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:set_keepalive(60000, 10)

            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:close()

            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:close()
        ';
    }
--- request
GET /t
--- response_body
0
1
2
0
--- no_error_log
[error]

=== TEST 3: connection pool timeout
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            ngx.exit(ngx.HTTP_OK);
        ';
    }

    location /t {
        content_by_lua '
	        local http = require "resty.http.simple"
            local client = http:new()
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:set_keepalive(6000, 10)

            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:set_keepalive(1, 10)

            ngx.sleep(1)
            local ok, err = client:connect("127.0.0.1", 1984)
            local bytes, err = client:send_req({path = "/foo"})
            local res, err = client:receive()
            local times, err = client:get_reused_times()
            ngx.say(times)
            client:close()

        ';
    }
--- request
GET /t
--- response_body
0
1
0
--- no_error_log
[error]
