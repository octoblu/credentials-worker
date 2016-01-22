shmock      = require '@octoblu/shmock'
uuid        = require 'uuid'
RedisNS     = require '@octoblu/redis-ns'
redis       = require 'fakeredis'
QueueWorker = require '../../src/queue-worker'

describe 'Get Credentials', ->
  beforeEach ->
    @meshblu = shmock 0xd00d
    @redisKey = uuid.v1()

    client = new RedisNS 'credentials', redis.createClient @redisKey

    meshbluConfig =
      server: 'localhost'
      port: 0xd00d

    @sut = new QueueWorker {meshbluConfig, client, timeout: 1}

    @redisClient = new RedisNS 'credentials', redis.createClient @redisKey

  afterEach (done) ->
    @meshblu.close done

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
      @messageFlow = @meshblu
        .post '/messages'
        .send
          devices: ['flow-uuid']
          payload: {}
        .reply 200
      @sut.run (error) => done error

    it 'should message the flow', ->
      @messageFlow.done()
