/*
 * takes the results from the MAC and puts it in "results" appropriately
 */
module result_counter
 #(parameter ACCUM_SIZE = 64,
   parameter NUM_FEAT = 2,
   parameter NUM_SV = 3,
   parameter NUM_INST = 2)
 (input   logic clk, rst, start, done,
  input   logic signed [ACCUM_SIZE-1:0]  result,
  output  logic signed [NUM_INST-1:0][ACCUM_SIZE-1:0]  results);

  enum  logic [1:0] {IDLE, FIRST, LATER} count_cs;

  logic [$clog2(NUM_SV*NUM_FEAT)-1:0] count;
  logic [$clog2(NUM_INST)-1:0]        result_i;

  logic valid;  // for internal testing and validation

  always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
      count <= 0;
      result_i <= 0;
      results <= 0;
      count_cs <= IDLE;
    end else begin
      case (count_cs)
        IDLE:   begin
                  count <= (start) ? count + 1 : 0;
                  result_i <= 0;
                  count_cs <= (start) ? FIRST : IDLE;
                end
        FIRST:  begin
                  if (count == NUM_SV * NUM_FEAT) begin
                    count <= 1;
                    result_i <= 1;
                    results[0] <= result;
                    count_cs <= LATER;
                  end else begin
                    count <= count + 1;
                    result_i <= 0;
                    count_cs <= FIRST;
                  end
                end
        LATER:  begin
                  if (done) begin
                    count <= 0;
                    result_i <= 0;
                    results[result_i] <= result;
                    count_cs <= IDLE;
                  end else begin
                    if (count == NUM_SV) begin
                      count <= 1;
                      result_i <= result_i + 1;
                      results[result_i] <= result;
                    end else begin
                      count <= count + 1;
                    end
                    count_cs <= LATER;
                  end
                end
      endcase
    end
  end
  
  always_comb begin
    valid = ((count_cs == FIRST) && (count == NUM_SV*NUM_FEAT)) ||
            ((count_cs == LATER) && (count == NUM_SV));
  end

endmodule: result_counter
