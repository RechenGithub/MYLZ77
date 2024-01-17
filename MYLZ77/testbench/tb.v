module tb  ();
    reg 				clk     ;   
    reg 				rst_n   ;  
    // input stream
    wire                i_rdy   ;   
    reg                 i_en    ;   
    reg   [7:0]         i_data  ;   
                        
    wire  			    o_en    ;   
    wire   			    finish  ;
    wire  	[7:0] 	    o_data  ;

LZ77_Encoder LZ77_Encoder_u(
.clk      (clk    ),
.rst_n    (rst_n  ),
.i_rdy    (i_rdy  ),
.i_en     (i_en   ),
.i_data   (i_data ),
.o_en     (o_en   ),
.finish   (finish ),
.o_data   (o_data )
);

initial begin
    rst_n  = 0;
    clk    = 0;
    i_en   = 1;
    #50    
    rst_n  = 1;
end

always #5 clk = ~clk;

reg		[13:0]	counter; // 8192+1
reg             stop_count;
initial begin
    i_data      = 0;
    stop_count  = 1;
    counter     = 0;
    #50
    stop_count  = 0;
end

always #10 begin
    if(~stop_count)begin 
        counter  = counter+1;
        i_data = {$random} % 10;
        //i_data = 1;
        if(counter == 4095)
            stop_count = 1;
    end
    else begin 
        counter     = 0;
        i_data      = 0;
    end
end

reg [13 : 0] out_count = 0;
always  #10  
begin
    if(o_en)    out_count = out_count + 1 ;
end


endmodule