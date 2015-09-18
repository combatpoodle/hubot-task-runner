# Description
#   A hubot script for running distributed tasks
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot hello - <what the respond trigger does>
#   orly - <what the hear trigger does>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Israel Shirk <israelshirk@gmail.com>

_ = require 'lodash'

config =
  environments_file: if process.env.HUBOT_TASK_ENVIRONMENT then process.env.HUBOT_TASK_ENVIRONMENT else '/etc/task-runner/environments.json'
  commands_file: if process.env.HUBOT_TASK_COMMANDS then process.env.HUBOT_TASK_COMMANDS else '/etc/task-runner/commands.json'

module.exports = (robot, TaskRunnerClass, fs) ->
  environments = {}
  commands = {}

  if not fs
    fs = require('fs')

  if not TaskRunnerClass
    TaskRunnerClass = require('task-runner')()

  reloadConfig = ->
    commands = JSON.parse(fs.readFileSync(config.commands_file))
    environments = JSON.parse(fs.readFileSync(config.environments_file))

    # fs.readFile config.environments_file, (err, data) ->
    #   if (err)
    #     throw err
    #   environments = data
    # fs.readFile config.commands_file, (err, data) ->
    #   if (err)
    #     throw err
    #   commands = data

  robot.respond /run ([\w-]+) on ([\w-]+)( with (([\w-]+=[\w-]+)(, |$)*)+)?$/i, (res) ->
    reloadConfig()

    command = res.match[1]
    environment = res.match[2]
    params = res.match[3]

    if not environments[environment]
      res.reply("Unknown environment #{environment}")
      return

    if not commands[command]
      res.reply("Unknown command #{command}")
      return

    if not params
      taskParams = {}
    else
      params = params.replace(/^ with +/i, '')
      params = params.split(', ')

      taskParams = {}

      _.each params, (param) ->
        paramName = param.split('=')[0]
        paramValue = param.split('=').slice(1).join('=')

        taskParams[paramName] = paramValue

    environmentSet = environments[environment]
    commandSet = commands[command]
    communicator = robot

    taskRunner = new TaskRunnerClass(commandSet, environmentSet, taskParams, communicator)
    taskRunner.run()

  robot.hear /orly/, ->
    res.send "yarly"
