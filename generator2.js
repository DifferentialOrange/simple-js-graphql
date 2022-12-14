var { graphql, buildSchema } = require('graphql');

var nil = 'nil'
var box = {NULL: 'box.NULL'}

var Float = 'float'
var value = 1.11111
var default_value = 0
var Nullable = 'Nullable'
var NonNullable = 'NonNullable'

var Lua_to_JS_type_map = {
    "float": "Float",
    "list": "list",
}

var Lua_to_JS_error = [
    {
        "regex": /^"Expected value of type \\\"(?<type>[a-zA-Z]+)!\\\", found null\."$/,
        "return": function(groups) {
            return `"Expected non-null for \\\"NonNull(${groups.type})\\\", got null"`
        }
    },
    {
        "regex": /^"Expected value of type \\\"\[(?<type>[a-zA-Z]+)\]!\\\", found null\."$/,
        "return": function(groups) {
            return `"Expected non-null for \\\"NonNull(List(${groups.type}))\\\", got null"`
        }
    },
    {
        "regex": /^"Expected value of type \\\"\[(?<type>[a-zA-Z]+)!\]\\\", found null\."$/,
        "return": function(groups) {
            return `"Expected non-null for \\\"List(NonNull(${groups.type}))\\\", got null"`
        }
    },
    {
        "regex": /^"Expected value of type \\\"\[(?<type>[a-zA-Z]+)!\]!\\\", found null\."$/,
        "return": function(groups) {
            return `"Expected non-null for \\\"NonNull(List(NonNull(${groups.type})))\\\", got null"`
        }
    },
    {
        "regex": /^"Variable \\"\$var1\\" of required type \\\"(?<type>[a-zA-Z]+)!\\\" was not provided\."$/,
        "return": function(groups) {
            return `"Variable \\\"var1\\\" expected to be non-null"`
        }
    },
    {
        "regex": /^"Variable \\"\$var1\\" of non-null type \\\"(?<type>[a-zA-Z]+)!\\\" must not be null\."$/,
        "return": function(groups) {
            return `"Variable \\\"var1\\\" expected to be non-null"`
        }
    },
    {
        "regex": /^"Variable \\"\$var1\\" of type \\\"(?<type1>[a-zA-Z]+)\\\" used in position expecting type \\\"(?<type2>[a-zA-Z]+)!\\\"\."$/,
        "return": function(groups) {
            return `"Variable \\\"var1\\\" type mismatch: the variable type \\\"${groups.type1}\\\" is not compatible with the argument type \\\"NonNull(${groups.type2})\\\""`
        }
    },
]

function JS_to_Lua_error_map_func(s) {
    let j = 0
    for (j = 0; j < Lua_to_JS_error.length; j++) {
        let found = s.match(Lua_to_JS_error[j].regex)

        if (found) {
            return Lua_to_JS_error[j].return(found.groups)
        }
    }

    return s
}

// == Build JS GraphQL objects ==

function get_JS_nullability(nullability) {
    if (nullability == NonNullable) {
        return `!`
    } else {
        return ``
    }
}

function get_JS_type(type, nullability,
                     inner_type, inner_nullability) {
    let js_type = Lua_to_JS_type_map[type]
    let js_nullability = get_JS_nullability(nullability)
    let js_inner_type = Lua_to_JS_type_map[inner_type]
    let js_inner_nullability = get_JS_nullability(inner_nullability)

    if (js_type === 'list') {
        return `[${js_inner_type}${js_inner_nullability}]${js_nullability}`
    } else {
        return `${js_type}${js_nullability}`
    }
}

function get_JS_value(value, plain_nil_as_null) {
    if (Array.isArray(value)) {
        if (value[0] === nil) {
            return `[]`
        } else if (value[0] === box.NULL) {
            return `[null]`
        } else {
            return JSON.stringify(value)
        }
    } else {
        if (value === nil) {
            if (plain_nil_as_null) {
                return `null`
            } else {
                return ``
            }
        } else if (value === box.NULL) {
            return `null`
        } else {
            return JSON.stringify(value)
        }
    }
}

function get_JS_default_value(value) {
    return get_JS_value(value, false)
}

function get_JS_argument_value(value) {
    return get_JS_value(value, true)
}

function build_schema(argument_type, argument_nullability,
                      argument_inner_type, argument_inner_nullability, 
                      argument_value,
                      variable_type, variable_nullability,
                      variable_inner_type, variable_inner_nullability, 
                      variable_value, variable_default) {
    let argument_str = get_JS_type(argument_type, argument_nullability,
                                   argument_inner_type, argument_inner_nullability)

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
                     argument_value,
                     variable_type, variable_nullability,
                     variable_inner_type, variable_inner_nullability, 
                     variable_value, variable_default) {
    let js_argument_type = Lua_to_JS_type_map[argument_type]

    if (variable_type !== null) {
        let js_variable_type = Lua_to_JS_type_map[variable_type]
        let variable_str = get_JS_type(variable_type, variable_nullability,
                                       variable_inner_type, variable_inner_nullability)

        let default_str = ``
        let js_variable_default = get_JS_default_value(variable_default)
        if (js_variable_default !== ``) {
            default_str = ` = ${js_variable_default}`
        }

        return `query MyQuery($var1: ${variable_str}${default_str}) { test(arg1: $var1) { arg1 } }`
    } else {
        let js_argument_value = get_JS_argument_value(argument_value)
        return `query MyQuery { test(arg1: ${js_argument_value}) { arg1 } }`
    }
};

function build_variables(argument_type, argument_nullability,
                         argument_inner_type, argument_inner_nullability, 
                         argument_value,
                         variable_type, variable_nullability,
                         variable_inner_type, variable_inner_nullability, 
                         variable_value, variable_default) {
    let variables = [];

    if (Array.isArray(variable_value)) {
        if (variable_value[0] == nil) {
            return {var1: []}
        } else if (variable_value[0] === box.NULL) {
            return {var1: [null]}
        } else {
            return {var1: variable_value}
        }
    }

    if (variable_value !== nil) {
        if (variable_value === box.NULL) {
            return {var1: null}
        } else {
            return {var1: variable_value}
        }
    }

    return []
}

var rootValue = {
    test: (args) => {
        return args;
    },
};

// == Build Lua GraphQL objects ==

var test_header = `
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
`
console.log(test_header)

function to_Lua(v) {
    if (v === null) {
        return `nil`
    } else if (v === box.NULL) {
        return 'box.NULL'
    }

    if (Array.isArray(v)) {
        if (v[0] === nil) {
            return '{}'
        } else if (v[0] === box.NULL) {
            return '{box.NULL}'
        } else {
            return `{${v}}`
        }
    }

    return `${v}`
}

function to_Lua_String(v) {
    if (v == null) {
        return `nil`
    }

    return `'${v}'`
}

function build_test_case(response, suite_name, i,
                         argument_type, argument_nullability,
                         argument_inner_type, argument_inner_nullability, 
                         argument_value,
                         variable_type, variable_nullability,
                         variable_inner_type, variable_inner_nullability, 
                         variable_value, variable_default,
                         query) {
    let expected_data

    if (response.hasOwnProperty('data')) {
        let _expected_data = JSON.stringify(response.data)
        expected_data = `'${_expected_data}'`
    } else {
        expected_data = `nil`
    }

    let expected_error

    if (response.hasOwnProperty('errors')) {
        let _expected_error = JSON.stringify(response.errors[0].message)
        expected_error = JS_to_Lua_error_map_func(`${_expected_error}`)
    } else {
        expected_error = `nil`
    }

    let Lua_argument_type = to_Lua_String(argument_type)
    let Lua_argument_nullability = to_Lua(argument_nullability)
    let Lua_argument_inner_type = to_Lua_String(argument_inner_type)
    let Lua_argument_inner_nullability = to_Lua(argument_inner_nullability)

    let Lua_variable_type = to_Lua_String(variable_type)
    let Lua_variable_nullability = to_Lua(variable_nullability)
    let Lua_variable_inner_type = to_Lua_String(variable_inner_type)
    let Lua_variable_inner_nullability = to_Lua(variable_inner_nullability)


    let Lua_variable_default = to_Lua(variable_default)
    let Lua_argument_value = to_Lua(argument_value)
    let Lua_variable_value = to_Lua(variable_value)

    let type_in_name
    if (argument_inner_type !== null) {
        type_in_name = argument_inner_type
    } else {
        type_in_name = argument_type
    }

    return `
g.test_${suite_name}_${type_in_name}_${i} = function(g) -- luacheck: no unused args
    local argument_type = ${Lua_argument_type}
    local argument_nullability = ${Lua_argument_nullability}
    local argument_inner_type = ${Lua_argument_inner_type}
    local argument_inner_nullability = ${Lua_argument_inner_nullability}
    local argument_value = ${Lua_argument_value}
    local variable_type = ${Lua_variable_type}
    local variable_nullability = ${Lua_variable_nullability}
    local variable_inner_type = ${Lua_variable_inner_type}
    local variable_inner_nullability = ${Lua_variable_inner_nullability}
    local variable_default = ${Lua_variable_default}
    local variable_value = ${Lua_variable_value}

    local query_schema = build_schema(argument_type, argument_nullability,
                                      argument_inner_type, argument_inner_nullability,
                                      argument_value,
                                      variable_type, variable_nullability,
                                      variable_inner_type, variable_inner_nullability,
                                      variable_value, variable_default)
    local query = '${query}'

    local ok, res = pcall(helpers.check_request, query, query_schema, nil, nil, { variables = { var1 = variable_value }})

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
                     argument_values,
                     variable_type, variable_nullabilities,
                     variable_inner_type, variable_inner_nullabilities,
                     variable_values,
                     variable_defaults) {
    let i = 0

    if (argument_inner_nullabilities.length == 0) {
        // Non-list case
        let argument_inner_nullability = null
        let variable_inner_nullability = null

        if (variable_type == null) {
            // No variables case
            let variable_nullability = null
            let variable_value = null
            let variable_default = null

            argument_nullabilities.forEach( async function (argument_nullability) {
                argument_values.forEach( async function (argument_value)  {
                    let schema = build_schema(argument_type, argument_nullability,
                                              argument_inner_type, argument_inner_nullability,
                                              argument_value,
                                              variable_type, variable_nullability,
                                              variable_inner_type, variable_inner_nullability,
                                              variable_value, variable_default)

                    let query = build_query(argument_type, argument_nullability,
                                            argument_inner_type, argument_inner_nullability, 
                                            argument_value,
                                            variable_type, variable_nullability,
                                            variable_inner_type, variable_inner_nullability, 
                                            variable_value, variable_default)
                    

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
                                               variable_type, variable_nullability,
                                               variable_inner_type, variable_inner_nullability, 
                                               variable_value, variable_default,
                                               query))
                    })
                })
            })
        } else {
            // Variables case
            argument_nullabilities.forEach( async function (argument_nullability) {
                variable_nullabilities.forEach( async function (variable_nullability)  {
                    variable_values.forEach( async function (variable_value)  {
                        variable_defaults.forEach( async function (variable_default)  {
                            let argument_value = null

                            let schema = build_schema(argument_type, argument_nullability,
                                                      argument_inner_type, argument_inner_nullability, 
                                                      argument_value,
                                                      variable_type, variable_nullability,
                                                      variable_inner_type, variable_inner_nullability, 
                                                      variable_value, variable_default)

                            let query = build_query(argument_type, argument_nullability,
                                                    argument_inner_type, argument_inner_nullability, 
                                                    argument_value,
                                                    variable_type, variable_nullability,
                                                    variable_inner_type, variable_inner_nullability, 
                                                    variable_value, variable_default)

                            let variables = build_variables(argument_type, argument_nullability,
                                                            argument_inner_type, argument_inner_nullability, 
                                                            argument_value,
                                                            variable_type, variable_nullability,
                                                            variable_inner_type, variable_inner_nullability, 
                                                            variable_value, variable_default)
                            

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
                                                            argument_value,
                                                            variable_type, variable_nullability,
                                                            variable_inner_type, variable_inner_nullability, 
                                                            variable_value, variable_default,
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
    if (variable_type == null) {
        argument_nullabilities.forEach( async function (argument_nullability) {
            argument_inner_nullabilities.forEach( async function (argument_inner_nullability) {
                argument_values.forEach( async function (argument_value)  {
                    let variable_nullability = null
                    let variable_inner_nullability = null
                    let variable_value = null
                    let variable_default = null

                    let schema = build_schema(argument_type, argument_nullability,
                                              argument_inner_type, argument_inner_nullability, 
                                              argument_value,
                                              variable_type, variable_nullability,
                                              variable_inner_type, variable_inner_nullability, 
                                              variable_value, variable_default)

                    let query = build_query(argument_type, argument_nullability,
                                            argument_inner_type, argument_inner_nullability, 
                                            argument_value,
                                            variable_type, variable_nullability,
                                            variable_inner_type, variable_inner_nullability, 
                                            variable_value, variable_default)
                    
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
                                                    variable_type, variable_nullability,
                                                    variable_inner_type, variable_inner_nullability, 
                                                    variable_value, variable_default,
                                                    query))
                    })
                })
            })
        })
    } else {
        argument_nullabilities.forEach( async function (argument_nullability) {
            argument_inner_nullabilities.forEach( async function (argument_inner_nullability) {
                variable_nullabilities.forEach( async function (variable_nullability) {
                    variable_inner_nullabilities.forEach( async function (variable_inner_nullability) {
                        variable_values.forEach( async function (variable_value)  {
                            variable_defaults.forEach( async function (variable_default)  {
                                let argument_value = null

                                let schema = build_schema(argument_type, argument_nullability,
                                                          argument_inner_type, argument_inner_nullability, 
                                                          argument_value,
                                                          variable_type, variable_nullability,
                                                          variable_inner_type, variable_inner_nullability, 
                                                          variable_value, variable_default)

                                let query = build_query(argument_type, argument_nullability,
                                                        argument_inner_type, argument_inner_nullability, 
                                                        argument_value,
                                                        variable_type, variable_nullability,
                                                        variable_inner_type, variable_inner_nullability, 
                                                        variable_value, variable_default)

                                let variables = build_variables(argument_type, argument_nullability,
                                                                argument_inner_type, argument_inner_nullability, 
                                                                argument_value,
                                                                variable_type, variable_nullability,
                                                                variable_inner_type, variable_inner_nullability, 
                                                                variable_value, variable_default)
                                    
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
                                                                argument_value,
                                                                variable_type, variable_nullability,
                                                                variable_inner_type, variable_inner_nullability, 
                                                                variable_value, variable_default,
                                                                query))
                                })
                            })
                        })
                    })
                })
            })
        })
    }
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
            [],
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
            [],
            [])

// == Non-list argument with variable nullability ==

build_suite('nonlist_argument_with_variables_nullability',
            Float, [Nullable, NonNullable],
            null, [],
            [],
            Float, [Nullable, NonNullable],
            null, [],
            [nil, box.NULL, value],
            [nil, box.NULL, default_value])

// == List argument with variable nullability ==
// 
// {nil} is the same as {} in Lua.

build_suite('list_argument_with_variables_nullability',
            'list', [Nullable, NonNullable],
            Float, [Nullable, NonNullable],
            [],
            'list', [Nullable, NonNullable],
            Float, [Nullable, NonNullable],
            [nil, box.NULL, [nil], [box.NULL], [value]],
            [nil, box.NULL, [nil], [box.NULL], [default_value]])