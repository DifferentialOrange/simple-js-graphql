var test = require('unit.js');
var { graphql, buildSchema } = require('graphql');

var rootValue = {
  test: (args) => {
    return args;
  },
}

var i = 1

function PrintResponse(response) {
  console.log(i)

  i = i + 1

  if (response.hasOwnProperty('data')) {
    console.log(JSON.parse(JSON.stringify(response.data)))
  }

  if (response.hasOwnProperty('errors')) {
    console.log(JSON.parse(JSON.stringify(response.errors)))
  }
}

var schema = buildSchema(`
  type result {
    arg1: Float!
  }

  type Query {
    test(arg1: Float!): result!
  }
`)

var query = `query MyQuery($var1: Float = 0)  { test(arg1: $var1)  { arg1 } }`

graphql({
  schema,
  source: query,
  rootValue,
  variableValues: { var1: null}
}).then(PrintResponse)

graphql({
  schema,
  source: query,
  rootValue,
}).then(PrintResponse)
