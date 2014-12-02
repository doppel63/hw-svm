module pipeline_stage
  #(parameter DATA_SIZE = 32,
    parameter ACCUM_SIZE = 64,
    parameter NUM_FEAT = 2,
    parameter FEAT_I = 0)
( input   logic                               clk, rst, start_inner, last_inner,
  input   logic signed [DATA_SIZE-1:0]               sv,
  input   logic signed [NUM_FEAT-1:0][DATA_SIZE-1:0] curr_vector_in,
  input   logic signed [ACCUM_SIZE-1:0]              accum_in,
  output  logic signed [NUM_FEAT-1:0][DATA_SIZE-1:0] curr_vector_out,
  output  logic signed [ACCUM_SIZE-1:0]              accum_out);

  // state
  enum  logic {INIT, RUN} cs;

  always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
      accum_out <= 0;
      curr_vector_out <= 0;
      cs <= INIT;
    end else begin
      case (cs)
        INIT: if (start_inner) begin
                curr_vector_out <= curr_vector_in;
                accum_out <= accum_in + curr_vector_in[FEAT_I] * sv;
                cs <= RUN;
              end
        RUN:  begin
                accum_out <= accum_out + curr_vector_out[FEAT_I] * sv;
                cs <= (last_inner) ? INIT : RUN;
              end
      endcase
    end
  end

endmodule: pipeline_stage

module pipeline_tb;

  logic clk, rst, start_inner, last_inner;
  logic [31:0]      sv;
  logic [1:0][31:0] curr_vector_in, curr_vector_out;
  logic [63:0]      accum_in, accum_out;

  pipeline_stage dut(.*);

  initial begin
    clk = 1;
    forever #5 clk = ~clk;
  end

  initial begin
    rst = 1; start_inner = 0; last_inner = 0; curr_vector_in = 0;
    accum_in = 0; sv = 0;
    @(posedge clk);
    rst <= 0;
    @(posedge clk);
    curr_vector_in <= {32'd3, 32'd7};
    accum_in <= 0;
    sv <= 4;
    start_inner <= 1;
    @(posedge clk);
    start_inner <= 0;
    sv <= 2;
    last_inner <= 1;
    @(posedge clk);
    last_inner <= 0;
    @(posedge clk);
    $display("result = %d", accum_out); // should be 7*4 + 7*2 = 42
    $finish;
  end

endmodule: pipeline_tb
