# Description:
#   Control your Philips Hue Lights from HUBOT! BAM, easy candy for the kids
#
# Dependencies:
#
# Configuration:
# This script is dependent on environment variables:
#   PHILIPS_HUE_HASH : export PHILIPS_HUE_HASH="secrets"
#   PHILIPS_HUE_IP : export PHILIPS_HUE_IP="xxx.xxx.xxx.xxx"
#
# Setting your Hue Hash
#
# This needs to be done once, it seems older versions of the Hue bridge used an md5 hash as a 'username' but now you can use anything.
#
# Make an HTTP POST request of the following to http://YourHueHub/api
#
# {"username": "YourHash", "devicetype": "YourAppName"}
# If you have not pressed the button on the Hue Hub you will receive an error like this;
#
# {"error":{"type":101,"address":"/","description":"link button not pressed"}}
# Press the link button on the hub and try again and you should receive;
#
# {"success":{"username":"YourHash"}}
# The key above will be the username you sent, remember this, you'll need it in all future requests
#
# ie: curl -v -H "Content-Type: application/json" -X POST 'http://YourHueHub/api' -d '{"username": "YourHash", "devicetype": "YourAppName"}'
#
# Dependencies:
#   "node-hue-api": "^1.0.5"
#
# Commands:
#   hubot hue lights - list all lights
#   hubot hue light <light number>  - shows light status
#   hubot hue turn light <light number> <on|off> - flips the switch
#   hubot hue groups - groups lights together to control with one API call
#   hubot hue config - reads bridge config
#   hubot hue hash - get a hash code (press the link button)
#   hubot hue linkbutton - programatically press the link button
#   hubot hue (alert|alerts) light <light number> - blink once or blink for 10 seconds specific light
#   hubot hue hsb light <light number> <hue 0-65535> <saturation 0-254> <brightness 0-254>
#   hubot hue xy light <light number> <x 0.0-1.0> <y 0.0-1.0>
#   hubot hue ct light <light number> <color temp 153-500>
#   hubot hue group <group name>=[<comma separated list of light indexes>]
#   hubot hue ls groups - lists the groups of lights
#   hubot hue rm group <group name> - remove grouping of lights named <group name>
#   hubot hue @<group id> off - turn all lights in <group name> off
#   hubot hue @<group id> on - turn all lights in <group name> on
#   hubot hue @<group id> hsb=(<hue>,<sat>,<bri>) - set hsb value for all lights in group
#   hubot hue @<group id> xy=(<x>,<y>) - set x, y value for all lights in group
#   hubot hue @<group id> ct=<color temp> - set color temp for all lights in group
#   hubot hue @<group id> white <white temp> - set to white in temp (150 - 500) (also stops the loop)
#   hubot hue @<group id> loop - loop through colors
#   :standup: - alert the lights in group 1
#   :standupbg: - alert the lights in group 4
#
# Notes:
#
# Author:
#   kingbin - chris.blazek@gmail.com

hue = require("node-hue-api")
HueApi = hue.HueApi
lightState = hue.lightState

module.exports = (robot) ->
  base_url = process.env.PHILIPS_HUE_IP
  hash  = process.env.PHILIPS_HUE_HASH
  api = new HueApi(base_url, hash)
  state = lightState.create();

  # GROUP COMMANDS
  robot.respond /hue (?:ls )?groups/i, (msg) ->
    api.groups (err, groups) ->
      return handleError msg, err if err
      robot.logger.debug groups
      msg.send "Light groups:"
      list = ''
      for group in groups
        if group.id == '0'
          list = "#{list}\n- #{group.id}: '#{group.name}' (All)"
        else
          list = "#{list}\n- #{group.id}: '#{group.name}' (#{group.lights.join(', ')})"
      msg.send list

  robot.respond /hue group (\w+)=(\[((\d)+,)*((\d)+)\])/i, (msg) ->
    group_name = msg.match[1]
    group_lights = JSON.parse(msg.match[2])
    msg.send "Setting #{group_name} to #{group_lights.join(', ')}"
    api.createGroup group_name, group_lights, (err, response) ->
      return handleError msg, err if err
      robot.logger.debug response
      msg.send "Group created!"

  robot.respond /hue rm group (\d)/i, (msg) ->
    group_id = msg.match[1]
    msg.send "Deleting #{group_id}"
    api.deleteGroup group_id, (err, response) ->
      return handleError msg, err if err
      robot.logger.debug response
      msg.send "Group deleted!"

  # LIGHT COMMANDS
  robot.respond /hue lights/i, (msg) ->
    api.lights (err, lights) ->
      return handleError msg, err if err
      robot.logger.debug lights
      msg.send "Connected hue lights:"
      list = ''
      for light in lights.lights
        list = "#{list}\n- #{light.id}: '#{light.name}'"
      msg.send list

  robot.respond /hue light (.*)/i, (msg) ->
    light = msg.match[1]
    api.lightStatus light, (err, light) ->
      return handleError msg, err if err
      robot.logger.debug light
      msg.send "Light Status:"
      msg.send "- On: #{light.state.on}"
      msg.send "- Reachable: #{light.state.reachable}"
      msg.send "- Name: '#{light.name}'"
      msg.send "- Model: #{light.modelid} - #{light.type}"
      msg.send "- Unique ID: #{light.uniqueid}"
      msg.send "- Software Version: #{light.swversion}"

  robot.respond /hue @(\d+) hsb=\((\d+),(\d+),(\d+)\)/i, (msg) ->
    [group, vHue, vSat, vBri] = msg.match[1..4]
    console.log "hsb"
    msg.send "Setting light group #{group} to: Hue=#{vHue}, Saturation=#{vSat}, Brightness=#{vBri}"
    state = lightState.create().on(true).bri(vBri).hue(vHue).sat(vSat)
    api.setGroupLightState group, state, (err, status) ->
      return handleError msg, err if err
      console.log status
      robot.logger.debug status

  robot.respond /hue hsb light (\d+) (\d+) (\d+) (\d+)/i, (msg) ->
    [light, vHue, vSat, vBri] = msg.match[1..4]
    msg.send "Setting light #{light} to: Hue=#{vHue}, Saturation=#{vSat}, Brightness=#{vBri}"
    state = lightState.create().on(true).bri(vBri).hue(vHue).sat(vSat)
    api.setLightState light, state, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status

  robot.respond /hue @(\d+) xy=\(([0-9]*[.][0-9]+),([0-9]*[.][0-9]+)\)/i, (msg) ->
    [group_name,x,y] = msg.match[1..3]
    groupMap group_name, (group) ->
      return msg.send "Could not find '#{group_name}' in list of groups" unless group
      msg.send "Setting light group #{group} to: X=#{x}, Y=#{y}"
      state = lightState.create().on(true).xy(x, y)
      api.setGroupLightState group, state, (err, status) ->
        return handleError msg, err if err
        robot.logger.debug status

  robot.respond /hue xy light (.*) ([0-9]*[.][0-9]+) ([0-9]*[.][0-9]+)/i, (msg) ->
    [light,x,y] = msg.match[1..3]
    msg.send "Setting light #{light} to: X=#{x}, Y=#{y}"
    state = lightState.create().on(true).xy(x, y)
    api.setLightState light, state, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status

  robot.respond /hue @(\w+) ct=(\d{3})/i, (msg) ->
    [group_name,ct] = msg.match[1..2]
    groupMap group_name, (group) ->
      return msg.send "Could not find '#{group_name}' in list of groups" unless group
      msg.send "Setting light group #{group} to: CT=#{ct}"
      state = lightState.create().on(true).ct(ct)
      api.setGroupLightState group, state, (err, status) ->
        return handleError msg, err if err
        robot.logger.debug status

  robot.respond /hue @(\d+) loop/i, (msg) ->
    group = msg.match[1]
    msg.send "Setting group #{group} to loop"
    state = lightState.create().white(500, 100)
    api.setGroupLightState group, state, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status
      state = lightState.create().effect("colorloop")
      api.setGroupLightState group, state, (err, status) ->
        return handleError msg, err if err
        robot.logger.debug status

  robot.respond /hue @(\d+) white (\d+)/i, (msg) ->
    [group, temp] = msg.match[1..2]
    msg.send "Setting group #{group} to white #{temp}"
    state = lightState.create().effect("none")
    api.setGroupLightState group, state, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status
      state = lightState.create().white(temp, 80)
      api.setGroupLightState group, state, (err, status) ->
        return handleError msg, err if err
        robot.logger.debug status


  robot.respond /hue ct light (.*) (\d{3})/i, (msg) ->
    [lights,ct] = msg.match[1..2]
    msg.send "Setting light #{lights} to: CT=#{ct}"
    lights.split(',').map (light) ->
      state = lightState.create().on(true).ct(ct)
      api.setLightState light, state, (err, status) ->
        return handleError msg, err if err
        robot.logger.debug status

  robot.hear /:standup:/, (msg) ->
    alertState = lightState.create().alertShort()
    api.setGroupLightState 1, alertState, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status

  robot.hear /:standupbg:/, (msg) ->
    alertState = lightState.create().alertShort()
    api.setGroupLightState 4, alertState, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status

  robot.respond /hue @(\w+) (on|off)/i, (msg) ->
    [group, state] = msg.match[1..2]
    msg.send "Setting light group #{group} to #{state}"
    state = lightState.create().on(state=='on')
    api.setGroupLightState group, state, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status

  robot.respond /hue @(\w+) alert/i, (msg) ->
    [group] = msg.match[1]
    state = lightState.create().alertShort()
    api.setGroupLightState group, state, (err, status) ->
      status

  robot.respond /hue turn light (\d+) (on|off)/i, (msg) ->
    [light, state] = msg.match[1..2]
    msg.send "Setting light #{light} to #{state}"
    state = lightState.create().on(state=='on')
    api.setLightState light, state, (err, status) ->
      return handleError msg, err if err
      robot.logger.debug status

  robot.respond /hue (alert|alerts) light (.+)/i, (msg) ->
    [alert_length,light] = msg.match[1..2]
    if alert_length == 'alert'
      alert_text = 'short alert'
      state = lightState.create().alertShort()
    else
      alert_text = 'long alert'
      state = lightState.create().alertLong()
    msg.send "Setting light #{light} to #{alert_text}"
    light.split(',').map (l) ->
      api.setLightState l, state, (err, status) ->
        return handleError msg, err if err
        robot.logger.debug status

  # BRIDGE COMMANDS
  robot.respond /hue config/i, (msg) ->
    api.config (err, config) ->
      return handleError msg, err if err
      robot.logger.debug config
      msg.send "Base Station: '#{config.name}'"
      msg.send "IP: #{config.ipaddress} / MAC: #{config.mac} / ZigBee Channel: #{config.zigbeechannel}"
      msg.send "Software: #{config.swversion} / API: #{config.apiversion} / Update Available: #{config.swupdate.updatestate}"

  robot.respond /hue hash/i, (msg) ->
    msg.http("http://#{base_url}/api")
      .headers(Accept: 'application/json')
      .post(JSON.stringify({devicetype: "hubot"})) (err, res, body) ->
        for line in JSON.parse(body)
          do (line) ->
            if (line.error)
              msg.send line.error.description
            if (line.success)
              msg.send "Hash:" + line.success.username

  robot.respond /hue (link|linkbutton|link button)/i, (msg) ->
    api.pressLinkButton (err, status) ->
      return handleError msg, err if err
      msg.send "Link button pressed!"

  # HELPERS
  groupMap = (group_name, callback) ->
    robot.logger.debug "mapping group names to group ids"
    api.groups (err, groups) ->
      return handleError msg, err if err
      group_map = {}
      for group in groups
        robot.logger.debug group
        if group.id == '0'
          group_map['all'] = '0'
        else
          group_map[group.name.toLowerCase()] = group.id
      match = group_map[group_name.toLowerCase()]
      callback match

  handleError = (msg, err) ->
    msg.send err
