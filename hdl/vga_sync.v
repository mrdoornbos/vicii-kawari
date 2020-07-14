`include "common.vh"

// Double the native resolution of the C64 in both dimensions.

// TODO : Theser are for PAL only @50hz. Get values for NTSC @ 60hz
localparam HS_STA = 21;              // horizontal sync start
localparam HS_END = 21 + 116;        // horizontal sync end
localparam HA_STA = 21 + 116 + 65;   // horizontal active pixel start
localparam VS_STA = 569 + 11;        // vertical sync start
localparam VS_END = 569 + 11 + 3;    // vertical sync end
localparam VA_END = 569;             // vertical active pixel end
localparam LINE   = 1007;            // complete line (pixels)
localparam SCREEN = 623;             // complete screen (lines)

localparam VERTICAL_OFFSET = 63;
localparam HORIZONTAL_CROP_LEFT = 96;
localparam HORIZONTAL_CROP_RIGHT = 104;

// Produce horizontal and vertical sync pulses for VGA output
module vga_sync(
    // TODO: Add chip here so we know ntsc vs pal
    input wire clk_dot4x,
    input wire rst,
    output reg o_hs,             // horizontal sync
    output reg o_vs,             // vertical sync
    output reg o_active,         // high during active pixel drawing
    output reg [9:0] o_v_count,
    output reg [9:0] o_h_count
 );

    reg [9:0] h_count;  // line position
    reg [9:0] v_count;  // screen position

    // generate sync signals active low
    assign o_hs = ~((h_count >= HS_STA) & (h_count < HS_END));
    assign o_vs = ~((v_count >= VS_STA) & (v_count < VS_END));

    // active: high during active pixel drawing
    assign o_active = ~((h_count < HA_STA) | (v_count > VA_END - 1)); 

    assign o_h_count = h_count;
    assign o_v_count = v_count;

    always @ (posedge clk_dot4x)
    begin
        if (rst)
        begin
            h_count <= 0;
            v_count <= SCREEN - VERTICAL_OFFSET; // TODO Make this a runtime param
        end
        else
        begin
            if (h_count < LINE) begin
               h_count <= h_count + 1;
            end else begin
               h_count <= 0;
               if (v_count < SCREEN) begin
                  v_count <= v_count + 1;
               end else begin
                  v_count <= 0;
               end
            end
        end
    end
endmodule : vga_sync

// Double buffer, while active_buf is being filled, we draw from filled_buf
// for output.
reg active_buf;

//  Fill active buf while producing pixels from previous line from filled_buf
module vga_scaler(
    input rst,
    input dot_rising_0,
    input clk_dot4x,
    input [8:0] h_count_div2,
    input [3:0] pixel_color3,
    input [9:0] raster_x,
    output reg [3:0] pixel_color4
);

// Cover the max possible here. Not all may be used depending on chip.
(* ram_style = "block" *) reg [3:0] line_buf_0[511:0];
(* ram_style = "block" *) reg [3:0] line_buf_1[511:0];

always @(posedge clk_dot4x)
begin
   if (!rst) begin
   if (dot_rising_0) begin
      if (raster_x == 0)
         active_buf = ~active_buf;

      if (active_buf)
        line_buf_0[raster_x[8:0]] = pixel_color3;
      else
        line_buf_1[raster_x[8:0]] = pixel_color3;
   end
   end
end

always @(posedge clk_dot4x)
begin
   if (!rst) begin
   if (h_count_div2 >= (HS_STA + HORIZONTAL_CROP_LEFT) &&
       h_count_div2 <= (HS_STA + 504 - HORIZONTAL_CROP_RIGHT + HORIZONTAL_CROP_LEFT)) begin
        pixel_color4 = !active_buf ? line_buf_0[h_count_div2 - HS_STA - HORIZONTAL_CROP_LEFT + HORIZONTAL_CROP_RIGHT] :
                                     line_buf_1[h_count_div2 - HS_STA - HORIZONTAL_CROP_LEFT + HORIZONTAL_CROP_RIGHT];
   end else
        pixel_color4 = 4'b0;
   end
end

endmodule : vga_scaler