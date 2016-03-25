local _M = {}
check_load = _M

function _M.check_server_load( )
	local sh_obj = require( "shell" )
	local cmd = "cat /proc/loadavg"
	local status, out, err = sh_obj.execute( cmd )
	ngx.log( ngx.ERR, "---status:", status, " out", out ) 
	ngx.log( ngx.ERR, "-------got the loadavg: ", string.match( out, "([0-9.]*)" ) )
	local loadavg = string.match( out, "([0-9.]*)" )
	if( tonumber(loadavg) > 80 ) then
		ngx.log( ngx.ERR, " loadavg too high ,", loadavg )
		return false
	end
	return true
end
	
function _M.is_need_task()
	local res = _M.check_server_load()
	--return false
	return res
end

return check_load
