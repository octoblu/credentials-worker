MeshbluHttp = require 'meshblu-http'
Credentials = require './credentials'
debug       = require('debug')('credentials-worker:queue-worker')

class QueueWorker
  constructor: ({@client,@meshbluConfig,@timeout}) ->

  run: (callback) =>
    @client.brpop 'request:queue', @timeout, (error,result) =>
      return callback error if error?
      return callback() unless result?

      [queueName, requestStr] = result

      request = JSON.parse requestStr
      {flowId} = request.metadata
      debug 'brpop', request.metadata

      credentials = new Credentials
      credentials.fetch request, (error) =>
        error.flowId = flowId if error?
        meshbluHttp = new MeshbluHttp @meshbluConfig
        message =
          devices: [flowId]
          payload: request.message

        meshbluHttp.message message, callback
        
module.exports = QueueWorker
