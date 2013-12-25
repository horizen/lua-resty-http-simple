local pairs    = pairs
local type     = type
local tonumber = tonumber
local tostring = tostring
local setmetatable = setmetatable
local encode_args  = ngx.encode_args
local tcp    = ngx.socket.tcp
local concat = table.concat
local insert = table.insert
local upper  = string.upper
local lower  = string.lower
local sub    = string.sub
local sfind  = string.find
local gmatch = string.gmatch
local gsub = string.gsub
local ipairs = ipairs
local rawset = rawset
local rawget = rawget
local min = math.min
local ngx = ngx


local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(10, 0);
_M._VERSION = "0.1.1"

--------------------------------------
-- LOCAL CONSTANTS                  --
--------------------------------------
local HTTP_1_1   = " HTTP/1.1\r\n"
local HTTP_1_0   = " HTTP/1.0\r\n"

local USER_AGENT = "Resty/HTTP-Simple " .. _M._VERSION .. " (Lua)"

-- canonical names for common headers
local common_headers = {
    "Cache-Control",
    "Content-Length", 
    "Content-Type", 
    "Date",
    "ETag",
    "Expires",
    "Host",
    "Location",
    "User-Agent"
}

for _,key in ipairs(common_headers) do
    rawset(common_headers, key, key)
    rawset(common_headers, lower(key), key)
end

local function _normalize_header(key)
    local val = common_headers[key]
    if val then
		return val
    end
    key = lower(key)
    val = common_headers[lower(key)]
    if val then
		return val
    end
    -- normalize it ourselves. do not cache it as we could explode our memory usage
    key = gsub(key, "^%l", upper)
    key = gsub(key, "-%l", upper)
    return key
end


--------------------------------------
-- LOCAL HELPERS                    --
--------------------------------------

local function _req_header(self, opts)
    -- Initialize request
	local req = new_tab(20, 0);
	local method = upper(opts.method or "GET") .. " "
	req[#req + 1] = method;
	
    -- Append path
    local path = opts.path;
    if type(path) ~= "string" then
		path = "/";
    elseif sub(path, 1, 1) ~= "/" then
		path = "/" .. path;
    end
    req[#req + 1] = path;

    -- Normalize query string
    local args = opts.args;
    if type(args) == "table" then
		args = encode_args(args);
    end

    -- Append query string
    if type(args) == "string" then
		req[#req + 1] = args .. " ";
    end

    -- Close first line
    if opts.version == 1 then
		req[#req + 1] = HTTP_1_1;
    else
		req[#req + 1] = HTTP_1_0;
    end

    -- Normalize headers
    opts.headers = opts.headers or {};
    local headers = {};
    for k, v in pairs(opts.headers) do
		headers[_normalize_header(k)] = v;
    end
    
    if opts.body then
		headers['Content-Length'] = #opts.body;
    end
    if not headers['Host'] then
		headers['Host'] = self.host;
    end
    if not headers['User-Agent'] then
		headers['User-Agent'] = USER_AGENT;
    end
    if not headers['Accept'] then
		headers['Accept'] = "*/*";
    end
    if opts.version == 0 and not headers['Connection'] then
		headers['Connection'] = "Keep-Alive";
    end
    
    -- Append headers
    for key, values in pairs(headers) do
		if type(values) ~= "table" then
		    values = {values};
		end
		
		key = tostring(key)
		for _, value in pairs(values) do
		    req[#req + 1] = key .. ": " .. tostring(value) .. "\r\n";
		end
    end
    
    -- Close headers
    req[#req + 1] = "\r\n";
    
    return concat(req)
end

local function _parse_headers(sock)
    local headers = {}
    local mode    = nil
    
    repeat
		local line = sock:receive()
		
		for key, val in gmatch(line, "([%w%-]+)%s*:%s*(.+)") do
		    key = _normalize_header(key)
		    if headers[key] then
				local delimiter = ", "
				if key == "Set-Cookie" then
				    delimiter = "; "
				end
				headers[key] = headers[key] .. delimiter .. tostring(val)
		    else
				headers[key] = tostring(val)
		    end
		end
    until sfind(line, "^%s*$")
    
    return headers, nil
end

local function _receive_length(sock, length)
    local chunks = {}

    local chunk, err = sock:receive(length)
    if not chunk then
		return nil, err
    end
    
    return chunk, nil
end


local function _receive_chunked(sock, maxsize)
    local chunks = {};

    local size = 0;
    local done = false;
    repeat
		local str, err = sock:receive("*l");
		if not str then
		    return nil, err;
		end
	
		local length = tonumber(str, 16);
		
		if not length then
		    return nil, "unable to read chunksize";
		end
	
		size = size + length;
		
		if length > 0 then
		    local str, err = sock:receive(length);
		    if not str then
				return nil, err;
		    end
		    chunks[#chunks + 1] = str;
		else
		    done = true;
		end
		-- read the \r\n
		sock:receive(2);
    until done

    return concat(chunks), nil;
end

local function _receive_all(sock)
    local chunk, err, partial = sock:receive("*a");

    -- in the case of reading all til closed, closed is not a "valid" error
    if not chunk then
		return nil, err;
    end
    return chunk, nil;
end


--------------------------------------
-- PUBLIC API                       --
--------------------------------------
local mt = {__index = _M};

function _M.new()
	local sock, err = tcp();
	if not sock then
		return nil, err;
	end
	return setmetatable({sock = sock}, mt);
end

function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end

function _M.connect(self, host, port, ...)
	local sock = self.sock;
    if not sock then
        return nil, "not initialized";
    end
	self.host = host;
    return sock:connect(host, port, ...);
end

function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end


function _M.get_reused_times(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:getreusedtimes()
end


function _M.close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:close()
end

function _M.send_req(self, opts)	
    local sock = self.sock;
    
    -- Build and send request header
    local version = opts.version
    if version then
		if version ~= 0 and version ~= 1 then
		    return nil, "unknown HTTP version"
		end
    else
		opts.version = 1
    end
    local req = _req_header(self, opts);
    local size = 0;
    
    local bytes, err = sock:send(req);
    if not bytes then
		return nil, err
    end
    size = size + bytes;
    
    -- Send the body if there is one
    if opts and type(opts.body) == "string" then
		local bytes, err = sock:send(opts.body)
		if not bytes then
		    return nil, err
		end
		size = size + bytes;
    end
    
    return size;
end

function _M.receive(self)
	local sock = self.sock;
	local line, err = sock:receive();
    if not line then
		return nil, err;
    end

    local status = tonumber(sub(line, 10, 12));

    local headers, err = _parse_headers(sock);
    if not headers then
		return nil, err;
    end	
    
    local length = tonumber(headers["Content-Length"]);
    local body
    local err
    
    local keepalive = true;
       
    if length then
		body, err = _receive_length(sock, length);
    else
		local encoding = headers["Transfer-Encoding"];
		if encoding and lower(encoding) == "chunked" then
		    body, err = _receive_chunked(sock);
		else
		    body, err = _receive_all(sock);
		    keepalive = false;
		end
    end
    
    if not body then 
		keepalive = false;
    end
    
    if keepalive then
		local connection = headers["Connection"];
		connection = connection and lower(connection) or nil;
		if connection then
		    if connection == "close" then
				keepalive = false;
		    end
		else
		    if self.version == 0 then
				keepalive = false;
		    end
		end
    end
    
    if keepalive then
		sock:setkeepalive();
    else
		sock:close();
    end
    
    return { status = status, headers = headers, body = body }
end

function _M.request(self, opts)
	local bytes, err = self:send_req(opts);
	if not bytes then
		return nil, err;
	end
	
	return self:receive();
end

return _M;