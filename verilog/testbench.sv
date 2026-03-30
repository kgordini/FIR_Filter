///////////////
// Testbench //
///////////////

module testbench;

    parameter tap_number   = 202;
    parameter inputw       = 16;
    parameter coeffw       = 24;
    parameter productw     = 40;
    parameter accumulatorw = 48;
    parameter outputw      = 16;
    parameter shift_bits   = 23;
    parameter test_length  = 300;

    reg clk;
    reg reset;

    // Single-rate input
    reg signed [inputw-1:0]   input_sample;
    reg                       input_valid;

    // L=2 input
    reg signed [inputw-1:0]   input_sample0_L2;
    reg signed [inputw-1:0]   input_sample1_L2;
    reg                       input_valid_L2;

    // L=3 input
    reg signed [inputw-1:0]   input_sample0_L3;
    reg signed [inputw-1:0]   input_sample1_L3;
    reg signed [inputw-1:0]   input_sample2_L3;
    reg                       input_valid_L3;

    // DUT outputs
    wire signed [outputw-1:0] filtered_output_base;
    wire                      output_valid_base;

    wire signed [outputw-1:0] filtered_output_pipe;
    wire                      output_valid_pipe;

    wire signed [outputw-1:0] filtered_output0_L2;
    wire signed [outputw-1:0] filtered_output1_L2;
    wire                      output_valid_L2;

    wire signed [outputw-1:0] filtered_output0_L3;
    wire signed [outputw-1:0] filtered_output1_L3;
    wire signed [outputw-1:0] filtered_output2_L3;
    wire                      output_valid_L3;

    wire signed [outputw-1:0] filtered_output0_L3_pipe;
    wire signed [outputw-1:0] filtered_output1_L3_pipe;
    wire signed [outputw-1:0] filtered_output2_L3_pipe;
    wire                      output_valid_L3_pipe;

    // Input samples and expected golden outputs from MATLAB
    reg signed [inputw-1:0]   input_vector  [0:test_length-1];
    reg signed [outputw-1:0]  golden_vector [0:test_length-1];

    // File read variables, loop counters, and sample index tracking
    integer i;
    integer scan_status;
    integer file_input;
    integer file_output;
    integer sample_index;
    integer idx_L2;
    integer idx_L3;

    // Counters, checked outputs, and max error
    integer mismatch_count_base;
    integer mismatch_count_pipe;
    integer mismatch_count_L2;
    integer mismatch_count_L3;
    integer mismatch_count_L3_pipe;

    integer total_checked_base;
    integer total_checked_pipe;
    integer total_checked_L2;
    integer total_checked_L3;
    integer total_checked_L3_pipe;

    integer max_error_base;
    integer max_error_pipe;
    integer max_error_L2;
    integer max_error_L3;
    integer max_error_L3_pipe;

    // Keeps track of which golden output each architecture should have
    integer golden_index_base;
    integer golden_index_pipe;
    integer golden_index_L2;
    integer golden_index_L3;
    integer golden_index_L3_pipe;

    integer error_base;
    integer error_pipe;
    integer error_L2_0;
    integer error_L2_1;
    integer error_L3_0;
    integer error_L3_1;
    integer error_L3_2;
    integer error_L3p_0;
    integer error_L3p_1;
    integer error_L3p_2;

    // Offset checker for pipelined FIR output alignment
    localparam PIPE_LATENCY = 0;

    // Because FIR_parallel_L3_pipeline has one extra output register stage
    localparam integer L3_PIPE_GROUP_LATENCY = 1;

    // Absolute value used for max error checking
    function integer abs_int;
        input integer value_in;
        begin
            if (value_in < 0)
                abs_int = -value_in;
            else
                abs_int = value_in;
        end
    endfunction


    // DUTs
    FIR_baseline #(tap_number, inputw, coeffw, productw, accumulatorw, outputw, shift_bits) 
    DUT_base (
        .clk(clk),
        .reset(reset),
        .input_sample(input_sample),
        .input_valid(input_valid),
        .filtered_output(filtered_output_base),
        .output_valid(output_valid_base)
        );

    FIR_pipeline #(tap_number, inputw, coeffw, productw, accumulatorw, outputw, shift_bits) 
    DUT_pipe (
        .clk(clk),
        .reset(reset),
        .input_sample(input_sample),
        .input_valid(input_valid),
        .filtered_output(filtered_output_pipe),
        .output_valid(output_valid_pipe)
        );

    FIR_parallel_L2 #(tap_number, inputw, coeffw, productw, accumulatorw, outputw, shift_bits) 
    DUT_L2 (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid_L2),
        .input_sample0(input_sample0_L2),
        .input_sample1(input_sample1_L2),
        .output_valid(output_valid_L2),
        .filtered_output0(filtered_output0_L2),
        .filtered_output1(filtered_output1_L2)
        );

    FIR_parallel_L3 #(tap_number, inputw, coeffw, productw, accumulatorw, outputw, shift_bits) 
    DUT_L3 (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid_L3),
        .input_sample0(input_sample0_L3),
        .input_sample1(input_sample1_L3),
        .input_sample2(input_sample2_L3),
        .output_valid(output_valid_L3),
        .filtered_output0(filtered_output0_L3),
        .filtered_output1(filtered_output1_L3),
        .filtered_output2(filtered_output2_L3)
        );

    FIR_parallel_L3_pipeline #(tap_number, inputw, coeffw, productw, accumulatorw, outputw, shift_bits) 
    DUT_L3_pipe (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid_L3),
        .input_sample0(input_sample0_L3),
        .input_sample1(input_sample1_L3),
        .input_sample2(input_sample2_L3),
        .output_valid(output_valid_L3_pipe),
        .filtered_output0(filtered_output0_L3_pipe),
        .filtered_output1(filtered_output1_L3_pipe),
        .filtered_output2(filtered_output2_L3_pipe)
        );


    // Clock
    initial clk = 1'b0;
    always #5 clk = ~clk;   // 10ns clock period


    // Read test files
    initial begin
      file_input = $fopen("input.txt", "r");
        if (file_input == 0) begin
            $display("ERROR: could not open input.txt");
            $finish;
         end

        for (i = 0; i < test_length; i = i + 1)
            scan_status = $fscanf(file_input, "%d\n", input_vector[i]);

        $fclose(file_input);

        file_output = $fopen("golden.txt", "r");
        if (file_output == 0) begin
            $display("ERROR: could not open golden.txt");
            $finish;
         end

        for (i = 0; i < test_length; i = i + 1)
            scan_status = $fscanf(file_output, "%d\n", golden_vector[i]);

        $fclose(file_output);

        $display("Loaded %0d input samples and %0d golden output samples.", test_length, test_length);
     end

    // Reset, initialize signals, send all test samples and then print final results
    initial begin
      reset = 1'b1;

      idx_L2  = 0;
      idx_L3  = 0;

      input_sample     = 0;
      input_valid      = 0;

      input_sample0_L2 = 0;
      input_sample1_L2 = 0;
      input_valid_L2   = 0;

      input_sample0_L3 = 0;
      input_sample1_L3 = 0;
      input_sample2_L3 = 0;
      input_valid_L3   = 0;

      // golden output starting index
      golden_index_base    = -1;
      golden_index_pipe    = 0;
      golden_index_L2      = 0;
      golden_index_L3      = 0;
      golden_index_L3_pipe = 0;

      // clear mismatch counters, checked counters, and max errors
      mismatch_count_base    = 0;
      mismatch_count_pipe    = 0;
      mismatch_count_L2      = 0;
      mismatch_count_L3      = 0;
      mismatch_count_L3_pipe = 0;

      total_checked_base    = 0;
      total_checked_pipe    = 0;
      total_checked_L2      = 0;
      total_checked_L3      = 0;
      total_checked_L3_pipe = 0;

      max_error_base    = 0;
      max_error_pipe    = 0;
      max_error_L2      = 0;
      max_error_L3      = 0;
      max_error_L3_pipe = 0;

        #20;
        @(posedge clk);
        reset <= 0;

      // Sends test samples to all architectures
      for (sample_index = 0; sample_index < test_length; sample_index = sample_index + 1) begin
        @(negedge clk);

         // Single-rate (every cycle)
         input_sample <= input_vector[sample_index];
         input_valid  <= 1;

         // L=2 (every 2 samples)
         if (sample_index % 2 == 0) begin
           input_valid_L2 <= 1;
           input_sample0_L2 <= input_vector[idx_L2];
           input_sample1_L2 <= (idx_L2 + 1 < test_length) ? input_vector[idx_L2+1] : 0;
           idx_L2 = idx_L2 + 2;
          end
         else begin
           input_valid_L2 <= 0;
          end

         // L=3 (every 3 samples)
         if (sample_index % 3 == 0) begin
          input_valid_L3 <= 1;
          input_sample0_L3 <= input_vector[idx_L3];
          input_sample1_L3 <= (idx_L3 + 1 < test_length) ? input_vector[idx_L3+1] : 0;
          input_sample2_L3 <= (idx_L3 + 2 < test_length) ? input_vector[idx_L3+2] : 0;
          idx_L3 = idx_L3 + 3;
         end
        else begin
          input_valid_L3 <= 0;
         end
       end

      // Stop driving inputs and let the FIR pipelines finish outputting
      @(negedge clk);
      input_valid     <= 0;
      input_valid_L2  <= 0;
      input_valid_L3  <= 0;

      repeat (tap_number + 100) @(posedge clk);


        // Prints pass or fail for all architectures
        $display("======== FINAL RESULTS ========");

        $display("\nBASELINE FIR:");
        $display("Total outputs checked : %0d", total_checked_base);
        $display("Mismatch count        : %0d", mismatch_count_base);
        $display("Maximum absolute error: %0d", max_error_base);
        if (mismatch_count_base == 0) $display("RESULT                : PASS");
        else                          $display("RESULT                : FAIL");

        $display("\nPIPELINED FIR:");
        $display("Total outputs checked : %0d", total_checked_pipe);
        $display("Mismatch count        : %0d", mismatch_count_pipe);
        $display("Maximum absolute error: %0d", max_error_pipe);
        if (mismatch_count_pipe == 0) $display("RESULT                : PASS");
        else                          $display("RESULT                : FAIL");

        $display("\nPARALLEL FIR L=2:");
        $display("Total outputs checked : %0d", total_checked_L2);
        $display("Mismatch count        : %0d", mismatch_count_L2);
        $display("Maximum absolute error: %0d", max_error_L2);
        if (mismatch_count_L2 == 0) $display("RESULT                : PASS");
        else                        $display("RESULT                : FAIL");

        $display("\nPARALLEL FIR L=3:");
        $display("Total outputs checked : %0d", total_checked_L3);
        $display("Mismatch count        : %0d", mismatch_count_L3);
        $display("Maximum absolute error: %0d", max_error_L3);
        if (mismatch_count_L3 == 0) $display("RESULT                : PASS");
        else                        $display("RESULT                : FAIL");

        $display("\nPARALLEL FIR L=3 + PIPELINE:");
        $display("Total outputs checked : %0d", total_checked_L3_pipe);
        $display("Mismatch count        : %0d", mismatch_count_L3_pipe);
        $display("Maximum absolute error: %0d", max_error_L3_pipe);
        if (mismatch_count_L3_pipe == 0) $display("RESULT                : PASS");
        else                             $display("RESULT                : FAIL");

        $display("===============================\n");

        $finish;
    end



    // Compares each hardware output to the MATLAB golden output

       // Checks Baseline (1-cycle latency)
       always @(posedge clk) begin
         if (!reset && output_valid_base) begin

           if (golden_index_base >= 0 && golden_index_base < test_length) begin
             // Difference between hardware and MATLAB golden outputs
             error_base = filtered_output_base - golden_vector[golden_index_base];

             if (abs_int(error_base) > max_error_base)
               max_error_base = abs_int(error_base);

             total_checked_base = total_checked_base + 1;

             if (filtered_output_base !== golden_vector[golden_index_base]) begin
               mismatch_count_base = mismatch_count_base + 1;
               $display("BASE MISMATCH at sample %0d: expected=%0d got=%0d error=%0d", golden_index_base, golden_vector[golden_index_base], filtered_output_base, error_base);
              end
            end

           golden_index_base = golden_index_base + 1;
          end
        end

       // Checks Pipeline
       always @(posedge clk) begin
         if (!reset && output_valid_pipe &&
           (golden_index_pipe + PIPE_LATENCY < test_length)) begin
            // Difference between hardware and MATLAB golden outputs
            error_pipe = filtered_output_pipe - golden_vector[golden_index_pipe + PIPE_LATENCY];

           if (abs_int(error_pipe) > max_error_pipe)
             max_error_pipe = abs_int(error_pipe);

           total_checked_pipe = total_checked_pipe + 1;

           if (filtered_output_pipe !== golden_vector[golden_index_pipe + PIPE_LATENCY]) begin
             mismatch_count_pipe = mismatch_count_pipe + 1;
             $display("PIPE MISMATCH at sample %0d: expected=%0d got=%0d error=%0d", golden_index_pipe + PIPE_LATENCY, golden_vector[golden_index_pipe + PIPE_LATENCY], filtered_output_pipe, error_pipe);
            end

           golden_index_pipe = golden_index_pipe + 1;
          end
        end

        // Cehcks L=2
        always @(posedge clk) begin
          if (!reset && output_valid_L2 && (golden_index_L2 < test_length)) begin
            error_L2_0 = filtered_output0_L2 - golden_vector[golden_index_L2];
            if (abs_int(error_L2_0) > max_error_L2)
              max_error_L2 = abs_int(error_L2_0);

              total_checked_L2 = total_checked_L2 + 1;

              if (filtered_output0_L2 !== golden_vector[golden_index_L2]) begin
                mismatch_count_L2 = mismatch_count_L2 + 1;
                $display("L2 MISMATCH output0 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L2, golden_vector[golden_index_L2], filtered_output0_L2, error_L2_0);
               end

              golden_index_L2 = golden_index_L2 + 1;

              if (golden_index_L2 < test_length) begin
                // Difference between hardware and MATLAB golden outputs
                error_L2_1 = filtered_output1_L2 - golden_vector[golden_index_L2];
                if (abs_int(error_L2_1) > max_error_L2)
                  max_error_L2 = abs_int(error_L2_1);

                total_checked_L2 = total_checked_L2 + 1;

                if (filtered_output1_L2 !== golden_vector[golden_index_L2]) begin
                  mismatch_count_L2 = mismatch_count_L2 + 1;
                  $display("L2 MISMATCH output1 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L2, golden_vector[golden_index_L2], filtered_output1_L2, error_L2_1);
                 end

                golden_index_L2 = golden_index_L2 + 1;
               end
           end
         end

        // Checks L=3
        always @(posedge clk) begin
          if (!reset && output_valid_L3 && (golden_index_L3 < test_length)) begin
            error_L3_0 = filtered_output0_L3 - golden_vector[golden_index_L3];
            if (abs_int(error_L3_0) > max_error_L3)
              max_error_L3 = abs_int(error_L3_0);

            total_checked_L3 = total_checked_L3 + 1;

            if (filtered_output0_L3 !== golden_vector[golden_index_L3]) begin
              mismatch_count_L3 = mismatch_count_L3 + 1;
              $display("L3 MISMATCH output0 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L3, golden_vector[golden_index_L3], filtered_output0_L3, error_L3_0);
             end

            golden_index_L3 = golden_index_L3 + 1;

            if (golden_index_L3 < test_length) begin
              // Difference between hardware and MATLAB golden outputs
              error_L3_1 = filtered_output1_L3 - golden_vector[golden_index_L3];
              if (abs_int(error_L3_1) > max_error_L3)
                max_error_L3 = abs_int(error_L3_1);

              total_checked_L3 = total_checked_L3 + 1;

              if (filtered_output1_L3 !== golden_vector[golden_index_L3]) begin
                mismatch_count_L3 = mismatch_count_L3 + 1;
                $display("L3 MISMATCH output1 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L3, golden_vector[golden_index_L3], filtered_output1_L3, error_L3_1);
               end

              golden_index_L3 = golden_index_L3 + 1;
             end

            if (golden_index_L3 < test_length) begin
              // Difference between hardware and MATLAB golden outputs
              error_L3_2 = filtered_output2_L3 - golden_vector[golden_index_L3];
              if (abs_int(error_L3_2) > max_error_L3)
                max_error_L3 = abs_int(error_L3_2);

              total_checked_L3 = total_checked_L3 + 1;

              if (filtered_output2_L3 !== golden_vector[golden_index_L3]) begin
                mismatch_count_L3 = mismatch_count_L3 + 1;
                $display("L3 MISMATCH output2 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L3, golden_vector[golden_index_L3], filtered_output2_L3, error_L3_2);
               end

              golden_index_L3 = golden_index_L3 + 1;
             end
           end
         end

        // Checks L=3 + pipeline
        always @(posedge clk) begin
          if (!reset && output_valid_L3_pipe) begin
            if ((golden_index_L3_pipe + 0) >= 0 && (golden_index_L3_pipe + 0) < test_length) begin
              error_L3p_0 = filtered_output0_L3_pipe - golden_vector[golden_index_L3_pipe + 0];
              if (abs_int(error_L3p_0) > max_error_L3_pipe)
                max_error_L3_pipe = abs_int(error_L3p_0);

              total_checked_L3_pipe = total_checked_L3_pipe + 1;

              if (filtered_output0_L3_pipe !== golden_vector[golden_index_L3_pipe + 0]) begin
                mismatch_count_L3_pipe = mismatch_count_L3_pipe + 1;
                $display("L3_PIPE MISMATCH output0 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L3_pipe + 0, golden_vector[golden_index_L3_pipe + 0], filtered_output0_L3_pipe, error_L3p_0);
               end
             end

            if ((golden_index_L3_pipe + 1) >= 0 && (golden_index_L3_pipe + 1) < test_length) begin
              error_L3p_1 = filtered_output1_L3_pipe - golden_vector[golden_index_L3_pipe + 1];
                if (abs_int(error_L3p_1) > max_error_L3_pipe)
                  max_error_L3_pipe = abs_int(error_L3p_1);

                total_checked_L3_pipe = total_checked_L3_pipe + 1;

                if (filtered_output1_L3_pipe !== golden_vector[golden_index_L3_pipe + 1]) begin
                  mismatch_count_L3_pipe = mismatch_count_L3_pipe + 1;
                  $display("L3_PIPE MISMATCH output1 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L3_pipe + 1, golden_vector[golden_index_L3_pipe + 1], filtered_output1_L3_pipe, error_L3p_1);
                 end
             end

             if ((golden_index_L3_pipe + 2) >= 0 && (golden_index_L3_pipe + 2) < test_length) begin
               error_L3p_2 = filtered_output2_L3_pipe - golden_vector[golden_index_L3_pipe + 2];
                 if (abs_int(error_L3p_2) > max_error_L3_pipe)
                   max_error_L3_pipe = abs_int(error_L3p_2);

                 total_checked_L3_pipe = total_checked_L3_pipe + 1;

                 if (filtered_output2_L3_pipe !== golden_vector[golden_index_L3_pipe + 2]) begin
                   mismatch_count_L3_pipe = mismatch_count_L3_pipe + 1;
                   $display("L3_PIPE MISMATCH output2 at sample %0d: expected=%0d got=%0d error=%0d", golden_index_L3_pipe + 2, golden_vector[golden_index_L3_pipe + 2], filtered_output2_L3_pipe, error_L3p_2);
                  end
              end

              golden_index_L3_pipe = golden_index_L3_pipe + 3;
           end
         end

endmodule 
