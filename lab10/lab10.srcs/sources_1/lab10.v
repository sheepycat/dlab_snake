`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
//
// Create Date: 2018/12/11 16:04:41
// Design Name:
// Module Name: lab9
// Project Name:
// Target Devices:
// Tool Versions:
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
//
// Dependencies: vga_sync, clk_divider, sram
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
   
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );







// declare SRAM control signals
wire [16:0] sram_addr;
wire [16:0] sram_addr_h;
wire [16:0] sram_addr_s;
wire [16:0] sram_addr_e;


wire [11:0] data_in;
wire [11:0] data_out;

wire [11:0] data_out_h;
wire [11:0] data_out_s;
wire [11:0] data_out_l;
wire [11:0] data_out_w;



wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
 
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
 
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639)
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
 
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel

// Application-specific VGA signals
reg  [17:0] pixel_addr;
reg  [17:0] pixel_addr_h;
reg  [17:0] pixel_addr_s;
reg  [17:0] pixel_addr_e;



integer move_delay = 0;
reg pause;
// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// snake
localparam snake_W      = 10; // Width of the user
localparam snake_H      = 10; // Height of the user
reg [17:0] snake_addr[0:2];

localparam H_VPOS      = 15;
localparam heart_W      = 64; // Width of the user
localparam heart_H      = 32; // Height of the user
reg  [17:0] heart_addr[0:2];
wire heart_region;
localparam S_VPOS      = 15;
localparam score_W      = 64; // Width of the user
localparam score_H      = 32; // Height of the user
reg  [17:0] score_addr[0:3];
wire score_region;
localparam E_VPOS      = 88;
localparam e_W      = 64; // Width of the user
localparam e_H      = 80; // Height of the user
wire end_region;
//assign heart_region = ((pixel_x>=477&&pixel_x<=605)&&(pixel_y>=25&&pixel_y<=89));
assign heart_region =  pixel_y >= (H_VPOS<<1) && pixel_y < (H_VPOS+heart_H)<<1 &&
                      (pixel_x + 127) >= 605 && pixel_x < 605 + 1;
assign score_region =  pixel_y >= (S_VPOS<<1) && pixel_y < (S_VPOS+heart_H)<<1 &&
                      (pixel_x + 127) >= 476 && pixel_x < 476 + 1;
assign end_region   =  pixel_y >= (E_VPOS<<1) && pixel_y < (E_VPOS+e_H)<<1 &&
                      (pixel_x + 127) >= 384 && pixel_x < 384 + 1;
initial begin
  heart_addr[0] =  'd0;         /* Addr for fish image #1 */
  heart_addr[1] = heart_H*heart_W;
  heart_addr[2] = heart_H*heart_W*2;
end
initial begin
  score_addr[0] =  'd0;         /* Addr for fish image #1 */
  score_addr[1] = score_H*score_W;
  score_addr[2] = score_H*score_W*2;
  score_addr[3] = score_H*score_W*3;
  score_addr[4] = score_H*score_W*4;
 // score_addr[4] = score_H*score_W*4;
end


wire btn_level[3:0];
debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);
debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);
debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level[2])
);
debounce btn_db3(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level[3])
);

///////////////////////////
reg [132:0]ball_x_pos=150; // Vertical location of the user
reg [132:0]ball_y_pos=400; // parallel po
reg [5:0]ball_r = 9;
wire r_region;
//wire[132:0] rand_x;
//wire[132:0] rand_y;
wire [0:0]state;
reg[0:0]state1=0;

assign r_region=( (pixel_x - ball_x_pos)*(pixel_x - ball_x_pos) + (pixel_y -ball_y_pos)*(pixel_y - ball_y_pos) <= (ball_r * ball_r));

/////////////////////////////////

reg[132:0] up_pos1 = 150;
reg[132:0] down_pos1 = 300;
reg[132:0] left_pos1 = 500;
reg[132:0] right_pos1 = 510;
reg[132:0] up_pos2 = 290;
reg[132:0] down_pos2 = 300;
reg[132:0] left_pos2 = 80;
reg[132:0] right_pos2 = 230;
reg[0:0]start1=0;
wire bar_region1;
wire bar_region2;
wire bar_region3;
reg [0:0]to_left;
///////////////////////////////////////

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit fish1 image, plus two 64x32 fish images.
// VBUF_W*VBUF_H+
// FISH_W*FISH_H*2
sram_seabed #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

         
// 3435
assign sram_we =  (usr_btn[0] && usr_btn[1] && usr_btn[2] && usr_btn[3]); // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------
sram_heart #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(heart_W*heart_H*3))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_h), .data_i(data_in), .data_o(data_out_h));
assign sram_addr_h = pixel_addr_h;

sram_score #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(score_W*score_H*5))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_s), .data_i(data_in), .data_o(data_out_s));
assign sram_addr_s = pixel_addr_s;

sram_lose #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(e_H*e_W))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_e), .data_i(data_in), .data_o(data_out_l));
assign sram_addr_s = pixel_addr_s;

sram_win #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(e_H*e_W))
  ram4 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_e), .data_i(data_in), .data_o(data_out_w));
assign sram_addr_e = pixel_addr_e;
// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec









localparam [3:0]
				MAIN_INIT = 0,
                GO_UP = 1,
                GO_RIGHT = 2,
                GO_DOWN = 3,
                GO_LEFT = 4,
                STOP = 5,
                LOSE = 6,
                COVER = 7,
                LV_CHANGE=8,
                WIN =9;

reg [1:0]cur_lv;
reg hit_bar;
reg hit_edge;
reg hit_self;
reg [2:0] heart;
reg [2:0] score;
reg [3:0] P, P_next;
wire lv_end;
assign lv_end = (score>=5 )? 1:0;



always @(posedge clk) begin
    if (~reset_n) begin
        P <= COVER;
    end
    else P <= P_next;
end


always @(*) begin
    case (P)
        COVER:
            if(btn_level[0]) P_next <= MAIN_INIT;
    		else P_next <= COVER;
    	MAIN_INIT:
    		if(btn_level[0]) P_next <= GO_RIGHT;
    		else if(lv_end) P_next <= LV_CHANGE;
    		else P_next <= MAIN_INIT;
        GO_UP:
            if(lv_end) P_next <= LV_CHANGE;
            else if(!ball&&(hit_edge||hit_self||hit_bar)) begin
                P_next <=  STOP;
            end
            else if(btn_level[1]) P_next <= GO_RIGHT;
            else if(btn_level[3]) P_next <= GO_LEFT;
            else P_next <= GO_UP;
        GO_RIGHT:
           if(lv_end) P_next <= LV_CHANGE;
            else if(!ball&&(hit_edge||hit_self||hit_bar)) begin
                P_next <=  STOP;
            end
            else if(btn_level[0]) P_next <= GO_UP;
            else if(btn_level[2]) P_next <= GO_DOWN;
            else P_next <= GO_RIGHT;
        GO_DOWN:
            if(lv_end) P_next <= LV_CHANGE;
            else if(!ball&&(hit_edge||hit_self||hit_bar)) begin
                P_next <=  STOP;
            end
            else if(btn_level[1]) P_next <= GO_RIGHT;
            else if(btn_level[3]) P_next <= GO_LEFT;
            else P_next <= GO_DOWN;
        GO_LEFT:
            if(lv_end) P_next <= LV_CHANGE;
            else if(!ball&&(hit_edge||hit_self||hit_bar)) begin
                P_next <=  STOP;
            end
            else if(btn_level[0]) P_next <= GO_UP;
            else if(btn_level[2]) P_next <= GO_DOWN;
            else P_next <= GO_LEFT;
        STOP:
            
                if(heart<=2)begin
                    P_next = MAIN_INIT;
                end
                else if(heart>2)P_next = LOSE;
            
           
        LOSE:
            P_next <= LOSE;
        LV_CHANGE:
        begin
            if(cur_lv==0)
            P_next = MAIN_INIT;
            else
            P_next <=WIN;
        end
        WIN:
            P_next <=WIN;
    endcase
end




reg already_hit_bar;
always@(posedge clk)begin
    if(~reset_n || P==MAIN_INIT)begin
        hit_bar <=0;
        already_hit_bar <=0;
    end
    else begin
        for(idx = 0; idx <  snake_node; idx = idx+1)begin
            if((!already_hit_bar)&& snake_region[idx] && (P==GO_LEFT||P==GO_RIGHT||P==GO_UP||P==GO_DOWN)&&(bar_region1 || bar_region2))begin
                hit_bar<=1;
                already_hit_bar<=1;
            end
        end
        already_hit_bar<=0;
    end
end

always@(posedge clk)begin
    if(~reset_n || P==MAIN_INIT)begin
        hit_edge <=0;
    end
    else if(!r_region&&edge_region&&((snake_region[1]&&(P==GO_LEFT||P==GO_RIGHT||P==GO_UP))||(snake_region[0]&&P==GO_DOWN)))begin
        hit_edge <=1;
    end
end
reg already_hit;
/*
always@(clk)begin
    if(~reset_n || P==MAIN_INIT)begin
        hit_self <=0;
        already_hit<=0;
    end
    for(idx = 1; idx <  snake_node; idx = idx+1)begin
        if((!already_hit)&&snake_region[0] && snake_region[idx] && (P==GO_LEFT||P==GO_RIGHT||P==GO_UP||P==GO_DOWN)&&!r_region)begin
           // hit_self <=1;
            already_hit<=1;
        end
    end
    
end
*/
// each snake node has 10 bits, maximum 20 nodes
reg [199:0] snake_VPOS; // Vertical location of the user
reg [199:0] snake_pos; // parallel pos
reg node_offset;
// node counter
wire ball;
reg [5:0] snake_node;
integer idx;
reg [1:0] add_done;
reg [1:0] score_done;
reg detector;
wire bar1;
wire bar2;
 assign bar1=(pixel_y>=141 && pixel_y<=309  && pixel_x>=491 && pixel_x<=519) ;
 assign bar2=(pixel_y>=281 && pixel_y<=309  && pixel_x>=21 && pixel_x<=299) ;
always @(posedge clk)begin
    if(~reset_n)begin
        detector<=0;
        cur_lv<=0;
    end
    if(P==COVER&&P_next == MAIN_INIT) begin
        detector<=0;
    end
    if(P==LV_CHANGE)begin
        detector<=1;
        cur_lv<=1;
    end
end

assign ball = r_region;
always @(posedge clk) begin
    if (~reset_n || P==MAIN_INIT) begin
      if(~reset_n) begin
      heart<=0;
      score<=0;
      ball_x_pos=150; // Vertical location of the user
      ball_y_pos=400;
      
      end
      
      node_offset =0;
      snake_node = 5;
      snake_VPOS = 0;
      snake_pos = 0;
      for(idx = 0; idx <  snake_node; idx = idx+1)begin
        snake_VPOS[snake_node*10-1-idx*10 -: 10] = 60;
        snake_pos[snake_node*10-1-idx*10 -: 10] = 150 - idx*snake_W*2;
      end
    end
    
   // if(edge_region&&snake_region[0]&&(P==GO_LEFT||P==GO_RIGHT||P==GO_UP||P==GO_DOWN))begin
    if(~reset_n || P==MAIN_INIT)begin
        hit_self <=0;
        already_hit<=0;
    end
    /*
    for(idx = 1; idx <  snake_node; idx = idx+1)begin
        if((!already_hit)&&snake_region[0] && snake_region[idx] && (P==GO_LEFT||P==GO_RIGHT||P==GO_UP||P==GO_DOWN))begin
           hit_self <=1;
            already_hit<=1;
        end
        end
    */
      if(r_region&&snake_region[0]&&!score_done&&!hit_self)begin
         // node_offset <=1;
          score<=score+1;
          score_done<=1;
          ball_x_pos=(39+snake_clock%(601-39+1)); // Vertical location of the user
             ball_y_pos=(39+snake_clock%(441-39+1));
            if(bar2&&bar1&&snake_region[0]&&snake_region[1]&&snake_region[2]&&snake_region[3]&&snake_region[4])begin
     ball_x_pos=(39+snake_clock%(601-39+1)); // Vertical location of the user
             ball_y_pos=(39+snake_clock%(441-39+1));
                     if(bar2&&bar1&&snake_region[0]&&snake_region[1]&&snake_region[2]&&snake_region[3]&&snake_region[4])begin
                 ball_x_pos=(39+snake_clock%(601-39+1)); // Vertical location of the user
             ball_y_pos=(39+snake_clock%(441-39+1));
                    if(bar2&&bar1&&snake_region[0]&&snake_region[1]&&snake_region[2]&&snake_region[3]&&snake_region[4])begin
           ball_x_pos=(39+snake_clock%(601-39+1)); // Vertical location of the user
             ball_y_pos=(39+snake_clock%(441-39+1));
                    end
                    end
             end

             if(P == GO_UP)begin
             
              snake_VPOS =  snake_VPOS[9 -: 10]|((snake_VPOS >> 10   | (snake_VPOS[(snake_node)*10-1 -: 10] - snake_clock[20]*snake_H) << ((snake_node-1)*10))<< 10) ;
              snake_pos  = snake_pos[9 -: 10] |((snake_pos >> 10  | (snake_pos[(snake_node)*10-1 -: 10]) << ((snake_node-1)*10))<< 10);
              snake_node = snake_node+1;
              score_done<=0;
             end else if(P == GO_RIGHT)begin
             
             snake_pos  = snake_pos[9 -: 10] |((snake_pos>> 10 | (snake_pos[(snake_node)*10-1 -: 10] + snake_clock[20]*snake_W*2 ) << ((snake_node-1)*10))<< 10)  ;
             snake_VPOS = snake_VPOS[9 -: 10]|((snake_VPOS>> 10  | (snake_VPOS[(snake_node)*10-1 -: 10]) << ((snake_node-1)*10))<< 10) ;
             snake_node = snake_node+1;
             score_done<=0;
             end else if(P == GO_DOWN)begin
              snake_VPOS = snake_VPOS[9 -: 10]|((snake_VPOS >> 10 | (snake_VPOS[(snake_node)*10-1 -: 10] + snake_clock[20]*snake_H) << ((snake_node-1)*10))<<10) ;
              snake_pos  = snake_pos[9 -: 10] |((snake_pos >> 10  | (snake_pos[(snake_node)*10-1 -: 10]) << ((snake_node-1)*10))<< 10) ;
              snake_node = snake_node+1;
              score_done<=0;
             end else if(P == GO_LEFT)begin
              snake_pos  = snake_pos[9 -: 10] |((snake_pos  >> 10 | (snake_pos[(snake_node)*10-1 -: 10] - snake_clock[20]*snake_W*2 ) << ((snake_node-1)*10))<< 10)  ;
             snake_VPOS = snake_VPOS[9 -: 10]|((snake_VPOS>> 10  | (snake_VPOS[(snake_node)*10-1 -: 10]) << ((snake_node-1)*10))<<10) ;
             snake_node = snake_node+1;
             score_done<=0;
             end
               
      
     end
     if(P==LV_CHANGE&& !cur_lv)begin
        snake_node = 5;
        snake_VPOS = 0;
        snake_pos = 0;
        score<=0;
        for(idx = 0; idx <  snake_node; idx = idx+1)begin
        snake_VPOS[snake_node*10-1-idx*10 -: 10] = 60;
        snake_pos[snake_node*10-1-idx*10 -: 10] = 150 - idx*snake_W*2;
        end
       // cur_lv<=1;
    end
    else if(r_region&&snake_region[0]&&!score_done)begin
    end
    else if((hit_edge||hit_self||hit_bar)&&!add_done&&!r_region)begin
        heart<=heart+1;
        add_done <= 1;
    end
    else if(P==MAIN_INIT)begin
        add_done <= 0;
        score_done<=0;
    end
    else if(P == GO_UP && snake_clock[20]) begin // go up

      snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node*10-1 -: 10] - snake_clock[20]*snake_H) << ((snake_node-1)*10);
      snake_pos  = snake_pos  >> 10 | (snake_pos[snake_node*10-1 -: 10]) << ((snake_node-1)*10);
      //snake_VPOS <= snake_VPOS - snake_clock[20];
    end
    else if(P == GO_RIGHT && snake_clock[20]) begin // go right

      snake_pos  = snake_pos >> 10  | (snake_pos[snake_node*10-1 -: 10] + snake_clock[20]*snake_W*2 ) << ((snake_node-1)*10);
      snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node*10-1 -: 10]) << ((snake_node-1)*10);
      //snake_pos <= snake_pos + snake_clock[20];
    end
    else if(P == GO_DOWN && snake_clock[20]) begin // go down
 
      snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node*10-1 -: 10] + snake_clock[20]*snake_H) << ((snake_node-1)*10);
      snake_pos  = snake_pos  >> 10 | (snake_pos[snake_node*10-1 -: 10]) << ((snake_node-1)*10);
      //snake_VPOS <= snake_VPOS + snake_clock[20];
    end
    else if(P == GO_LEFT && snake_clock[20]) begin // go left

      snake_pos  = snake_pos >> 10  | (snake_pos[snake_node*10-1 -: 10] - snake_clock[20]*snake_W*2 ) << ((snake_node-1)*10);
      snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node*10-1 -: 10]) << ((snake_node-1)*10);
      //snake_pos <= snake_pos - snake_clock[20];
    end
end


     assign   bar_region1 = (detector&&(cur_lv==1)&&(pixel_y>=up_pos1 && pixel_y<=down_pos1  && pixel_x>=left_pos1 && pixel_x<=right_pos1)) ;


 assign   bar_region2 = (detector&&(cur_lv==1)&&(pixel_y>=up_pos2 && pixel_y<=down_pos2  && pixel_x>=left_pos2 && pixel_x<=right_pos2)) ;
 assign   bar_region3 = (pixel_y>=up_pos2 && pixel_y<=down_pos2  && pixel_x>=30 && pixel_x<=290) ;


reg [20:0] snake_clock;
always @(posedge clk) begin
  if (~reset_n)begin
    snake_clock <= 0;
    /* up_pos1 = 150;
         down_pos1 = 300;
        left_pos1 = 500;
        right_pos1 = 510;
        up_pos2 = 290;
        down_pos2 = 300;
         left_pos2 = 80;
          right_pos2 = 230;
          to_left=1;*/
  end else if(snake_clock[20] == 1) begin
  
 /* if (to_left)  begin  
            left_pos2 <= left_pos2 - 2;  
            right_pos2 <= right_pos2 - 2;  
            if(left_pos2<=30 )begin
                to_left=(~to_left);
            end
      end   else begin       
            left_pos2 <= left_pos2 + 2; 
            right_pos2 <= right_pos2 + 2; 
            if(right_pos2>=290 )begin
                to_left=(~to_left);
            end 
         end*/
         snake_clock <= 0;
  end
  else if (speed == 0)
      snake_clock <= snake_clock + 1;
end






integer speed=0;

always @(posedge clk) begin
  if (~reset_n) begin
    speed = 0;
  end
  else if(power_ful)begin
	  if (speed >= 10) speed <= 0;
	  else speed <= speed + 1; 	
  end
  else begin
	  if (speed >= 35) speed <= 0;
	  else speed <= speed + 1;	
  end

end


// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.


wire edge_region;
assign edge_region = (pixel_y<=24 || pixel_y>=460 || pixel_x <=20 || pixel_x >= 610);

integer i;
reg [20:0] snake_region;
always @(posedge clk) begin
  if (~reset_n) begin
    for(i=0; i<snake_node; i= i+1)begin
      snake_region[i] = 0;
    end
  end
  else begin
     for(i=0; i<snake_node; i= i+1)begin
      snake_region[i] <=
           pixel_y >= (snake_VPOS[snake_node*10-1-i*10 -: 10]<<1) && pixel_y < (snake_VPOS[snake_node*10-1-i*10 -: 10]+snake_H)<<1 &&
           (pixel_x + (2*snake_W-1) ) >= snake_pos[snake_node*10-1-i*10 -: 10] && pixel_x < snake_pos[snake_node*10-1-i*10 -: 10] + 1;
    end  
  end
end

// assign snake_region =
//            pixel_y >= (snake_VPOS<<1) && pixel_y < (snake_VPOS+snake_H)<<1 &&
//            (pixel_x + 19) >= snake_pos && pixel_x < snake_pos + 1;








always @ (posedge clk) begin
  if (~reset_n)begin
    pixel_addr <= 0;
    pixel_addr_h <= 0;
    pixel_addr_s<=0;
    end
  else
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    if(end_region)
        pixel_addr_e<= ((pixel_y>>1)-E_VPOS)*e_W + //>>1 -> /2//-25
                      ((pixel_x +(e_W*2-1)-384)>>1);
   
    if(score_region)
        if(score=='d4)
        pixel_addr_s<='d8192+
                      ((pixel_y>>1)-S_VPOS)*score_W + //>>1 -> /2//-25
                      ((pixel_x +(score_W*2-1)-476)>>1);
        else
        pixel_addr_s<=score_addr[score]+
                      ((pixel_y>>1)-S_VPOS)*score_W + //>>1 -> /2//-25
                      ((pixel_x +(score_W*2-1)-476)>>1);
    if(heart_region)
       /*if(P==MAIN_INIT)
        pixel_addr_h<= heart_addr[0] +
                    ((pixel_y>>1)-H_VPOS)*heart_W + //>>1 -> /2//-25
                    ((pixel_x +(heart_W*2-1)-605)>>1);
       else
       if(P==STOP)
        pixel_addr_h<= heart_addr[1] +
                    ((pixel_y>>1)-H_VPOS)*heart_W + //>>1 -> /2//-25
                    ((pixel_x +(heart_W*2-1)-605)>>1);
       else*/
        pixel_addr_h<= heart_addr[heart] +
                      ((pixel_y>>1)-H_VPOS)*heart_W + //>>1 -> /2//-25
                      ((pixel_x +(heart_W*2-1)-605)>>1);
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end


// Extra mode
// ------------------------------------------------------------------------

parameter CC = 5_000_000; // change color per 0.8 sec
reg [30:0] tick;
wire show_time;
assign show_time = (tick == CC);

always@(posedge clk) begin
  if (~reset_n || tick == CC)
    tick <= 0;
  else
    tick <= tick + 1;
end

// This is color spiner
reg [59:0]  color_arr; // 5 colors , each 12 bits
always @(posedge clk) begin
  if (~reset_n) begin
    color_arr[11 -: 12] = 12'he12;
    color_arr[23 -: 12] = 12'hff0;
    color_arr[35 -: 12] = 12'h0f0;
    color_arr[47 -: 12] = 12'h0ff;
    color_arr[59 -: 12] = 12'hf0f;
  end
  else if(show_time)begin
    color_arr = (color_arr >> 12) | (color_arr[11:0] << 48);
  end
end


parameter rainbow_gate = 50_000_000;
parameter normal_gate = 100_000;
reg [30:0] count;
reg [30:0] z_count;

reg power_ful;
wire UP_press, RIGHT_press, DOWN_press, LEFT_press;
assign UP_press = (P == GO_UP) && (btn_level[0] || btn_level[1] || btn_level[3]);
assign RIGHT_press = (P == GO_RIGHT) && (btn_level[0] || btn_level[1] || btn_level[2]);
assign DOWN_press = (P == GO_DOWN) && (btn_level[1] || btn_level[2] || btn_level[3]);
assign LEFT_press = (P == GO_LEFT) && (btn_level[2] || btn_level[3] || btn_level[0]);

always @(posedge clk) begin
  if (~reset_n) begin
  	count = 0;
  	z_count = 0;
  	power_ful = 0;
  end
  else if(z_count == normal_gate)begin
	count = 0;
	power_ful = 0;
	if(UP_press || RIGHT_press || DOWN_press || LEFT_press)
		z_count = 0;
  end
  else if(count == rainbow_gate)begin // be powerful
  	if(UP_press || RIGHT_press || DOWN_press || LEFT_press)begin
  		power_ful = 1;
  		z_count = 0;
  	end
  	else if(~btn_level[0] && ~btn_level[1] && ~btn_level[2] && ~btn_level[3])begin
  		z_count = z_count + 1;
  	end
  	
  end
  else if(UP_press || RIGHT_press || DOWN_press || LEFT_press)begin
  	count = count + 1;
  end
  else if(~btn_level[0] && ~btn_level[1] && ~btn_level[2] && ~btn_level[3])begin
  	z_count = z_count + 1;
  end
end



// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end
reg gate;
integer j;
always @(*) begin
  if (~video_on) begin
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
    gate = 0;
  end
  else begin
   if(P==COVER)begin
    rgb_next =data_out;
   end
   else if(P == WIN)begin
     if(end_region&&data_out_w!=12'h006)rgb_next = data_out_w;
     else rgb_next = 12'h005;
  end
   else if(P == LOSE)begin
    if(end_region&&data_out_l!=12'h006)rgb_next = data_out_l;
    else rgb_next = 12'h005;
  end
   else if(edge_region)begin
    rgb_next = 12'hfff;
  end
  else if (r_region)begin  
        rgb_next <=  12'hee0;  
   end
  else begin
      if(bar_region1|bar_region2)begin
        rgb_next <=  12'hac9;
   end
    for(j=0; j<snake_node; j=j+1)begin
      if(snake_region[j]) begin
      // if(j == 0)
      //   rgb_next = 12'he12;
      //   else if(j == 1)
      //   rgb_next = 12'h3e8;
      //   else if(j == 2)
      //   rgb_next = 12'h0f0;
      //   else if(j == 3)
      //   rgb_next = 12'h123;
      //   else if(j == 4)
      //   rgb_next = 12'h89a;
        if(power_ful) // extra mode
          rgb_next = color_arr[11:0];
        else begin
          rgb_next = 12'heb7;
        end
        gate = 1;
      end    
    end
    if(gate == 0) begin
        if(score_region && data_out_s > 12'haaa) rgb_next = 12'hfff;//set score
        else if(heart_region && data_out_h != 12'h2f0) rgb_next = data_out_h;
        else rgb_next = 12'h005;
    end
   end
    gate = 0;
   
  end
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule