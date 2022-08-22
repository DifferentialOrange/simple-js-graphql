var { graphql, buildSchema } = require('graphql');

var schema = buildSchema(`
  type result {
    arg1: Float!
  }

  type Query {
    test(arg1: Float!): result
  }
`);

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

function BuildTestCase(argument_type, argument_nullability, value) {
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

  console.log(schema_str);
  console.log(query);

  return graphql({
    schema,
    source: query,
    rootValue
  })
}

BuildTestCase('Float', true, 1.1111111).then(PrintResponse);
BuildTestCase('Float', true, null).then(PrintResponse);
