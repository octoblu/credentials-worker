_       = require 'lodash'
mongojs = require 'mongojs'
textCrypt = require './text-crypt'

class Credentials
  constructor: ({@mongoDBUri}) ->
    @database = mongojs @mongoDBUri, ['users', 'flows']

  getUserUuidByFlow: (flowId, callback) =>
    @database.flows.findOne flowId: flowId, (error, flow) =>
      return callback error if error?
      return callback new Error 'Missing flow' unless flow?
      callback null, _.get flow, 'resource.owner.uuid'

  getUserApi: (userUuid, callback) =>
    @database.users.findOne 'resource.uuid': userUuid, (error, user) =>
      return callback error if error?
      return callback new Error 'Missing user' unless user?
      callback null, _.get user, 'api'

  fetch: (flowId, callback) =>
    @getUserUuidByFlow flowId, (error, userUuid) =>
      return callback error if error?
      @getUserApi userUuid, (error, userApis) =>
        return callback error if error?
        callback null, @decrypt userApis

  decrypt: (userApis, callback) =>
    _.map userApis, (userApi) =>
      if userApi.token_crypt
        userApi.token  = textCrypt.decrypt userApi.token_crypt
      if userApi.secret_crypt
        userApi.secret = textCrypt.decrypt userApi.secret_crypt
      if userApi.refreshToken_crypt
        userApi.refreshToken = textCrypt.decrypt userApi.refreshToken_crypt
      return userApi

module.exports = Credentials
