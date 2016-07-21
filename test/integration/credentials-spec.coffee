shmock      = require '@octoblu/shmock'
uuid        = require 'uuid'
RedisNS     = require '@octoblu/redis-ns'
redis       = require 'fakeredis'
JobManager  = require 'meshblu-core-job-manager'
mongojs     = require 'mongojs'
{ObjectId}  = require 'mongojs'
textCrypt  = require '../../src/text-crypt'
QueueWorker = require '../../src/queue-worker'
enableDestroy = require 'server-destroy'

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
    enableDestroy @meshblu
    @redisKey = uuid.v1()

    client = new RedisNS 'credentials', redis.createClient @redisKey
    jobManager = new JobManager client: client, timeoutSeconds: 1
    testClient = new RedisNS 'credentials', redis.createClient @redisKey
    @testJobManager = new JobManager client: testClient, timeoutSeconds: 1
    meshbluConfig =
      uuid: 'credentials-worker-uuid'
      token: 'credentials-worker-token'
      server: 'localhost'
      port: 0xd00d

    @sut = new QueueWorker {meshbluConfig,jobManager,@database}

    @redisClient = new RedisNS 'credentials', redis.createClient @redisKey

  afterEach (done) ->
    @meshblu.destroy done

  describe 'when a user and flow is in the database', ->
    beforeEach (done) ->
      flow =
        flowId: 'flow-uuid'
        resource:
          owner:
            uuid: 'user-uuid'
      @database.flows.insert flow, done

    beforeEach (done) ->
      @token_crypt = textCrypt.encrypt 'github-auth-access-token'
      user =
        resource:
          uuid: 'user-uuid'
        api: [
          authtype: "oauth",
          token_crypt: @token_crypt
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
            nodeId: 'node-uuid'
            toNodeId: 'engine-input'
            transactionId: 'message-uuid'
          rawData: '{}'

        @testJobManager.createRequest 'request', message, done

      beforeEach (done) ->
        workerAuth = new Buffer('credentials-worker-uuid:credentials-worker-token').toString('base64')
        @messageFlow = @meshblu
          .post '/messages'
          .set 'Authorization', "Basic #{workerAuth}"
          .send
            devices: ['flow-uuid']
            payload:
              from: 'node-uuid'
              transactionId: 'message-uuid'
              userApis: [
                authtype: "oauth",
                token_crypt: @token_crypt
                token: 'github-auth-access-token'
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
          nodeId: 'node-uuid'
          toNodeId: 'engine-input'
          transactionId: 'message-uuid'

        rawData: '{}'

      @testJobManager.createRequest 'request', message, done

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
          nodeId: 'node-uuid'
          toNodeId: 'engine-input'
          transactionId: 'message-uuid'
        rawData: '{}'

      @testJobManager.createRequest 'request', message, done

    beforeEach (done) ->
      @sut.run (@error) => done()

    it 'should have an error', ->
      expect(@error.message).to.deep.equal 'Missing user'
