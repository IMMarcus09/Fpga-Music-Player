module chipmunks(input CLOCK_50, input CLOCK2_50, input [3:0] KEY, input [9:0] SW,
                 input AUD_DACLRCK, input AUD_ADCLRCK, input AUD_BCLK, input AUD_ADCDAT,
                 inout FPGA_I2C_SDAT, output FPGA_I2C_SCLK, output AUD_DACDAT, output AUD_XCK,
                 output [6:0] HEX0, output [6:0] HEX1, output [6:0] HEX2,
                 output [6:0] HEX3, output [6:0] HEX4, output [6:0] HEX5,
                 output [9:0] LEDR);
			
// signals that are used to communicate with the audio core
// DO NOT alter these -- we will use them to test your design

reg read_ready, write_ready, write_s;
reg [15:0] writedata_left, writedata_right;
reg [15:0] readdata_left, readdata_right;	
wire reset, read_s;

// signals that are used to communicate with the flash core
// DO NOT alter these -- we will use them to test your design

reg flash_mem_read;
reg flash_mem_waitrequest;
reg [22:0] flash_mem_address;
reg [31:0] flash_mem_readdata;
reg flash_mem_readdatavalid;
reg [3:0] flash_mem_byteenable;
reg rst_n, clk;


assign clk=CLOCK_50;
// The audio core requires an active high reset signal
assign reset = ~KEY[3];
assign rst_n = KEY[3];
assign flash_mem_byteenable = 4'b1111;
assign read_s = 1'b0;


//SW[1:0] 10 faster 
//10 slow
//00 or 11 same 

reg [1:0] Iterate_Counter_Upper;
reg [1:0] Iterate_Counter_Lower;

// DO NOT alter the instance names or port names below -- we will use them to test your design

clock_generator my_clock_gen(CLOCK2_50, reset, AUD_XCK);
audio_and_video_config cfg(CLOCK_50, reset, FPGA_I2C_SDAT, FPGA_I2C_SCLK);
audio_codec codec(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK,read_ready, write_ready,readdata_left, readdata_right,AUD_DACDAT);
flash flash_inst(.clk_clk(clk), .reset_reset_n(rst_n), .flash_mem_write(1'b0), .flash_mem_burstcount(1'b1),
                 .flash_mem_waitrequest(flash_mem_waitrequest), .flash_mem_read(flash_mem_read), .flash_mem_address(flash_mem_address),
                 .flash_mem_readdata(flash_mem_readdata), .flash_mem_readdatavalid(flash_mem_readdatavalid), .flash_mem_byteenable(flash_mem_byteenable), .flash_mem_writedata());

// your code for the rest of this task here






//Defining the states
`define Wait                    6'b000_000
`define Reset                   6'b000_001
`define Assert_Read_Flash       6'b000_010
`define Flash_Wait              6'b000_011
`define Receive_Flash_Data      6'b000_100
`define Wait_Write_Ready        6'b000_101
`define Assert_Write_Lower      6'b000_110         
`define Wait_Write_Lower_Done   6'b000_111          //Here we wait for write to go low 
`define Write_Lower_Done        6'b001_000          //Here we wait for write ready again 
`define Assert_Write_Upper      6'b001_001
`define Wait_Write_Upper_Done   6'b001_010
`define Write_Upper_Done        6'b001_011
`define Increment               6'b001_100

//Newly added states for Task 6
//To slow down playback rate we want to write the same sample twice
`define Assert_Write_Lower_Slow             6'b001_101       
`define Wait_Write_Lower_Done_Slow          6'b001_110
`define Write_Lower_Done_Slow               6'b001_111
`define Assert_Write_Upper_Slow             6'b010_000
`define Wait_Write_Upper_Done_Slow          6'b010_001
`define Write_Upper_Done_Slow               6'b010_010
          
//To increase the playback rate we only write the half sample 
`define Assert_Write_Lower_Chip             6'b010_011
`define Wait_Write_Lower_Done_Chip          6'b010_100
`define Write_Lower_Done_Chip               6'b010_101
`define Assert_Write_Upper_Chip             6'b010_110
`define Wait_Write_Upper_Done_Chip          6'b010_111
`define Write_Upper_Done_Chip               6'b011_000
`define Increment_Chip                      6'b011_001
          


//We want to be in wait state at default
reg [5:0]state=`Wait;

reg [22:0] Counter;
wire[22:0]  FSM_Counter;
assign FSM_Counter=Counter;
reg [31:0] Temp;
//First sample lower of address 0
//Last sample upper of 0x7FFFF[524287]
//There are 0x200000 samples[2097152]
//Means we have to read 1048576 addresses
//address 1048575 is 0xFFFFF


//Did not specify asynchronous reset 
always@(posedge clk)begin
    if(reset)begin
        state=`Reset;
    end 
    else begin
        case(state)
            `Wait:begin
                state=`Wait;
            end 
            `Reset:begin
                state=`Assert_Read_Flash;
            end 

            `Assert_Read_Flash:begin
                state=`Flash_Wait;
            end 

            `Flash_Wait:begin
                if(flash_mem_waitrequest)begin
                    state=`Flash_Wait;
                end 
                else begin
                    state=`Receive_Flash_Data;
                end 
            end 

            `Receive_Flash_Data:begin
                if(flash_mem_readdatavalid)begin
                    state=`Wait_Write_Ready;
                end 
                else begin//If the data is not valid we want to wait herefor the valid data 
                    state=`Receive_Flash_Data;
                end    
            end 

            `Wait_Write_Ready:begin
                if(write_ready)begin    //We wait for ready to be high before  movingto the next state 
                    if(SW[1:0]==2'b01)begin
                        state=`Assert_Write_Lower_Chip;
                    end
                    else if(SW[1:0]==2'b10)begin
                        state=`Assert_Write_Lower_Slow;
                    end 
                    else begin
                        state=`Assert_Write_Lower;
                    end 
                end 
                else begin //When ready is low we stay hjere to wait for it to be high 
                    state=`Wait_Write_Ready;
                end 
            end 

            `Assert_Write_Lower:begin       //We assert write signal here
                state=`Wait_Write_Lower_Done;
            end 

            `Wait_Write_Lower_Done:begin    //Here we are waiting for ready signal to be low which indicates that it is writing 
                if(write_ready)begin        //When write is still 1 means that it is still has not begun writing 
                    state=`Wait_Write_Lower_Done;
                end 
                else begin//When write ready is low means it has begun writing 
                    state=`Write_Lower_Done;
                end 
            end 

            `Write_Lower_Done:begin //Here we wait for writing to complete 
                if(write_ready)begin    //When ready is 1 again means it has completed writing
                    state=`Assert_Write_Upper;//So we move to write the upper sample 
                end 
                else begin  //When ready is low means it is stil writing
                    state=`Write_Lower_Done;
                end 
            end 
            
            `Assert_Write_Upper:begin
                state=`Wait_Write_Upper_Done;
            end 

            `Wait_Write_Upper_Done:begin
                 if(write_ready)begin   //When ready is 1 means it has not started writing
                    state=`Wait_Write_Upper_Done;
                end 
                else begin//When write ready is low means it has started writing
                    state=`Write_Upper_Done;
                end 
            end 

            `Write_Upper_Done:begin
                if(write_ready)begin//When ready is high again means it has finnish writing  
                    state=`Increment;
                end 
                else begin//When ready is still low means we are still wriing so we want to stat at this state
                    state=`Write_Upper_Done;
                end 
            end 

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //States added for SLOW 
            `Assert_Write_Lower_Slow :begin
                state=`Wait_Write_Lower_Done_Slow;
            end 

            `Wait_Write_Lower_Done_Slow:begin
                if(write_ready)begin        //When write is still 1 means that it is still has not begun writing 
                    state=`Wait_Write_Lower_Done_Slow;
                end 
                else begin//When write ready is low means it has begun writing 
                    state=`Write_Lower_Done_Slow;
                end 
            end 

            `Write_Lower_Done_Slow:begin//We increment Iterate_Counter_Lower here when  write ready is 1
                if(write_ready)begin    //When ready is 1 again means it has completed writing
                    if(Iterate_Counter_Lower==2'd2)begin    //When counter equals 2 means we have writen twice so we proceed to next state 
                        state=`Assert_Write_Upper_Slow;//NEXT STATE 
                    end 
                    else begin
                        state=`Assert_Write_Lower_Slow;//Write same sample second time 
                    end 
                end 
                else begin  //When ready is low means it is stil writing
                    state=`Write_Lower_Done_Slow;
                end 
            end  

            `Assert_Write_Upper_Slow:begin
                state=`Wait_Write_Upper_Done_Slow;
            end 


            `Wait_Write_Upper_Done_Slow:begin
                  if(write_ready)begin   //When ready is 1 means it has not started writing
                    state=`Wait_Write_Upper_Done_Slow;//So we wait here until ready is deasserted
                end 
                else begin//When write ready is low means it has started writing
                    state=`Write_Upper_Done_Slow;//SO WE CAN PROCEED TO NEXT STATE
                end 
            end 
            `Write_Upper_Done_Slow:begin
                if(write_ready)begin    //When ready is 1 again means it has completed writing
                    if(Iterate_Counter_Upper==2'd2)begin    //When counter equals 2 means we have writen twice so we proceed to next state 
                        state=`Increment;//We go to normal incrementer not the chip incrementer 
                    end 
                    else begin
                        state=`Assert_Write_Upper_Slow;//Write same sample second time 
                    end 
                end 
                else begin  //When ready is low means it is stil writing
                    state=`Write_Upper_Done_Slow;//So we wait here
                end 
            end 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//CHIPMUNK SECTION
//We want to write same as normal but we increment by 2 instead of 1
`Assert_Write_Lower_Chip:begin       //We assert write signal here
                state=`Wait_Write_Lower_Done_Chip;
            end 

            `Wait_Write_Lower_Done_Chip:begin    //Here we are waiting for ready signal to be low which indicates that it is writing 
                if(write_ready)begin        //When write is still 1 means that it is still has not begun writing 
                    state=`Wait_Write_Lower_Done_Chip;
                end 
                else begin//When write ready is low means it has begun writing 
                    state=`Write_Lower_Done_Chip;
                end 
            end 

            `Write_Lower_Done_Chip:begin //Here we wait for writing to complete 
                if(write_ready)begin    //When ready is 1 again means it has completed writing
                    state=`Assert_Write_Upper_Chip;//So we move to write the upper sample 
                end 
                else begin  //When ready is low means it is stil writing
                    state=`Write_Lower_Done_Chip;
                end 
            end 
            
            `Assert_Write_Upper_Chip:begin
                state=`Wait_Write_Upper_Done_Chip;
            end 

            `Wait_Write_Upper_Done_Chip:begin
                 if(write_ready)begin   //When ready is 1 means it has not started writing
                    state=`Wait_Write_Upper_Done_Chip;
                end 
                else begin//When write ready is low means it has started writing
                    state=`Write_Upper_Done_Chip;
                end 
            end 

            `Write_Upper_Done_Chip:begin
                if(write_ready)begin//When ready is high again means it has finnish writing  
                    state=`Increment_Chip;
                end 
                else begin//When ready is still low means we are still wriing so we want to stat at this state
                    state=`Write_Upper_Done_Chip;
                end 
            end 

            `Increment_Chip:begin
                if(FSM_Counter>1048575)begin//When we reach  the last address we want to restarts from address 0
                    state=`Reset;
                end 
                else begin//After incrementing we want to read again 
                    state=`Assert_Read_Flash;
                end 
            end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            `Increment:begin
                //Last address we want to read is 7FFFF=524287
                if(FSM_Counter>1048575)begin//When we reach  the last address we want to restarts from address 0
                    state=`Reset;
                end 
                else begin//After incrementing we want to read again 
                    state=`Assert_Read_Flash;
                end 
            end 

            default:begin
                state=`Wait;
            end //default
        endcase
    end 
end 

//Flash Variables
    //[31:0] flash_mem_readdata;
    // flash_mem_readdatavalid;
    //flash_mem_waitrequest

//CODEC Variables
    //[31:0] flash_mem_readdata;
    //write_ready


always@(posedge clk)begin
    case(state)
        `Wait:begin
            //Flash Variables
            flash_mem_read=1'b0;
            flash_mem_address=23'd0;

            //Audio codec variables
            write_s=1'b0;
            writedata_left=16'd0;
            writedata_right=16'd0;

            //Internal Variables
            Counter=23'd0;
            Temp=32'd0;
            Iterate_Counter_Upper=2'd0;
            Iterate_Counter_Lower=2'd0;
            

        end 

        `Reset:begin
            //Flash Variables
            flash_mem_read=1'b0;
            flash_mem_address=23'd0;

            //Audio codec variables
            write_s=1'b0;
            writedata_left=16'd0;
            writedata_right=16'd0;

            //Internal Variables
            Counter=23'd0;
            Temp=32'd0;
            Iterate_Counter_Upper=2'd0;
            Iterate_Counter_Lower=2'd0;
         
        end 


        `Assert_Read_Flash:begin
            flash_mem_read=1'b1;
            flash_mem_address=Counter;
        end     


        `Flash_Wait:begin
         
        end     

                   
        `Receive_Flash_Data:begin
            flash_mem_read=1'b0;
            if(flash_mem_readdatavalid)begin
                Temp=flash_mem_readdata;
            end 
            else begin
                Temp=32'd0;
            end 
         
        end     

           
        `Wait_Write_Ready:begin
           
        end     

             
        `Assert_Write_Lower:begin
            write_s=1'b1;
            //Singed 
            if(Temp[15])begin
                writedata_left=Temp[15:0];
                writedata_right=Temp[15:0];
            end 
            else begin
                writedata_left=Temp[15:0];
                writedata_right=Temp[15:0];
            end 
            
        
        end     

           
        `Wait_Write_Lower_Done:begin
            if(write_ready)begin//When write ready is still high means it has not started 
                write_s=1;
            end 
            else begin//When write ready is low means it has started 
                write_s=0;
            end 
      
        end     

        
        `Write_Lower_Done:begin
            
        end     

             
        `Assert_Write_Upper:begin
            write_s=1;
            writedata_left=Temp[31:16];
            writedata_right=Temp[31:16];
          
        end     

           
        `Wait_Write_Upper_Done:begin
             if(write_ready)begin//When write ready is still high means it has not started 
                write_s=1;
            end 
            else begin//When write ready is low means it has started 
                write_s=0;
            end 
       
        end     

        
        `Write_Upper_Done:begin
            
        end     

             
        `Increment:begin
            Counter=Counter+1;
            Iterate_Counter_Upper=2'd0;
        end  
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  
//SLOW SECTION
        `Assert_Write_Lower_Slow:begin
            write_s=1;
            writedata_left=Temp[15:0];
            writedata_right=Temp[15:0];
        end   

        `Wait_Write_Lower_Done_Slow:begin
             if(write_ready)begin//When write ready is still high means it has not started 
                write_s=1;
            end 
            else begin//When write ready is low means it has started 
                write_s=0;
            end 
        end 
        `Write_Lower_Done_Slow:begin
            if(write_ready)begin//When write ready is 1 again means it has done writing so we incremnt the counter 
                Iterate_Counter_Lower=Iterate_Counter_Lower+1;
            end 
            else begin  
                Iterate_Counter_Lower=Iterate_Counter_Lower;
            end 
        end  


        `Assert_Write_Upper_Slow:begin
            write_s=1;
            writedata_left=Temp[31:16];
            writedata_right=Temp[31:16];

            Iterate_Counter_Lower=2'd0;//When we reach here we want to clear the counter 
        end 


        `Wait_Write_Upper_Done_Slow:begin
            if(write_ready)begin//When write ready is still high means it has not started 
                write_s=1;
            end 
            else begin//When write ready is low means it has started 
                write_s=0;
            end 
        end


        `Write_Upper_Done_Slow:begin
            if(write_ready)begin//When write ready is 1 again means it has done writing so we incremnt the counter 
                Iterate_Counter_Upper=Iterate_Counter_Upper+1;
            end 
            else begin  
                Iterate_Counter_Upper=Iterate_Counter_Upper;
            end 
        end 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////          
//CHIP SECTION 
        `Assert_Write_Lower_Chip:begin
            write_s=1'b1;
            //Singed 
            if(Temp[15])begin
                writedata_left=Temp[15:0];
                writedata_right=Temp[15:0];
            end 
            else begin
                writedata_left=Temp[15:0];
                writedata_right=Temp[15:0];
            end 
        end     

           
        `Wait_Write_Lower_Done_Chip:begin
            if(write_ready)begin//When write ready is still high means it has not started 
                write_s=1;
            end 
            else begin//When write ready is low means it has started 
                write_s=0;
            end 
      
        end     

        
        `Write_Lower_Done_Chip:begin
            
        end     

             
        `Assert_Write_Upper_Chip:begin
            write_s=1;
            writedata_left=Temp[31:16];
            writedata_right=Temp[31:16];
          
        end     

           
        `Wait_Write_Upper_Done_Chip:begin
             if(write_ready)begin//When write ready is still high means it has not started 
                write_s=1;
            end 
            else begin//When write ready is low means it has started 
                write_s=0;
            end 
       
        end     

        
        `Write_Upper_Done_Chip:begin
            
        end     

             
        `Increment_Chip:begin
            Counter=Counter+2;
        end          

        default:begin
            //Flash Variables
            flash_mem_read=1'b0;
            flash_mem_address=23'd0;

            //Audio codec variables
            write_s=1'b0;
            writedata_left=16'd0;
            writedata_right=16'd0;

            //Internal Variables
            Counter=23'd0;
            Temp=32'd0;
        
        end 
    endcase
end 

endmodule 

//we make atemp to record the data then spli the datat inleft roight 
//nmormal thenwe el;ft right upper lwoer
//slower , we want o wroite each data twice 
//what is we read 2 addresses at once 
