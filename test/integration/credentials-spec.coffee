shmock      = require '@octoblu/shmock'
uuid        = require 'uuid'
RedisNS     = require '@octoblu/redis-ns'
redis       = require 'fakeredis'
mongojs     = require 'mongojs'
{ObjectId}  = require 'mongojs'
QueueWorker = require '../../src/queue-worker'

describe 'Get Credentials', ->
  beforeEach ->
    @mongoDBUri = 'credentials-test-database'
    @database = mongojs @mongoDBUri, ['users', 'flows']

  beforeEach (done) ->
    @database.users.remove => done()

  beforeEach (done) ->
    @database.flows.remove => done()

  beforeEach ->
    @meshblu = shmock 0xd00d
    @redisKey = uuid.v1()

    client = new RedisNS 'credentials', redis.createClient @redisKey

    meshbluConfig =
      uuid: 'credentials-worker-uuid'
      token: 'credentials-worker-token'
      server: 'localhost'
      port: 0xd00d

    @sut = new QueueWorker {meshbluConfig,client,@mongoDBUri,timeout: 1}

    @redisClient = new RedisNS 'credentials', redis.createClient @redisKey

  afterEach (done) ->
    @meshblu.close done

  describe 'when a user and flow is in the database', ->
    beforeEach (done) ->
      flow =
        flowId: 'flow-uuid'
        resource:
          owner:
            uuid: 'user-uuid'
      @database.flows.insert flow, done

    beforeEach (done) ->
      user =
        resource:
          uuid: 'user-uuid'
        api: [
          authtype: "oauth",
          token_crypt: 'github-auth-access-token'
          channelid: ObjectId("532a258a50411e5802cb8053"),
          _id: ObjectId("56a1254b0c6266010001875e"),
          type: "channel:github",
          uuid: "channel-github-uuid"
        ]
      @database.users.insert user, done

    describe 'when a request is in the queue', ->
      beforeEach (done) ->
        message =
          metadata:
            flowId: 'flow-uuid'
            instanceId: 'instance-uuid'
            toNodeId: 'engine-input'
          message: {}

        messageStr = JSON.stringify message
        @redisClient.lpush 'request:queue', messageStr, done

      beforeEach (done) ->
        workerAuth = new Buffer('credentials-worker-uuid:credentials-worker-token').toString('base64')
        @messageFlow = @meshblu
          .post '/messages'
          .set 'Authorization', "Basic #{workerAuth}"
          .send
            devices: ['flow-uuid']
            payload:
              userApi: [
                authtype: "oauth",
                token_crypt: 'github-auth-access-token'
                channelid: "532a258a50411e5802cb8053"
                _id: "56a1254b0c6266010001875e"
                type: "channel:github"
                uuid: "channel-github-uuid"
              ]
          .reply 200
        @sut.run (error) => done error

      it 'should message the flow', ->
        @messageFlow.done()

  describe 'when the flow isn\'t in the database', ->
    beforeEach (done) ->
      message =
        metadata:
          flowId: 'flow-uuid'
          instanceId: 'instance-uuid'
          toNodeId: 'engine-input'
        message: {}

      messageStr = JSON.stringify message
      @redisClient.lpush 'request:queue', messageStr, done

    beforeEach (done) ->
      @sut.run (@error) => done()

    it 'should have an error', ->
      expect(@error.message).to.deep.equal 'Missing flow'

  describe 'when the flow but not user is in the database', ->
    beforeEach (done) ->
      flow =
        flowId: 'flow-uuid'
        resource:
          owner:
            uuid: 'user-uuid'
      @database.flows.insert flow, done

    beforeEach (done) ->
      message =
        metadata:
          flowId: 'flow-uuid'
          instanceId: 'instance-uuid'
          toNodeId: 'engine-input'
        message: {}

      messageStr = JSON.stringify message
      @redisClient.lpush 'request:queue', messageStr, done

    beforeEach (done) ->
      @sut.run (@error) => done()

    it 'should have an error', ->
      expect(@error.message).to.deep.equal 'Missing user'
