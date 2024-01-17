module LZ77_Encoder (
    input 				clk         ,
    input 				rst_n       ,
    // input stream
    output              i_rdy       ,
    input               i_en        ,
    input   [7:0]       i_data      ,


    output reg 			o_en        ,
    output   			finish      ,

    output reg 	[7:0] 	o_data
);
    //send input data to a fifo, depth 4096
    wire        valid_encode             ;
    wire [7:0]  chardata                 ;    
    reg         ready_encode             ;
    sync_fifo input_fifo (
        .rstn    (rst_n)         ,
        .clk     (clk)           ,
        //in            
        .i_rdy   (i_rdy)         ,
        .i_en    (i_en)          ,
        .i_data  (i_data)        ,
        //out
        .o_rdy   (ready_encode)  ,
        .o_en    (valid_encode)       ,
        .o_data  (chardata)
    );

    reg       [1:0] cur_state,
                    nxt_state;
    parameter [1:0] IDLE    = 3'b00,
                    INPUT   = 3'b01,
                    SEARCH  = 3'b11,
                    OUTPUT  = 3'b10;

    reg [7 :0]      search_buffer       [1023:0];   //1024byte
    reg [7 :0]      look_ahead_buffer   [15  :0];   //16byte
    reg [12:0]      encoded_length              ;   //0~4096

    integer i;

    reg [3 :0]      count_input                 ;   //0~15
    reg             count_out                   ;   //0~1 or 0~2
    reg [4 :0]      count_shift                 ;
    reg             count_search                ;
    reg             finish_out                  ;
    reg             finish_shift                ;

    wire [1024*8-1:0] search_buffer_w           ;
    wire [16*8-1  :0] look_ahead_buffer_w       ;
    wire [4     :0] match_len1, match_len2      ;
    wire [10    :0] SB_index1,  SB_index2       ;
    reg  [4     :0] match_len                   ;
    reg  [10    :0] SB_index                    ;   

    genvar j;
    generate
        for(j=0 ; j<1024 ; j=j+1)begin
            assign search_buffer_w[8*(j+1)-1 : 8*j]     = search_buffer[j];
        end
        for(j=0 ; j<16   ; j=j+1)begin
            assign look_ahead_buffer_w[8*(j+1)-1 : 8*j] = look_ahead_buffer[j];
        end
    endgenerate

    search search_u0(
    .clk                 (clk)                              ,
    .rst_n               (rst_n)                            ,
    .look_ahead_buffer_w (look_ahead_buffer_w)              ,
    .search_buffer_w     (search_buffer_w[8*512-1:0])       ,

    .match_len           (match_len1)                       ,
    .SB_index            (SB_index1)   
    );
    search search_u1(
    .clk                 (clk)                              ,
    .rst_n               (rst_n)                            ,
    .look_ahead_buffer_w (look_ahead_buffer_w)              ,
    .search_buffer_w     (search_buffer_w[8*1024-1:8*512])  ,

    .match_len           (match_len2)                       ,
    .SB_index            (SB_index2)   
    );

always@(posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        cur_state <= IDLE;
    end
    else
        cur_state <= nxt_state;
end

always @(posedge clk or negedge rst_n) begin
    if(~rst_n)begin
        ready_encode <= 0;
        finish_out   <= 0;
        finish_shift <= 0;
        count_input  <= 0;
        count_search <= 0;
        count_out    <= 0;
        count_shift  <= 0;
        match_len    <= 0;
        SB_index     <= 0;

        encoded_length <= 0;
        o_data       <= 0;
        o_en         <= 0;
    end
    else begin
        case (cur_state)
            IDLE    :   begin;
                //encoder is ready to work
                ready_encode <= 1;
                //reset search buffer and lool ahead buffer
                for(i=0 ; i<1024 ; i=i+1) begin
                    search_buffer[i] <= 0;
                end
                for(i=0 ; i<16 ; i=i+1)   begin
                    look_ahead_buffer[i] <= 0;
                end
                encoded_length <= 0;
            end
            INPUT   :   begin
                count_input          <= (count_input == 15)  ? 0 : (count_input + 1);
                ready_encode         <= (count_input == 15)  ? 0 : 1;
                for(i=0 ; i<15 ; i=i+1)   begin
                    look_ahead_buffer[i+1] <= look_ahead_buffer[i];
                end
                look_ahead_buffer[0] <= chardata;
            end
            SEARCH  :   begin
                //choose the longest match length from 2  512Byte search buffer
                count_search    <= (count_search == 0)  ? 1 : 0;
                if(count_search) begin
                    {match_len, SB_index} <= (match_len1 >= match_len2) ? {match_len1,SB_index1} : {match_len2,(SB_index2+12'd512)};
                    ready_encode <= 1;
                    finish_out   <= 0;
                    finish_shift <= 0;
                end
            end
            OUTPUT  :   begin
                if(~finish_out)begin
                    o_en        <= 1;
                    if(match_len == 0)  //gennerte 2 byte output data   i.e: matchlen,data
                        if(count_out == 0)  begin
                            o_data <= {3'b0,match_len};
                            count_out<= 1;
                        end
                        else    begin
                            o_data      <= look_ahead_buffer[15];
                            count_out   <= 0;
                            finish_out  <= 1;
                            encoded_length <= encoded_length + 1;
                        end
                    else    begin       //generate 2byte output data   i.e: matchlen,offset
                        if(count_out == 0)  begin
                            o_data <= {SB_index[2:0],match_len};
                            count_out<= 1;
                        end
                        else    begin
                            o_data <= SB_index[10:3];
                            count_out   <= 0;
                            finish_out  <= 1;
                            encoded_length <= encoded_length + match_len;
                        end
                    end
                end
                else 
                    o_en        <= 0;

                
                if(~finish_shift)begin
                    if((match_len == 0)||(match_len ==1))begin
                            for(i=0;i<1024;i=i+1)
                                search_buffer[i+1]      <= search_buffer[i];
                            search_buffer[0]            <= look_ahead_buffer[15];
                            for(i=0;i<16;i=i+1)
                                look_ahead_buffer[i+1]  <= look_ahead_buffer[i];
                            look_ahead_buffer[0]        <= chardata;
                            finish_shift                <= 1;
                            ready_encode                <= 0;
                    end
                    else begin
                        if(count_shift != (match_len-1)) begin
                            for(i=0;i<1024;i=i+1)
                                search_buffer[i+1]      <= search_buffer[i];
                            search_buffer[0]            <= look_ahead_buffer[15];
                            for(i=0;i<16;i=i+1)
                                look_ahead_buffer[i+1]  <= look_ahead_buffer[i];
                            look_ahead_buffer[0]        <= chardata;
                            count_shift                 <= count_shift + 1;
                        end
                        else begin
                            finish_shift        <= 1;
                            ready_encode        <= 0;
                            count_shift         <= 0;
                        end
                    end
                end
            end
        endcase
    end
end

always@(*)  begin
    case(cur_state)
        IDLE  : begin
            nxt_state = valid_encode                ?   INPUT   : IDLE ;
        end
        INPUT : begin
            nxt_state = (count_input == 15)         ?   SEARCH  : INPUT;
        end
        SEARCH :begin
            nxt_state = count_search                ?   OUTPUT  : SEARCH;
        end
        OUTPUT :begin
            nxt_state = (encoded_length >= 13'd4096)?   IDLE    :
                        (finish_out && finish_shift)?   SEARCH  : OUTPUT;
        end
    endcase
end


assign finish = (encoded_length >= 13'd4096)  ? 1 : 0;

    
endmodule