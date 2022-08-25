
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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: 1.11111) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: 1.11111) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: []) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [null]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [1.11111]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: []) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [null]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [1.11111]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: []) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [null]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [1.11111]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: null) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: []) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [null]) { arg1 } }"

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
    local query = "query MyQuery { test(arg1: [1.11111]) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float = 1.11111) { test(arg1: $var1) { arg1 } }"

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

g.test_nonlist_argument_with_variables_nullability_float_4 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float! = 1.11111) { test(arg1: $var1) { arg1 } }"

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

g.test_nonlist_argument_with_variables_nullability_float_13 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = Nullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float! = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float! = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float = 1.11111) { test(arg1: $var1) { arg1 } }"

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

g.test_nonlist_argument_with_variables_nullability_float_22 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
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
    local query = "query MyQuery($var1: Float = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'Nullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = nil

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float! = 1.11111) { test(arg1: $var1) { arg1 } }"

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

g.test_nonlist_argument_with_variables_nullability_float_31 = function(g) -- luacheck: no unused args
    local argument_type = 'float'
    local argument_nullability = NonNullable
    local argument_inner_type = nil
    local argument_inner_nullability = nil
    local argument_value = nil
    local variable_type = 'float'
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = box.NULL

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float! = 1.11111) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float!) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
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
    local query = "query MyQuery($var1: Float! = null) { test(arg1: $var1) { arg1 } }"

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
    local variable_nullability = 'NonNullable'
    local variable_inner_type = nil
    local variable_inner_nullability = nil
    local variable_default = 1.11111
    local variable_value = 1.11111

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = "query MyQuery($var1: Float! = 1.11111) { test(arg1: $var1) { arg1 } }"

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
