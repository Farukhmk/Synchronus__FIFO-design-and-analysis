module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 8
)(
    input                   clk,
    input                   rst,
    input                   wr_en,
    input  [DATA_WIDTH-1:0] wr_data,
    input                   rd_en,
    output [DATA_WIDTH-1:0] rd_data,
    output                  full,
    output                  empty
);

    localparam PTR_WIDTH = $clog2(DEPTH);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers and count
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;
    reg [PTR_WIDTH:0]   count;

    // Write logic
    always @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr] <= wr_data;
    end

    // Pointer and count logic
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            if (wr_en && !full)
                wr_ptr <= wr_ptr + 1;

            if (rd_en && !empty)
                rd_ptr <= rd_ptr + 1;

            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1;
                2'b01:   count <= count - 1;
                default: count <= count;
            endcase
        end
    end

    // Outputs
    assign rd_data = mem[rd_ptr];
    assign full    = (count == DEPTH);
    assign empty   = (count == 0);

endmodule
