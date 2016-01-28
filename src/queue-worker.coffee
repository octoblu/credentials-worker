MeshbluHttp = require 'meshblu-http'
Credentials = require './credentials'
debug       = require('debug')('credentials-worker:queue-worker')

class QueueWorker
  constructor: ({@jobManager,@meshbluConfig,@mongoDBUri}) ->
  run: (callback) =>
    debug 'running...'
    @jobManager.getRequest ['request'], (error, result) =>
      debug 'brpop response', error: error, result: result
      return callback error if error?
      return callback() unless result?

      {flowId,nodeId,messageId} = result.metadata

      credentials = new Credentials {@mongoDBUri}
      credentials.fetch flowId, (error, userApis) =>
        error.flowId = flowId if error?
        return callback error if error?
        meshbluHttp = new MeshbluHttp @meshbluConfig
        message =
          devices: [flowId]
          payload:
            from: nodeId
            messageId: messageId
            userApis: userApis
        debug 'sending message', message
        meshbluHttp.message message, callback

module.exports = QueueWorker
