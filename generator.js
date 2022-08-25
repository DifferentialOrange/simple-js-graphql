var { graphql, buildSchema } = require('graphql');

var nil = 'nil'
var box = {NULL: 'box.NULL'}

var argument_type = 'Float'
var value = 1.11111
var Nullable = true
var NonNullable = false

function build_schema(argument_type, argument_nullability, argument_value) {
  var argument_nullability_str = ``
  if (argument_nullability == NonNullable) {
    argument_nullability_str = `!`
  }

  // var argument_inner_nullability_str = ``
  // if (argument_inner_nullability) {
  //   argument_inner_nullability_str = `!`
  // }

  // if (argument_type === 'list') {
  //   argument_str = `[${argument_inner_type}${argument_inner_nullability_str}]${argument_nullability_str}`
  // } else {
    var argument_str = `${argument_type}${argument_nullability_str}`
  // }

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

function build_query(argument_type, argument_nullability, argument_value) {
    if ((argument_value == nil) || (argument_value == box.NULL)) {
        return `query MyQuery { test(arg1: null) { arg1 } }`
    } else {
        return `query MyQuery { test(arg1: ${argument_value}) { arg1 } }`
    }
};

var rootValue = {
    test: (args) => {
        // console.log(args)
        return args;
    },
};


console.log(`
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

local function gen_schema(argument_type, argument_nullability)
    local type
    if argument_nullability == NonNullable then
        type = types.nonNull(graphql_types[argument_type].graphql_type)
    else
        type = graphql_types[argument_type].graphql_type
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

`)

// == Non-list argument nullability ==
// 
// There is no way pass no value to the argument
// since `test(arg1)` is invalid syntax.
// We use `test(arg1: null)` for both nil and box.NULL,
// so the behavior will be the same for them.

var case_1_body_arr = []

var argument_nullabilities = [Nullable, NonNullable]
var argument_values = [nil, box.NULL, value]

var i = 0

var promises = []

argument_nullabilities.forEach( function (argument_nullability) {
    argument_values.forEach( function (argument_value)  {
        var schema = build_schema(argument_type, argument_nullability, argument_value)
        var query = build_query(argument_type, argument_nullability, argument_value)
        
        promises.push(graphql({
            schema,
            source: query,
            rootValue,
        }).then((response) => {
            var expected_data = `nil`

            if (response.hasOwnProperty('data')) {
                var _expected_data = JSON.stringify(response.data)
                expected_data = `"${_expected_data}"`
            }

            var expected_error = `nil`

            if (response.hasOwnProperty('errors')) {
                var _expected_error = JSON.stringify(response.errors[0].message)
                expected_error = `"${_expected_error}"`
            }

            i = i + 1

            console.log(`
g.test_nonlist_argument_nullability_${argument_type}_${i} = function()
    local argument_type = "${argument_type}"
    local argument_nullability = ${argument_nullability}
    local argument_value = ${argument_value}
    local schema = build_schema(argument_type, argument_nullability, argument_value)
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
    t.assert_equals(result, expected_error_json)
end

`)
        }))
    })
});

// console.log(promises)

// async function final() {
//     output_file = output_file
//     promises.forEach( async function (promise) {
//         let res = await promise
//         output_file += res
//     })

//     const fs = require('fs')

//     fs.writeFile('./fuzzing_test.lua', output_file, err => {
//       if (err) {
//         console.error(err)
//         return
//       }
//     })
// }

// final()
