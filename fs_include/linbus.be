var lin_module = module("linbus")

class miniterm
  var ser, id, hex, start
  def init(rx, tx, baud, mode, inverted, hex)
    self.id = f'miniterm_instance_{rx}/{tx}'
    self.hex = hex
    tasmota.remove_driver(global.member(self.id))
    self.start =
      def ()
        self.msg('opening')
        self.ser = serial(rx, tx, baud==nil ? 115200 : baud, mode==nil ? serial.SERIAL_8N1 : mode, inverted==nil ? false : inverted)
        tasmota.add_driver(self)
        global.setmember(self.id, self)
      end
    self.start()
  end
  def send(msg)
    if ! self.ser return end
    self.msg('sending', msg)
    self.ser.write(self.hex ? bytes(msg) : bytes().fromstring(msg))
  end
  def close()
    if ! self.ser return end
    self.msg('closing')
    tasmota.remove_driver(self)
    self.ser.close()
    self.ser = nil
    self.id='closed'
  end
  def every_50ms()
    if ! self.ser return end
    if self.ser.available() == 0 return end
    var ba = self.ser.read()
    self.msg('received', self.hex ? ba.tohex() : ba.asstring())
  end
  def msg(tag, data)
    print('serial', self.id, tag, data ? data : '')
  end
end

lin_module.init =
  def(m)
    class LIN_factory
      def create(rx, tx, baud, mode, inverted, hex)
        return miniterm(rx, tx, baud, mode, inverted, hex)
      end
    end
    return LIN_factory()
  end
return lin_module