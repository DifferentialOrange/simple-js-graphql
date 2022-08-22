var test = require('unit.js');
var { graphql, buildSchema } = require('graphql');

var rootValue = {
  test: (args) => {
    // console.log(args)
    return args;
  },
};


function PrintResponse(response) {
  if (response.hasOwnProperty('data')) {
    console.log(JSON.parse(JSON.stringify(response.data)));
  }
  if (response.hasOwnProperty('errors')) {
    console.log(response.errors);
  }
}

var box = {NULL: 'null'}

function transform_value(v) {
  if (v === box.NULL) {
    return null
  }

  if (Array.isArray(v) && v.length > 0) {
    if (v[0] === box.NULL) {
      return [null]
    } else if (v[0] === null) { // Lua {nil} is {}
      return []
    }
  }

  return v
};

function BuildTestCase(argument_type, argument_nullability,
                       argument_inner_type, argument_inner_nullability,
                       value,
                       variable_nullability, variable_inner_type,
                       variable_inner_nullability, default_variable_value,
                       error_msg) {
  var argument_str

  var argument_nullability_str = ``
  if (argument_nullability) {
    argument_nullability_str = `!`
  }

  var argument_inner_nullability_str = ``
  if (argument_inner_nullability) {
    argument_inner_nullability_str = `!`
  }

  if (argument_type === 'list') {
    argument_str = `[${argument_inner_type}${argument_inner_nullability_str}]${argument_nullability_str}`
  } else {
    argument_str = `${argument_type}${argument_nullability_str}`
  }

  var schema_str = `
    type result {
      arg1: ${argument_str}
    }

    type Query {
      test(arg1: ${argument_str}): result
    }
  `

  var schema = buildSchema(schema_str);

  var value_str = `null`
  if ((value !== null) && (value !== box.NULL)) {
    value_str = JSON.stringify(transform_value(value))
  }
   
  var query
  var variables = []
  if (variable_nullability !== null) {
    var variable_str

    var variable_nullability_str = ``
    if (variable_nullability) {
      variable_nullability_str = `!`
    }

    var variable_inner_nullability_str = ``
    if (variable_inner_nullability) {
      variable_inner_nullability_str = `!`
    }

    if (argument_type === 'list') {
      variable_str = `[${variable_inner_type}${variable_inner_nullability_str}]${variable_nullability_str}`
    } else {
      variable_str = `${argument_type}${variable_nullability_str}`
    }

    var default_str = ``
    if (default_variable_value !== null) {
      var def_prestr = transform_value(default_variable_value)
      default_str = ` = ${def_prestr}`
    }

    query = `query MyQuery($var1: ${variable_str}${default_str}) { test(arg1: $var1) { arg1 } }`

    if (value !== null) {
      if (value === box.NULL) {
        variables = {var1: null}
      } else {
        variables = {var1: value}
      }
    }
  } else {
    query = `query MyQuery { test(arg1: ${value_str}) { arg1 } }`
  }

  console.log(schema_str);
  console.log(value);
  // console.log(value !== null);
  // console.log(value !== box.NULL);
  // console.log(value.hasOwnProperty('isArray'));
  // console.log(value.isArray());
  // console.log(value.length);
  console.log(query);
  console.log(variables);

  return graphql({
    schema,
    source: query,
    rootValue,
    variableValues: variables
  }).then((response) => {
    if (error_msg !== null) {
      if (response.hasOwnProperty('data')) {
        console.log(JSON.parse(JSON.stringify(response.data)))
        test.fail('Data got when error expected')
      }
      test.assert.deepEqual(response.errors[0].message, error_msg)
    } else {
      if (response.hasOwnProperty('errors')) {
        console.log(JSON.parse(JSON.stringify(response.errors)))
        test.fail('Errors got when data expected')
      }

      if ((default_variable_value !== null) && (value === null)) {
        test.assert.deepEqual(response.data.test.arg1, transform_value(default_variable_value))
      } else {
        test.assert.deepEqual(response.data.test.arg1, transform_value(value))
      }
    }
  });
}

var k = 'Float'
var Nullable = false
var NonNullable = true
var v = {value: 1.1111111, default: 0}
var nil = null

describe('test_nonlist_arguments_nullability', function() {
  it('(1) Argument: T -> Value: value - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, nil, nil, nil, nil, nil);
  });

  it('(2) Argument: T -> Value: nil - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, nil, nil, nil, nil, nil);
  });

  it('(3) Argument: T -> Value: null - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, nil, nil, nil, nil, nil);
  });

  it('(4) Argument: T! -> Value: value - OK', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, nil, nil, nil, nil, nil);
  });

  it('(5) Argument: T! -> Value: nil - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, nil, nil, nil, nil, 'Expected value of type "Float!", found null.');
  });

  it('(6) Argument: T! -> Value: null - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, nil, nil, nil, nil, 'Expected value of type "Float!", found null.');
  });
});

describe('test_list_arguments_nullability', function() {
  it('(1) Argument: [T] -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', Nullable, k, Nullable, [v.value], nil, nil, nil, nil, nil);
  });

  it('(2) Argument: [T] -> Value: [] - OK', async function() {
    await BuildTestCase('list', Nullable, k, Nullable, [], nil, nil, nil, nil, nil);
  });

  it('(3) Argument: [T] -> Value: [null] - OK', async function() {
    await BuildTestCase('list', Nullable, k, Nullable, [box.NULL], nil, nil, nil, nil, nil);
  });

  it('(4) Argument: [T] -> Value: nil - OK', async function() {
    await BuildTestCase('list', Nullable, k, Nullable, nil, nil, nil, nil, nil, nil);
  });

  it('(5) Argument: [T] -> Value: null - OK', async function() {
    await BuildTestCase('list', Nullable, k, Nullable, box.NULL, nil, nil, nil, nil, nil);
  });

  it('(6) Argument: [T!] -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', Nullable, k, NonNullable, [v.value], nil, nil, nil, nil, nil);
  });

  it('(7) Argument: [T!] -> Value: [] - OK', async function() {
    await BuildTestCase('list', Nullable, k, NonNullable, [], nil, nil, nil, nil, nil);
  });

  it('(8) Argument: [T!] -> Value: [null] - FAIL', async function() {
    await BuildTestCase('list', Nullable, k, NonNullable, [box.NULL], nil, nil, nil, nil, 'Expected value of type "Float!", found null.');
  });

  it('(9) Argument: [T!] -> Value: nil - OK', async function() {
    await BuildTestCase('list', Nullable, k, NonNullable, nil, nil, nil, nil, nil, nil);
  });

  it('(10) Argument: [T!] -> Value: null - OK', async function() {
    await BuildTestCase('list', Nullable, k, NonNullable, box.NULL, nil, nil, nil, nil, nil);
  });

  it('(11) Argument: [T]! -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', NonNullable, k, Nullable, [v.value], nil, nil, nil, nil, nil);
  });

  it('(12) Argument: [T]! -> Value: [] - OK', async function() {
    await BuildTestCase('list', NonNullable, k, Nullable, [], nil, nil, nil, nil, nil);
  });

  it('(13) Argument: [T]! -> Value: [null] - OK', async function() {
    await BuildTestCase('list', NonNullable, k, Nullable, [box.NULL], nil, nil, nil, nil, nil);
  });

  it('(14) Argument: [T]! -> Value: nil - FAIL', async function() {
    await BuildTestCase('list', NonNullable, k, Nullable, nil, nil, nil, nil, nil, 'Expected value of type "[Float]!", found null.');
  });

  it('(15) Argument: [T]! -> Value: null - FAIL', async function() {
    await BuildTestCase('list', NonNullable, k, Nullable, box.NULL, nil, nil, nil, nil, 'Expected value of type "[Float]!", found null.');
  });

  it('(16) Argument: [T!]! -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', NonNullable, k, NonNullable, [v.value], nil, nil, nil, nil, nil);
  });

  it('(17) Argument: [T!]! -> Value: [] - OK', async function() {
    await BuildTestCase('list', NonNullable, k, NonNullable, [], nil, nil, nil, nil, nil);
  });

  it('(18) Argument: [T!]! -> Value: [null] - FAIL', async function() {
    await BuildTestCase('list', NonNullable, k, NonNullable, [box.NULL], nil, nil, nil, nil, 'Expected value of type "Float!", found null.');
  });

  it('(19) Argument: [T!]! -> Value: nil - FAIL', async function() {
    await BuildTestCase('list', NonNullable, k, NonNullable, nil, nil, nil, nil, nil, 'Expected value of type "[Float!]!", found null.');
  });

  it('(20) Argument: [T!]! -> Value: null - FAIL', async function() {
    await BuildTestCase('list', NonNullable, k, NonNullable, box.NULL, nil, nil, nil, nil, 'Expected value of type "[Float!]!", found null.');
  });
});

describe('test_nonlist_arguments_with_variables_nullability', function() {
  it('(1) Argument: T -> Variable: T -> Value: value -> Default: value - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, Nullable, nil, nil, v.default, nil);
  });

  it('(2) Argument: T -> Variable: T -> Value: value -> Default: nil - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, Nullable, nil, nil, nil, nil);
  });

  it('(3) Argument: T -> Variable: T -> Value: value -> Default: null - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, Nullable, nil, nil, box.NULL, nil);
  });

  it('(4) Argument: T -> Variable: T -> Value: nil -> Default: value - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, Nullable, nil, nil, v.default, nil);
  });

  it('(5) Argument: T -> Variable: T -> Value: nil -> Default: nil - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, Nullable, nil, nil, nil, nil);
  });

  it('(6) Argument: T -> Variable: T -> Value: nil -> Default: null - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, Nullable, nil, nil, box.NULL, nil);
  });

  it('(7) Argument: T -> Variable: T -> Value: null -> Default: value - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, Nullable, nil, nil, v.default, nil);
  });

  it('(8) Argument: T -> Variable: T -> Value: null -> Default: nil - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, Nullable, nil, nil, nil, nil);
  });

  it('(9) Argument: T -> Variable: T -> Value: null -> Default: null - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, Nullable, nil, nil, box.NULL, nil);
  });

  it('(10) Argument: T -> Variable: T! -> Value: value -> Default: value - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, NonNullable, nil, nil, v.default, 'Non-null variables can not have default values');
  });

  it('(11) Argument: T -> Variable: T! -> Value: value -> Default: nil - OK', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, NonNullable, nil, nil, nil, nil);
  });

  it('(12) Argument: T -> Variable: T! -> Value: value -> Default: null - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, v.value, NonNullable, nil, nil, box.NULL, 'Non-null variables can not have default values');
  });

  it('(13) Argument: T -> Variable: T! -> Value: nil -> Default: value - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, NonNullable, nil, nil, v.default, 'Non-null variables can not have default values');
  });

  it('(14) Argument: T -> Variable: T! -> Value: nil -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, NonNullable, nil, nil, nil, 'Variable "var1" expected to be non-null');
  });

  it('(15) Argument: T -> Variable: T! -> Value: nil -> Default: null - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, nil, NonNullable, nil, nil, box.NULL, 'Non-null variables can not have default values');
  });

  it('(16) Argument: T -> Variable: T! -> Value: null -> Default: value - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, NonNullable, nil, nil, v.default, 'Non-null variables can not have default values');
  });

  it('(17) Argument: T -> Variable: T! -> Value: null -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, NonNullable, nil, nil, nil, 'Variable "var1" expected to be non-null');
  });

  it('(18) Argument: T -> Variable: T! -> Value: null -> Default: null - FAIL', async function() {
    await BuildTestCase(k, Nullable, nil, nil, box.NULL, NonNullable, nil, nil, box.NULL, 'Non-null variables can not have default values');
  });

  it('(19) Argument: T! -> Variable: T -> Value: value -> Default: value - OK', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, Nullable, nil, nil, v.default, nil);
  });

  it('(20) Argument: T! -> Variable: T -> Value: value -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, Nullable, nil, nil, nil, 'Variable "var1" type mismatch: the variable type "" is not compatible with the argument type "NonNull()"');
  });

  it('(21) Argument: T! -> Variable: T -> Value: value -> Default: null - OK', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, Nullable, nil, nil, box.NULL, nil);
  });

  it('(22) Argument: T! -> Variable: T -> Value: nil -> Default: value - OK', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, Nullable, nil, nil, v.default, nil);
  });

  it('(23) Argument: T! -> Variable: T -> Value: nil -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, Nullable, nil, nil, nil, 'Variable "var1" type mismatch: the variable type ""is not compatible with the argument type "NonNull()"');
  });

  it('(24) Argument: T! -> Variable: T -> Value: nil -> Default: null - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, Nullable, nil, nil, box.NULL, 'Expected non-null for "NonNull()", got null');
  });

  it('(25) Argument: T! -> Variable: T -> Value: null -> Default: value - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, Nullable, nil, nil, v.default, 'Expected non-null for "NonNull()", got null');
  });

  it('(26) Argument: T! -> Variable: T -> Value: null -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, Nullable, nil, nil, nil, 'Variable "var1" type mismatch: the variable type ""is not compatible with the argument type "NonNull()"');
  });

  it('(27) Argument: T! -> Variable: T -> Value: null -> Default: null - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, Nullable, nil, nil, box.NULL, 'Expected non-null for "NonNull()", got null');
  });

  it('(28) Argument: T! -> Variable: T! -> Value: value -> Default: value - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, NonNullable, nil, nil, v.default, 'Non-null variables can not have default values');
  });

  it('(29) Argument: T! -> Variable: T! -> Value: value -> Default: nil - OK', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, NonNullable, nil, nil, nil, nil);
  });

  it('(30) Argument: T! -> Variable: T! -> Value: value -> Default: null - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, v.value, NonNullable, nil, nil, box.NULL, 'Non-null variables can not have default values');
  });

  it('(31) Argument: T! -> Variable: T! -> Value: nil -> Default: value - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, NonNullable, nil, nil, v.default, 'Non-null variables can not have default values');
  });

  it('(32) Argument: T! -> Variable: T! -> Value: nil -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, NonNullable, nil, nil, nil, 'Variable "var1" expected to be non-null');
  });

  it('(33) Argument: T! -> Variable: T! -> Value: nil -> Default: null - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, nil, NonNullable, nil, nil, box.NULL, 'Non-null variables can not have default values');
  });

  it('(34) Argument: T! -> Variable: T! -> Value: null -> Default: value - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, NonNullable, nil, nil, v.default, 'Non-null variables can not have default values');
  });

  it('(35) Argument: T! -> Variable: T! -> Value: null -> Default: nil - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, NonNullable, nil, nil, nil, 'Variable "var1" expected to be non-null');
  });

  it('(36) Argument: T! -> Variable: T! -> Value: null -> Default: null - FAIL', async function() {
    await BuildTestCase(k, NonNullable, nil, nil, box.NULL, NonNullable, nil, nil, box.NULL, 'Non-null variables can not have default values');
  });
});
