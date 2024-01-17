module LZ77_Decoder (
    input        clk    ,
    input        rst_n  ,
    //input stream
    input  [7:0] i_data ,
    input        i_en   ,
    output       i_ready,
    //output stream
    output reg [7:0]  o_data ,
    output reg        o_en   ,
    input            o_ready
);
    reg       [1:0] cur_state,nxt_state;   
    parameter [2:0] IDLE      = 3'd0,
                    INPUT     = 3'd1,
                    DECODE1   = 3'd2,
                    DECODE2_1 = 3'd3,
                    DECODE2_2 = 3'd4,
                    FINISH    = 3'd5;
    reg  [4 :0] match_len;
    reg  [10:0] offset;
    reg  [12:0] decoded_length;

    integer i;
    reg  [7 :0] buffer [4095 : 0];
    reg  [11:0] wptr,rptr;
    wire [11:0] rptr_next = (decoded_length == 4096)   ? 0            :
                            (o_en & o_ready)           ? (rptr+12'd1) : rptr;



always @(posedge clk or negedge rst_n) begin
    if(~rst_n)
        cur_state <= IDLE;
    else
        cur_state <= nxt_state;
end

always @(posedge clk or negedge rst_n) begin
    if(~rst_n)begin
        match_len <= 0;
        offset    <= 0;
        decoded_length <= 0;
        wptr      <= 0;
        for(i=0;i<4096;i=i+1)begin
            buffer[i] <= 0;
        end

    end
    else begin
        case (cur_state)
            IDLE    : begin
                match_len    <= i_data[4:0];
                offset[2:0]  <= i_data[7:5];
            end 

            DECODE1 : begin
                buffer[wptr] <= i_data;
                wptr         <= wptr + 12'd1;
                decoded_length<= decoded_length + 1;
            end

            DECODE2_1 : begin
                offset[10:3] <= i_data;
            end

            DECODE2_2 : begin
                buffer[wptr] <= buffer[wptr-offset];
                wptr         <= wptr + 12'd1;
                match_len    <= match_len - 1;
                decoded_length<= decoded_length + 1;
            end

            FINISH    : begin
                wptr <= 0;
            end 
        endcase
    end
end


always @(*) begin
    case (cur_state)
        IDLE: begin
            nxt_state = (i_en == 0)                  ? IDLE    : INPUT;      
        end
        INPUT:begin
            nxt_state = (match_len == 0)             ? DECODE1 : DECODE2_1;
        end
        DECODE1     : begin
            nxt_state = (decoded_length == 13'd4096) ? FINISH  :IDLE;
        end
        DECODE2_1   : begin
            nxt_state = DECODE2_2;
        end
        DECODE2_2   : begin
            nxt_state = (decoded_length == 13'd4096) ? FINISH    :
                        (match_len == 0)             ? DECODE2_2 : IDLE;
        end
        FINISH      : begin
            nxt_state = IDLE;
        end
    endcase
end

//output
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        rptr   <= 0;
        o_en   <= 0;
        o_data <= 0;
    end
    else begin
        rptr   <= rptr_next;
        o_en   <= (rptr_next != wptr);
        o_data <= buffer[rptr_next];
    end
end
endmodule