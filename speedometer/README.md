# FPGA-Based Speedometer

## Objective
Design and implement a digital speedometer system on the Nexys A7 FPGA board. The system calculates the speed of an object passing between two external sensors placed at a known distance.

## Hardware Setup
- **Board:** Nexys A7 (Artix-7).
- **Sensors:** Connect the first sensor to PyMOD Header JA pin 1 (`C17`) and the second sensor to PyMOD Header JA pin 2 (`D18`).
- **Display:** The speed is displayed on the onboard 7-segment display.
- **Clock:** 100 MHz onboard clock (`E3`).
- **Reset:** `CPU_RESET` button (`C12`), active low.

## How it works
1. **Edge Detection:** The incoming sensor signals are synchronized to prevent metastability and debounced. When a rising edge is detected on `Sensor 1`, the FSM moves from `IDLE` to `TIMING` and starts a high-resolution 32-bit `Timer`.
2. **Timing:** The timer counts clock cycles (10 ns per cycle).
3. **Trigger 2:** Upon detecting a rising edge on `Sensor 2`, the FSM moves to `CALC`, stops the timer, and triggers the `Speed_Calc` module.
4. **Speed Calculation:** Uses fixed-point iterative division logic: `Speed = (Distance * Clock Frequency) / Cycles`. The result is clamped to a 16-bit integer (max speed = 65535 cm/s, or ~2359 km/h).
5. **Display:** The `Bin2BCD` module converts the 16-bit binary speed into binary-coded decimal. The `Seven_Segment_Driver` then multiplexes these digits across the 8-digit multiplexed common-anode display.

## How to Program the Nexys A7
1. Open Vivado and create a new project targeting the `xc7a100tcsg324-1` (Nexys A7-100T).
2. Add all `.v` files in the `src/` directory to the project as design sources.
3. Add the `constraints/NexysA7_speedometer.xdc` file as the constraint.
4. Run synthesis, implementation, and generate the bitstream.
5. Open the Hardware Manager, open the target board, and program the device with the generated `.bit` file.

## Expected Output
Once programmed, passing a hand or an object first across Sensor 1 then Sensor 2 (assumed distance: 50 cm) will display the calculated speed in cm/s on the rightmost 7-segment digits.

## Assumptions Made
- The distance is parameterized. The default logic assumes `DISTANCE_CM = 50`. Modify this in `Top_Speedometer.v`.
- The sensors trigger on a rising edge and are inherently noisy (debouncer assumes typical switch noise or bouncy optical sensor output; debounce timer `DEBOUNCE_MAX = 100000`).
