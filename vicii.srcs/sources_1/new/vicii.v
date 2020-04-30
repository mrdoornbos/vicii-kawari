`timescale 1ns / 1ps

// This intent of this module is to drive the CXA1545P to generate a
// display. It simply excercises the circuitry attached to the r,g,b
// sync and color clock signals. It is not meant to be a functioning
// vicii.  Only a test pattern is generated.
module vicii(
   input reset,
   input clk_dot,
   input clk_phi,
   output[1:0] red,
   output[1:0] green,
   output[1:0] blue,
   output cSync,
   inout [11:0] ad,
   inout tri [11:0] db,
   input ce,
   input rw,
   output irq,
   output aec,
   output reg ba
);

  // current raster x and y position
  reg [9:0] x_pos;
  reg [8:0] y_pos;

  // line_cycle_num : The cycle we're in on the current raster line. Each
  //                  cycle is 8 pixels.
  // 6567R56A : 0-63
  // 6567R8   : 0-64
  // 6569     : 0-63
  wire [5:0] line_cycle_num;

  // bit_cycle : The pixel number within the line cycle.
  wire [2:0] bit_cycle;

  // char_line_num : For text mode, what character line are we on.
  reg [2:0] char_line_num;

  // ec : border (edge) color
  reg [3:0] ec;
  // b#c : background color registers
  reg [3:0] b0c,b1c,b2c,b3c;
  reg [3:0] mm0,mm1;

  // Temporary
  wire visible_horizontal;
  wire visible_vertical;
  wire WE;

  assign bit_cycle = x_pos[2:0];
  assign line_cycle_num = x_pos[8:3];
  // Stuff like this won't work in the real core. There is no comparitor controlling
  // when the border is visible like this.
  assign visible_vertical = (y_pos >= 51) & (y_pos < 251) ? 1 : 0;
  // Official datasheet says 28-348 but Christian's doc says 24-344
  assign visible_horizontal = (x_pos >= 24) & (x_pos < 344) ? 1 : 0;
  assign WE = visible_horizontal & visible_vertical & (bit_cycle == 2) & (char_line_num == 0);

  // Update x,y position
  always @(posedge clk_dot)
  if (reset)
  begin
    x_pos <= 0;
    y_pos <= 0;
  end
  else if (x_pos < 520) // TODO : 64 cycles needs to be configurable
    x_pos <= x_pos + 1;
  else
  begin
    x_pos <= 0;
    y_pos <= (y_pos < 262) ? y_pos + 1 : 0;
  end

  reg [11:0] char_buffer [39:0];
  reg [11:0] char_buffer_out;
  reg [5:0] char_buf_pos;

 always @(posedge clk_dot)
  if (WE)
    begin
      char_buffer[char_buf_pos] <= 12'b000000000000;
      char_buffer_out <= 12'b000000000000;
    end
  else
    char_buffer_out <= char_buffer[char_buf_pos];

  always @(posedge clk_dot)
    if (!visible_vertical)
      char_line_num <= 0;
    else if (x_pos == 384)
      char_line_num <= char_line_num + 1;

  always @(posedge clk_dot)
    if (!visible_vertical)
      char_buf_pos <= 0;
    else if (bit_cycle == 0 & visible_horizontal)
    begin
      if (char_buf_pos < 39)
        char_buf_pos <= char_buf_pos + 1;
      else
        char_buf_pos <= 0;
    end

  reg [9:0] screen_mem_pos;
  always @(posedge clk_dot)
    if (!visible_vertical)
       screen_mem_pos <= 0;
    else if (bit_cycle == 0 & visible_horizontal & char_line_num == 0)
       screen_mem_pos <= screen_mem_pos + 1;

//  always @*
//    if (bit_cycle == 1)
//       addr = {4'b1, screen_mem_pos};

//    always @*
//     if (bit_cycle == 1)
//       addr = {4'b1, screen_mem_pos};
//     else
//       addr = {3'b010,char_buffer_out[7:0],char_line_num};

  wire [3:0] out_color;
  wire [3:0] out_pixel;
  reg [7:0] pixel_shift_reg;
  reg [3:0] color_buffered_val;

  assign out_color = pixel_shift_reg[7] == 1 ? color_buffered_val : b0c; // 4'd6
  assign out_pixel = visible_vertical & visible_horizontal ? out_color : ec; // 4'd14

  always @(posedge clk_dot)
  if (bit_cycle == 7)
    color_buffered_val <= char_buffer_out[11:8];

  always @(posedge clk_dot)
  if (bit_cycle == 7)
      pixel_shift_reg <= 8'b00000000;  //    pixel_shift_reg <= data[7:0];
  else
      pixel_shift_reg <= {pixel_shift_reg[6:0],1'b0};

  // Translate out_pixel (indexed) to RGB values
  color viccolor(
     .x_pos(x_pos),
     .y_pos(y_pos),
     .out_pixel(out_pixel),
     .red(red),
     .green(green),
     .blue(blue)
  );

  // Generate cSync signal
  sync vicsync(
     .rst(reset),
     .clk(clk_dot),
     .rasterX(x_pos),
     .rasterY(y_pos),
     .cSync(cSync)
  );
endmodule