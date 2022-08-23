var test = require('unit.js');
var { graphql, buildSchema } = require('graphql');

var rootValue = {
  test: (args) => {
    return args;
  },
}

function PrintResponse(response) {
  console.log(JSON.parse(JSON.stringify(response.data)));
}

var schema = buildSchema(`
  type result {
    arg1: Float
  }

  type Query {
    test(arg1: Float): result
  }
`)

var query = `query MyQuery($var1: Float! = 0)  { test(arg1: $var1)  { arg1 } }`

graphql({
  schema,
  source: query,
  rootValue
}).then(PrintResponse)
