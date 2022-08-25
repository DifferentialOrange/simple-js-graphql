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
                      value,
                      variable_type, variable_nullability,
                      variable_inner_type, variable_inner_nullability, 
                      variable_default) {
    var js_argument_type = Lua_to_JS_type_map[argument_type]
    var js_argument_inner_type = Lua_to_JS_type_map[argument_inner_type]

    var js_argument_nullability = ``
    if (argument_nullability == NonNullable) {
        js_argument_nullability = `!`
    }

    var js_argument_inner_nullability = ``
    if (argument_inner_nullability == NonNullable) {
        js_argument_inner_nullability = `!`
    }

    var argument_str
    if (js_argument_type === 'list') {
        argument_str = `[${js_argument_inner_type}${js_argument_inner_nullability}]${js_argument_nullability}`
    } else {
        argument_str = `${js_argument_type}${js_argument_nullability}`
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
                     value,
                     variable_type, variable_nullability,
                     variable_inner_type, variable_inner_nullability, 
                     variable_default) {
    let js_argument_type = Lua_to_JS_type_map[argument_type]
    let js_argument_inner_type = Lua_to_JS_type_map[argument_inner_type]
    let js_variable_type = Lua_to_JS_type_map[variable_type]
    let js_variable_inner_type = Lua_to_JS_type_map[variable_inner_type]

    var js_variable_nullability = ``
    if (variable_nullability == NonNullable) {
        js_variable_nullability = `!`
    }

    var js_variable_inner_nullability = ``
    if (variable_inner_nullability == NonNullable) {
        js_variable_inner_nullability = `!`
    }

    // Variable case
    if (variable_type !== null) {
        let variable_str
        if (js_variable_type === 'list') {
            variable_str = `[${js_variable_inner_type}${js_variable_inner_nullability_str}]${js_variable_inner_nullability}`
        } else {
          variable_str = `${js_variable_type}${js_variable_nullability}`
        }

        let default_str = ``
        if (js_variable_type === 'list') {
            if (variable_default[0] === nil) {
                default_str = ` = []`
            } else if (value[0] === box.NULL) {
                default_str = ` = [null]`
            } else {
                var js_default = JSON.stringify(variable_default)
                default_str = ` = [${js_default}]`
            }
        } else {
            if (variable_default === nil) {
                default_str = ``
            } else if (variable_default === box.NULL) {
                default_str = ` = null`
            } else {
                var js_default = JSON.stringify(variable_default)
                default_str = ` = ${js_default}`
            }
        }

        return `query MyQuery($var1: ${variable_str}${default_str}) { test(arg1: $var1) { arg1 } }`
    }

    // No variables case
    if ((value === nil) || (value === box.NULL)) {
        return `query MyQuery { test(arg1: null) { arg1 } }`
    } else {
        if (js_argument_type === 'list') {
            if (value[0] === nil) {
                return `query MyQuery { test(arg1: []) { arg1 } }`
            } else if (value[0] === box.NULL) {
                return `query MyQuery { test(arg1: [null]) { arg1 } }`
            } else {
                var js_value = JSON.stringify(value)
                return `query MyQuery { test(arg1: ${js_value}) { arg1 } }`
            }
        }
        return `query MyQuery { test(arg1: ${value}) { arg1 } }`
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
                            value,
                            variable_type, variable_nullability,
                            variable_inner_type, variable_inner_nullability,
                            variable_default)
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
                         value,
                         variable_type, variable_nullability,
                         variable_inner_type, variable_inner_nullability, 
                         variable_default,
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

    var Lua_argument_type = `'${argument_type}'`
    var Lua_argument_nullability = argument_nullability

    var Lua_argument_inner_type
    if (argument_inner_type !== null) {
        Lua_argument_inner_type = `'${argument_inner_type}'`
    } else {
        Lua_argument_inner_type = `nil`
    }

    var Lua_argument_inner_nullability
    if (argument_inner_nullability !== null) {
        Lua_argument_inner_nullability = argument_inner_nullability
    } else {
        Lua_argument_inner_nullability = `nil`
    }

    var Lua_variable_type
    if (variable_type !== null) {
        Lua_variable_type = `'${variable_type}'`
    } else {
        Lua_variable_type = `nil`
    }

    var Lua_variable_nullability
    if (variable_nullability !== null) {
        Lua_variable_nullability = `'${variable_nullability}'`
    } else {
        Lua_variable_nullability = `nil`
    }

    var Lua_variable_inner_type
    if (variable_inner_type !== null) {
        Lua_variable_inner_type = `'${variable_inner_type}'`
    } else {
        Lua_variable_inner_type = `nil`
    }

    var Lua_variable_inner_nullability
    if (variable_inner_nullability !== null) {
        Lua_variable_inner_nullability = `'${variable_inner_nullability}'`
    } else {
        Lua_variable_inner_nullability = `nil`
    }

    let variables = `nil`

    let Lua_variable_default = `nil`
    if (variable_default !== null) {
        Lua_variable_default = variable_default
    } 

    return `
g.test_${suite_name}_${argument_type}_${i} = function()
    local argument_type = ${Lua_argument_type}
    local argument_nullability = ${Lua_argument_nullability}
    local argument_inner_type = ${Lua_argument_inner_type}
    local argument_inner_nullability = ${Lua_argument_inner_nullability}
    local value = ${value}
    local variable_type = ${Lua_variable_type}
    local variable_nullability = ${Lua_variable_nullability}
    local variable_inner_type = ${Lua_variable_inner_type}
    local variable_inner_nullability = ${Lua_variable_inner_nullability}
    local variable_default = ${Lua_variable_default}

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_default)
    local query = "${query}"

    local ok, res
    if variable_type == nil then
        ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, nil)
    else
        ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = value }})
    end

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

function build_variables(argument_type, argument_nullability,
                         argument_inner_type, argument_inner_nullability, 
                         value,
                         variable_type, variable_nullability,
                         variable_inner_type, variable_inner_nullability, 
                         variable_default) {
    let variables = [];

    if (value !== nil) {
        if (value === box.NULL) {
            variables = {var1: null}
        } else {
            variables = {var1: value}
        }
    }

    return variables
}

async function build_suite(suite_name,
                     argument_type, argument_nullabilities,
                     argument_inner_type, argument_inner_nullabilities,
                     values, // argument values in case of no variable and variable value if it is used
                     variable_type, variable_nullabilities,
                     variable_inner_type, variable_inner_nullabilities,
                     variable_defaults) {
    let i = 0

    if (argument_inner_nullabilities.length == 0) {
        // Non-list case
        let argument_inner_nullability = null
        let variable_inner_nullability = null

        if (variable_type == null) {
            // No variables case
            let variable_nullability = null
            let variable_default = null

            argument_nullabilities.forEach( async function (argument_nullability) {
                values.forEach( async function (value)  {
                    let schema = build_schema(argument_type, argument_nullability,
                                              argument_inner_type, argument_inner_nullability, 
                                              value,
                                              variable_type, variable_nullability,
                                              variable_inner_type, variable_inner_nullability, 
                                              variable_default)
                    let query = build_query(argument_type, argument_nullability,
                                            argument_inner_type, argument_inner_nullability, 
                                            value,
                                            variable_type, variable_nullability,
                                            variable_inner_type, variable_inner_nullability, 
                                            variable_default)
                    

                    await graphql({
                        schema,
                        source: query,
                        rootValue,
                    }).then((response) => {
                        i = i + 1
                        console.log(build_test_case(response, suite_name, i,
                                               argument_type, argument_nullability,
                                               argument_inner_type, argument_inner_nullability, 
                                               value,
                                               variable_type, variable_nullability,
                                               variable_inner_type, variable_inner_nullability, 
                                               variable_default,
                                               query))
                    })
                })
            })
        } else {
            argument_nullabilities.forEach( async function (argument_nullability) {
                variable_nullabilities.forEach( async function (variable_nullability)  {
                    values.forEach( async function (value)  {
                        variable_defaults.forEach( async function (variable_default)  {
                            let schema = build_schema(argument_type, argument_nullability,
                                                      argument_inner_type, argument_inner_nullability, 
                                                      value,
                                                      variable_type, variable_nullability,
                                                      variable_inner_type, variable_inner_nullability, 
                                                      variable_default)
                            let query = build_query(argument_type, argument_nullability,
                                                    argument_inner_type, argument_inner_nullability, 
                                                    value,
                                                    variable_type, variable_nullability,
                                                    variable_inner_type, variable_inner_nullability, 
                                                    variable_default)

                            let variables = build_variables(argument_type, argument_nullability,
                                                            argument_inner_type, argument_inner_nullability, 
                                                            value,
                                                            variable_type, variable_nullability,
                                                            variable_inner_type, variable_inner_nullability, 
                                                            variable_default)
                            

                            await graphql({
                                schema,
                                source: query,
                                rootValue,
                                variableValues: variables
                            }).then((response) => {
                                i = i + 1
                                console.log(build_test_case(response, suite_name, i,
                                                            argument_type, argument_nullability,
                                                            argument_inner_type, argument_inner_nullability, 
                                                            value,
                                                            variable_type, variable_nullability,
                                                            variable_inner_type, variable_inner_nullability, 
                                                            variable_default,
                                                            query))
                            })
                        })
                    })
                })
            })
        }

        return
    }

    // List case
    argument_nullabilities.forEach( async function (argument_nullability) {
        argument_inner_nullabilities.forEach( async function (argument_inner_nullability) {
            values.forEach( async function (value)  {
                let variable_nullability = null
                let variable_inner_nullability = null
                let variable_default = null

                let schema = build_schema(argument_type, argument_nullability,
                                          argument_inner_type, argument_inner_nullability, 
                                          value,
                                          variable_type, variable_nullability,
                                          variable_inner_type, variable_inner_nullability, 
                                          variable_default)
                let query = build_query(argument_type, argument_nullability,
                                        argument_inner_type, argument_inner_nullability, 
                                        value,
                                        variable_type, variable_nullability,
                                        variable_inner_type, variable_inner_nullability, 
                                        variable_default)
                
                await graphql({
                    schema,
                    source: query,
                    rootValue,
                }).then((response) => {
                    i = i + 1
                    console.log(build_test_case(response, suite_name, i,
                                                argument_type, argument_nullability,
                                                argument_inner_type, argument_inner_nullability, 
                                                value,
                                                variable_type, variable_nullability,
                                                variable_inner_type, variable_inner_nullability, 
                                                variable_default,
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
            [nil, box.NULL, value],
            null, [],
            null, [],
            [])

// == List argument nullability ==
// 
// {nil} is the same as {} in Lua.

build_suite('list_argument_nullability',
            'list', [Nullable, NonNullable],
            Float, [Nullable, NonNullable],
            [nil, box.NULL, [nil], [box.NULL], [value]],
            null, [],
            null, [],
            [])

// == Non-list argument with variable nullability ==

build_suite('nonlist_argument_with_variables_nullability',
            Float, [Nullable, NonNullable],
            null, [],
            [nil, box.NULL, value],
            Float, [Nullable, NonNullable],
            null, [],
            [nil, box.NULL, value],)