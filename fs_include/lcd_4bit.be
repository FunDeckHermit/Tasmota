import undefined
import math
import string
import gpio

var lcd_module = module("lcd_4bit")

class LcdApi : Driver
    static LCD_CLR = 0x01              # DB0: clear display
    static LCD_HOME = 0x02             # DB1: return to home position

    static LCD_ENTRY_MODE = 0x04       # DB2: set entry mode
    static LCD_ENTRY_INC = 0x02        # --DB1: increment
    static LCD_ENTRY_SHIFT = 0x01      # --DB0: shift

    static LCD_ON_CTRL = 0x08          # DB3: turn lcd/cursor on
    static LCD_ON_DISPLAY = 0x04       # --DB2: turn display on
    static LCD_ON_CURSOR = 0x02        # --DB1: turn cursor on
    static LCD_ON_BLINK = 0x01         # --DB0: blinking cursor

    static LCD_MOVE = 0x10             # DB4: move cursor/display
    static LCD_MOVE_DISP = 0x08        # --DB3: move display (0-> move cursor)
    static LCD_MOVE_RIGHT = 0x04       # --DB2: move right (0-> left)

    static LCD_FUNCTION = 0x20         # DB5: function set
    static LCD_FUNCTION_8BIT = 0x10    # --DB4: set 8BIT mode (0->4BIT mode)
    static LCD_FUNCTION_2LINES = 0x08  # --DB3: two lines (0->one line)
    static LCD_FUNCTION_10DOTS = 0x04  # --DB2: 5x10 font (0->5x7 font)
    static LCD_FUNCTION_RESET = 0x30   # See "Initializing by Instruction" section

    static LCD_CGRAM = 0x40            # DB6: set CG RAM address
    static LCD_DDRAM = 0x80            # DB7: set DD RAM address

    static LCD_RS_CMD = 0
    static LCD_RS_DATA = 1

    static LCD_RW_WRITE = 0
    static LCD_RW_READ = 1

    var cursor_x, cursor_y
    var num_lines, num_columns
    var implied_newline

    def init(num_lines, num_columns)
      self.num_lines = math.min(num_lines, 4)
      self.num_columns = math.min(num_columns, 40)
      self.cursor_x = 0
      self.cursor_y = 0
      self.implied_newline = false
      self.display_off()
      self.clear()
      self.hal_write_command(self.LCD_ENTRY_MODE | self.LCD_ENTRY_INC)
      self.hide_cursor()
      self.display_on()
    end


    def clear()
        # Clears the LCD display and moves the cursor to the top left corner.
        self.hal_write_command(self.LCD_CLR)
        self.hal_write_command(self.LCD_HOME)
        self.cursor_x = 0
        self.cursor_y = 0
    end


    def show_cursor()
        # Causes the cursor to be made visible.
        self.hal_write_command(self.LCD_ON_CTRL | self.LCD_ON_DISPLAY | self.LCD_ON_CURSOR)
    end


    def hide_cursor()
        # Causes the cursor to be hidden.
        self.hal_write_command(self.LCD_ON_CTRL | self.LCD_ON_DISPLAY)
    end


    def blink_cursor_on()
        # Turns on the cursor, and makes it blink.
        self.hal_write_command(self.LCD_ON_CTRL | self.LCD_ON_DISPLAY | self.LCD_ON_CURSOR | self.LCD_ON_BLINK)
    end


    def blink_cursor_off()
        # Turns on the cursor, and makes it no blink (i.e. be solid).
        self.hal_write_command(self.LCD_ON_CTRL | self.LCD_ON_DISPLAY | self.LCD_ON_CURSOR)
    end


    def display_on()
        # Turns on (i.e. unblanks) the LCD.
        self.hal_write_command(self.LCD_ON_CTRL | self.LCD_ON_DISPLAY)
    end


    def display_off()
        # Turns off (i.e. blanks) the LCD.
        self.hal_write_command(self.LCD_ON_CTRL)
    end

    def move_to(cursor_x, cursor_y)
        # Moves the cursor position to the indicated position. The cursor
        # position is zero based (i.e. cursor_x == 0 indicates first column).

        self.cursor_x = cursor_x
        self.cursor_y = cursor_y
        var addr = cursor_x & 0x3f
        # Lines 1 & 3 add 0x40 while lines 2 & 3 add number of columns
        if cursor_y & 0x01
            addr += 0x40
        end
        if cursor_y & 0x02
            addr += self.num_columns
        end
        self.hal_write_command(self.LCD_DDRAM | addr)
    end


    def putchar(char)
        # Writes the indicated character to the LCD at the current cursor
        # position, and advances the cursor by one position.

        if char == '\n'
            if self.implied_newline
                # self.implied_newline means we advanced due to a wraparound,
                # so if we get a newline right after that we ignore it.
                self.implied_newline = False
            else
                self.cursor_x = self.num_columns
            end
        else
            var b = string.byte(char)
            self.hal_write_data(b)
            self.cursor_x += 1
        end
        if self.cursor_x >= self.num_columns
            self.cursor_x = 0
            self.cursor_y += 1
            self.implied_newline = (char != '\n')
        end
        if self.cursor_y >= self.num_lines
            self.cursor_y = 0
        end
        self.move_to(self.cursor_x, self.cursor_y)
    end


    def putstr(string)
        # Write the indicated string to the LCD at the current cursor
        # position and advances the cursor position appropriately.

        for i:0..size(string)-1
          self.putchar(string[i])
        end
    end

    def custom_char(location, charmap)
        # Write a character to one of the 8 CGRAM locations, available
        # as chr(0) through chr(7).

        location &= 0x7
        self.hal_write_command(self.LCD_CGRAM | (location << 3))
        self.hal_sleep_us(40)
        for i: 0..8
            self.hal_write_data(charmap[i])
            self.hal_sleep_us(40)
        end
        self.move_to(self.cursor_x, self.cursor_y)
    end

    def hal_write_command(cmd)
        # Write a command to the LCD.
        # It is expected that a derived HAL class will implement this
        # function.
        return undefined
    end


    def hal_write_data(data)
        # Write data to the LCD.

        # It is expected that a derived HAL class will implement this
        # function.
        return undefined
    end

    def hal_sleep_us(usecs)
      if usecs >= 1000
        tasmota.delay((usecs / 1000) + 1)
      else
        for i: 0 .. usecs
          # empty for loops aren't optimized out in Berry
        end
      end
    end
end


class GpioLcd : LcdApi
  var rs_pin, enable_pin, d4_pin, d5_pin, d6_pin, d7_pin
  def init(rs_pin, enable_pin, d4_pin, d5_pin, d6_pin, d7_pin, num_lines, num_columns)

    self.rs_pin = rs_pin
    self.enable_pin = enable_pin
    self.d4_pin = d4_pin
    self.d5_pin = d5_pin
    self.d6_pin = d6_pin
    self.d7_pin = d7_pin

    gpio.pin_mode(self.rs_pin, gpio.OUTPUT)
    gpio.pin_mode(self.enable_pin, gpio.OUTPUT)
    gpio.pin_mode(self.d4_pin, gpio.OUTPUT)
    gpio.pin_mode(self.d5_pin, gpio.OUTPUT)
    gpio.pin_mode(self.d6_pin, gpio.OUTPUT)
    gpio.pin_mode(self.d7_pin, gpio.OUTPUT)

    self.hal_sleep_us(20000)   # Allow LCD time to powerup
    # Send reset 3 times
    self.hal_write_init_nibble(self.LCD_FUNCTION_RESET)
    self.hal_sleep_us(5000)   # need to delay at least 4.1 msec
    self.hal_write_init_nibble(self.LCD_FUNCTION_RESET)
    self.hal_sleep_us(1000)
    self.hal_write_init_nibble(self.LCD_FUNCTION_RESET)
    self.hal_sleep_us(1000)
    var cmd = self.LCD_FUNCTION
    self.hal_write_init_nibble(cmd)
    self.hal_sleep_us(1000)
    super(self).init(num_lines, num_columns)
    if num_lines > 1
      cmd |= self.LCD_FUNCTION_2LINES
    end
    self.hal_write_command(cmd)
  end

  def hal_pulse_enable()
    gpio.digital_write(self.enable_pin, 0)
    self.hal_sleep_us(1)
    gpio.digital_write(self.enable_pin, 1)
    self.hal_sleep_us(1)
    gpio.digital_write(self.enable_pin, 0)
    self.hal_sleep_us(100)
  end

  def hal_write_init_nibble(nibble)
    self.hal_write_4bits(nibble >> 4)
  end

  def hal_write_command(cmd)
    gpio.digital_write(self.rs_pin, 0)
    self.hal_write_8bits(cmd)
    if cmd <= 3
      self.hal_sleep_us(5000)
    end
  end

  def hal_write_data(data)
    gpio.digital_write(self.rs_pin, 1)
    self.hal_write_8bits(data)
  end

  def hal_write_8bits(value)
    self.hal_write_4bits(value >> 4)
    self.hal_write_4bits(value)
  end

  def hal_write_4bits(nibble)
    gpio.digital_write(self.d7_pin, nibble & 0x08)
    gpio.digital_write(self.d6_pin, nibble & 0x04)
    gpio.digital_write(self.d5_pin, nibble & 0x02)
    gpio.digital_write(self.d4_pin, nibble & 0x01)
    self.hal_pulse_enable()
  end
end


lcd_module.init =
  def(m)
    class Lcd_factory
      def create(rs_pin, enable_pin, d4_pin, d5_pin, d6_pin, d7_pin, num_lines, num_columns)
        return GpioLcd(rs_pin, enable_pin, d4_pin, d5_pin, d6_pin, d7_pin, num_lines, num_columns)
      end
    end
    return Lcd_factory()
  end
return lcd_module
