MeshbluHttp = require 'meshblu-http'
Credentials = require './credentials'
debug       = require('debug')('credentials-worker:queue-worker')

class QueueWorker
  constructor: ({@client,@meshbluConfig,@timeout,@mongoDBUri}) ->

  run: (callback) =>
    @client.brpop 'request:queue', @timeout, (error,result) =>
      return callback error if error?
      return callback() unless result?

      [queueName, requestStr] = result

      request = JSON.parse requestStr
      {flowId} = request.metadata
      debug 'brpop', request.metadata

      credentials = new Credentials {@mongoDBUri}
      credentials.fetch flowId, (error, userApi) =>
        error.flowId = flowId if error?
        return callback error if error?
        meshbluHttp = new MeshbluHttp @meshbluConfig
        message =
          devices: [flowId]
          payload:
            userApi: userApi
        meshbluHttp.message message, callback

module.exports = QueueWorker
