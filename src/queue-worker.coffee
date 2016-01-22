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
      {flowId,nodeId} = request.metadata
      debug 'brpop', request.metadata

      credentials = new Credentials {@mongoDBUri}
      credentials.fetch flowId, (error, userApis) =>
        error.flowId = flowId if error?
        return callback error if error?
        meshbluHttp = new MeshbluHttp @meshbluConfig
        message =
          devices: [flowId]
          payload:
            from: nodeId
            userApis: userApis
        meshbluHttp.message message, callback

module.exports = QueueWorker
