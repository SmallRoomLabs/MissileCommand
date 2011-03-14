/*
 *                      _         _ _      
 *                /\/\ (_)___ ___(_) | ___ 
 *               /    \| / __/ __| | |/ _ \
 *              / /\/\ \ \__ \__ \ | |  __/
 *      ___     \/    \/_|___/___/_|_|\___|          _
 *     / __\___  _ __ ___  _ __ ___   __ _ _ __   __| |
 *    / /  / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |
 *   / /__| (_) | | | | | | | | | | | (_| | | | | (_| |
 *   \____/\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|
 *  
 * A simple implementation of the classic "Missile Command"
 * arcade game to be used with the Video Game Shield by Layne & Wayne
 * 
 * This game is based on the Atari 2600 version of the game with six
 * cities to defend and a single missile base. 
 *
 * The bitmaps are converted from .bmp to c-source using image2code
 * that cand be found at http://sourceforge.net/projects/image2code/
 *
 * This software is licensed under the Creative Commons Attribution-
 * ShareAlike 3.0 Unported License.
 * http://creativecommons.org/licenses/by-sa/3.0/
 *
 * Copyright (c) 2011 Mats Engstrom (mats@smallroomlabs.com)
 *
 * 
 */
 
#include <TVout.h>
#include <fontALL.h>
#include <avr/pgmspace.h>
#include <i2cmaster.h>
#include <nunchuck.h>
#include "bitmaps.h"

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

uint8_t explosionX[50];  // X-coordinate of fireball
uint8_t explosionY[50];  // Y-coordinate of fireball
uint8_t explosionS[50];  // status/step of fireball sequence


uint8_t ballsize[]= {0,3,4,5,6,7,8,9,10,11,10,9,8,7,6,5,4,3,0};


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



void UpdateExplosions() {
  uint8_t i;
  uint8_t siz;
  
  for (i=0; i<50; i++) {
    if (explosionS[i]>0) {
      siz=ballsize[explosionS[i]];
      if (siz>0) {
        tv.draw_circle(explosionX[i], explosionY[i], siz, 1);
        explosionS[i]++;
      } else {
        explosionS[i]=0;
      }
    }
  }

}



        
        
void loop() {
  uint8_t i;
  float fx, fy;
  uint8_t noMissiles;

  tv.bitmap(10, 10, bitmap_Missile);
  tv.bitmap(0, 30, bitmap_Command);

  tv.select_font(font4x6);
  tv.delay_frame(100);

  cursorX=10;
  cursorY=10;
  noMissiles=28;

  for (;;) {
    n.update();
    tv.fill(0);
    tv.draw_row(0, 0, MAX_X, 1);
    tv.draw_row(MAX_Y-1, 0, MAX_X, 1);
    for (i=0; i<6; i++) DrawCity(i);

    DrawCursor(cursorX, cursorY);
    
    fx=n.joy_x()-47;
    if (fx<0) fx=0;
    fx*=0.85;
    if (fx>MAX_X-7) fx=MAX_X-7;

    fy=n.joy_y()-64;
    if (fy<0) fy=0;
    fy*=0.6;
    if (fy>MAX_Y-16) fy=MAX_Y-16;

    cursorX=3+fx;
    cursorY=MAX_Y-12-fy;
    
    DrawBase(noMissiles);
  
    if (n.button_z()) {
      uint8_t i;
      if (noMissiles>0) {
        for (i=0;i<50 && explosionS[i]>0; i++);
        if (i<50) {
          noMissiles--;
          explosionX[i]=cursorX;
          explosionY[i]=cursorY;
          explosionS[i]=1;
        }
      }
    }

    UpdateExplosions();

    tv.delay_frame(2);
  }
  
  for (;;);
}

