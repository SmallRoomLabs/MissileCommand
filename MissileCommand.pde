#include <TVout.h>
#include <fontALL.h>
#include <avr/pgmspace.h>

TVout tv;

#define TVMODE PAL    // Set to either PAL or NTSC

#define MAX_X 128
#define MAX_Y 96

uint8_t building[]={2,3,5,2,4,2,4,3,2,3,2,1};
uint8_t citypos[] = {3, 3+18*1, 3+18*2, 3+18*3, 3+18*4, 3+18*5, 3+18*6};


void setup() {
#if TVMODE == PAL
  tv.begin(_PAL, MAX_X, MAX_Y);
#else
  tv.begin(_NTSC, MAX_X, MAX_Y);
#endif
}



void DrawCity(uint8_t no) {
  uint8_t i;

  if (no>2) no++;
  for (i=0; i<12; i++) {
    tv.draw_column(citypos[no]+i, MAX_Y-2-building[i], MAX_Y-2, 1);
  }  
}




//     0123456789ABCDE 
//   0 ......X......
//   1 .....X.X.....
//   2 ....X.X.X....
//   3 ...X.X.X.X...
//   4 ..X.X.X.X.X..
//   5 .X.X.X.X.X.X.
//   6 X.X.X.X.X.X.X
//

uint8_t missilestack[] = {0x66, 0x64, 0x68, 0x62, 0x6a, 0x60, 0x6c, 0x55, 0x57, 0x53, 0x59, 0x51, 0x5b, 0x46, 0x44, 0x48, 0x42, 0x4a, 0x35, 0x37, 0x33, 0x39, 0x26, 0x24, 0x28, 0x15, 0x17, 0x06};

void DrawBase(uint8_t shots) {
  uint8_t i;
  uint8_t x;
  uint8_t y;

  for (i=0; i<28; i++) {
    x=citypos[3]+(missilestack[i]&0x0F);
    y=MAX_Y-8+(missilestack[i]>>4);
    tv.set_pixel(x,y, 1);
  }
}


void loop() {
  uint8_t i;
  tv.select_font(font8x8);
  tv.printPGM(3,3,PSTR("Missile Command"));
  tv.draw_row(0, 0, MAX_X-1, 1);
  tv.draw_row(MAX_Y-1, 0, MAX_X-1, 1);
  for (i=0; i<6; i++) DrawCity(i);
  for (i=0; i<29; i++) {
    DrawBase(i);
    tv.delay(250);
  }
//  tv.fill(2);
  for (;;);
}

