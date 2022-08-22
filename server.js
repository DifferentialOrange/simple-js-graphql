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
                       argument_internal_type, argument_internal_nullability,
                       value, error_msg) {
  var argument_str

  var argument_nullability_str
  if (argument_nullability) {
    argument_nullability_str = `!`
  } else {
    argument_nullability_str = ``
  }

  var argument_internal_nullability_str
  if (argument_internal_nullability) {
    argument_internal_nullability_str = `!`
  } else {
    argument_internal_nullability_str = ``
  }

  if (argument_type == 'list') {
    argument_str = `[${argument_internal_type}${argument_internal_nullability_str}]${argument_nullability_str}`
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

  var value_str
  if (value === null) {
    value_str = 'null'
  } else {
    value_str = value.toString()
  }

  var query = `{ test(arg1: ${value_str}) { arg1 } }`

  // console.log(schema_str);
  // console.log(query);

  graphql({
    schema,
    source: query,
    rootValue
  }).then((response) => {
    if (error_msg != null) {
      test.assert.deepEqual(response.errors[0].message, error_msg)
    } else {
      test.assert.deepEqual(response.data.test.arg1, value)
    }
  });

  console.log('OK');
}

console.log('test_nonlist_arguments_nullability');
// (1) Argument: T -> Value: value - OK
BuildTestCase('Float', false, null, null, 1.1111111, null);
// (2) Argument: T -> Value: nil - OK
// (3) Argument: T -> Value: null - OK
BuildTestCase('Float', false, null, null, null, null);
// (4) Argument: T! -> Value: value - OK
BuildTestCase('Float', true, null, null, 1.1111111, null);
// (5) Argument: T! -> Value: nil - FAIL
// (6) Argument: T! -> Value: null - FAIL
BuildTestCase('Float', true, null, null, null, 'Expected value of type "Float!", found null.');

console.log('test_nonlist_arguments_nullability');
// (1) Argument: [T] -> Value: [value(s)] - OK
BuildTestCase('list', false, 'Float', false, [1.1111111], null);
