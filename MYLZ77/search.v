module search (
    input clk                                      ,              
    input rst_n                                    ,

    input [512 *8-1:0] search_buffer_w             ,
    input [16*8-1  :0] look_ahead_buffer_w         ,

    output     [4:0]   match_len                   ,
    output    [10:0]   SB_index
);

    wire   [7:0]  look_ahead_buffer   [15 : 0]    ;
    wire   [7:0]  search_buffer       [511: 0]    ;
    genvar j;
    generate
        for(j=0 ; j<512  ; j=j+1)begin
            assign  search_buffer[j]    = search_buffer_w[8*(j+1)-1 : 8*j];
        end
        for(j=0 ; j<16   ; j=j+1)begin
            assign  look_ahead_buffer[j]= look_ahead_buffer_w[8*(j+1)-1 : 8*j];
        end
    endgenerate
    wire    [4:0]   equal     [15:0]  ;
    wire    [3:0]   match_fail        ;
    genvar i;
    generate
        for(i=0 ; i<16 ; i=i+1) begin
            find_equal find_equal_i(
                .look_ahead_buffer  (look_ahead_buffer[15])                 ,
                .search_buffer_w    (search_buffer_w[256*(i+1)-1:256*i])    ,
                .equal              (equal[i])                              ,
                .match_fail         (match_fail[i])
            );
        end
    endgenerate

    wire [10:0] SB_index_w,SB_index_w2;
    assign  SB_index_w =  (equal[15] != 0) ?  (15*32 + equal[15])     :
                        (equal[14] != 0) ?  (14*32 + equal[14])     :
                        (equal[13] != 0) ?  (13*32 + equal[13])     :
                        (equal[12] != 0) ?  (12*32 + equal[12])     :
                        (equal[11] != 0) ?  (11*32 + equal[11])     :
                        (equal[10] != 0) ?  (10*32 + equal[10])     :
                        (equal[9 ] != 0) ?  (9 *32 + equal[9])      :
                        (equal[8 ] != 0) ?  (8 *32 + equal[8])      :
                        (equal[7 ] != 0) ?  (7 *32 + equal[7])      :
                        (equal[6 ] != 0) ?  (6 *32 + equal[6])      :
                        (equal[5 ] != 0) ?  (5 *32 + equal[5])      :
                        (equal[4 ] != 0) ?  (4 *32 + equal[4])      :
                        (equal[3 ] != 0) ?  (3 *32 + equal[3])      :
                        (equal[2 ] != 0) ?  (2 *32 + equal[2])      :
                        (equal[1 ] != 0) ?  (1 *32 + equal[1])      :
                      /*(equal[0] != 0)?*/  (0 *32 + equal[0]);

    assign SB_index_w2 = (SB_index_w < 11'd16) ? (SB_index_w + 11'd16) : SB_index_w;

    reg    [10:0]   SB_index;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)
            SB_index <= 16;
        else
            SB_index <= SB_index_w2;
    end


    wire [7 : 0]    match_xor [15:0];
    generate
        for(i=0;i<16;i=i+1)begin
            assign match_xor[i] = search_buffer[SB_index-15+i] ^ look_ahead_buffer [i] ;
        end
    endgenerate

    wire [15 : 0]   match_data16;
    wire [7  : 0]   match_data8 ;
    wire [3  : 0]   match_data4 ;
    wire [1  : 0]   match_data2 ;
    wire [3  : 0]   match_pos   ;
    generate
        for(i=0;i<16;i=i+1)begin
            assign match_data16[i] = (match_xor[i] == 0) ?  0 : 1;
        end
    endgenerate

    assign match_pos[3] = |match_data16[15:8];
    assign match_data8  = match_pos[3] ? match_data16[15:8] : match_data16[7:0];
    assign match_pos[2] = |match_data16[7:4];
    assign match_data4  = match_pos[2] ? match_data16[7:4] : match_data16[3:0];
    assign match_pos[1] = |match_data4[3:2];
    assign match_data2  = match_pos[1] ? match_data4[3:2] : match_data4[1:0];
    assign match_pos[0] = match_data2[1];

    assign match_len    = match_fail    ? 0 : (5'd16 - {0,match_pos});

     

/*
always@(*)begin
    if(match_fail)  begin
        match_len = 0;
    end
    else begin
        match_len = 1;
            if(( SB_index    !=0) && (search_buffer[SB_index-1 ] == look_ahead_buffer[15-1]))begin
                   match_len = 2; 
            if(((SB_index-1 )!=0) && (search_buffer[SB_index-2 ] == look_ahead_buffer[15-1]))begin
                   match_len = 2; 
            if(((SB_index-2 )!=0) && (search_buffer[SB_index-3 ] == look_ahead_buffer[15-1]))begin
                   match_len = 3; 
            if(((SB_index-3 )!=0) && (search_buffer[SB_index-4 ] == look_ahead_buffer[15-1]))begin
                   match_len = 4; 
            if(((SB_index-4 )!=0) && (search_buffer[SB_index-5 ] == look_ahead_buffer[15-1]))begin
                   match_len = 5; 
            if(((SB_index-5 )!=0) && (search_buffer[SB_index-6 ] == look_ahead_buffer[15-1]))begin
                   match_len = 6; 
            if(((SB_index-6 )!=0) && (search_buffer[SB_index-7 ] == look_ahead_buffer[15-1]))begin
                   match_len = 7; 
            if(((SB_index-7 )!=0) && (search_buffer[SB_index-8 ] == look_ahead_buffer[15-1]))begin
                match_len = 8; 
            if(((SB_index-8 )!=0) && (search_buffer[SB_index-9 ] == look_ahead_buffer[15-1]))begin
                match_len = 9; 
            if(((SB_index-9 )!=0) && (search_buffer[SB_index-10] == look_ahead_buffer[15-1]))begin
                match_len = 10; 
            if(((SB_index-10)!=0) && (search_buffer[SB_index-11] == look_ahead_buffer[15-1]))begin
                match_len = 11; 
            if(((SB_index-11)!=0) && (search_buffer[SB_index-12] == look_ahead_buffer[15-1]))begin
                match_len = 12; 
            if(((SB_index-12)!=0) && (search_buffer[SB_index-13] == look_ahead_buffer[15-1]))begin
                   match_len = 13; 
            if(((SB_index-13)!=0) && (search_buffer[SB_index-14] == look_ahead_buffer[15-1]))begin
                match_len = 14; 
            if(((SB_index-14)!=0) && (search_buffer[SB_index-15] == look_ahead_buffer[15-1]))begin
                match_len = 15; 
            end
            end
            end
            end
            end
            end
            end
            end
            end
            end
            end
            end
            end
            end
            end         
    end 
end
*/
endmodule




module find_equal (
    input   [7:0]       look_ahead_buffer            ,
    input   [8*32-1:0]  search_buffer_w              ,
    output  [4:0]       equal                        ,
    output              match_fail
);
    wire   [7:0]  search_buffer       [31: 0]    ;
    genvar j;
    generate
        for(j=0 ; j<32 ; j=j+1)begin
            assign  search_buffer[j]    = search_buffer_w[8*(j+1)-1 : 8*j];
        end
    endgenerate

    assign {match_fail,equal} = 
                      (search_buffer[0]  == look_ahead_buffer) ? 0   :
                      (search_buffer[1]  == look_ahead_buffer) ? 1   :
                      (search_buffer[2]  == look_ahead_buffer) ? 2   :
                      (search_buffer[3]  == look_ahead_buffer) ? 3   :
                      (search_buffer[4]  == look_ahead_buffer) ? 4   : 
                      (search_buffer[5]  == look_ahead_buffer) ? 5   :
                      (search_buffer[6]  == look_ahead_buffer) ? 6   :
                      (search_buffer[7]  == look_ahead_buffer) ? 7   :
                      (search_buffer[8]  == look_ahead_buffer) ? 8   :
                      (search_buffer[9]  == look_ahead_buffer) ? 9   :
                      (search_buffer[10] == look_ahead_buffer) ? 10  :
                      (search_buffer[11] == look_ahead_buffer) ? 11  :
                      (search_buffer[12] == look_ahead_buffer) ? 12  :
                      (search_buffer[13] == look_ahead_buffer) ? 13  :
                      (search_buffer[14] == look_ahead_buffer) ? 14  :
                      (search_buffer[15] == look_ahead_buffer) ? 15  :
                      (search_buffer[16] == look_ahead_buffer) ? 16  :
                      (search_buffer[17] == look_ahead_buffer) ? 17  : 
                      (search_buffer[18] == look_ahead_buffer) ? 18  :
                      (search_buffer[19] == look_ahead_buffer) ? 19  :
                      (search_buffer[20] == look_ahead_buffer) ? 20  :
                      (search_buffer[21] == look_ahead_buffer) ? 21  :
                      (search_buffer[22] == look_ahead_buffer) ? 22  :
                      (search_buffer[23] == look_ahead_buffer) ? 23  :
                      (search_buffer[24] == look_ahead_buffer) ? 24  :
                      (search_buffer[25] == look_ahead_buffer) ? 25  :
                      (search_buffer[26] == look_ahead_buffer) ? 26  :
                      (search_buffer[27] == look_ahead_buffer) ? 27  :
                      (search_buffer[28] == look_ahead_buffer) ? 28  :
                      (search_buffer[29] == look_ahead_buffer) ? 29  :
                      (search_buffer[30] == look_ahead_buffer) ? 30  : 
                      (search_buffer[31] == look_ahead_buffer) ? 31  :  32;
endmodule