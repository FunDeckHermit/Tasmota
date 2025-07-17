# Om ervoor te zorgen dat serial weet in welke stand hij moet opereren.
# sserialsend1 = soft serial die wacht op newline \n, zend A(live).
tasmota.cmd("sserialsend1 A")


tasmota.add_rule('SSerialReceived',
  def (value)
    print(value[0..4])
    if value[0..4] == "<CMD>"
      print(f'Command received: {value}')
      tasmota.cmd(value[5..])
    end
  end
)

#commands:
#<CMD>power1 on -> Error LED red on
#<CMD>power1 off -> Error LED red off
#<CMD>power2 on -> Error LED green on
#<CMD>power2 off -> Error LED green off
#<CMD>power3 on -> Ready LED red on
#<CMD>power3 off -> Ready LED red off
#<CMD>power4 on -> Ready LED green on
#<CMD>power4 off -> Ready LED green off