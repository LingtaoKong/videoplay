
local _M = {}

ksy_auth = _M

local sig_key = {}
local file = io.open("/etc/authkeys", "r");
if file then

	for line in file:lines() do
		local id, key = string.match(line, "(%d+) (%x+)")
		if (id == nil or key == nil) then
		else
		sig_key[ id ] = key
		end
	end
	file:close()
else
	ngx.log( ngx.ERR, "authkeys file is not existed");
end


function _M.get_auth_sig_sha1( secret_string, secret_keyId)
	local crypto = require "crypto"
	local hmac = require("crypto.hmac")
	local hex = require "hex2string"

	if( nil == sig_key[ secret_keyId ] ) then
		return nil, "ill keyid"	
	end

	local secret_key = str2hex( sig_key[ secret_keyId ] )
	local signature = hmac.digest("sha1", secret_string, secret_key , rawequal)
	return ngx.encode_base64(signature), "OK"
end

function _M.get_auth_sig_sha256( secret_string, secret_keyId)
	local crypto = require "crypto"
	local hmac = require("crypto.hmac")
	if nil == sig_key[ secret_keyId ] then
		return nil
	end
	local signature = hmac.digest("sha256", secret_string, sig_key[ secret_keyId ], rawequal)
	ngx.log( ngx.ERR, "--hamc----secret_string: ", secret_string, "secret_key: ", sig_key[ secret_keyId ], " siga", to_base64(signature ) )
	return ngx.encode_base64(signature)
end

function _M.get_auth_sha256( secret_string )
	local crypto = require "crypto"
	local evp = require("crypto.evp")
	ngx.log( ngx.ERR, "--------------------------------------secret_string: ", secret_string )
	local ret = evp.digest( "sha256", secret_string, "", rawequal)
	return ngx.encode_base64(ret)
end

return ksy_auth
