# Run this by calling load("test_lcd_api") from the Berry console
# Change the pin numbering to suit your board

import lcd_4bit

var lcd1 = lcd_4bit.create(38,9,39,40,41,42,4,20)
lcd1.putstr("Hello\nWorld\nFrom\nTasmota")
