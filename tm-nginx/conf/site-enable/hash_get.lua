
function send_response_obj( status, playUrl , message)
	local res_obj = {}
        local json = require "cjson"
        res_obj.status = status
        res_obj.playUrl = playUrl
        res_obj.message = message
        local res_str = json.encode( res_obj )

        ngx.status = status
        ngx.say( res_str )

        ngx.log( ngx.ERR, "-------------send_response_obj message:", message )
        return res_obj
end

ngx.req.read_body()
local post_data = ngx.req.get_body_data()
if( nil == post_data ) then 
	send_response_obj( 403, "nil", "post_body is nil" )
	return
end

if nil == ngx.var.args then
	send_response_obj( 403, "nil", "args is nil" )
	return
end

local socket = require( "socket" )
local src_seed = string.format( "%s:%s", socket.gettime()*1000,math.random(1,9999999) ) 
local stream_name = string.format( "%s%s", ngx.md5( src_seed ), ngx.md5( post_data ) )
ngx.log( ngx.ERR, "src_seed : ", src_seed )

local url = "/proxy"..ngx.var.uri.."?"..ngx.var.args.."&".."stream_name="..stream_name

local counts = 4
if( nil ~= ngx.var.upstream_list_counts ) then 
	counts = tonumber( ngx.var.upstream_list_counts )	
end

for i = 1, counts do
	ngx.log( ngx.ERR, string.format("-----hash_get url: %s", url) )
	local res = ngx.location.capture(url, {
			method = ngx.HTTP_POST,
			body = post_data,
			}
	)
	if ( res.status ~= 503 ) then 
		ngx.status = res.status
		ngx.say(res.body)
		ngx.log( ngx.ERR, "play url: ", res.body )
		return 
	end
	ngx.log( ngx.ERR, "*** machine ip :", ngx.var.remote_addr, " worker refause to do work ***" , "status:", res.status)
end

	ngx.log( ngx.ERR, "***** workers is all busy , loadavg too high *****" )
	ngx.status = 503
	send_response_obj( 503, "null", "server is too busy, please try later" )
	--ngx.say( "{\"error\":\"server is too busy, please try later\"}" )
return

