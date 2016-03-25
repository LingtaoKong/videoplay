function get_db_data( db, key )
        local res = db:Get( key );
	return res
end	

function set_db_data( db, key, value )
	local res = db:Set( key, value )	
	return res
end

function del_db_data( db, key )
	db:Del( key )	
	return
end

function del_file( fileName )
	local sh_obj = require( "shell" )
	local del_cmd = string.format( "rm %s", fileName )
	local status, out, err = sh_obj.execute( del_cmd )
	return status
end

function post_mp4_data( fileName, key  ,db)
	-- upload the mp4 data
	--local mp4_file_name = string.format( "%s.mp4", fileName )
	local data = read_mp4_file( fileName )
	if( nil == data ) then
		ngx.log( ngx.ERR, string.format("------------>no mpt file<-------------------name: %s", fileName ) )
		return
	end

	ngx.log( ngx.ERR, string.format("set db key: %s md5: %s", key, ngx.md5(key)) )
	del_file( string.format("%s.mp4",fileName ) )

	local stream = string.match( key, "/([^/]*)/[^/]*" )
	local index_m3u8 = get_db_data( db, ngx.md5( string.format("/%s/index.m3u8", stream ) )  )
	if( index_m3u8 == nil ) then
		ngx.log( ngx.ERR,  string.format( "get m3u8 nill return 403 :/%s/index.m3u8", stream ) )
		return ngx.exit( 403 )
	end
	ngx.log( ngx.ERR, "-----------insert db key ", key)
	set_db_data( db, ngx.md5(key), data )
	return
end

function read_mp4_file( fileName )
	local mp4_file = io.open( string.format( "%s.mp4",fileName ), "r" )
	local data = mp4_file:read("*a")
	return data 
end

function create_dir( dir )
        local shell = require("shell")
        local cmd = string.format( "mkdir %s", dir )
        shell.execute( cmd )
        shell.execute( string.format("chmod -R 777 %s", dir ) )
        return
end

function write_ts_file( fileName, data )
	if nil == data then
		ngx.log( ngx.ERR, " upload data is nil " )
		return false
	end
	local file = io.open( fileName, "w" )
	if nil == file then
                create_dir( "/tmp/mp4" )
                file = io.open( file_name, "w" )
        end
	fileiwrite( data )
	file:close()
	return true
end

function set_ts_data( db, key, data )
	if nil == data then
		ngx.log( ngx.ERR, " set ts data is nil " )
		return false
	end 
	set_db_data( db, ngx.md5(key), data )
	return
end

function del_ts_data( db, key )
	del_db_data( db, ngx.md5(key) )	
	return
end

function start_exec( ts_key ,tmp_mp4_file)

	local file = io.open( "/tmp/mp4/test.txt", "w" )
        if nil == file then
                create_dir( "/tmp/mp4" )
	else
		file:close()
        end

	local url_for_ts = string.format( "http://127.0.0.1:8080%s", ts_key )
	local sh_obj = require( "shell" )
	local cmd = string.format( "/usr/local/bin/ffmpeg -i %s -vcodec copy -acodec copy -bsf:a aac_adtstoasc -f mp4 -y %s.mp4", url_for_ts, tmp_mp4_file ) 
	ngx.log( ngx.ERR, "------cmd: ", cmd )
	local status, out, err = sh_obj.execute( cmd )
	--del_file( tmp_mp4_file )
	return status
end

function insert_info_to_db( db ,stream_name )
	local stream_heart_key = string.format( "/%s/heartbeat", stream_name )
	ngx.log( ngx.ERR, "-----------insert db key ", stream_heart_key )
	set_db_data( db, ngx.md5( stream_heart_key ), ngx.time() )

	local stream_cur_key = string.format( "/%s/cur", stream_name )
	ngx.log( ngx.ERR, "-----------insert db key ", stream_cur_key)
	set_db_data( db, ngx.md5( stream_cur_key ), "0.ts" )

	--ngx.log( ngx.ERR, "post m3u8 ----------------heart_key:", stream_heart_key )
	return
end

	local socket = require "socket"
	local Database = require('Database')
        --local redis_host = '10.4.23.112:62000'
	local redis_host = string.format( "127.0.0.1:%d",  ngx.var.redis_port )
        local db = Database.new(redis_host)
        if db:Connect() ~= true then
                ngx.log(ngx.ERR, string.format('---Connect to redis(%s) failed!', redis_host))
		return ngx.exit( 500 )
        end

	--ngx.log( ngx.ERR, string.format("------upload--url: %s", ngx.var.uri ) )
	local upload_type, stream_name_key = string.match( ngx.var.uri, "/[^/]*/([^/]*)(.*)" )
	--ngx.log( ngx.ERR, string.format("------upload_type: %s stream_name_key: %s", upload_type , stream_name_key) )

	if( ngx.req.get_method() == "POST" ) then
		ngx.req.read_body() 				

		local data = ngx.req.get_body_data()
		if nil == data then
			ngx.log( ngx.ERR, "-----upload data is nil -----, return 403 " )
			return ngx.exit( 403 )
		end

		if( upload_type == "ts_type" ) then
			set_db_data( db, ngx.md5(stream_name_key), data )
			return ngx.exit( 200 )
		end
		if( upload_type == "mp4_type" ) then
			local stream_name, index = string.match( stream_name_key, "/([^/]*)/([^/]*)" )
			if( index == "index.m3u8" ) then
				ngx.log( ngx.ERR, "--------111---------upload index.m3u8 success " )
				insert_info_to_db( db ,stream_name )
				set_db_data( db, ngx.md5(stream_name_key), data )
				ngx.log( ngx.ERR, "----------22-------upload index.m3u8 success ,key:", ngx.md5(stream_name_key) )
				return ngx.exit( 200 )
			end
			ngx.log( ngx.ERR, "------------------upload ts data ---------------------" )
			local ts_key = string.format( "/localfile/%s/%s", stream_name, index )
			local tmp_mp4_file = string.format( "/tmp/mp4/%s-%s", stream_name, index )
			--write_ts_file( tmp_mp4_file, data )
			set_ts_data( db, ts_key, data ) 
			start_exec( ts_key, tmp_mp4_file)
			del_ts_data( db, ts_key )	
			post_mp4_data( tmp_mp4_file, stream_name_key, db )		
		end
	end

	--/stream/0.ts/clean
	local db_cmd_key, clean_flag = string.match( stream_name_key, "(/[^/]*/[^/]*)/(.*)")
	if( clean_flag == "clean" ) then 
		ngx.log( ngx.ERR, string.format( " get clean req key: %s , clean_flag: %s", db_cmd_key, clean_flag ) )
		del_db_data( db, ngx.md5(db_cmd_key ) )	
		return ngx.exit( 200 )
	end
	
	-- cur request 	
	local stream_name = string.match( stream_name_key, "(/[^/]*/).*")
	if( nil == stream_name ) then 
		return ngx.exit(403)
	end	
	-- if not have index.m3u8 then return 404
--[[
	local index_data = get_db_data( db, ngx.md5(string.format( "%sindex.m3u8", stream_name )) )
	if( nil == index_data ) then 
		ngx.log( ngx.ERR, "----nil index_data, return 404, key : ",ngx.md5(string.format( "%sindex.m3u8", stream_name )) )
		return ngx.exit( 404 )
	end	
--]]

	ngx.log( ngx.ERR, string.format( " get cur pic req stream: '%s'", stream_name) )

	local stream_req_pic = get_db_data( db, ngx.md5( string.format( "%scur" , stream_name ) ) ) 	
	local stream_least_time = get_db_data( db, ngx.md5( string.format( "%sheartbeat", stream_name ) ) ) 	
	stream_least_time = ngx.time()
	local res_body = string.format( "resopnse_code:200\r\nstream_req_pic:%s\r\nstream_least_time:%s\r\n\r\n",
			 stream_req_pic, stream_least_time )
	ngx.log( ngx.ERR, "response req cur ", res_body )

	ngx.say( res_body )
	return ngx.exit( 200 )
	
