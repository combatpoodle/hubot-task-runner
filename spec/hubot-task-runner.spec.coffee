describe 'hubot-task-runner', ->
  taskRunner = undefined
  responders = undefined
  runTaskCallback = undefined
  runTaskMatcher = undefined
  filesystem = undefined

  environments = {
    "dev": ['web1', 'web2', 'ni1', 'mqm', 'mqs'],
    "staging": ['staging-box1', 'staging-box2', 'staging-box3', 'staging-box4'],
    "production": ['production-box1', 'production-box2', 'production-box3', 'production-box4']
  }

  commands = {
    "puppet-apply": [
      { name: "stop web UI", command: "stop-web-ui", only: ["web"], environment: "should_be_overridden" },
      { name: "stop messaging services", command: "stop-messaging", only: ["worker"] },
      { name: "stop slave broker", command: "stop-slave-broker", only: ["slave-broker"] },
      { name: "stop master broker", command: "stop-master-broker", only: ["master-broker"] },
      { name: "run puppet-apply", command: "puppet-apply", only: ["all"] },
      { name: "start master message broker", command: "start-master-broker", only: ["master-broker"] },
      { name: "start slave message broker", command: "start-slave-broker", only: ["slave-broker"] },
      { name: "start messaging services", command: "start-messaging", only: ["worker"] },
      { name: "start web UI", command: "start-web-ui", only: ["web"] },
    ]
  }

  beforeEach ->
    taskRunner = undefined
    runTaskCallback = undefined
    runTaskMatcher = undefined
    responders = []
    filesystem = {
      '/etc/task-runner/environments.json': JSON.stringify(environments),
      '/etc/task-runner/commands.json': JSON.stringify(commands)
    }

    @robot =
      respond: (matcher, callback) ->
        responders.push([matcher, callback])

        if (matcher.toString().match(/run .*/g))
          runTaskCallback = callback
          runTaskMatcher = matcher

      hear: ->

    spyOn(@robot, "respond").and.callThrough()
    spyOn(@robot, "hear").and.callThrough()

    class TaskRunnerMock
      constructor: (commandSet, clientSet, taskParams, communicator) ->
        @commandSet = commandSet
        @clientSet = clientSet
        @taskParams = taskParams
        @communicator = communicator

        @run = () ->

        spyOn(@, "run").and.callThrough()

        taskRunner = @

      run: () ->

    fsMock =
      readFileSync: (path) ->
        if filesystem[path] == undefined
          throw new Error("File #{path} not found")

        return filesystem[path]

      lstatSync: (path) ->
        if filesystem[path] == undefined
          throw new Error("File #{path} not found")

        return { dev: 2114, ino: 48064969, mode: 33188, nlink: 1, uid: 85, gid: 100, rdev: 0, size: 527, blksize: 4096, blocks: 8, atime: new Date("Mon, 10 Oct 2011 23:24:11 GMT"), mtime: new Date("Mon, 10 Oct 2011 23:24:11 GMT"), ctime: new Date("Mon, 10 Oct 2011 23:24:11 GMT"), birthtime: new Date("Mon, 10 Oct 2011 23:24:11 GMT") }

    require('../src/hubot-task-runner')(@robot, TaskRunnerMock, fsMock)

  it 'registers a respond listener', ->
    expect(@robot.respond).toHaveBeenCalled()
    regex = @robot.respond.calls.first().args[0]

    expect(regex.toString()).toMatch(/run .*/g)

  shouldMatch = (string, regexp, matches) ->
    result = string.match(regexp)

    expect(result).not.toEqual(null)
    expect(result[0]).not.toEqual('')

  shouldNotMatch = (string, regexp) ->
    result = string.match(regexp)

    if (result == null)
      return

    if (result[0] == '')
      return

    expect(result).toEqual(null)

  it 'responds to the regexes right', ->
    regex = @robot.respond.calls.first().args[0]

    shouldMatch("run stuff on staging", regex)
    shouldMatch("run stuff on staging with a=b, c=d, e=f", regex)
    shouldNotMatch("run stuff", regex)
    shouldNotMatch("run stuff on $%%@", regex)
    shouldNotMatch("cats are not evil")
    shouldNotMatch("run stuff on staging with ")
    shouldNotMatch("run stuff on test with c, b=d")

  it 'sets up and runs the task runner on getting a command', ->
    callCommand = "run puppet-apply on staging with a=b, c=d"

    res =
      send: (content) ->
        console.error "send", content
      match: callCommand.match(runTaskMatcher)
      reply: (content) ->
        console.error "reply", content

    spyOn(res, "reply").and.callThrough()
    spyOn(res, "send").and.callThrough()

    runTaskCallback(res)

    expect(res.send).not.toHaveBeenCalled()
    expect(res.reply).not.toHaveBeenCalled()

    expect(taskRunner.commandSet).toEqual(commands['puppet-apply'])
    expect(taskRunner.clientSet).toEqual(environments["staging"])
    expect(taskRunner.taskParams).toEqual({"a": "b", "c": "d"})
    expect(taskRunner.communicator).toEqual(@robot)

    expect(taskRunner.run).toHaveBeenCalled()
