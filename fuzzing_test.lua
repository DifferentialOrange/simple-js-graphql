
local json = require('json')
local types = require('graphql.types')

local t = require('luatest')
local g = t.group('fuzzing')

local helpers = require('test.helpers')

-- constants
local Nullable = true
local NonNullable = false

local my_enum = types.enum({
    name = 'MyEnum',
    values = {
        a = { value = 'a' },
        b = { value = 'b' },
    },
})

local object_fields = {
    input_object_arg = types.string,
}

local my_input_object = types.inputObject({
    name = 'MyInputObject',
    fields = object_fields,
    kind = types.string,
})

local my_object = types.object({
    name = 'MyObject',
    fields = object_fields,
})

local function isString(value)
    return type(value) == 'string'
end

local function coerceString(value)
    if value ~= nil then
        value = tostring(value)
        if not isString(value) then return end
        return value
    end
    return box.NULL
end

local custom_string = types.scalar({
    name = 'CustomString',
    description = 'Custom string type',
    serialize = coerceString,
    parseValue = coerceString,
    parseLiteral = function(node)
        return coerceString(node.value)
    end,
    isValueOfTheType = isString,
})

local function decodeJson(value)
    if value ~= nil then
        return json.decode(value)
    end
    return box.NULL
end

local json_type = types.scalar({
    name = 'Json',
    description = 'Custom type with JSON decoding',
    serialize = function(value)
        if type(value) ~= 'string' then
            return json.encode(value)
        else
            -- in some cases need to prevent dual json.encode
            return value
        end
    end,
    parseValue = decodeJson,
    parseLiteral = function(node)
        return decodeJson(node.value)
    end,
    isValueOfTheType = isString,
})

local graphql_types = {
    ['enum'] = {
        graphql_type = my_enum,
        var_type = 'MyEnum',
        value = 'b',
        default = 'a',
    },
    ['boolean_true'] = {
        graphql_type = types.boolean,
        var_type = 'Boolean',
        value = true,
        default = false,
    },
    ['boolean_false'] = {
        graphql_type = types.boolean,
        var_type = 'Boolean',
        value = false,
        default = true,
    },
    ['id'] = {
        graphql_type = types.id,
        var_type = 'ID',
        value = '00000000-0000-0000-0000-000000000000',
        default = '11111111-1111-1111-1111-111111111111',
    },
    ['int'] = {
        graphql_type = types.int,
        var_type = 'Int',
        value = 2^30,
        default = 0,
    },
    ['float'] = {
        graphql_type = types.float,
        var_type = 'Float',
        value = 1.1111111,
        default = 0,
    },
    ['string'] = {
        graphql_type = types.string,
        var_type = 'String',
        value = 'Test string',
        default = 'Default Test string',
    },
    ['custom_string'] = {
        graphql_type = custom_string,
        var_type = 'CustomString',
        value = 'Test custom string',
        default = 'Default test custom string',
    },
    ['custom_json'] = {
        graphql_type = json_type,
        var_type = 'Json',
        value = '{"test":123}',
        default = '{"test":0}',
    },
    ['inputObject'] = {
        graphql_type = my_input_object,
        var_type = 'MyInputObject',
        value = { input_object_arg = "Input Object Test String" },
        default = { input_object_arg = "Default Input Object Test String" },
    },
}

local function build_schema(argument_type, argument_nullability,
                            argument_inner_type, argument_inner_nullability,
                            argument_value,
                            variable_type, variable_nullability,
                            variable_inner_type, variable_inner_nullability,
                            variable_value, variable_default) -- luacheck: no unused args
    local type
    if argument_type == 'list' then
        if argument_inner_nullability == NonNullable then
            type = types.list(types.nonNull(graphql_types[argument_inner_type].graphql_type))
        else
            type = types.list(graphql_types[argument_inner_type].graphql_type)
        end
        if argument_nullability == NonNullable then
            type = types.nonNull(type)
        end
    else
        if argument_nullability == NonNullable then
            type = types.nonNull(graphql_types[argument_type].graphql_type)
        else
            type = graphql_types[argument_type].graphql_type
        end
    end

    return {
        ['test'] = {
            kind = types.object({
                name = 'result',
                fields = {arg1 = type}
            }),
            arguments = {arg1 = type},
            resolve = function(_, args)
                return args
            end,
        }
    }
end


g.test_nonlist_argument_nullability_float_1 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_nullability_float_2 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_nullability_float_3 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = 1.11111
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: 1.11111) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_nullability_float_4 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_nullability_float_5 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_nullability_float_6 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = 1.11111
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: 1.11111) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_1 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_2 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_3 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: []) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_4 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [null]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[null]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_5 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = 1.11111
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [1.11111]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_6 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_7 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_8 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: []) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_9 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [null]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_10 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = 1.11111
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [1.11111]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_11 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_12 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_13 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: []) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_14 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [null]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[null]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_15 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = 1.11111
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [1.11111]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_16 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_17 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: null) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_18 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: []) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_19 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = box.NULL
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [null]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_list_argument_nullability_list_20 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = 1.11111
    local variable_type = nil
    local variable_nullability = nil
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery { test(arg1: [1.11111]) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_1 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_2 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_3 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":0}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_4 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_5 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_6 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_7 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_8 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_9 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_10 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" expected to be non-null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_11 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_12 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":0}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_13 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" expected to be non-null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_14 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_15 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" expected to be non-null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_16 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_17 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_18 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_19 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" type mismatch: the variable type \"Float\" is not compatible with the argument type \"NonNull(Float)\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_20 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" type mismatch: the variable type \"Float\" is not compatible with the argument type \"NonNull(Float)\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_21 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":0}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_22 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" type mismatch: the variable type \"Float\" is not compatible with the argument type \"NonNull(Float)\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_23 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" type mismatch: the variable type \"Float\" is not compatible with the argument type \"NonNull(Float)\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_24 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"Float!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_25 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" type mismatch: the variable type \"Float\" is not compatible with the argument type \"NonNull(Float)\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_26 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" type mismatch: the variable type \"Float\" is not compatible with the argument type \"NonNull(Float)\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_27 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = Nullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_28 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" expected to be non-null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_29 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_30 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":0}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_31 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" expected to be non-null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_32 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_33 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"var1\" expected to be non-null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_34 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_35 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_float_36 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = NonNullable
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: Float! = 0) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":1.11111}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_1 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_2 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_3 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_4 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[null]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_5 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_6 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_7 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_8 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_9 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_10 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_11 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_12 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_13 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_14 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_15 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_16 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_17 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_18 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_19 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_20 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_21 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_22 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_23 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_24 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_25 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_26 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_27 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_28 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_29 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_30 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_31 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_32 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_33 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_34 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_35 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_36 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_37 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_38 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_39 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_40 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_41 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_42 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_43 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_44 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_45 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_46 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_47 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_48 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_49 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_50 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_51 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of required type \"[Float]!\" was not provided."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_52 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_53 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_54 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[null]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_55 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_56 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_57 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_58 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_59 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_60 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_61 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_62 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_63 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_64 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_65 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_66 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_67 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_68 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_69 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_70 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_71 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_72 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_73 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_74 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_75 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_76 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of required type \"[Float!]!\" was not provided."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_77 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_78 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_79 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_80 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_81 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_82 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_83 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_84 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_85 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_86 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_87 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_88 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_89 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_90 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_91 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_92 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_93 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_94 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_95 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_96 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_97 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_98 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_99 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_100 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_101 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_102 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_103 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_104 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_105 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_106 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_107 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_108 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_109 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_110 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_111 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_112 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_113 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_114 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_115 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_116 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_117 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_118 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_119 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_120 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_121 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_122 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_123 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_124 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_125 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_126 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_127 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_128 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_129 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_130 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_131 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_132 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_133 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_134 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_135 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":null}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_136 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_137 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_138 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_139 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_140 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_141 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_142 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_143 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_144 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_145 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_146 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_147 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_148 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_149 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_150 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_151 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_152 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_153 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_154 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_155 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_156 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_157 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_158 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_159 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_160 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_161 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_162 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_163 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_164 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_165 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_166 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_167 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_168 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_169 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_170 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_171 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_172 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_173 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_174 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_175 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_176 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of required type \"[Float!]!\" was not provided."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_177 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_178 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_179 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_180 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_181 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_182 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_183 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_184 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_185 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_186 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_187 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_188 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_189 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_190 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_191 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_192 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_193 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_194 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_195 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_196 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_197 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_198 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_199 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_200 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = Nullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_201 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_202 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_203 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_204 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[null]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_205 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_206 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_207 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_208 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_209 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_210 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_211 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_212 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_213 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_214 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_215 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_216 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_217 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_218 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_219 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_220 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_221 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_222 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_223 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_224 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_225 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_226 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_227 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_228 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_229 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_230 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_231 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_232 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_233 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_234 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_235 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_236 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_237 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_238 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_239 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_240 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_241 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_242 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_243 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_244 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_245 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_246 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_247 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_248 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_249 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_250 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_251 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of required type \"[Float]!\" was not provided."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_252 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_253 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_254 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[null]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_255 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_256 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_257 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_258 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_259 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_260 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_261 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_262 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_263 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_264 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_265 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_266 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_267 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_268 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_269 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_270 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_271 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_272 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_273 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_274 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_275 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_276 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of required type \"[Float!]!\" was not provided."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_277 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_278 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_279 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_280 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_281 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_282 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_283 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_284 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_285 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_286 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_287 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_288 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_289 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_290 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_291 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_292 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_293 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_294 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_295 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_296 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_297 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_298 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_299 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_300 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = Nullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_301 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_302 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_303 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_304 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_305 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_306 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_307 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_308 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_309 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_310 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_311 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_312 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_313 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_314 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_315 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_316 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_317 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_318 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_319 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_320 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_321 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_322 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_323 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_324 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_325 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_326 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_327 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_328 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_329 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_330 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_331 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_332 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_333 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_334 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_335 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = 'null'
    local expected_error_json = "Argument \"arg1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_336 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_337 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_338 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_339 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_340 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_341 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_342 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_343 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_344 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_345 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_346 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_347 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float!]\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_348 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_349 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_350 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = Nullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!] = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_351 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_352 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_353 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_354 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_355 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_356 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_357 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_358 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_359 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_360 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_361 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_362 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_363 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_364 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_365 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_366 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_367 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_368 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_369 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_370 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_371 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_372 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(Float))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_373 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_374 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_375 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = Nullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of type \"[Float]!\" used in position expecting type \"[Float!]!\"."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_376 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of required type \"[Float!]!\" was not provided."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_377 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_378 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_379 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_380 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[0]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_381 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_382 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_383 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_384 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_385 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" of non-null type \"[Float!]!\" must not be null."

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_386 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_387 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_388 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_389 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_390 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"nil\" at \"var1[0]\"; Float cannot represent non numeric value: \"nil\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_391 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_392 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_393 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_394 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_395 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Variable \"$var1\" got invalid value \"box.NULL\" at \"var1[0]\"; Float cannot represent non numeric value: \"box.NULL\""

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_396 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]!) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_397 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = null) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(List(NonNull(Float)))\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_398 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = nil
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = []) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_399 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = box.NULL
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [null]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = nil
    local expected_error_json = "Expected non-null for \"NonNull(Float)\", got null"

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end

g.test_nonlist_argument_with_variables_nullability_list_400 = function(g) -- luacheck: no unused args
    local argument_type = 'list'
    local argument_nullability = NonNullable
    local argument_inner_type = 'float'
    local argument_inner_nullability = NonNullable
    local argument_value = nil
    local variable_type = 'list'
    local variable_nullability = NonNullable
    local variable_inner_type = 'float'
    local variable_inner_nullability = NonNullable
    local variable_default = 0
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = 'query MyQuery($var1: [Float!]! = [0]) { test(arg1: $var1) { arg1 } }'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = '{"test":{"arg1":[1.11111]}}'
    local expected_error_json = nil

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end
