## ============================================================
## NEXYS A7 - CONSTRAINTS FILE (.XDC)
## For Speedometer FPGA Project
## ============================================================

## ============================================================
## CLOCK - 100 MHz Onboard Oscillator
## ============================================================
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];


## ============================================================
## RESET BUTTON
## Nexys A7: BTNC (Center button) - Active HIGH
## ============================================================
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { reset_btn }];


## ============================================================
## IR SENSORS - Connected via PMOD JA (Top row)
## ============================================================
## IR Sensor 1 (io_pin_1) - PMOD JA Pin 1
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { ir1 }];

## IR Sensor 2 (io_pin_2) - PMOD JA Pin 2
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { ir2 }];

## OPTIONAL: PMOD JA Pin 3 & 4 for future use
## set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { ir3 }];
## set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { ir4 }];


## ============================================================
## 7-SEGMENT DISPLAY - Cathode Segments (a-g)
## Common-Cathode Configuration
## Segment pins are output signals for each segment
## ============================================================

## seg[0] = a
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { seg[0] }];

## seg[1] = b
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { seg[1] }];

## seg[2] = c
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { seg[2] }];

## seg[3] = d
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports { seg[3] }];

## seg[4] = e
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { seg[4] }];

## seg[5] = f
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { seg[5] }];

## seg[6] = g
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { seg[6] }];


## ============================================================
## 7-SEGMENT DISPLAY - Anode Selectors (Digit Enable)
## Common-Cathode: Anode HIGH enables the digit
## ============================================================

## an[0] - First 7-segment display (Ones place)
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { an[0] }];

## an[1] - Second 7-segment display (Tens place)
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { an[1] }];

## an[2] - Third 7-segment display (Hundreds place)
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { an[2] }];

## an[3] - Fourth 7-segment display (unused in this project)
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports { an[3] }];

## an[4] - Fifth 7-segment display (unused in this project)
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { an[4] }];

## an[5] - Sixth 7-segment display (unused in this project)
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { an[5] }];

## an[6] - Seventh 7-segment display (unused in this project)
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { an[6] }];

## an[7] - Eighth 7-segment display (unused in this project)
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { an[7] }];


## ============================================================
## RED LED - Overspeed Indicator
## Connect to any available LED on Nexys A7
## Using LED17 (LD17)
## ============================================================
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { red_led }];


## ============================================================
## OPTIONAL: ADDITIONAL LEDS (16 total available)
## Uncomment if needed for debugging
## ============================================================

## LED 0 - LD0
## set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];

## LED 1 - LD1
## set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];

## LED 2 - LD2
## set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];

## LED 3 - LD3
## set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## LED 4 - LD4
## set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { led[4] }];

## LED 5 - LD5
## set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { led[5] }];

## LED 6 - LD6
## set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { led[6] }];

## LED 7 - LD7
## set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { led[7] }];

## LED 8 - LD8
## set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { led[8] }];

## LED 9 - LD9
## set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { led[9] }];

## LED 10 - LD10
## set_property -dict { PACKAGE_PIN M16 IOSTANDARD LVCMOS33 } [get_ports { led[10] }];

## LED 11 - LD11
## set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { led[11] }];

## LED 12 - LD12
## set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { led[12] }];

## LED 13 - LD13
## set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { led[13] }];

## LED 14 - LD14
## set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { led[14] }];

## LED 15 - LD15
## set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { led[15] }];


## ============================================================
## OPTIONAL: OTHER BUTTONS (for future expansion)
## Uncomment if needed
## ============================================================

## BTNU - Up
## set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports { btn_up }];

## BTNL - Left
## set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports { btn_left }];

## BTNR - Right
## set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports { btn_right }];

## BTND - Down
## set_property -dict { PACKAGE_PIN C8 IOSTANDARD LVCMOS33 } [get_ports { btn_down }];


## ============================================================
## OPTIONAL: PMOD Connectors (if using additional sensors)
## ============================================================

## PMOD JB - Row 1 (pins 1-4)
## set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports { pmod_jb[0] }];
## set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports { pmod_jb[1] }];
## set_property -dict { PACKAGE_PIN D16 IOSTANDARD LVCMOS33 } [get_ports { pmod_jb[2] }];
## set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { pmod_jb[3] }];

## PMOD JC - Row 1 (pins 1-4)
## set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports { pmod_jc[0] }];
## set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { pmod_jc[1] }];
## set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { pmod_jc[2] }];
## set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { pmod_jc[3] }];


## ============================================================
## IO VOLTAGE AND SLEW RATE (Performance)
## ============================================================

## Set slew rate for 7-segment display (fast outputs needed for multiplexing)
set_property SLEW FAST [get_ports { seg[*] }];
set_property SLEW FAST [get_ports { an[*] }];
set_property SLEW FAST [get_ports { red_led }];

## Set drive strength if needed (optional)
set_property DRIVE 12 [get_ports { seg[*] }];
set_property DRIVE 12 [get_ports { an[*] }];


## ============================================================
## BITSTREAM SETTINGS (Optional)
## ============================================================

## Uncomment for faster bitstream generation
## set_property BITSTREAM.CONFIG.CCLKPIN {AA16} [current_design]
## set_property BITSTREAM.CONFIG.DONE {Y17} [current_design]

## Uncomment to enable internal pull-ups on unused pins
## set_property INTERNAL_VREF 0.675 [get_iobanks 34]
