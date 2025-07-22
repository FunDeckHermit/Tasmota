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

class ButtonHandler
  def any_key(cmd, idx, payload, raw)
    print(f"device_save | key | state | device 0x {idx:X}")
    print(f"Button {idx & 0xF} Pressed { ((idx >> 8) & 0xF) - 9 } times")
    tasmota.cmd(f"<BTN>{idx & 0xFF}")
  end
end

d1 = ButtonHandler()
tasmota.add_driver(d1)

# HMI Commands:
#<CMD>power1 on -> Error LED red on
#<CMD>power1 off -> Error LED red off
#<CMD>power2 on -> Error LED green on
#<CMD>power2 off -> Error LED green off
#<CMD>power3 on -> Ready LED red on
#<CMD>power3 off -> Ready LED red off
#<CMD>power4 on -> Ready LED green on
#<CMD>power4 off -> Ready LED green off
#<CMD>channel5 x -> Set LCD contrast to x %
#<CMD>channel6 x -> Set LCD brightness to x %

# Optional, shouldn't be used in normal operation:
#<CMD>power5 on -> Contrast control on
#<CMD>power5 off -> Contrast control off
#<CMD>power6 on -> Brightness control on
#<CMD>power6 off -> Brightness control off


#Micropython master code:
#from machine import UART
#
#uart = UART(1, 9600)
#uart.init(9600, bits=8, parity=None, stop=1, tx=17, rx=18)
#uart.write('<CMD>setbrights')
#TODO: Make Tasmota command to write lines to LCD