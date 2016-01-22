_             = require 'lodash'
redis         = require 'redis'
RedisNS       = require '@octoblu/redis-ns'

class Command
  constructor: ->
    @serverOptions =
      port          : process.env.PORT || 80
      disableLogging: process.env.DISABLE_LOGGING == "true"

    @redisUri = process.env.REDIS_URI

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    # Use this to require env
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @redisUri

    redisClient = redis.createClient process.env.REDIS_URI
    client = new RedisNS 'credentials', redisClient

command = new Command()
command.run()
