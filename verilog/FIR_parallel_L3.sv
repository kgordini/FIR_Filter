// Parallel FIR, L = 3
                         // Parameters come from MATLAB
module FIR_parallel_L3 #(parameter tap_number   = 202,
                         parameter inputw       = 16,
                         parameter coeffw       = 24,
                         parameter productw     = 40,
                         parameter accumulatorw = 48,
                         parameter outputw      = 16,
                         parameter shift_bits   = 23)

                        (input                           clk,
                         input                           reset,
                         input                           input_valid,
                         input      signed [inputw-1:0]  input_sample0, // oldest of the 3 new samples
                         input      signed [inputw-1:0]  input_sample1,
                         input      signed [inputw-1:0]  input_sample2, // newest of the 3 new samples
                         output reg                      output_valid,
                         output reg signed [outputw-1:0] filtered_output0,
                         output reg signed [outputw-1:0] filtered_output1,
                         output reg signed [outputw-1:0] filtered_output2);

                         reg signed [inputw-1:0]       x_hist    [0:tap_number-1];
                         reg signed [coeffw-1:0]       FIR_coeff [0:tap_number-1];
                         reg signed [accumulatorw-1:0] sum0;    // output for input_sample0
                         reg signed [accumulatorw-1:0] sum1;    // output for input_sample1
                         reg signed [accumulatorw-1:0] sum2;    // output for input_sample2

                         integer i;

                     // Converts back to 16 bit, performs rounding before shifting, and prevents overflow
                     function signed [outputw-1:0] sat_round;
                       input signed [accumulatorw-1:0] value_in;
                       reg   signed [accumulatorw-1:0] abs_value;
                       reg   signed [accumulatorw-1:0] rounded_mag;
                       reg   signed [accumulatorw-1:0] round_const;
                       reg   signed [accumulatorw-1:0] rounded;
                         begin
                            round_const = {{(accumulatorw-shift_bits){1'b0}}, 1'b1, {(shift_bits-1){1'b0}}};

                           if (value_in >= 0) begin
                             rounded = (value_in + round_const) >>> shift_bits;
                            end
                           else begin
                             abs_value    = -value_in;
                             rounded_mag  = (abs_value + round_const) >>> shift_bits;
                             rounded      = -rounded_mag;
                            end

                           if (rounded > 32767)
                             sat_round = 16'sd32767;
                           else if (rounded < -32768)
                             sat_round = -16'sd32768;
                           else
                             sat_round = rounded[outputw-1:0];
                         end
                     endfunction

                     initial begin
                       $readmemh("matlab.hex", FIR_coeff);
                      end

                  // Puts in 3 new samples per cycle and shifts by 3 positions
                     always @(*) begin
                       sum0 = '0;
                       sum1 = '0;
                       sum2 = '0;

                       // y for input_sample0
                       sum0 = sum0 + input_sample0 * FIR_coeff[0];
                       for (i = 1; i < tap_number; i = i + 1)
                         sum0 = sum0 + x_hist[i-1] * FIR_coeff[i];

                       // y for input_sample1
                       sum1 = sum1 + input_sample1 * FIR_coeff[0];
                       if (tap_number > 1)
                         sum1 = sum1 + input_sample0 * FIR_coeff[1];
                         for (i = 2; i < tap_number; i = i + 1)
                           sum1 = sum1 + x_hist[i-2] * FIR_coeff[i];

                       // y for input_sample2
                       sum2 = sum2 + input_sample2 * FIR_coeff[0];
                       if (tap_number > 1)
                         sum2 = sum2 + input_sample1 * FIR_coeff[1];
                       if (tap_number > 2)
                         sum2 = sum2 + input_sample0 * FIR_coeff[2];
                       for (i = 3; i < tap_number; i = i + 1)
                         sum2 = sum2 + x_hist[i-3] * FIR_coeff[i];
                      end

                     always @(posedge clk or posedge reset) begin
                       if (reset) begin
                         for (i = 0; i < tap_number; i = i + 1)
                           x_hist[i] <= '0;
                           filtered_output0 <= '0;
                           filtered_output1 <= '0;
                           filtered_output2 <= '0;
                           output_valid     <= 1'b0;
                        end
                       else begin
                         if (input_valid) begin
                           for (i = tap_number-1; i >= 3; i = i - 1)
                             x_hist[i] <= x_hist[i-3];

                             x_hist[0] <= input_sample2;
                             x_hist[1] <= input_sample1;
                             x_hist[2] <= input_sample0;

                             filtered_output0 <= sat_round(sum0);
                             filtered_output1 <= sat_round(sum1);
                             filtered_output2 <= sat_round(sum2);
                             output_valid     <= 1'b1;
                          end
                         else begin
                           output_valid <= 1'b0;
                          end
                        end
                      end
endmodule
