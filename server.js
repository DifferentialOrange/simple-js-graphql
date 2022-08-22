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

  var value_str = JSON.stringify(value)

  var query = `query MyQuery { test(arg1: ${value_str}) { arg1 } }`

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

describe('test_nonlist_arguments_nullability', function() {
  it('(1) Argument: T -> Value: value - OK', async function() {
    await BuildTestCase('Float', false, null, null, 1.1111111, null, null, null, null, null);
  });

  it('(2) Argument: T -> Value: nil - OK', async function() {
    await BuildTestCase('Float', false, null, null, null, null, null, null, null, null);
  });

  it('(3) Argument: T -> Value: null - OK', async function() {
    await BuildTestCase('Float', false, null, null, null, null, null, null, null, null);
  });

  it('(4) Argument: T! -> Value: value - OK', async function() {
    await BuildTestCase('Float', true, null, null, 1.1111111, null, null, null, null, null);
  });

  it('(5) Argument: T! -> Value: nil - FAIL', async function() {
    await BuildTestCase('Float', true, null, null, null, null, null, null, null, 'Expected value of type "Float!", found null.');
  });

  it('(6) Argument: T! -> Value: null - FAIL', async function() {
    await BuildTestCase('Float', true, null, null, null, null, null, null, null, 'Expected value of type "Float!", found null.');
  });
});

describe('test_list_arguments_nullability', function() {
  it('(1) Argument: [T] -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', false, 'Float', false, [1.1111111], null, null, null, null, null);
  });

  it('(2) Argument: [T] -> Value: [] - OK', async function() {
    await BuildTestCase('list', false, 'Float', false, [], null, null, null, null, null);
  });

  it('(3) Argument: [T] -> Value: [null] - OK', async function() {
    await BuildTestCase('list', false, 'Float', false, [null], null, null, null, null, null);
  });

  it('(4) Argument: [T] -> Value: nil - OK', async function() {
    await BuildTestCase('list', false, 'Float', false, null, null, null, null, null, null);
  });

  it('(5) Argument: [T] -> Value: null - OK', async function() {
    await BuildTestCase('list', false, 'Float', false, null, null, null, null, null, null);
  });

  it('(6) Argument: [T!] -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', false, 'Float', true, [1.1111111], null, null, null, null, null);
  });

  it('(7) Argument: [T!] -> Value: [] - OK', async function() {
    await BuildTestCase('list', false, 'Float', true, [], null, null, null, null, null);
  });

  it('(8) Argument: [T!] -> Value: [null] - FAIL', async function() {
    await BuildTestCase('list', false, 'Float', true, [null], null, null, null, null, 'Expected value of type "Float!", found null.');
  });

  it('(9) Argument: [T!] -> Value: nil - OK', async function() {
    await BuildTestCase('list', false, 'Float', true, null, null, null, null, null, null);
  });

  it('(10) Argument: [T!] -> Value: null - OK', async function() {
    await BuildTestCase('list', false, 'Float', true, null, null, null, null, null, null);
  });

  it('(11) Argument: [T]! -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', true, 'Float', false, [1.1111111], null, null, null, null, null);
  });

  it('(12) Argument: [T]! -> Value: [] - OK', async function() {
    await BuildTestCase('list', true, 'Float', false, [], null, null, null, null, null);
  });

  it('(13) Argument: [T]! -> Value: [null] - OK', async function() {
    await BuildTestCase('list', true, 'Float', false, [null], null, null, null, null, null);
  });

  it('(14) Argument: [T]! -> Value: nil - FAIL', async function() {
    await BuildTestCase('list', true, 'Float', false, null, null, null, null, null, 'Expected value of type "[Float]!", found null.');
  });

  it('(15) Argument: [T]! -> Value: null - FAIL', async function() {
    await BuildTestCase('list', true, 'Float', false, null, null, null, null, null, 'Expected value of type "[Float]!", found null.');
  });

  it('(16) Argument: [T!]! -> Value: [value(s)] - OK', async function() {
    await BuildTestCase('list', true, 'Float', true, [1.1111111], null, null, null, null, null);
  });

  it('(17) Argument: [T!]! -> Value: [] - OK', async function() {
    await BuildTestCase('list', true, 'Float', true, [], null, null, null, null, null);
  });

  it('(18) Argument: [T!]! -> Value: [null] - FAIL', async function() {
    await BuildTestCase('list', true, 'Float', true, [null], null, null, null, null, 'Expected value of type "Float!", found null.');
  });

  it('(19) Argument: [T!]! -> Value: nil - FAIL', async function() {
    await BuildTestCase('list', true, 'Float', true, null, null, null, null, null, 'Expected value of type "[Float!]!", found null.');
  });

  it('(20) Argument: [T!]! -> Value: null - FAIL', async function() {
    await BuildTestCase('list', true, 'Float', true, null, null, null, null, null, 'Expected value of type "[Float!]!", found null.');
  });
});
