box.cfg {
--    background = true,
--    log = 'test.log'
}

local log = require('log')
local app = require('app')
local t   = require('luatest')
local g   = t.group('kv')

local _base_url = function()
    g.server.
end

g.before_each(function()
    g.server = app
    log.info('Test suite start')
    g.server:start()
end)

g.after_each(function()
    log.info('Test suite stop')
    g.server:stop()
end)

g.test_post = function()
    local r = http_client.post(app.base_uri .. '/kv', '{ "key" : "k1", "value" : { "Foo": "Bar", "Baz" : { "Test": 111 } } }')
    t.assert_equals(r.status, 200)
    t.assert_equals(r.body, "OK")
end
