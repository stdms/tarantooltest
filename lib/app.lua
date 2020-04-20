local os     = require('os')
local log    = require('log')
local json   = require('json')
local server = require('http.server')
local router = require('http.router')

local kv = require('kv')

local rps_limit = 3
local rps = 0    -- requests per second counter
local lrtime = 0 -- last request time in seconds from epoch

-- HTTP server setup
local s = server.new(nil, 8080, {
    log_requests = true,
    log_errors = true
})


local function incorrect_req()
    return { status = 400, body = json.encode({ error = 'Invalid data' }) }
end

local function not_found()
    return { status = 404, body = json.encode({ error = 'Not found' }) }
end

-- handlers
local function get_kv_handler(req)
    local key = req:stash('key')
    if key == nil then
        return not_found()
    end

    local tuple = kv:get(key)
    if tuple == nil then
        log.error('Get: ' .. key .. ' not found')
        return not_found()
    end

    return {status = 200, body = json.encode( tuple )}
end

local function create_kv_handler(req)
    local body = req:json()

    if body.key == nil or type(body.value) ~= 'table' then
        log.error('Invalid body')
        return incorrect_req()
    end

    local tuple = kv:add(body.key, body.value)
    if tuple == nil then
        return { status = 409, body = json.encode({ error = 'Already exists' }) }
    end

    return { status = 200, body = json.encode( tuple ) }
end

local function update_kv_handler(req)
    local body = req:json()
    local key = req:stash('key')
    if key == nil then
        log.error('Key missing')
        return not_found()
    end

    if type(body.value) ~= 'table' then
        log.error('Invalid value')
        return incorrect_req()
    end

    local tuple = kv:upd(key, body.value)
    if tuple == nil then
        log.error('Update: ' .. key .. ' not found')
        return not_found()
    end

    return { status = 200, body = json.encode( tuple ) }
end

local function delete_kv_handler(req)
    local key = req:stash('key')
    if key == nil then
        log.error('Key missing')
        return not_found()
    end

    local ok = kv:del(key)
    if ok == nil then
        log.error('Delete: ' .. key .. ' not found')
        return not_found()
    end

    return { status = 200 }
end

local function rps_limit_control(req)
    local now = os.time()

    if now == lrtime then
        rps = rps + 1
        if rps == rps_limit then
            log.error('RPS limit reached')
            return { status = 429 }
        end
    else
        rps    = 0
        lrtime = now
    end

    log.info('rps: ' .. rps .. ' ' .. lrtime )
end

-- POST /kv body: {key: "test", "value": {SOME ARBITRARY JSON}}
-- PUT kv/{id} body: {"value": {SOME ARBITRARY JSON}}
-- GET kv/{id}
-- DELETE kv/{id}
local r = router.new()
    :route({
            method = 'GET',
            path = '/kv/:key',
        },
        get_kv_handler
    )
    :route({
            method = 'POST',
            path = '/kv',
        },
        create_kv_handler
    )
    :route({
            method = 'PUT',
            path = '/kv/:key',
        },
        update_kv_handler
    )
    :route({
            method = 'DELETE',
            path = '/kv/:key',
        },
        delete_kv_handler
    )

local ok = r:use(rps_limit_control, {
    path     = '/.*',
    method   = 'ANY'
})
assert(ok, 'no conflict on adding rps_limit_control')

s:set_router(r)

return s
