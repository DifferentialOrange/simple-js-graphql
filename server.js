var assert = require('assert');
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

function BuildTestCase(argument_type, argument_nullability, value, error_msg) {
  var argument_str

  if (argument_nullability) {
    argument_str = `${argument_type}!`
  } else {
    argument_str = argument_type
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
      assert.equal(response.errors[0].message, error_msg)
    } else {
      assert.equal(response.data.test.arg1, value)
    }
  });

  console.log('OK');
}

BuildTestCase('Float', true, 1.1111111, null);
BuildTestCase('Float', true, null, 'Expected value of type "Float!", found null.');
