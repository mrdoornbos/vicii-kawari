`timescale 1ns / 1ps

`include "common.vh"

// We initialize raster_x,raster_y = (0,0) and let the fist tick
// bring us to raster_x=1 because that initial state is common to all
// chip types. So for reset blocks, remember we are
// starting things off with PHI LOW but already 1/4 the way
// through its phase and with DOT high but already on the second
// pixel. (This really only matters for the simulator since things
// would eventually fall into line eventually anyway).

// Notes on RST : The reset signal has to reach every flip flop we
// end up resetting.  Try to keep this list to essential resets only.
// i.e, those that are necessary for a sane start state. If the toolchain
// complains about placing dbl into IOB that is connected to flip flops
// with multiple set/reset signals, it'slikely a reset signal (or signals)
// causing it.

module vicii(
           input [1:0] chip,
           input rst,
           input clk_dot4x,
           output clk_phi,
           output [9:0] xpos,
           output [9:0] raster_x,
           output [8:0] raster_line,
           output [3:0] pixel_color3,
           output [11:0] ado,
           input [5:0] adi,
           output [7:0] dbo,
           input [11:0] dbi,
           input ce,
           input rw,
           output irq,
           input lp,
           output reg aec,
           output ba,
           output ras,
           output cas,
           output ls245_data_dir,
           output ls245_data_oe,
           output ls245_addr_dir,
           output ls245_addr_oe,
           output vic_write_db,
           output vic_write_ab
       );

// BA must go low 3 cycles before any dma access on a PHI
// HIGH phase.

// AEC is LOW for PHI LOW phase (vic) and HIGH for PHI
// HIGH phase (cpu) but kept LOW in PHI HIGH phase if vic
// 'stole' a cpu cycle.

// Limits for different chips
reg [9:0] raster_x_max;
reg [8:0] raster_y_max;
reg [9:0] max_xpos;
reg [6:0] sprite_dmachk1;
reg [6:0] sprite_dmachk2;
reg [6:0] sprite_yexp_chk;
reg [6:0] sprite_disp_chk;
reg [9:0] chars_ba_start;
reg [9:0] chars_ba_end;
// These xpos's cover the sprite dma period and 3 cycles
// before the first dma access is required. They are used
// in ba low calcs.
wire [9:0] sprite_ba_start [`NUM_SPRITES-1:0];
wire [9:0] sprite_ba_end [`NUM_SPRITES-1:0];

// raster_x but offset such that the BA fall for the
// first sprite is position 0. This is so we can use a
// simple interval comparison for ba high/low and avoid
// wrap around conditions.
wire [9:0] sprite_raster_x;

// clk_dot4x;     32.727272 Mhz NTSC, 31.527955 Mhz PAL
// clk_col4x;     14.318181 Mhz NTSC, 17.734475 Mhz PAL
// clk_dot;       8.18181 Mhz NTSC, 7.8819888 Mhz PAL
// clk_colref     3.579545 Mhz NTSC, 4.43361875 Mhz PAL
// clk_phi        1.02272 Mhz NTSC, .985248 Mhz PAL

// Set limits for chips
always @(chip)
case(chip)
    `CHIP6567R8:
    begin
        raster_x_max = 10'd519;    // 520 pixels
        raster_y_max = 9'd262;     // 263 lines
        max_xpos = 10'h1ff;
        sprite_dmachk1 = 7'd55;    // low phase
        sprite_dmachk2 = 7'd56;    // low phase
        sprite_yexp_chk = 7'd56;   // high phase
        sprite_disp_chk = 7'd58;
        chars_ba_start = 'h1f4;
        chars_ba_end = 'h14c;
    end
    `CHIP6567R56A:
    begin
        raster_x_max = 10'd511;    // 512 pixels
        raster_y_max = 9'd261;     // 262 lines
        max_xpos = 10'h1ff;
        sprite_dmachk1 = 7'd55;    // low phase
        sprite_dmachk2 = 7'd56;    // low phase
        sprite_yexp_chk = 7'd56;   // high phase
        sprite_disp_chk = 7'd57;
        chars_ba_start = 'h1f4;
        chars_ba_end = 'h14c;
    end
    `CHIP6569, `CHIPUNUSED:
    begin
        raster_x_max = 10'd503;     // 504 pixels
        raster_y_max = 9'd311;      // 312
        max_xpos = 10'h1f7;
        sprite_dmachk1 = 7'd54;     // low phase
        sprite_dmachk2 = 7'd55;     // low phase
        sprite_yexp_chk = 7'd55;    // high phase
        sprite_disp_chk = 7'd57;
        chars_ba_start = 'h1ec;
        chars_ba_end = 'h14c;
    end
endcase

// used to generate phi and dot clocks
reg [31:0] phi_gen;
reg [31:0] dot_gen;

// used to detect rising edge of dot clock inside a dot4x always block
reg [3:0] dot_rising;

// delayed raster line for irq comparison
wire [8:0] raster_line_d;
reg allow_bad_lines;

reg [7:0] reg11_delayed;
reg [4:0] reg16_delayed;

// xpos is the x coordinate relative to raster irq
// It is not simply raster_x with an offset, it does not
// increment on certain cycles for 6567R8
// chips and wraps at the high phase of cycle 12.

// What cycle we are on.  Only valid on 2nd tick (or greater)
// within a half-phase.
wire [3:0] cycle_type;

// DRAM refresh counter
reg [7:0] refc;

wire [2:0] sprite_cnt;

// Video matrix and character banks.
wire [3:0] vm;
wire [2:0] cb;

// cycleNum : Each cycle is 8 pixels.
// 6567R56A : 0-63
// 6567R8   : 0-64
// 6569     : 0-62
// NOTE: cycleNum not valid until 2nd tick within low phase of phi
wire [6:0] cycle_num;

// ec : border (edge) color
wire [3:0] ec;
// b#c : background color registers
wire [3:0] b0c,b1c,b2c,b3c;

// lets us detect when a phi phase is
// starting within a 4x dot always block
// phi_phase_start[15]==1 means phi will transition next tick
reg [15:0] phi_phase_start;

// determines timing within a phase when RAS,CAS and MUX will
// fall.  (MUX determines when address transition occurs which
// should be between RAS and CAS)
reg [15:0] ras_gen;
reg [15:0] cas_gen;
reg [15:0] mux_gen;

// muxes the last 8 bits of our read address for CAS/RAS latches
wire mux;

// tracks whether the condition for triggering these
// types of interrupts happened, but may not be
// reported via irq unless enabled
reg irst;
wire ilp;
wire immc;
wire imbc;

// interrupt latches for $d019, these are set HIGH when
// an interrupt of that type occurs. They are not automatically
// cleared by the VIC.
wire irst_clr;
wire imbc_clr;
wire immc_clr;
wire ilp_clr;

// interrupt enable registers for $d01a, these determine
// if these types of interrupts will make irq low
wire erst;
wire embc;
wire emmc;
wire elp;

// if enabled, what raster line do we trigger irq for irst?
wire [8:0] raster_irq_compare;
// keeps track of whether raster irq was raised on a line
reg raster_irq_triggered;

wire [9:0] vc; // video counter
wire [2:0] rc; // row counter
wire idle;

wire den; // display enable
wire bmm; // bitmap mode
wire ecm; // extended color mode

wire [2:0] xscroll;
wire [2:0] yscroll;

wire rsel; // border row select
wire csel; // border column select
wire mcm; // multi color mode

wire stage1;
wire is_background_pixel1;

// mostly used for iterating over sprites
integer n;

// char read off the bus, eventually transfered to charRead
wire [11:0] char_next;

// pixels read off the data bus and char read from the bus (char_next on badline) or char_buf (not badline)
wire [11:0] char_read;
wire [7:0] pixels_read;

// badline condition
reg badline;

// determines when ba should drop due to chars and sprites
reg ba_chars;
reg [7:0] ba_sprite;

// NOTE: The sprite_*_o regs/wires are 'flattened' 2D arrays that we
// pack and slice between modules.  Verilog does not support passing
// 2D arrays to modules as params so we have to do this for our
// sprite arrays.  The module that owns the register declares a
// 'flattened' _o output wire that we hook up here.  Any module that
// receives the _o flattened wire via an input will slice it apart
// back into a usable 2D array.
wire [71:0] sprite_x_o; // 9 bits * 8 sprites
wire [63:0] sprite_y_o; // 8 bits * 8 sprites
wire [31:0] sprite_col_o; // 4 bits * 8 sprites
wire [63:0] sprite_ptr_o; // 8 bits * 8 sprites
wire [47:0] sprite_mc_o; // 6 bits * 8 sprites
wire [15:0] sprite_cur_pixel_o; // 2 bits * 8 sprites

wire [7:0] sprite_pri;
wire [3:0] sprite_mc0;
wire [3:0] sprite_mc1;
wire [7:0] sprite_en;
wire [7:0] sprite_xe;
wire [7:0] sprite_ye;
wire [7:0] sprite_mmc;
wire [`NUM_SPRITES - 1:0] sprite_dma;

// Setup sprite ba start/end ranges.  These are compared against
// sprite_raster_x which is makes sprite #0 drop point = 0
// TODO: Should these end values be +4 to rise back up with
// AEC/PHI? Find out on the scope.
assign sprite_ba_start[0] = 10'd0 + 10'd16 * 0;
assign sprite_ba_end[0] = 10'd40 + 10'd16 * 0;
assign sprite_ba_start[1] = 10'd0 + 10'd16 * 1;
assign sprite_ba_end[1] = 10'd40 + 10'd16 * 1;
assign sprite_ba_start[2] = 10'd0 + 10'd16 * 2;
assign sprite_ba_end[2] = 10'd40 + 10'd16 * 2;
assign sprite_ba_start[3] = 10'd0 + 10'd16 * 3;
assign sprite_ba_end[3] = 10'd40 + 10'd16 * 3;
assign sprite_ba_start[4] = 10'd0 + 10'd16 * 4;
assign sprite_ba_end[4] = 10'd40 + 10'd16 * 4;
assign sprite_ba_start[5] = 10'd0 + 10'd16 * 5;
assign sprite_ba_end[5] = 10'd40 + 10'd16 * 5;
assign sprite_ba_start[6] = 10'd0 + 10'd16 * 6;
assign sprite_ba_end[6] = 10'd40 + 10'd16 * 6;
assign sprite_ba_start[7] = 10'd0 + 10'd16 * 7;
assign sprite_ba_end[7] = 10'd40 + 10'd16 * 7;

// When we pass in xpos to the pixel sequencer, we subtract 4
// pixels to make the xpos_mod_8 zero point 4 pixles past the
// phi clock edge, which appears to be the right spot to 'catch'
// the b0c register changes on Krestage to hide foreground pixels
// on the vertical scrolling text at the bottom (to the left and
// right of the sprites).
wire [9:0] xpos_gfx;
assign xpos_gfx = xpos >= 10'd2 ? xpos - 10'd2 : max_xpos - 10'd1 + xpos;

// When we pass xpos to the sprite module, we subtract 5
// pixels to make shifting start at the right time.  The output
// pixels are shifted another 6 before reaching the pixel
// sequencer.
wire [9:0] xpos_sprite;
assign xpos_sprite = xpos >= 10'd3 ? xpos - 10'd3 : max_xpos - 10'd2 + xpos;

// dot_rising[3] means dot going high next cycle
always @(posedge clk_dot4x)
    if (rst)
        dot_rising <= 4'b1000;
    else
        dot_rising <= {dot_rising[2:0], dot_rising[3]};

// phi_gen[31]=HIGH means phi is high next cycle
always @(posedge clk_dot4x)
    if (rst) begin
        phi_gen <= 32'b00000000000011111111111111110000;
    end else begin
        phi_gen <= {phi_gen[30:0], phi_gen[31]};
    end
    
assign clk_phi = phi_gen[0];

// phi_phase_start[15]=HIGH means phi is high next cycle
always @(posedge clk_dot4x)
    if (rst) begin
        phi_phase_start <= 16'b0000000000001000;
    end else
        phi_phase_start <= {phi_phase_start[14:0], phi_phase_start[15]};

// This is simply raster_x divided by 8.
assign cycle_num = raster_x[9:3];


// allow_bad_lines goes high on line 48
// if den is high at any point on line 48
// allow_bad_lines falls on line 248
// den only takes effect on line 48
// the timing here ensures we have allow_bad_lines available @ [1]
always @(posedge clk_dot4x)
begin
    if (rst)
        allow_bad_lines <= `FALSE;
    else if (clk_phi && phi_phase_start[0]) begin // just ticked high
        if (raster_line == 48 && den == `TRUE)
            allow_bad_lines <= `TRUE;
        if (raster_line == 248)
            allow_bad_lines <= `FALSE;
    end
end

// Raise raster irq once per raster line
// On raster line 0, it happens on cycle 1, otherwise, cycle 0
always @(posedge clk_dot4x)
begin
    if (rst) begin
        irst <= `FALSE;
        raster_irq_triggered <= `FALSE;
    end else begin
        if (clk_phi && phi_phase_start[3]) begin
            // Here, we use the delayed raster line to match the expected
            // behavior of triggering the interrupt on cycle 1 for raster line
            // 0 and cycle 0 for any other line.
            if (raster_line_d == raster_irq_compare) begin
                if (!raster_irq_triggered) begin
                    raster_irq_triggered <= `TRUE;
                    irst <= `TRUE;
                end
            end else begin
                raster_irq_triggered <= `FALSE;
            end
        end
        if (irst_clr)
            irst <= `FALSE;
    end
end

// NOTE: Things like raster irq conditions happen even if the enable bit is off.
// That means as soon as erst is enabled, for example, if the condition was
// met, it will trigger irq immediately.  This seems consistent with how the
// C64 works.  Even if you set raster_irq_compare to 11, when you first enable erst,
// your ISR will get called immediately on the next line. Then, only afer you clear
// the interrupt will you actually get the ISR on the desired line.
assign irq = (ilp & elp) | (immc & emmc) | (imbc & embc) | (irst & erst);

// DRAM refresh counter
always @(posedge clk_dot4x)
    if (rst)
        refc <= 8'hff;
    else if (phi_phase_start[1]) begin // cycle_type is about to transition
        // Decrement at the start of the phase when cycle_type is still valid for
        // the previous half cycle.
        if (cycle_num == 1 && raster_line == 9'd0)
            refc <= 8'hff;
        else if (cycle_type == `VIC_LR)
            refc <= refc - 8'd1;
    end

// Border pixels are delayed to align with gfx data.
// For reasons not fully understood:
//    d3 is passed to the pixel sequencer
//    d4 is passed to sprite module
wire main_border;
wire top_bot_border;
border vic_border(
           .rst(rst),
           .clk_dot4x(clk_dot4x),
           .clk_phi(clk_phi),
           .cycle_num(cycle_num),
           .xpos(xpos),
           .raster_line(raster_line),
           .rsel(rsel),
           .csel(csel),
           .den(den),
           .vborder(top_bot_border),
           .main_border(main_border)
       );

wire [7:0] lpx;
wire [7:0] lpy;

lightpen vic_lightpen(
           .clk_dot4x(clk_dot4x),
           .rst(rst),
           .ilp_clr(ilp_clr),
           .raster_line(raster_line),
           .raster_y_max(raster_y_max),
           .lp(lp),
           .xpos_div_2(xpos[8:1]),
           .lpx(lpx),
           .lpy(lpy),
           .ilp(ilp)
);

raster vic_raster(
   .clk_phi(clk_phi),
   .clk_dot4x(clk_dot4x),
   .rst(rst),
   .phi_phase_start_0(phi_phase_start[0]),
   .dot_rising_0(dot_rising[0]),
   .chip(chip),
   .cycle_num(cycle_num),
   .raster_x_max(raster_x_max),
   .raster_y_max(raster_y_max),
   .xpos(xpos),
   .raster_x(raster_x),
   .sprite_raster_x(sprite_raster_x),
   .raster_line(raster_line),
   .raster_line_d(raster_line_d)
);

matrix vic_matrix(
   .rst(rst),
   .clk_phi(clk_phi),
   .clk_dot4x(clk_dot4x),
   .phi_phase_start_1(phi_phase_start[1]),
   .phi_phase_start_14(phi_phase_start[14]),
   .cycle_num(cycle_num),
   .raster_line(raster_line),
   .badline(badline),
   .idle(idle),
   .vc(vc),
   .rc(rc)
);

// Handle when ba should go low due to c-access. We can use xpos
// here since there are no repeats within this range.
always @(*)
    if (rst)
        ba_chars = `FALSE;
    else begin
        if ((xpos >= chars_ba_start || xpos < chars_ba_end) && badline)
            ba_chars = `FALSE;
        else
            ba_chars = `TRUE;
    end
    
// Handle when ba should go low due to s-access. These ranges are
// compared against sprite_raster_x which is just raster_x with an
// offset that brings sprite 0 to the start.
always @(*) begin
    for (n = 0; n < `NUM_SPRITES; n = n + 1) begin
        if (sprite_dma[n] && sprite_raster_x >= sprite_ba_start[n] && sprite_raster_x < sprite_ba_end[n])
            ba_sprite[n] = 1;
        else
            ba_sprite[n] = 0;
    end
end

// Drop BA if either chars or sprites need it.
assign ba = ba_chars & (ba_sprite == 0);

// Cascade ba through three cycles, making sure
// aec is lowered 3 cycles after ba went low
reg ba1,ba2,ba3;
always @(posedge clk_dot4x)
    if (rst) begin
        ba1 <= `TRUE;
        ba2 <= `TRUE;
        ba3 <= `TRUE;
    end
    else begin
        if (clk_phi == `TRUE && phi_phase_start[15]) begin
            ba1 <= ba;
            ba2 <= ba1 | ba;
            ba3 <= ba2 | ba;
        end
    end

// Cycle state machine
cycles vic_cycles(
   .rst(rst),
   .clk_dot4x(clk_dot4x),
   .clk_phi(clk_phi),
   .chip(chip),
   .phi_phase_start_1(phi_phase_start[1]),
   .sprite_dma(sprite_dma),
   .badline(badline),
   .cycle_num(cycle_num),
   .cycle_type(cycle_type),
   .sprite_cnt(sprite_cnt)
);

// Notes on RAS/CAS/MUX: We don't know what the cycle type is
// until the 3rd tick into the phase ([2]). The lines should
// be high upon entering the phase for 3 ticks until the blocks
// below reset the registers to make them fall at the defined
// times. I could just as easily have changed the assigns
// to use [2] instead of [15] and lined all the 1's flush against
// the left but I like to look at the last bit when debugging to
// know if the line is high or low.

// Timing observed
// NTSC:
//       CAS/RAS separated by ~52ns
//       RAS falls ~167ns after PHI edge
//       ADDR mux @ ~38ns after RAS edge

// RAS/CAS/MUX profiles
// Data must be stable by falling RAS edge
// NOTE: Rise with AEC
always @(posedge clk_dot4x)
    if (rst)
        ras_gen <= 16'b1100000000000011;
    else if (phi_phase_start[2])
        ras_gen <= 16'b1100000000000011;
    else
        ras_gen <= {ras_gen[14:0], 1'b0};

// Then stable by falling CAS edge
// NOTE: Rise with AEC
always @(posedge clk_dot4x)
    if (rst)
        cas_gen <= 16'b1111000000000011;
    else if (phi_phase_start[2])
        cas_gen <= 16'b1111000000000011;
    else
        cas_gen <= {cas_gen[14:0], 1'b0};

assign ras = ras_gen[15];
assign cas = cas_gen[15];

// The ado transition happens between ras and cas.
// NOTE: We make mux rise back up at the same time
// the cycle type transitions so that mux changes along
// with the address gen.  This avoids unnecessary
// noise due to address line switching.
always @(posedge clk_dot4x)
    if (rst)
        mux_gen <= 16'b1110000000000001;
    else if (phi_phase_start[2]) begin
        // Now that the cycle type is known, make mux fall
        // at expected times.
        mux_gen <= 16'b1110000000000001;
    end else
        mux_gen <= {mux_gen[14:0], 1'b0};
assign mux = mux_gen[15];

// sprite logic
wire handle_sprite_crunch;
wire m2m_clr;
wire m2d_clr;
wire [7:0] sprite_m2m;
wire [7:0] sprite_m2d;
wire main_border_stage1;

sprites vic_sprites(
         .rst(rst),
         .clk_dot4x(clk_dot4x),
         .clk_phi(clk_phi),
         .cycle_type(cycle_type),
         .dbi(dbi),
         .dot_rising_0(dot_rising[0]),
         .dot_rising_1(dot_rising[1]),
         .phi_phase_start_m2clr(phi_phase_start[`M2CLR_CHECK]),
         .phi_phase_start_13(phi_phase_start[13]),
         .phi_phase_start_1(phi_phase_start[1]),
         .phi_phase_start_dav(phi_phase_start[`DATA_DAV]),
         .xpos(xpos_sprite[8:0]), // top bit omitted
         .raster_line(raster_line[7:0]), // top bit omitted
         .cycle_num(cycle_num),
         .cycle_bit(raster_x[2:0]),
         .handle_sprite_crunch(handle_sprite_crunch),
         .sprite_x_o(sprite_x_o),
         .sprite_y_o(sprite_y_o),
         .sprite_xe(sprite_xe),
         .sprite_ye(sprite_ye),
         .sprite_en(sprite_en),
         .sprite_mmc(sprite_mmc),
         .sprite_cnt(sprite_cnt),
         .aec(aec),
         .is_background_pixel(is_background_pixel1),
         .stage(stage1),
         .main_border(main_border_stage1),
         .imbc_clr(imbc_clr),
         .immc_clr(immc_clr),
         .sprite_dmachk1(sprite_dmachk1),
         .sprite_dmachk2(sprite_dmachk2),
         .sprite_yexp_chk(sprite_yexp_chk),
         .sprite_disp_chk(sprite_disp_chk),
         .immc(immc),
         .imbc(imbc),
         .sprite_cur_pixel_o(sprite_cur_pixel_o),
         .sprite_mc_o(sprite_mc_o),
         .sprite_dma(sprite_dma),
         .m2m_clr(m2m_clr),
         .m2d_clr(m2d_clr),
         .sprite_m2m(sprite_m2m),
         .sprite_m2d(sprite_m2d)
);


// AEC LOW tells CPU to tri-state its bus lines
// AEC will remain HIGH during Phi phase 2 for 3 cycles
// after which it will remain LOW with ba.
always @(posedge clk_dot4x)
    if (rst) begin
        aec <= `FALSE;
    end else
    begin
        aec <= ba ? clk_phi : ba3 & clk_phi;
    end

// For reference, on LS245's:
//    OE pin low = all channels active
//    OE pin high = all channels disabled
//    DIR pin low = Bx to Ax (vic sets bus)
//    DIR pin high = Ax to Bx (vic reads bus)

// Both data/addr LS245s have OE pin grounded (always enabled)

// We write to data bus when aec is high, chip select is low and rw is high
// (cpu reading from us).  
assign vic_write_db = aec && rw && ~ce;

// AEC low means we own the address bus so we can write to it.
// For address bus direction pin, use aec,
assign vic_write_ab = ~aec;

// For data bus direction, use inverse of vic_write_db
assign ls245_data_dir = ~vic_write_db;
assign ls245_data_oe = 1'b0; // aec & ce;  for now, always enable
assign ls245_addr_dir = aec;
assign ls245_addr_oe = 1'b0; // aec & ce;  for now, always enable
 
  
// Handle cycles that perform data bus accesses
bus_access vic_bus_access(
         .rst(rst),
         .clk_dot4x(clk_dot4x),
         .phi_phase_start_0(phi_phase_start[0]),
         .phi_phase_start_dav(phi_phase_start[`DATA_DAV]),
         .cycle_type(cycle_type),
         .cycle_num(cycle_num),
         .dbi(dbi),
         .idle(idle),
         .sprite_cnt(sprite_cnt),
         .sprite_dma(sprite_dma),
         .sprite_ptr_o(sprite_ptr_o),
         .pixels_read(pixels_read),
         .char_read(char_read),
         .char_next(char_next),
         .clk_phi(clk_phi),
         .aec(aec)
);

// Address generation
addressgen vic_addressgen(
               //.rst(rst),
               .cycle_type(cycle_type),
               .cb(cb),
               .vc(vc),
               .vm(vm),
               .rc(rc),
               .mux(mux),
               // Some magic from VICE: g_fetch_addr((uint8_t)(vicii.regs[0x11] | (vicii.reg11_delay & 0x20)));
               .bmm(bmm | reg11_delayed[5]),
               .ecm(ecm), // NOT delayed!
               .idle(idle),
               .refc(refc),
               .char_ptr(char_next[7:0]),
               .aec(aec),
               .sprite_cnt(sprite_cnt),
               .sprite_ptr_o(sprite_ptr_o),
               .sprite_mc_o(sprite_mc_o),
               .ado(ado));

// Handle set/get registers
registers vic_registers(
              .rst(rst),
              .clk_dot4x(clk_dot4x),
              .clk_phi(clk_phi),
              .phi_phase_start_1(phi_phase_start[1]),
              .phi_phase_start_dav(phi_phase_start[`DATA_DAV]),
              .ce(ce),
              .rw(rw),
              .aec(aec),
              .ras(ras),
              .adi(adi),
              .dbi(dbi[7:0]),
              .raster_line(raster_line_d), // advertise the delayed version
              .irq(irq),
              .ilp(ilp),
              .immc(immc),
              .imbc(imbc),
              .irst(irst),
              .sprite_m2m(sprite_m2m),
              .sprite_m2d(sprite_m2d),
              .lpx(lpx),
              .lpy(lpy),
              .ec(ec),
              .b0c(b0c),
              .b1c(b1c),
              .b2c(b2c),
              .b3c(b3c),
              .xscroll(xscroll),
              .yscroll(yscroll),
              .csel(csel),
              .rsel(rsel),
              .den(den),
              .bmm(bmm),
              .ecm(ecm),
              .mcm(mcm),
              .irst_clr(irst_clr),
              .imbc_clr(imbc_clr),
              .immc_clr(immc_clr),
              .ilp_clr(ilp_clr),
              .raster_irq_compare(raster_irq_compare),
              .sprite_en(sprite_en),
              .sprite_xe(sprite_xe),
              .sprite_ye(sprite_ye),
              .sprite_pri(sprite_pri),
              .sprite_mmc(sprite_mmc),
              .sprite_mc0(sprite_mc0),
              .sprite_mc1(sprite_mc1),
              .sprite_x_o(sprite_x_o),
              .sprite_y_o(sprite_y_o),
              .sprite_col_o(sprite_col_o),
              .m2m_clr(m2m_clr),
              .m2d_clr(m2d_clr),
              .handle_sprite_crunch(handle_sprite_crunch),
              .dbo(dbo),
              .cb(cb),
              .vm(vm),
              .elp(elp),
              .emmc(emmc),
              .embc(embc),
              .erst(erst)
          );

// at the start of every high phase, store current reg11 for delayed fetch
// and badline calcs
always @(posedge clk_dot4x)
begin
    if (rst) begin
        reg11_delayed <= 8'b0;
        reg16_delayed <= 5'b0;
    end else
    // must be before badline idle reset in vic_matrix
    if (clk_phi && phi_phase_start[0]) begin
        reg11_delayed[2:0] <= yscroll;
        reg11_delayed[3] <= rsel;
        reg11_delayed[4] <= den;
        reg11_delayed[5] <= bmm;
        reg11_delayed[6] <= ecm;
        reg11_delayed[7] <= raster_line[8];
        reg16_delayed[2:0] <= xscroll;
        reg16_delayed[3] <= csel;
        reg16_delayed[4] <= mcm;
    end
end

// use delayed reg11 for yscroll
// since allow_bad_lines is set @ [1], this is also available @ [1]
always @(raster_line_d, reg11_delayed, allow_bad_lines)
begin
    badline = `FALSE;
    if (raster_line_d[2:0] == reg11_delayed[2:0] && allow_bad_lines == `TRUE && raster_line_d >= 48 && raster_line_d < 248)
        badline = `TRUE;
end

// Pixel sequencer - outputs stage 3 pixel_color3
pixel_sequencer vic_pixel_sequencer(
                    .rst(rst),
                    .clk_dot4x(clk_dot4x),
                    .clk_phi(clk_phi),
                    .dot_rising_0(dot_rising[0]),
                    .dot_rising_1(dot_rising[1]),
                    .phi_phase_start_pl(phi_phase_start[`PIXEL_LATCH]),
                    .phi_phase_start_dav(phi_phase_start[`DATA_DAV]),
                    .phi_phase_start_xscroll_latch(phi_phase_start[`XSCROLL_LATCH]),
                    .mcm(reg16_delayed[4]), // delayed
                    .bmm(reg11_delayed[5]), // delayed
                    .ecm(reg11_delayed[6]), // delayed
                    .idle(idle),
                    .cycle_num(cycle_num),
                    .xpos_mod_8(xpos_gfx[2:0]),
                    .xscroll(xscroll),
                    .pixels_read(pixels_read),
                    .char_read(char_read),
                    .b0c(b0c),
                    .b1c(b1c),
                    .b2c(b2c),
                    .b3c(b3c),
                    .ec(ec),
                    .main_border(main_border),
                    .main_border_stage1(main_border_stage1),
                    .vborder(top_bot_border),
                    .sprite_cur_pixel_o(sprite_cur_pixel_o),
                    .sprite_pri(sprite_pri),
                    .sprite_mmc(sprite_mmc),
                    .sprite_col_o(sprite_col_o),
                    .sprite_mc0(sprite_mc0),
                    .sprite_mc1(sprite_mc1),
                    .is_background_pixel1(is_background_pixel1),
                    .stage1(stage1),
                    .pixel_color3(pixel_color3)
                );

endmodule : vicii
