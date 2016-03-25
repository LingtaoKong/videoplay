function get_db_data( db, key )
        local res = db:Get( key );
	return res
end	

function set_db_data( db, key, value )
	local res = db:Set( key, value )	
	return res
end

	local socket = require("socket")
	local Database = require('Database')
	local redis_host_info = string.format( "127.0.0.1:%d",  ngx.var.redis_port )
        local db = Database.new(redis_host_info)
        if db:Connect() ~= true then
                ngx.log(ngx.ERR, string.format('-------------Connect to redis(%s) failed!', redis_host_info))
		return ngx.exit( 500 )
        end

	local data = get_db_data( db, ngx.md5( ngx.var.uri ) )
	if nil == data then
		return ngx.exit( 404 )
	end

	ngx.print( data )
	ngx.exit( ngx.HTTP_OK )
	return
