local Database = {}

function newObject(o, class)
    class.__index = class
    return setmetatable(o, class)
end

function Database.new(sock)
    local obj = {
        redis = require 'redis',
        client = nil,
        sock = sock,
        status = false
    }
    obj = newObject(obj, Database)
    return obj
end

function Database:Connect ()
    self.client = self.redis:new()
    self.client:set_timeout(1000)
    local ok, err = self.client:connect(self.sock)
    if not ok then
        return false
    end
    return true
end

function Database:Close ()
    local ok, err = self.client:close()
    if not ok then
        return false
    end
    return true
end

function Database:Get (key)
    local res, err = self.client:get(key)
    if res == ngx.null then
        return nil
    end
    return res
end

function Database:TTL (key)
    return self.client:ttl(key)
end

function Database:Set (key, value)
    return self.client:set(key, value)
end

function Database:Setex (key, expire, value)
    return self.client:setex(key, expire, value)
end

function Database:Del (key)
    return self.client:del(key)
end

function Database:Expire (key, expire)
    return self.client:expire(key, expire)
end

return Database

