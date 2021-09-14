#include "tests.h"

#include <6502.h>
#include <peekpoke.h>
#include <kawari.h>
#include <util.h>
#include <stdio.h>
#include <stdlib.h>

static signed short sadd(signed short v1, signed short v2)
{
   signed short result;
   POKE(OP_1_HI, (v1&0xff00)>>8);
   POKE(OP_1_LO, v1&0xff);
   POKE(OP_2_HI, (v2&0xff00)>>8);
   POKE(OP_2_LO, v2&0xff);
   POKE(OPER, SADD);
   // Result is 16 bits
   result = (PEEK(OP_2_HI) << 8) |
            (PEEK(OP_2_LO));
   return result;
}

int sadd_1(void) {
   signed short o1; 
   signed short o2; 
   unsigned long p1;
   unsigned long p2;
   int t;

   EXPECT_EQ(sadd(32767,2) , (signed short)(32767+2));
   EXPECT_EQ(PEEK(OPER) & DIVZ, 0);
   EXPECT_EQ(PEEK(OPER) & OVERFLOW, OVERFLOW);
   EXPECT_EQ(PEEK(OPER) & UNDERFLOW, 0);

   EXPECT_EQ(sadd(-32767,-2) , (signed short)(-32767-2));
   EXPECT_EQ(PEEK(OPER) & DIVZ, 0);
   EXPECT_EQ(PEEK(OPER) & OVERFLOW, 0);
   EXPECT_EQ(PEEK(OPER) & UNDERFLOW, 1);

   EXPECT_EQ(sadd(8,3) , 8+3);
   EXPECT_EQ(PEEK(OPER) & DIVZ, 0);
   EXPECT_EQ(PEEK(OPER) & OVERFLOW, 0);
   EXPECT_EQ(PEEK(OPER) & UNDERFLOW, 0);

   EXPECT_EQ(sadd(-257,64) , -257+64);
   EXPECT_EQ(PEEK(OPER) & DIVZ, 0);
   EXPECT_EQ(PEEK(OPER) & OVERFLOW, 0);
   EXPECT_EQ(PEEK(OPER) & UNDERFLOW, 0);

   EXPECT_EQ(sadd(1234,-64) , 1234-64);
   EXPECT_EQ(PEEK(OPER) & DIVZ, 0);
   EXPECT_EQ(PEEK(OPER) & OVERFLOW, 0);
   EXPECT_EQ(PEEK(OPER) & UNDERFLOW, 0);

   for (t=0;t<NUM_RAND_RUNS;t++) {
      o1=(signed short) rand();
      o2=(signed short) rand();
      EXPECT_EQ(sadd(o1,o2) , o1+o2);
      EXPECT_EQ(PEEK(OPER) & DIVZ, 0);
      p1=(unsigned long)o1;
      p2=(unsigned long)o2;
      if ((p1 + p2) > 32767L) {
          EXPECT_EQ(PEEK(OPER) & OVERFLOW, OVERFLOW);
      } else {
          EXPECT_EQ(PEEK(OPER) & OVERFLOW, 0);
      }
      EXPECT_EQ(PEEK(OPER) & UNDERFLOW, 0);
   }
}

