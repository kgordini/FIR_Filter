// FIR BASELINE
                      // Parameters come from MATLAB
module FIR_baseline #(parameter tap_number   = 202,
                      parameter inputw       = 16,
                      parameter coeffw       = 24,
                      parameter productw     = 40,
                      parameter accumulatorw = 48,
                      parameter outputw      = 16,
                      parameter shift_bits   = 23)

                     (input                           clk,
                      input                           reset,
                      input      signed [inputw-1:0]  input_sample,
                      input                           input_valid,
                      output reg signed [outputw-1:0] filtered_output,
                      output reg                      output_valid);

                      reg signed [inputw-1:0]       reg_shift [0:tap_number-1];
                      reg signed [coeffw-1:0]       FIR_coeff [0:tap_number-1];
                      reg signed [productw-1:0]     product   [0:tap_number-1];
                      reg signed [accumulatorw-1:0] accum_sum;

                      integer i;

                  // Converts back to 16 bit, performs rounding before shifting, and prevents overflow
                  function signed [outputw-1:0]      sat_round;
                    input signed  [accumulatorw-1:0] value_in;
                    reg   signed  [accumulatorw-1:0] abs_value;
                    reg   signed  [accumulatorw-1:0] rounded_mag;
                    reg   signed  [accumulatorw-1:0] round_const;
                    reg   signed  [accumulatorw-1:0] rounded;
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

                  // Delay line (shift register):
                  // reg_shift[0] = x[n], reg_shift[1] = x[n-1], reg_shift[2] = x[n-2], ...
                  always @(posedge clk or posedge reset) begin
                    if (reset) begin
                      for (i = 0; i < tap_number; i = i + 1)
                        reg_shift[i] <= '0;
                     end
                    else if (input_valid) begin
                      for (i = tap_number-1; i > 0; i = i - 1)
                        reg_shift[i] <= reg_shift[i-1];
                        reg_shift[0] <= input_sample;
                     end
                   end

                  // Delayed sample multiplied by its coefficient
                  always @(*) begin
                    for (i = 0; i < tap_number; i = i + 1)
                      product[i] = reg_shift[i] * FIR_coeff[i];
                   end

                  // Accumulation of all products
                  always @(*) begin
                    accum_sum = '0;
                    for (i = 0; i < tap_number; i = i + 1) begin
                      accum_sum = accum_sum + {{(accumulatorw-productw){product[i][productw-1]}}, product[i]};
                     end
                   end

                  // Output corresponding to the updated delay line appears one clock after input_valid
                  always @(posedge clk or posedge reset) begin
                    if (reset) begin
                      filtered_output <= '0;
                      output_valid    <= 1'b0;
                     end
                    else begin
                      output_valid <= input_valid;
                      if (input_valid)
                        filtered_output <= sat_round(accum_sum);
                     end
                   end
endmodule
