
require "ksy_auth"
local sig_str = "123456789"
local key_id = "1415003348858"
local sig = get_auth_sig_sha1( sig_str, key_id )
print( sig )

local base = require "base64"
local aaa = test_encode ( sig )

print ( aaa )
