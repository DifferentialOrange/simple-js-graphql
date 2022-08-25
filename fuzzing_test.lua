
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

g.test_list_argument_nullability_float_1 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_2 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_3 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_4 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_5 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_6 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_7 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_8 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_9 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_10 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_11 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_12 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_13 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_14 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_15 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_16 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_17 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_18 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_19 = function(g) -- luacheck: no unused args
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

g.test_list_argument_nullability_float_20 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_1 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_2 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_3 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_4 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_5 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_6 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_7 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_8 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_9 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_10 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_11 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_12 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_13 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_14 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_15 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_16 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_17 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_18 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_19 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_20 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_21 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_22 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_23 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_24 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_25 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_26 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_27 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_28 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_29 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_30 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_31 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_32 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_33 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_34 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_35 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_36 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_37 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_38 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_39 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_40 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_41 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_42 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_43 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_44 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_45 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_46 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_47 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_48 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_49 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_50 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_51 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_52 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_53 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_54 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_55 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_56 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_57 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_58 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_59 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_60 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_61 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_62 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_63 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_64 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_65 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_66 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_67 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_68 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_69 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_70 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_71 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_72 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_73 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_74 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_75 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_76 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_77 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_78 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_79 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_80 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_81 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_82 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_83 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_84 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_85 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_86 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_87 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_88 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_89 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_90 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_91 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_92 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_93 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_94 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_95 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_96 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_97 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_98 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_99 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_100 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_101 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_102 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_103 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_104 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_105 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_106 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_107 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_108 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_109 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_110 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_111 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_112 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_113 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_114 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_115 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_116 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_117 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_118 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_119 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_120 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_121 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_122 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_123 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_124 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_125 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_126 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_127 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_128 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_129 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_130 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_131 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_132 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_133 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_134 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_135 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_136 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_137 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_138 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_139 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_140 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_141 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_142 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_143 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_144 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_145 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_146 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_147 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_148 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_149 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_150 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_151 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_152 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_153 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_154 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_155 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_156 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_157 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_158 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_159 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_160 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_161 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_162 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_163 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_164 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_165 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_166 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_167 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_168 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_169 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_170 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_171 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_172 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_173 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_174 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_175 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_176 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_177 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_178 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_179 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_180 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_181 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_182 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_183 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_184 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_185 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_186 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_187 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_188 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_189 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_190 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_191 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_192 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_193 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_194 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_195 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_196 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_197 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_198 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_199 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_200 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_201 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_202 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_203 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_204 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_205 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_206 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_207 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_208 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_209 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_210 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_211 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_212 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_213 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_214 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_215 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_216 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_217 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_218 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_219 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_220 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_221 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_222 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_223 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_224 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_225 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_226 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_227 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_228 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_229 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_230 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_231 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_232 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_233 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_234 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_235 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_236 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_237 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_238 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_239 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_240 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_241 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_242 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_243 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_244 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_245 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_246 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_247 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_248 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_249 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_250 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_251 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_252 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_253 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_254 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_255 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_256 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_257 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_258 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_259 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_260 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_261 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_262 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_263 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_264 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_265 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_266 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_267 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_268 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_269 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_270 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_271 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_272 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_273 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_274 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_275 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_276 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_277 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_278 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_279 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_280 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_281 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_282 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_283 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_284 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_285 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_286 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_287 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_288 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_289 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_290 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_291 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_292 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_293 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_294 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_295 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_296 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_297 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_298 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_299 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_300 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_301 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_302 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_303 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_304 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_305 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_306 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_307 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_308 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_309 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_310 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_311 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_312 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_313 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_314 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_315 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_316 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_317 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_318 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_319 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_320 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_321 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_322 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_323 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_324 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_325 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_326 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_327 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_328 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_329 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_330 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_331 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_332 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_333 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_334 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_335 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_336 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_337 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_338 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_339 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_340 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_341 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_342 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_343 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_344 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_345 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_346 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_347 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_348 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_349 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_350 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_351 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_352 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_353 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_354 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_355 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_356 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_357 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_358 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_359 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_360 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_361 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_362 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_363 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_364 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_365 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_366 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_367 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_368 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_369 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_370 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_371 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_372 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_373 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_374 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_375 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_376 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_377 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_378 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_379 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_380 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_381 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_382 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_383 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_384 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_385 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_386 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_387 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_388 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_389 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_390 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_391 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_392 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_393 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_394 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_395 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_396 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_397 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_398 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_399 = function(g) -- luacheck: no unused args
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

g.test_list_argument_with_variables_nullability_float_400 = function(g) -- luacheck: no unused args
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
