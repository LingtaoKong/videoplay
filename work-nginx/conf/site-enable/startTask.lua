function create_dir( dir )
	local shell = require("shell")	
	local cmd = string.format( "mkdir %s", dir )
	shell.execute( cmd )
	shell.execute( string.format("chmod -R 777 %s", dir ) )
	return 
end

function write_file_info( file_name, file_info )
	if nil == file_info then
		ngx.log( ngx.ERR, "data for write is nil " )
		return
	end
	local file = io.open( file_name, "w" )
	if nil == file then
		create_dir( "/tmp/mp4" )	
		file = io.open( file_name, "w" )
	end
        file:write( file_info )
        file:close()
        return
end

function ngx_load_response( code )
	ngx.log( ngx.ERR, " this worker machine loadavg is too high " )
	ngx.status = code	
	ngx.say( redirect_server_addr, "worker machine is too high " )
	return
end

function check_server_load()
	local check = require( "check_load" )

	local check_res = check.is_need_task() 
	if( false == check_res ) then 
		ngx.log( ngx.ERR, " work machine load too high " )
		ngx_load_response( ngx.HTTP_FORBIDDEN )
	end

	return check_res
end

function get_post_body_info( post_body )
	local json = require "cjson"
	if nil == post_body then
		return nil
	end
	local obj = json.decode(post_body)
	if nil == obj then
		return nil	
	end
	return obj
end

function send_response_obj( res_obj, status, playUrl , message)
	local json = require "cjson"
	res_obj.status = status	
	res_obj.playUrl = playUrl
	res_obj.message = message
	local res_str = json.encode( res_obj )

	ngx.status = status
	ngx.print( res_str )	
	ngx.log( ngx.ERR, "-------------send_response_obj message:", message )
	return res_obj
end

function get_sig_str( check_info, check_sk )
	if nil == check_info.taskhost or nil == check_info.expires then
		return nil, "var taskhost or expires is nil"
	end
	if nil == check_info.keyId or nil == check_info.nonce then
		return nil, "var keyid or nonce is nil "
	end

	if( tonumber(check_info.expires) < ngx.time() )then
		ngx.log( ngx.ERR, "-nil--expire :", tonumber( check_info.expires ), " ngxtime:", ngx.time() )
		return nil, "expires invalid"
	end
	
	local sig_str = string.format( "%s%s", check_info.taskhost, check_info.body )
	return sig_str ,"OK"
end

function hamc_sha1_base64( sha1_string, key_id )
	local ksy_auth = require ("ksy_auth")	
	local sig , msg= ksy_auth.get_auth_sig_sha1( sha1_string, key_id )	
	return sig, msg
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

function check_sig( check_info, key_id )
	
	local sig_str , message = get_sig_str( check_info, key_id )
	if nil == sig_str then
		return false, message	
	end

	local loc_sig , msg= hamc_sha1_base64( sig_str, key_id )
	if( nil == loc_sig )then
		return false, msg	
	end
	
	local safe_sig = url_safe_encode( loc_sig )
	if( nil == safe_sig )then
		return false, "url safe encode failed"
	end

	ngx.log( ngx.ERR, "sig_str :", sig_str, " loc_sig:", loc_sig, " safe_sig:", safe_sig," arg_sig :", check_info.sig )
	if safe_sig == check_info.sig  then
		return true, "signature match success "
	end
	return false ,"signature not match"
end

function create_play_url(  play_host, key_id, stream_name )
	local ksy_auth = require ("ksy_auth")	
        local nonce = math.random( 1, 999999)
	local expires = ngx.time() + 86400
        local args = string.format( "keyid=%s&nonce=%s&expires=%d",  key_id, nonce, expires )
        local sig_str = string.format( "streamName=%s&%s", stream_name, args )
	ngx.log( ngx.ERR, "----play sig  sig_str:", sig_str, " key_id:", key_id )
        local signature = ksy_auth.get_auth_sig_sha1( sig_str, key_id )
	if nil == signature then
		return nil	
	end
	local safe_sig = url_safe_encode( signature )
	if nil == safe_sig then
		return nil
	end
        local socket = require("socket")
        local localhostname = socket.dns.gethostname()
	local localid = string.match(localhostname, "videoplay%d+")
        local play_url = string.format( "https://%s/downdata/%s/%s/index.m3u8?%s&signature=%s", 
						play_host, localid, stream_name, args, safe_sig )
        return play_url
end

function init_codec_info( resolution_table, codec_format) 
	resolution_table[ "P240" ] = "320x240"
	resolution_table[ "P320" ] = "480x320"
	resolution_table[ "P480" ] = "640x480"
	resolution_table[ "P720" ] = "1280x720"
	codec_format[ "NORMAL" ] = ""
	codec_format[ "FAST" ] = "-preset ultrafast"
	return
end

function get_queryVar( queryVar, data )
	local encrypt_uri = string.match( ngx.var.request_uri, "(.*)&sig" )
	local request_url = string.format( "https://%s%s", ngx.var.host, encrypt_uri )
	queryVar.taskhost		= request_url
	queryVar.keyId 			= ngx.var.arg_keyId
	queryVar.nonce 			= ngx.var.arg_nonce
	queryVar.expires		= ngx.var.arg_expires
	queryVar.sig 			= ngx.var.arg_sig
	queryVar.stream_name 		= ngx.var.arg_stream_name
	queryVar.body			= data
	queryVar.stream_type		= "mp4_type"
	queryVar.time_out		= 300

	return queryVar
end


if( false == check_server_load() ) then
	ngx.log( ngx.ERR, " service load too high, reload the task" )
	return 
end

local socket = require "socket"
local json = require "cjson"
local res_obj = {}
local queryVar = {}
local codec_format = {}
local resolution_table = {}

init_codec_info( resolution_table, codec_format)

ngx.req.read_body()
local body_data = ngx.req.get_body_data()
local data_info = ngx.unescape_uri( body_data )
--local data_info = body_data
local data = string.match( data_info, "[^=]*=(.*)" )
ngx.log( ngx.ERR, "--------------11111111111111---test :", data, "--------------" )
if nil == data then
	send_response_obj( res_obj,400, "null", "post body is bad" )
	return
end

local obj_body = get_post_body_info( data )
if nil == obj_body then
	send_response_obj( res_obj, 400, "null" , "ill bodyinfo ")	
	return 
end

get_queryVar( queryVar, data )

local obj_meta = obj_body
local bitrate 		= obj_meta.bit_rate
local resolution 	= resolution_table[ obj_meta.resolution ]
local codec 		= obj_meta.codec
local filesize		= obj_meta.filesize
local data_url		= obj_meta.url
local meta		= obj_meta.meta

local decode_down_info = {}
decode_down_info.meta		= meta
--local down_info_str = json.encode( decode_down_info )
local down_info_str = meta

local ret , msg = check_sig( queryVar, queryVar.keyId  )
if( false == ret ) then
	send_response_obj( res_obj, 400, "null", msg )
	return
end

ngx.log( ngx.ERR, "*bitrate: ", bitrate, "*resolution :",resolution, "*codec:", codec, "*filesize:", filesize, "*data_url:", data_url,"*meta:", meta )

local file_data_name = string.format( "/tmp/mp4/%s.info", queryVar.stream_name )
local post_data = string.format( "meta=%s", down_info_str )
write_file_info( file_data_name, post_data )

local shell = require("shell")
local ffmpeg_cmd = string.format( "/usr/local/bin/ffmpeg -fflags ignidx -xiaomi_video_scale %s -xiaomi_info %s -xiaomi_length %s -i \"xiaomi+%s\" -f xiaomi -vf scale=%s -vcodec libx264 %s -b:v %sk -acodec libfaac -ac 1 -ab 32k -copyts -vsync 0 -sn -dn -map_metadata -1 -pix_fmt yuv420p -vprofile main -weightp simple -me_method dia -me_range 16 -subq 4 -trellis 1 -qmin 15 -qmax 48 -i_qfactor 0.710000 -b_qfactor 1.200000 -aq-strength 0.600000 -rc-lookahead 4 -refs 2 -fast-pskip 1 -weightb 1 -direct-pred spatial -bf 3 -b_strategy 0 -threads 2 -keyint_min 24 -g 50 -x264opts b-pyramid=2:mixed-refs=0:ratetol=0.10 -xiaomi_pregen 3 -xiaomi_timeout %s -xiaomi_ts_segment_duration 5 -y http://127.0.0.1:8080/upload/%s/%s > /tmp/%s.log 2>&1 & " , resolution, file_data_name, filesize, data_url, resolution, codec_format[codec], bitrate, queryVar.time_out, queryVar.stream_type, queryVar.stream_name, queryVar.stream_name)

local play_url, ret_msg = create_play_url( ngx.var.redirect_server_addr, queryVar.keyId, queryVar.stream_name )

if nil == play_url then
	send_response_obj( res_obj, 403, play_url, ret_msg )	
	return 
end
send_response_obj( res_obj, 200, play_url, "success" )	

local status, out, err = shell.execute( ffmpeg_cmd )
