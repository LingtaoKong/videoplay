function get_db_data( db, key )
        local res = db:Get( key );
	return res
end	

function set_db_data( db, key, value )
	local res = db:Set( key, value )	
	return res
end

function insert_heartbeat_to_db( db , stream_name )
	local stream_heart_key = string.format( "%sheartbeat", stream_name ) 
	ngx.log( ngx.ERR, "recv heart beat ", stream_heart_key  )
	set_db_data( db, ngx.md5( stream_heart_key ), ngx.time() )
	return
end

function redirect_handler( premature, url )
	ngx.log( ngx.ERR, string.format( "ngx.timer.at url: %s", url ) )
	--return ngx.redirect( url, 302)
	return ngx.exit( 302 )
end

function send_response_obj( status,  message)
        local json = require "cjson"
	local res_obj = {}
        res_obj.status = status
        res_obj.message = message
        local res_str = json.encode( res_obj )
        ngx.status = status
        ngx.say( res_str )
        ngx.log( ngx.ERR, "-------------send_response_obj message:", message )
        return res_obj
end

function url_safe_encode( src_str )
        if nil == string then
                return nil
        end

        local res = string.gsub(src_str, "/", "_")
        res = string.gsub(res, "+", "-")
        res = string.gsub(res, "=", "")

        return res
end

function check_play_args( args )
	if( nil == args["signature"] or nil ==  args["keyid"] )then
		return false, "sig or keyid args is nil "
	end
	if( nil ==  args["nonce"] or nil == args["expires"] ) then
		return false , "nonce or expires is nil "
	end

	return true, "OK"
end

function check_play_sig( args )

        local ksy_auth = require ("ksy_auth")
	local var_sig		= args["signature"]
	local key_id  		= args["keyid"]
	local nonce   		= args["nonce"]		
	local expires 		= args["expires"]

	local chk_res, msg = check_play_args( args )
	if false == chk_res then
		return false, msg
	end
	if tonumber( expires ) < ngx.time() then
		return false, "expires invalid" 
	end

	local stream_name = string.match( ngx.var.uri, "/[^/]*/([^/]*)" )
	if nil == stream_name then
		return false, "stream_name is nil"
	end

	local sig_str = string.format( "streamName=%s&keyid=%s&nonce=%s&expires=%s", stream_name, key_id, nonce, expires )
	local loc_sig = ksy_auth.get_auth_sig_sha1( sig_str, key_id )	
	local safe_sig = url_safe_encode( loc_sig )
	if nil == safe_sig then
		return false, "url safe encode sig failed "
	end

	if( safe_sig == var_sig ) then
		return true, "success"
	end
	return false, "signature failed"
end

	local socket = require("socket")
	local Database = require('Database')
        local redis_host = '127.0.0.1:6379'
        local db = Database.new(redis_host)
        if db:Connect() ~= true then
                ngx.log(ngx.ERR, string.format('-------------Connect to redis(%s) failed!', redis_host))
		return ngx.exit( 500 )
        end

	ngx.log( ngx.ERR, string.format("--------url: %s server_addr: %s", ngx.var.uri , ngx.var.redirect_server_addr) )
	
	local stream_name_key = string.match( ngx.var.uri, "/[^/]*(.*)" )
	local stream_name, cur_flag = string.match( stream_name_key, "(/[^/]*/)(.*)")
	local cur_name_key = string.format( "%scur", stream_name ) 
	local index_name_key = string.format( "%sindex.m3u8", stream_name )
	ngx.log(ngx.ERR, string.format( "stream_name: %s  cur_flag: %s", cur_name_key ,cur_flag) )

	--[[
	if( cur_flag == "index.m3u8" ) then
		local args = ngx.req.get_uri_args()
		res, message = check_play_sig( args ) 
		if( false == res ) then
			send_response_obj( 400, message )
			return
		end
	end
	]]

	--see if the index m3u8 have
	local index_data = get_db_data( db, ngx.md5( index_name_key ) )
	if( nil == index_data ) then 
		ngx.log( ngx.ERR, string.format( "index_key : %s  req_uri : %s", index_name_key, ngx.var.uri ) )
		send_response_obj( 404, "not found stream" )
		return 
	end

	-- resp heart beat req 
	if( cur_flag == "heartbeat" ) then
		insert_heartbeat_to_db( db, stream_name )
		return ngx.exit( 200 )
	end

	-- resp m3u8 file req
	if( cur_flag == "index.m3u8" ) then 
		ngx.print( index_data )
		return ngx.exit( ngx.HTTP_OK )
	end

	-- resp ts file req
	ngx.log( ngx.ERR, string.format(" set db  key: %s",  cur_name_key  ) )
	set_db_data( db, ngx.md5( cur_name_key ), cur_flag )
	local data = get_db_data( db, ngx.md5( stream_name_key ) )
	if( nil == data ) then
		socket.sleep( 0.5 )
		ngx.log( ngx.ERR , string.format( "302 - uri: %s", ngx.var.uri ) )
		return ngx.redirect( string.format("http://%s/%s", ngx.var.redirect_server_addr, ngx.var.uri ), 302 )
	end

	ngx.print( data )
	return ngx.exit( 200 )
