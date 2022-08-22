var test = require('unit.js');
var { graphql, buildSchema } = require('graphql');

var rootValue = {
  test: (args) => {
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

function BuildTestCase(argument_type, argument_nullability,
                       argument_inner_type, argument_inner_nullability,
                       value,
                       variable_nullability, variable_inner_type,
                       variable_inner_nullability, default_variable_value,
                       error_msg) {
  var argument_str

  var argument_nullability_str
  if (argument_nullability) {
    argument_nullability_str = `!`
  } else {
    argument_nullability_str = ``
  }

  var argument_inner_nullability_str
  if (argument_inner_nullability) {
    argument_inner_nullability_str = `!`
  } else {
    argument_inner_nullability_str = ``
  }

  if (argument_type == 'list') {
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

  var value_str = JSON.stringify(value)

  var query
  if (variable_nullability != null) {
    var variable_str

    var variable_nullability_str
    if (variable_nullability) {
      variable_nullability_str = `!`
    } else {
      variable_nullability_str = ``
    }

    var variable_inner_nullability_str
    if (variable_inner_nullability) {
      variable_inner_nullability_str = `!`
    } else {
      variable_inner_nullability_str = ``
    }

    if (argument_type == 'list') {
      variable_str = `[${variable_inner_type}${variable_inner_nullability_str}]${variable_nullability_str}`
    } else {
      variable_str = `${argument_type}${variable_nullability_str}`
    }

    var default_str
    if (default_variable_value != null) {
      default_str = ` = ${default_variable_value}`
    }

    var query_v1 = `query MyQuery($var1: ${variable_str}${default_str}) { test(arg1: $var1) { arg1 } }`

    query = JSON.stringify({
      query_v1,
      variables: { value_str },
    })
  } else {
    query = `query MyQuery { test(arg1: ${value_str}) { arg1 } }`
  }

  // console.log(schema_str);
  // console.log(query);

  return graphql({
    schema,
    source: query,
    rootValue
  }).then((response) => {
    if (error_msg != null) {
      test.assert.deepEqual(response.errors[0].message, error_msg)
    } else {
      test.assert.equal(response.hasOwnProperty('errors'), false, response.errors)
      test.assert.deepEqual(response.data.test.arg1, value)
    }
  });
}

var k = 'Float'
var Nullable = false
var NonNullable = true
var v = {value: 1.1111111}
var box = {NULL: null}
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
    await BuildTestCase('list', NonNullable, k, Nullable, [nil], nil, nil, nil, nil, nil);
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

// describe('test_nonlist_arguments_with_variables_nullability', function() {
//   it('(1) Argument: T -> Value: value - OK', async function() {
//     await BuildTestCase(k, Nullable, nil, nil, v.value, Nullable, nil, nil, v.default, nil);
//   });
// });
