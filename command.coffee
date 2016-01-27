_             = require 'lodash'
commander     = require 'commander'
async         = require 'async'
redis         = require 'redis'
RedisNS       = require '@octoblu/redis-ns'
debug         = require('debug')('credentials-worker:command')
MeshbluConfig = require 'meshblu-config'
JobManager    = require 'meshblu-core-job-manager'
packageJSON   = require './package.json'
QueueWorker   = require './src/queue-worker'

class Command
  parseInt: (str) =>
    parseInt str

  parseOptions: =>
    commander
      .version packageJSON.version
      .option '-n, --namespace <credentials>', 'job handler queue namespace.', 'credentials'
      .option '-s, --single-run', 'perform only one job.'
      .option '-t, --timeout <45>', 'seconds to wait for a next job.', @parseInt, 45
      .option '-db, --database <meshines>', 'database to connect to, can be a full URI or just a database name.', 'meshines'
      .parse process.argv

    {@namespace,@singleRun,@timeout,@database} = commander

    if process.env.CREDENTIALS_NAMESPACE?
      @namespace = process.env.CREDENTIALS_NAMESPACE

    if process.env.CREDENTIALS_SINGLE_RUN?
      @singleRun = process.env.CREDENTIALS_SINGLE_RUN == 'true'

    if process.env.CREDENTIALS_TIMEOUT?
      @timeout = parseInt process.env.CREDENTIALS_TIMEOUT

    if process.env.MONGODB_URI?
      @database = process.env.MONGODB_URI

    if process.env.REDIS_URI
      @redisUri = process.env.REDIS_URI
    else
      @redisUri = 'redis://localhost:6379'

  run: =>
    console.log '[booting up]'
    @parseOptions()
    client = new RedisNS @namespace, redis.createClient @redisUri
    jobManager = new JobManager {client, timeoutSeconds: @timeout}

    process.on 'SIGTERM', => @terminate = true
    return @queueWorkerRun {jobManager, meshbluConfig}, @die if @singleRun
    meshbluConfig = new MeshbluConfig().toJSON()
    async.until @terminated, async.apply(@queueWorkerRun, {jobManager, meshbluConfig}), @die

  terminated: => @terminate

  queueWorkerRun: ({jobManager, meshbluConfig}, callback) =>
    queueWorker = new QueueWorker {jobManager,meshbluConfig,mongoDBUri:@database}

    queueWorker.run (error) =>
      if error?
        console.log "Error flowId: #{error.flowId}"
        console.error error.stack
      process.nextTick callback

  die: (error) =>
    return process.exit(0) unless error?
    console.log "Error flowId: #{error.flowId}" if error.flowId?
    console.error error.stack
    process.exit 1

commandWork = new Command()
commandWork.run()
