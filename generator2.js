var { graphql, buildSchema } = require('graphql');

var nil = 'nil'
var box = {NULL: 'box.NULL'}

var Float = 'float'
var value = 1.11111
var Nullable = 'Nullable'
var NonNullable = 'NonNullable'

var Lua_to_JS_type_map = {
    "float": "Float",
    "list": "list",
}

function JS_to_Lua_error_map_func(s) {
    if (s === 'nil') {
        return s
    }

    const regex = /^"Expected value of type \\\"(?<type>[a-zA-Z]+)!\\\", found null\."$/
    let found = s.match(regex)

    if (found) {
        return `"Expected non-null for \\\"NonNull(${found.groups.type})\\\", got null"`
    }

    const regex2 = /^"Expected value of type \\\"\[(?<type>[a-zA-Z]+)\]!\\\", found null\."$/
    found = s.match(regex2)

    if (found) {
        return `"Expected non-null for \\\"NonNull(List(${found.groups.type}))\\\", got null"`
    }

    const regex3 = /^"Expected value of type \\\"\[(?<type>[a-zA-Z]+)!\]\\\", found null\."$/
    found = s.match(regex3)

    if (found) {
        return `"Expected non-null for \\\"List(NonNull(${found.groups.type}))\\\", got null"`
    }

    const regex4 = /^"Expected value of type \\\"\[(?<type>[a-zA-Z]+)!\]!\\\", found null\."$/
    found = s.match(regex4)

    if (found) {
        return `"Expected non-null for \\\"NonNull(List(NonNull(${found.groups.type})))\\\", got null"`
    }

    return s
}

function build_schema(argument_type, argument_nullability,
                      argument_inner_type, argument_inner_nullability, 
                      argument_value) {
    var js_type = Lua_to_JS_type_map[argument_type]
    var js_inner_type = Lua_to_JS_type_map[argument_inner_type]

    var js_nullability = ``
    if (argument_nullability == NonNullable) {
        js_nullability = `!`
    }

    var js_inner_nullability = ``
    if (argument_inner_nullability == NonNullable) {
        js_inner_nullability = `!`
    }

    var argument_str
    if (js_type === 'list') {
        argument_str = `[${js_inner_type}${js_inner_nullability}]${js_nullability}`
    } else {
        argument_str = `${js_type}${js_nullability}`
    }

    var schema_str = `
        type result {
          arg1: ${argument_str}
        }

        type Query {
          test(arg1: ${argument_str}): result!
        }
    `

  return buildSchema(schema_str);
};

function build_query(argument_type, argument_nullability,
                     argument_inner_type, argument_inner_nullability, 
                     argument_value) {
    var js_type = Lua_to_JS_type_map[argument_type]

    if ((argument_value == nil) || (argument_value == box.NULL)) {
        return `query MyQuery { test(arg1: null) { arg1 } }`
    } else {
        if (js_type == 'list') {
            if (argument_value[0] == nil) {
                return `query MyQuery { test(arg1: []) { arg1 } }`
            } else if (argument_value[0] == box.NULL) {
                return `query MyQuery { test(arg1: [null]) { arg1 } }`
            } else {
                var js_value = JSON.stringify(argument_value)
                return `query MyQuery { test(arg1: ${js_value}) { arg1 } }`
            }
        }
        return `query MyQuery { test(arg1: ${argument_value}) { arg1 } }`
    }
};

var rootValue = {
    test: (args) => {
        return args;
    },
};


var test_header = `
local json = require('json')
local types = require('graphql.types')

local t = require('luatest')
local g = t.group('fuzzing')

local helpers = require('test.helpers')

-- constants
local Nullable = true
local NonNullable = false

local ARGUMENTS = 1
local ARGUMENT_TYPE = 1
local ARGUMENT_NULLABILITY = 2
local ARGUMENT_INNER_TYPE = 3
local ARGUMENT_INNER_NULLABILITY = 4
local INPUT_VALUE = 5
local VARIABLE_NULLABILITY = 6
local VARIABLE_INNER_TYPE = 7
local VARIABLE_INNER_NULLABILITY = 8
local VARIABLE_DEFAULT = 9
local EXPECTED_ERROR = 2

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

local function is_box_null(value)
    if value and value == nil then
        return true
    end
    return false
end

local function build_schema(argument_type, argument_nullability,
                            argument_inner_type, argument_inner_nullability,
                            argument_value)
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

`
console.log(test_header)

function build_test_case(response, suite_name, i,
                         argument_type, argument_nullability,
                         argument_inner_type, argument_inner_nullability, 
                         argument_value,
                         query) {
    var expected_data

    if (response.hasOwnProperty('data')) {
        var _expected_data = JSON.stringify(response.data)
        expected_data = `'${_expected_data}'`
    } else {
        expected_data = `nil`
    }

    var expected_error

    if (response.hasOwnProperty('errors')) {
        var _expected_error = JSON.stringify(response.errors[0].message)
        expected_error = JS_to_Lua_error_map_func(`${_expected_error}`)
    } else {
        expected_error = `nil`
    }

    var Lua_type = `'${argument_type}'`
    var Lua_nullability = argument_nullability

    var Lua_inner_type
    if (argument_inner_type !== null) {
        Lua_inner_type = `'${argument_inner_type}'`
    } else {
        Lua_inner_type = `nil`
    }

    var Lua_inner_nullability
    if (argument_inner_nullability !== null) {
        Lua_inner_nullability = argument_inner_nullability
    } else {
        Lua_inner_nullability = `nil`
    }

    return `
g.test_${suite_name}_${argument_type}_${i} = function()
    local argument_type = ${Lua_type}
    local argument_nullability = ${Lua_nullability}
    local argument_inner_type = ${Lua_inner_type}
    local argument_inner_nullability = ${Lua_inner_nullability}
    local argument_value = ${argument_value}
    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value)
    local query = "${query}"

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, nil)

    local result, err
    if ok then
        result = json.encode(res)
    else
        err = res
    end

    local expected_data_json = ${expected_data}
    local expected_error_json = ${expected_error}

    t.assert_equals(result, expected_data_json)
    t.assert_equals(err, expected_error_json)
end`
}

async function build_suite(suite_name,
                     argument_type, argument_nullabilities,
                     argument_inner_type, argument_inner_nullabilities,
                     argument_values) {
    let i = 0

    if (argument_inner_nullabilities.length == 0) {
        let argument_inner_nullability = null

        argument_nullabilities.forEach( async function (argument_nullability) {
            argument_values.forEach( async function (argument_value)  {
                let schema = build_schema(argument_type, argument_nullability,
                                          argument_inner_type, argument_inner_nullability, 
                                          argument_value)
                let query = build_query(argument_type, argument_nullability,
                                        argument_inner_type, argument_inner_nullability, 
                                        argument_value)
                

                await graphql({
                    schema,
                    source: query,
                    rootValue,
                }).then((response) => {
                    i = i + 1
                    console.log(build_test_case(response, suite_name, i,
                                           argument_type, argument_nullability,
                                           argument_inner_type, argument_inner_nullability, 
                                           argument_value,
                                           query))
                })
            })
        })

        return
    }

    argument_nullabilities.forEach( async function (argument_nullability) {
        argument_inner_nullabilities.forEach( async function (argument_inner_nullability) {
            argument_values.forEach( async function (argument_value)  {

                let schema = build_schema(argument_type, argument_nullability,
                                          argument_inner_type, argument_inner_nullability, 
                                          argument_value)
                let query = build_query(argument_type, argument_nullability,
                                        argument_inner_type, argument_inner_nullability, 
                                        argument_value)
                
                await graphql({
                    schema,
                    source: query,
                    rootValue,
                }).then((response) => {
                    i = i + 1
                    console.log(build_test_case(response, suite_name, i,
                                           argument_type, argument_nullability,
                                           argument_inner_type, argument_inner_nullability, 
                                           argument_value,
                                           query))
                })
            })
        })
    })
}

// == Non-list argument nullability ==
// 
// There is no way pass no value to the argument
// since `test(arg1)` is invalid syntax.
// We use `test(arg1: null)` for both nil and box.NULL,
// so the behavior will be the same for them.

build_suite('nonlist_argument_nullability',
            Float, [Nullable, NonNullable],
            null, [],
            [nil, box.NULL, value])

// == List argument nullability ==
// 
// {nil} is the same is {} in Lua.

// suite_name = 'list_argument_nullability'
// argument_type = 'list'
// argument_nullabilities = [Nullable, NonNullable]
// argument_inner_type = Float
// argument_inner_nullability = [Nullable, NonNullable]
// argument_values = [nil, box.NULL, [nil], [box.NULL], [value]]

build_suite('list_argument_nullability',
            'list', [Nullable, NonNullable],
            Float, [Nullable, NonNullable],
            [nil, box.NULL, [nil], [box.NULL], [value]])
