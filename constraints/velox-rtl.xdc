## =============================================================================
## Velox RTL - Nexys A7-100T Constraint File
## Multi-Object Speed Measurement System
## =============================================================================

## ============================================================
## Clock - 100 MHz on-board oscillator
## ============================================================
set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports CLK100MHZ]
create_clock -period 10.000 -name sys_clk [get_ports CLK100MHZ]

## ============================================================
## Reset - CPU_RESETN pushbutton (active-low)
## ============================================================
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports CPU_RESETN]

## ============================================================
## IR Sensor inputs via Pmod JA connector (active-low)
##   JA[0] = SENSOR_A
##   JA[1] = SENSOR_B
## ============================================================
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports SENSOR_A]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports SENSOR_B]

## ============================================================
## 7-Segment Display - Cathodes (active-low)
##   SEG[6] = CA, SEG[5] = CB, SEG[4] = CC, SEG[3] = CD,
##   SEG[2] = CE, SEG[1] = CF, SEG[0] = CG
## ============================================================
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {SEG[6]}]
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports {SEG[5]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {SEG[4]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports {SEG[3]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {SEG[2]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {SEG[1]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {SEG[0]}]

## ============================================================
## 7-Segment Display - Anodes (active-low, rightmost 4 digits)
## ============================================================
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {AN[0]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {AN[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {AN[2]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {AN[3]}]

## ============================================================
## LED Status indicators
##   LED[0] = LED_OVERFLOW
##   LED[1] = LED_TOO_FAST
##   LED[2] = LED_TIMEOUT
## ============================================================
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports LED_OVERFLOW]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports LED_TOO_FAST]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports LED_TIMEOUT]

## ============================================================
## Timing constraints
## ============================================================
## Sensor inputs are asynchronous - disable path timing checks to the
## first synchroniser flip-flop.
set_false_path -from [get_ports SENSOR_A] -to [get_cells -hierarchical -filter {NAME =~ *u_cap_a*meta_ff*}]
set_false_path -from [get_ports SENSOR_B] -to [get_cells -hierarchical -filter {NAME =~ *u_cap_b*meta_ff*}]

## Relax timing on 32-bit counter carry chain (it has 10 ns to propagate)
set_multicycle_path 2 -setup -from [get_cells -hierarchical -filter {NAME =~ *counter*}]