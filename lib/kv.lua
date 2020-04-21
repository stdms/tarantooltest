log = require('log')

box.once('kv', function()
    log.info('kv.start: create space')

    box.schema.space.create('kv')

    box.space.kv:create_index("primary",  {type = 'tree', parts = {1, 'str'}, unique = true})
end)

local kv = {
    space  = box.space.kv,
    fields = {
        { name = "key",   type = "string" },
        { name = "value", type = "table" }
    },

    unflatten = function (self, tuple)
        local row = {}

        table.foreach( self.fields, function(i, value)
            row[value.name] = tuple[i]
        end )

        return row
    end,

    add = function(self, key, value)
        log.info('kv:add ' .. key )
        if key == nil then
            log.error('kv.add: Null key')
            return nil
        end
        if type(value) ~= 'table' then
            log.error('kv.add: wrong value type ')
            return nil
        end

        local tuple = self.space:get(key)
        if tuple ~= nil then
            log.error('kv.add: ' .. key .. ' already exists')
            return false
        end

        return self:unflatten(self.space:insert({ key, value }))
    end,

    upd = function(self, key, value)
        log.info('kv:upd ' .. key)
        if key == nil then
            log.error('kv.add: Null key')
            return nil
        end
        if type(value) ~= 'table' then
            log.error('kv.add: wrong value type')
            return nil
        end

        local tuple = self.space:get(key)
        if tuple == nil then
            log.error('kv.add: ' .. key .. ' not found')
            return false
        end

        return self:unflatten(self.space:update({key}, {{ '=', 2, value }}))
    end,

    del = function(self, key)
        log.info('kv:del ' .. key)
        if key == nil then
            log.error('kv.delete: Null key')
            return nil
        end
        local tuple = self.space:get(key)
        if tuple == nil then
            log.error('kv.delete: ' .. key .. ' not found')
            return false
        end

        self.space:delete(key)
        return true
    end,

    get = function(self, key)
        log.info('kv:get ' .. key)
        if key == nil then
            log.error('kv.get: Null key')
            return nil
        end
        local tuple = self.space:get(key)
        if tuple == nil then
            log.error('kv.get: ' .. key .. ' not found')
            return false
        end

        return self:unflatten(tuple)
    end
}

return kv

