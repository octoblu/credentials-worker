MeshbluHttp = require 'meshblu-http'
Credentials = require './credentials'
debug       = require('debug')('credentials-worker:queue-worker')

class QueueWorker
  constructor: ({@jobManager,@meshbluConfig,@database}) ->
  run: (callback) =>
    @jobManager.getRequest ['request'], (error, result) =>
      return callback error if error?
      return callback() unless result?

      {flowId,nodeId,transactionId} = result.metadata

      credentials = new Credentials {@database}
      credentials.fetch flowId, (error, userApis) =>
        error.flowId = flowId if error?
        return callback error if error?
        meshbluHttp = new MeshbluHttp @meshbluConfig
        message =
          devices: [flowId]
          payload:
            from: nodeId
            transactionId: transactionId
            userApis: userApis
        debug 'sending message', JSON.stringify(message)
        meshbluHttp.message message, callback

module.exports = QueueWorker
