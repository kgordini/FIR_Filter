// Pipelined FIR
                      // Parameters come from MATLAB
module FIR_pipeline #(parameter tap_number   = 202,
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

                      reg signed [coeffw-1:0]       FIR_coeff  [0:tap_number-1];
                      wire signed [productw-1:0]    mult       [0:tap_number-1];
                      reg signed [accumulatorw-1:0] state_reg  [0:tap_number-2];
                      reg signed [accumulatorw-1:0] next_state [0:tap_number-2];    // next pipeline state
                      reg signed [accumulatorw-1:0] y_accum;    // output accumulation

                      integer i;
                      genvar g;

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

                  generate
                    for (g = 0; g < tap_number; g = g + 1) begin : GEN_PIPE_MULT
                      assign mult[g] = input_sample * FIR_coeff[g];
                     end
                  endgenerate

                  always @(*) begin
                    if (tap_number > 1)
                      y_accum = {{(accumulatorw-productw){mult[0][productw-1]}}, mult[0]} + state_reg[0];
                    else
                      y_accum = {{(accumulatorw-productw){mult[0][productw-1]}}, mult[0]};

                    for (i = 0; i < tap_number-2; i = i + 1)
                      next_state[i] = {{(accumulatorw-productw){mult[i+1][productw-1]}}, mult[i+1]} + state_reg[i+1];

                      if (tap_number > 1)
                        next_state[tap_number-2] = {{(accumulatorw-productw){mult[tap_number-1][productw-1]}}, mult[tap_number-1]};
                   end

                  always @(posedge clk or posedge reset) begin
                    if (reset) begin
                      for (i = 0; i < tap_number-1; i = i + 1)
                        state_reg[i] <= '0;
                        filtered_output <= '0;
                        output_valid    <= 1'b0;
                     end
                    else begin
                      if (input_valid) begin
                        for (i = 0; i < tap_number-1; i = i + 1)
                          state_reg[i] <= next_state[i];
                          filtered_output <= sat_round(y_accum);
                          output_valid    <= 1'b1;
                       end
                      else begin
                        output_valid <= 1'b0;
                       end
                     end
                   end
endmodule
