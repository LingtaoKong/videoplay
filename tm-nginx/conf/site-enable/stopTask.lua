function get_db_data( db, key )
        local res = db:Get( key );
	return res
end	

function del_db_data( db, key )
        db:Del( key );
end	

function set_db_data( db, key, value )
	local res = db:Set( key, value )	
	return res
end

	local Database = require('Database')
        local redis_host = '127.0.0.1:6379'
        local db = Database.new(redis_host)
        if db:Connect() ~= true then
                ngx.log(ngx.ERR, string.format('-------------Connect to redis(%s) failed!', redis_host))
		return ngx.exit( 500 )
        end

	ngx.log( ngx.ERR, string.format("--------url: %s", ngx.var.uri ) )
	
	local stream_name = ngx.var.arg_stream_name
	if( nil == stream_name ) then
		ngx.log( ngx.ERR, string.format(" stop uri : %s stream_name = nil", ngx.var.uri ) )
		return ngx.exit( 403 )
	end

	del_db_data( db, string.format( "/%s/index.m3u8", stream_name ) )
	return ngx.exit( 200 )
