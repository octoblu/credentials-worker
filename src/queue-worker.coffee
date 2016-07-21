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
      credentials.fetch flowId, (fetchError, userApis) =>
        fetchError.flowId = flowId if fetchError?
        # make sure the message always gets sent back
        # even if error
        meshbluHttp = new MeshbluHttp @meshbluConfig
        message =
          devices: [flowId]
          payload:
            from: nodeId
            transactionId: transactionId
            userApis: userApis
            error: fetchError?.message
        debug 'sending message', JSON.stringify(message)
        meshbluHttp.message message, (error) =>
          return callback error if error?
          callback fetchError

module.exports = QueueWorker
