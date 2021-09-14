#define CHIP6567R8 0
#define CHIP6569R3 1
#define CHIP6567R56A 2
#define CHIP6569R1 3

#define OP_1_HI 0xd02fL
#define OP_1_LO 0xd030L
#define OP_2_HI 0xd031L
#define OP_2_LO 0xd032L
#define OPER    0xd033L

#define UMULT 0
#define UDIV 1
#define UADD 2
#define USUB 3
#define SMULT 4
#define SDIV 5
#define SADD 6
#define SSUB 7

#define DIVZ 4
#define OVERFLOW 2
#define UNDERFLOW 1

#define SPI_REG 0xd034L
#define VIDEO_MEM_1_IDX 0xd035L
#define VIDEO_MEM_2_IDX 0xd036L
#define VIDEO_MODE1 0xd037L
#define VIDEO_MODE2 0xd038L
#define VIDEO_MEM_1_LO 0xd039L
#define VIDEO_MEM_1_HI 0xd03aL
#define VIDEO_MEM_1_VAL 0xd03bL
#define VIDEO_MEM_2_LO 0xd03cL
#define VIDEO_MEM_2_HI 0xd03dL
#define VIDEO_MEM_2_VAL 0xd03eL
#define VIDEO_MEM_FLAGS 0xd03fL

#define VMEM_FLAG_REGS_BIT 32
#define VMEM_FLAG_PERSIST_BIT 64

#define MAGIC_0 0x00
#define MAGIC_1 0x01
#define MAGIC_2 0x02
#define MAGIC_3 0x03
#define DISPLAY_FLAGS 0x04
#define EEPROM_BANK 0x05
#define CHIP_MODEL 0x1f
#define RGB_START 0x40
#define BLACK_LEVEL 0x80
#define BURST_AMPLITUDE 0x81
#define VERSION 0x83
#define CURSOR_LO 0x85
#define CURSOR_HI 0x86
#define CAP_LO 0x87
#define CAP_HI 0x88
#define TIMING_CHANGE 0x89
#define VARIANT 0x90
#define LUMA_START 0xa0
#define PHASE_START 0xb0
#define AMPLITUDE_START 0xc0

#define DISPLAY_SHOW_RASTER_LINES_BIT 1
#define DISPLAY_IS_NATIVE_Y_BIT 2
#define DISPLAY_IS_NATIVE_X_BIT 4
#define DISPLAY_ENABLE_CSYNC_BIT 8
#define DISPLAY_VPOLARITY_BIT 16
#define DISPLAY_HPOLARITY_BIT 32
#define DISPLAY_CHIP_INVERT_SWITCH 64

#define FLASH_BULK_OP 128
#define FLASH_BULK_WRITE 1
#define FLASH_BULK_READ  2
