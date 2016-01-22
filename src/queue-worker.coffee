debug           = require('debug')('credentials-worker:queue-worker')

class QueueWorker
  constructor: ({@client,@timeout}) ->

  run: (callback) =>
    @client.brpop 'request:queue', @timeout, (error,result) =>
      return callback error if error?
      return callback() unless result?

      [queueName, requestStr] = result

      request = JSON.parse requestStr
      debug 'brpop', request.metadata

      credentials = new Credentials
      credentials.fetch request, (error) =>
        error.flowId = request.metadata?.flowId if error?
        callback error

module.exports = QueueWorker
