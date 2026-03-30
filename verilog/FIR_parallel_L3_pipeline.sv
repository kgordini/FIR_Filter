// Parallel & Pipelined FIR, L = 3
                                  // Parameters come from MATLAB
module FIR_parallel_L3_pipeline #(parameter tap_number   = 202,
                                  parameter inputw       = 16,
                                  parameter coeffw       = 24,
                                  parameter productw     = 40,
                                  parameter accumulatorw = 48,
                                  parameter outputw      = 16,
                                  parameter shift_bits   = 23)

                                 (input                           clk,
                                  input                           reset,
                                  input                           input_valid,
                                  input      signed [inputw-1:0]  input_sample0,
                                  input      signed [inputw-1:0]  input_sample1,
                                  input      signed [inputw-1:0]  input_sample2,
                                  output reg                      output_valid,
                                  output reg signed [outputw-1:0] filtered_output0,
                                  output reg signed [outputw-1:0] filtered_output1,
                                  output reg signed [outputw-1:0] filtered_output2);

                                  reg signed [inputw-1:0]         x_hist    [0:tap_number-1];
                                  reg signed [coeffw-1:0]         FIR_coeff [0:tap_number-1];

                                  reg signed [accumulatorw-1:0]   sum0_comb;
                                  reg signed [accumulatorw-1:0]   sum1_comb;
                                  reg signed [accumulatorw-1:0]   sum2_comb;

                                  reg signed [accumulatorw-1:0]   sum0_pipe;
                                  reg signed [accumulatorw-1:0]   sum1_pipe;
                                  reg signed [accumulatorw-1:0]   sum2_pipe;

                                  reg                             valid_pipe;

                                  integer i;

                              // Converts back to 16 bit, performs rounding before shifting, and prevents overflow
                              function signed [outputw-1:0] sat_round;
                                input signed [accumulatorw-1:0] value_in;
                                reg   signed [accumulatorw-1:0] round_const;
                                reg   signed [accumulatorw-1:0] temp;
                                  begin
                                     round_const = 1 <<< (shift_bits - 1);

                                     temp = value_in + round_const;
                                     temp = temp >>> shift_bits;

                                     if (temp > 32767)
                                       sat_round = 16'sd32767;
                                     else if (temp < -32768)
                                       sat_round = -16'sd32768;
                                     else
                                       sat_round = temp[15:0];
                                  end
                              endfunction

                              initial begin
                                $readmemh("matlab.hex", FIR_coeff);
                               end

                              always @(*) begin
                                sum0_comb = '0;
                                sum1_comb = '0;
                                sum2_comb = '0;

                                sum0_comb = sum0_comb + input_sample0 * FIR_coeff[0];
                                for (i = 1; i < tap_number; i = i + 1)
                                  sum0_comb = sum0_comb + x_hist[i-1] * FIR_coeff[i];

                                sum1_comb = sum1_comb + input_sample1 * FIR_coeff[0];
                                if (tap_number > 1)
                                  sum1_comb = sum1_comb + input_sample0 * FIR_coeff[1];
                                for (i = 2; i < tap_number; i = i + 1)
                                  sum1_comb = sum1_comb + x_hist[i-2] * FIR_coeff[i];

                                sum2_comb = sum2_comb + input_sample2 * FIR_coeff[0];
                                if (tap_number > 1)
                                  sum2_comb = sum2_comb + input_sample1 * FIR_coeff[1];
                                if (tap_number > 2)
                                  sum2_comb = sum2_comb + input_sample0 * FIR_coeff[2];
                                for (i = 3; i < tap_number; i = i + 1)
                                  sum2_comb = sum2_comb + x_hist[i-3] * FIR_coeff[i];
                               end

                              always @(posedge clk or posedge reset) begin
                                if (reset) begin
                                  for (i = 0; i < tap_number; i = i + 1)
                                    x_hist[i] <= '0;

                                    sum0_pipe  <= '0;
                                    sum1_pipe  <= '0;
                                    sum2_pipe  <= '0;
                                    valid_pipe <= 1'b0;
                                 end
                                else begin
                                  if (input_valid) begin
                                    sum0_pipe  <= sum0_comb;
                                    sum1_pipe  <= sum1_comb;
                                    sum2_pipe  <= sum2_comb;
                                    valid_pipe <= 1'b1;

                                    for (i = tap_number-1; i >= 3; i = i - 1)
                                      x_hist[i] <= x_hist[i-3];
                                      x_hist[0] <= input_sample2;
                                      x_hist[1] <= input_sample1;
                                      x_hist[2] <= input_sample0;
                                   end
                                  else begin
                                    valid_pipe <= 1'b0;
                                   end
                                 end
                               end

                              always @(posedge clk or posedge reset) begin
                                if (reset) begin
                                  filtered_output0 <= '0;
                                  filtered_output1 <= '0;
                                  filtered_output2 <= '0;
                                  output_valid     <= 1'b0;
                                 end
                                else begin
                                  filtered_output0 <= sat_round(sum0_pipe);
                                  filtered_output1 <= sat_round(sum1_pipe);
                                  filtered_output2 <= sat_round(sum2_pipe);
                                  output_valid     <= valid_pipe;
                                 end
                               end
endmodule 
