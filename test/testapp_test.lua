box.cfg {
}

local case = {
    tests = {
        test_create
    }
}

local cl  = require('http.client')
local log = require('log')
local tap = require('tap')
local test = tap.test('test app tests')
test:plan(2)

local srv;

function case.before()
    log.info('Test suite start')
    srv = require('app')
    srv:start()
    log.info('Test suite start 2')
end

function case.after()
    log.info('Test suite stop')
    srv:stop()
end

function test_create()
    local r = cl.post('http://localhost:8080/kv', '{ "key" : "k1", "value" : { "Foo": "Bar", "Baz" : { "Test": 111 } } }')
    test.is(r.status, 200)
    test.is(r.body, "OK")
end



case.before()
for test_index = 1, #case.tests do
    case.tests[test_index]()
end
case.after()
