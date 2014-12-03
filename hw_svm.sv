`define DATA_SIZE 32
`define ACCUM_SIZE 64
`define NUM_FEAT 16
`define NUM_SV 10
`define NUM_INST 5

/*
  NOTE: "results" is valid ONE CYCLE AFTER "done" is asserted!
*/
module hw_svm
( input   logic clk, rst, start,
  output  logic done);

  // support vectors
  logic [$clog2(`NUM_SV)-1:0]   sv_i;
  logic signed [`DATA_SIZE-1:0]  sv_in[`NUM_FEAT-1:0];
  //logic signed [`DATA_SIZE-1:0]  support_vectors[`NUM_SV-1:0][`NUM_FEAT-1:0];
  logic signed [`DATA_SIZE-1:0] support_vectors[`NUM_SV*`NUM_FEAT-1:0];
  // test vector stuff
  logic last_input;
  logic [$clog2(`NUM_INST)-1:0] test_i;
  logic signed [`NUM_FEAT-1:0][`DATA_SIZE-1:0] test_vectors[`NUM_INST-1:0];
  logic signed [`NUM_FEAT-1:0][`DATA_SIZE-1:0] test_vector;
  // interconnect
  logic signed [`NUM_FEAT-1:0][`NUM_FEAT-1:0][`DATA_SIZE-1:0]  curr_vector_in,
                                                        curr_vector_out;
  logic signed [`NUM_FEAT-1:0][`ACCUM_SIZE-1:0]                accum_in, accum_out;
  logic signed [`ACCUM_SIZE-1:0]       result;
  // misc
  logic                         start_inner, last_inner, final_inst;
  logic [$clog2(`NUM_FEAT)-1:0] delay;
  logic signed [`NUM_INST-1:0][`ACCUM_SIZE-1:0]  results;
  logic signed [`NUM_INST-1:0]         labels;
  
  initial begin
    $readmemh("sv.hex", support_vectors);
    $readmemh("test.hex", test_vectors);
  end

  int k;

  // labels are whether each result is negative
  always_comb begin
    for (k=0;k<`NUM_INST;k++)
      labels[k] = ~results[k][`ACCUM_SIZE-1];
  end
  
  // interconnect
  always_comb begin
	 case (sv_i)
		0:	sv_in = support_vectors[`NUM_FEAT-1:0];
		1:	sv_in = support_vectors[2*`NUM_FEAT-1:`NUM_FEAT];
		2:	sv_in = support_vectors[3*`NUM_FEAT-1:2*`NUM_FEAT];
		3:	sv_in = support_vectors[4*`NUM_FEAT-1:3*`NUM_FEAT];
		4:	sv_in = support_vectors[5*`NUM_FEAT-1:4*`NUM_FEAT];
		5:	sv_in = support_vectors[6*`NUM_FEAT-1:5*`NUM_FEAT];
		6:	sv_in = support_vectors[7*`NUM_FEAT-1:6*`NUM_FEAT];
		7:	sv_in = support_vectors[8*`NUM_FEAT-1:7*`NUM_FEAT];
		8:	sv_in = support_vectors[9*`NUM_FEAT-1:8*`NUM_FEAT];
		9:	sv_in = support_vectors[10*`NUM_FEAT-1:9*`NUM_FEAT];
		default:	sv_in = support_vectors[`NUM_FEAT-1:0];
	 endcase
	 //sv_in = support_vectors[sv_i];
    test_vector = test_vectors[test_i];
    last_input = test_i == (`NUM_INST-1);
    curr_vector_in = {curr_vector_out[`NUM_FEAT-2:0], test_vector};
    accum_in = {accum_out[`NUM_FEAT-2:0], `ACCUM_SIZE'd0};
    result = accum_out[`NUM_FEAT-1];
  end

  generate
    genvar i; // i is index of feature
    for (i=0; i<`NUM_FEAT; i++) begin: PIPELINE
      pipeline_stage #(`DATA_SIZE, `ACCUM_SIZE, `NUM_FEAT, i)
                      pipeline_module(.sv(sv_in[i]),
                                      .curr_vector_in(curr_vector_in[i]),
                                      .accum_in(accum_in[i]),
                                      .curr_vector_out(curr_vector_out[i]),
                                      .accum_out(accum_out[i]),
                                      .*);
    end
  endgenerate

  // state stuff
  enum  logic [1:0] {INIT, RUN, RUN_LAST, DONE} cs;

  always_comb begin
    start_inner = ((cs == INIT) && start) ||
                  (((cs == RUN) || (cs == RUN_LAST)) && (sv_i == 0));
    last_inner = sv_i == (`NUM_SV-1);
    final_inst = delay == (`NUM_FEAT-1);
    done = cs == DONE;
  end

  always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
      sv_i <= 0;
      test_i <= 0;
      delay <= 0;
      cs <= INIT;
    end else begin
      case (cs)
        INIT:     begin
                    sv_i <= (start) ? 1 : sv_i;
                    cs <= (start) ? RUN : INIT;
                  end
        RUN:      begin
                    sv_i <= (last_inner) ? 0 : sv_i + 1;
                    test_i <= (sv_i == (`NUM_SV-1)) ? test_i + 1 : test_i;
                    delay <= (last_input) ? 0 : delay;
                    cs <= (last_input) ? RUN_LAST : RUN;
                  end
        RUN_LAST: begin
                    sv_i <= (last_inner) ? 0 : sv_i + 1;
                    test_i <= (sv_i == (`NUM_SV-1)) ? test_i + 1 : test_i;
                    delay <= (last_inner) ? delay + 1 : delay;
                    cs <= (final_inst && last_inner) ? DONE : RUN_LAST;
                  end
        DONE:     begin
                    sv_i <= 0;
                    test_i <= 0;
                    cs <= INIT;
                  end
      endcase
    end
  end

  // separate counter to track when results are valid
  result_counter #(`ACCUM_SIZE, `NUM_FEAT, `NUM_SV, `NUM_INST) rc(.*);
 
endmodule: hw_svm
/*
module hw_svm_tb;

  // assume 3 SVs, 2 features, 2 test instances, 32 bit data, 64 bit accum
  logic clk, rst, start;
  logic done;

  int i;

  hw_svm dut(.*);

  initial begin
    clk = 1;
    forever #5 clk = ~clk;
  end

  initial begin
    rst = 1; start = 0;
    @(posedge clk);
    rst <= 0;
    @(posedge clk);
    // begin test sequence
    start <= 1;
    @(posedge clk);
    start <= 0;
    //$monitor("accum[0]: %x, accum[1]: %x, result: %x",
    //          dut.accum_out[0], dut.accum_out[1], dut.result);
    @(posedge done);
    repeat (2) @(posedge clk);
    for (i=0;i<`NUM_INST;i++) $display("%x", dut.results[i]);
    $finish;
  end

endmodule: hw_svm_tb
*/