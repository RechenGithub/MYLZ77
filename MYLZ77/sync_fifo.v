
module sync_fifo #(
    parameter            DW = 8   // data width
) (
    input  wire          rstn,
    input  wire          clk,
    // input stream
    output wire          i_rdy,
    input  wire          i_en,
    input  wire [DW-1:0] i_data,
    // output stream
    input  wire          o_rdy,
    output reg           o_en,
    output reg  [DW-1:0] o_data
);


reg  [12:0] wptr    = 13'd0;
reg  [12:0] wptr_d1 = 13'd0;
reg  [12:0] wptr_d2 = 13'd0;
reg  [12:0] rptr    = 13'd0;
wire [12:0] rptr_next = (o_en & o_rdy) ? (rptr+13'd1) : rptr;

reg  [DW-1:0] buffer [4095:0];

assign i_rdy = ( wptr != {~rptr[12], rptr[11:0]} );


always @ (posedge clk or negedge rstn)
    if (~rstn)
        {wptr_d2, wptr_d1} <= 24'd0;
    else
        {wptr_d2, wptr_d1} <= {wptr_d1, wptr};

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        wptr <= 12'h0;
    end else begin
        if (i_en & i_rdy)
            wptr <= wptr + 12'h1;
    end

always @ (posedge clk)
    if (i_en & i_rdy)
        buffer[wptr[11:0]] <= i_data;


always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        rptr <= 13'h0;
        o_en <= 1'b0;
    end else begin
        rptr <= rptr_next;
        o_en <= (rptr_next != wptr_d2);
    end

always @ (posedge clk)
    o_data <= buffer[rptr_next[11:0]];

endmodule

