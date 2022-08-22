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

graphql({
  schema,
  source: '{ test(arg1: 1.1111111)  { arg1 } }',
  rootValue
}).then(PrintResponse);

graphql({
  schema,
  source: '{ test(arg1: null)  { arg1 } }',
  rootValue
}).then(PrintResponse);
