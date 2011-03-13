#include <TVout.h>
#include <fontALL.h>
#include <avr/pgmspace.h>
#include <i2cmaster.h>
#include <nunchuck.h>



TVout tv;
Nunchuck n;

#define TVMODE PAL    // Set to either PAL or NTSC

#define MAX_X 128
#define MAX_Y 96

// The heights of the buildings that make up a city
uint8_t building[]={2,3,5,2,4,2,4,3,2,3,2,1};

// The locations of the cities [0,1,2,4,5,6] and the missile base [3] 
uint8_t citypos[] = {4, 4+18*1, 4+18*2, 4+18*3, 4+18*4, 4+18*5, 4+18*6};

uint8_t cursorX;
uint8_t cursorY;
uint8_t minx, miny, maxx, maxy;


void setup() {
#if TVMODE == PAL
  tv.begin(_PAL, MAX_X, MAX_Y);
#else
  tv.begin(_NTSC, MAX_X, MAX_Y);
#endif

  if (n.begin(NUNCHUCK_PLAYER_1)) {
    tv.print("Nunchuck begin error");
    while(1);
  }

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

  for (i=0; i<shots; i++) {
    x=citypos[3]+(missilestack[i]&0x0F);
    y=MAX_Y-8+(missilestack[i]>>4);
    tv.set_pixel(x,y, 1);
  }
}


//    n.update();
//   if (n.button_c())
//       bool joy_up();
//        bool joy_down();
//        bool joy_left();
//        bool joy_right();
//        unsigned char joy_x();
//        unsigned char joy_y();
//        unsigned char acc_x();
//        unsigned char acc_y();
//        unsigned char acc_z();
        
void DrawCursor(uint8_t x, uint8_t y) {

  tv.draw_row(y, x-2, x+3, 2);
  tv.draw_column(x, y-3, y+3, 2);
  
}

void WaitForZRelease() {
  tv.delay_frame(10);
  do {
    tv.delay_frame(1);
    n.update();
  } while (n.button_z());
}



        
        
void loop() {
  uint8_t i;
  tv.select_font(font8x8);
  tv.printPGM(3,3,PSTR("Missile Command"));
  tv.delay_frame(100);
  float myx, myy;
  char buf[4];


  cursorX=10;
  cursorY=10;

  for (;;) {
    n.update();
    tv.fill(0);
    tv.draw_row(0, 0, MAX_X, 1);
    tv.draw_row(MAX_Y-1, 0, MAX_X, 1);
    for (i=0; i<6; i++) DrawCity(i);
    DrawCursor(cursorX, cursorY);
    myx=n.joy_x();
    myy=n.joy_y();
    
    myx=myx-47;
    if (myx<0) myx=0;
    myx=myx*0.85;
    if (myx>MAX_X-7) myx=MAX_X-7;

    myy=myy-64;
    if (myy<0) myy=0;
    myy=myy*0.6;
    if (myy>MAX_Y-16) myy=MAX_Y-16;

    cursorX=3+myx;
    cursorY=MAX_Y-12-myy;
    DrawBase(28);
    tv.delay_frame(1);
  }
  
  for (;;);
}

