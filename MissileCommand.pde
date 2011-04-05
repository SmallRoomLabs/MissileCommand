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
 * http://www.wayneandlayne.com/projects/video-game-shield/
 * 
 * This game is based on the Atari 2600 version of the game with six
 * cities to defend and a single missile base. 
 *
 * The bitmaps used in this game are converted from .bmp to c-source
 *  using image2code. http://sourceforge.net/projects/image2code/
 *
 * This software is licensed under the Creative Commons Attribution-
 * ShareAlike 3.0 Unported License.
 * http://creativecommons.org/licenses/by-sa/3.0/
 *
 * Copyright (c) 2011 Mats Engstrom (mats@smallroomlabs.com)
 *
 * 
 */
 
#include <avr/pgmspace.h>
#include <i2cmaster.h>
#include <nunchuck.h>
#include <TVout.h>
#include <fontALL.h>
#include "bitmaps.h"

TVout tv;
Nunchuck nc;

// For accessing the screen memory directly using *display.screen
extern TVout_vid display;


#define TVMODE PAL    // Set to either PAL or NTSC

// Screen size
#define MAX_X 128
#define MAX_Y 96

#define FREE 255 // Magic value indicating usused slot

// Offsets & Scaling factors for the nunchuck
#define NUNCHUCK_HOR_OFFSET 47
#define NUNCHUCK_HOR_SCALE  0.85
#define NUNCHUCK_VER_OFFSET 64
#define NUNCHUCK_VER_SCALE  0.85

#define FULLMISSILEPILE 28  // Number of missiles on the missile base when full
#define MAXEXPLOSIONS 50    // Maximum number of explosions
#define MAXMISSILES 3       // Max number of missiles in the air

// Current position of the missiles (X/Y) and target (T)
uint8_t missileX[MAXMISSILES];
uint8_t missileY[MAXMISSILES];
uint8_t missileT[MAXMISSILES]; // Missile target - index to explosionsXYS[] -arrays 
uint8_t missileL[MAXMISSILES];


//     0123456789ABCDE 
//   0 ......X......
//   1 .....X.X.....
//   2 ....X.X.X....
//   3 ...X.X.X.X...
//   4 ..X.X.X.X.X..
//   5 .X.X.X.X.X.X.
//   6 X.X.X.X.X.X.X
//
uint8_t missilestack[FULLMISSILEPILE] = {
  0x66, 0x64, 0x68, 0x62, 0x6a, 0x60, 0x6c, 0x55, 
  0x57, 0x53, 0x59, 0x51, 0x5b, 0x46, 0x44, 0x48, 
  0x42, 0x4a, 0x35, 0x37, 0x33, 0x39, 0x26, 0x24, 
  0x28, 0x15, 0x17, 0x06};

#define CITYWIDTH 12   // Twelve buldings makes up a city

// The heights of the buildings that make up a city
uint8_t building[CITYWIDTH]={2,3,5,2,4,2,4,3,2,3,2,1};

// The locations of the cities [0,1,2,4,5,6] and the missile base [3] 
uint8_t citypos[] = {4, 4+18*1, 4+18*2, 4+18*3, 4+18*4, 4+18*5, 4+18*6};

// Current cursor location
uint8_t cursorX, cursorY;

// Coordinates and Statuses of all fireballs
uint8_t explosionX[MAXEXPLOSIONS];  // X-coordinate of fireball
uint8_t explosionY[MAXEXPLOSIONS];  // Y-coordinate of fireball
uint8_t explosionS[MAXEXPLOSIONS];  // status/step of fireball sequence

// The size of the fireball - as indexed by explosionS[]
uint8_t ballsize[]= {0,1,3,4,5,6,7,8,9,10,11,10,9,8,7,6,5,4,3,0};


//
// Initialize system
//
void setup() {
  // Initialize TVOut
  #if TVMODE == PAL
    tv.begin(_PAL, MAX_X, MAX_Y);
  #else
    tv.begin(_NTSC, MAX_X, MAX_Y);
  #endif

  tv.select_font(font4x6);

  // Try to initialize nunchucks
  if (nc.begin(NUNCHUCK_PLAYER_1)) {
    tv.printPGM(10, 10, PSTR("Nunchuck error."));
    tv.printPGM(10, 20, PSTR("Please connect & reset."));
    for(;;);
  }


}
/* Fill a row from one point to another
 *
 * Argument:
 *	line:
 *		The row that fill will be performed on.
 *	x0:
 *		edge 0 of the fill.
 *	x1:
 *		edge 1 of the fill.
 *	c:
 *		the color of the fill.
 *		(see color note at the top of this file)
*/
void draw_row_clipped(uint8_t line, uint16_t x0, uint16_t x1, uint8_t c) {
	uint8_t lbit, rbit;
	

        if (line>=MAX_Y) return;
        
        if ((x0>MAX_X) && (x1>MAX_X)) return;
        if (x0>MAX_X) x0=0;
        if (x1>MAX_X) x1=MAX_X-1;
        
        if (x0 == x1) return;

	if (x0 > x1) {
		lbit = x0;
		x0 = x1;
		x1 = lbit;
	}

	lbit = 0xff >> (x0&7);
	x0 = x0/8 + display.hres*line;
	rbit = ~(0xff >> (x1&7));
	x1 = x1/8 + display.hres*line;
	if (x0 == x1) {
		lbit = lbit & rbit;
		rbit = 0;
	}
	if (c == WHITE) {
		display.screen[x0++] |= lbit;
		while (x0 < x1) display.screen[x0++] = 0xff;
		display.screen[x0] |= rbit;
	}
	else if (c == BLACK) {
		display.screen[x0++] &= ~lbit;
		while (x0 < x1) display.screen[x0++] = 0;
		display.screen[x0] &= ~rbit;
	}
	else if (c == INVERT) {
		display.screen[x0++] ^= lbit;
		while (x0 < x1) display.screen[x0++] ^= 0xff;
		display.screen[x0] ^= rbit;
	}
} // end of draw_row_clipped



/* 
 * Draw a circle given a coordinate x,y and radius both filled and non filled.
 *
 * This code is copied from the TVout -library and modified to clip the cicle
 * at the borders of the screen.
 *
 * Arguments:
 * 	x0:
 *		The x coordinate of the center of the circle.
 *	y0:
 *		The y coordinate of the center of the circle.
 *	radius:
 *		The radius of the circle.
 *	c:
 *		The color of the circle.
 *		(see color note at the top of this file)
 *	fc:
 *		The color to fill the circle.
 *		(see color note at the top of this file)
 *		defualt  =-1 (do not fill)
 */
void draw_circle_clipped(uint8_t x0, uint8_t y0, uint8_t radius, char c, char fc) {

	int f = 1 - radius;
	int ddF_x = 1;
	int	ddF_y = -2 * radius;
	int x = 0;
	int y = radius;
	uint8_t pyy = y,pyx = x;
	
	draw_row_clipped(y0,x0-radius,x0+radius,fc);
        	
	while(x < y) {
		if(f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
		x++;
		ddF_x += 2;
		f += ddF_x;
		
		//there is a fill color
		if (fc != -1) {
			//prevent double draws on the same rows
			if (pyy != y) {
				draw_row_clipped(y0+y,x0-x,x0+x,fc);
				draw_row_clipped(y0-y,x0-x,x0+x,fc);
			}
			if (pyx != x && x != y) {
				draw_row_clipped(y0+x,x0-y,x0+y,fc);
				draw_row_clipped(y0-x,x0-y,x0+y,fc);
			}
			pyy = y;
			pyx = x;
		}
//		sp(x0 + x, y0 + y,c);
//		sp(x0 - x, y0 + y,c);
//		sp(x0 + x, y0 - y,c);
//		sp(x0 - x, y0 - y,c);
//		sp(x0 + y, y0 + x,c);
//		sp(x0 - y, y0 + x,c);
//		sp(x0 + y, y0 - x,c);
//		sp(x0 - y, y0 - x,c);
	}
} // end of draw_circle_clipped










//
// Draw a city on the screen - cityNo from 0 to 5
//
void DrawCity(uint8_t cityNo) {
  uint8_t i;

  if (cityNo>2) cityNo++;  // Offset after three cities to make space for base
  for (i=0; i<CITYWIDTH; i++) {
    tv.draw_column(citypos[cityNo]+i, MAX_Y-2-building[i], MAX_Y-2, 1);
  }  
}




//
// Draw the missile base showing the number of missiles left
//
void DrawMissileBase(uint8_t shots) {
  uint8_t i;
  uint8_t x;
  uint8_t y;
  uint8_t c;

  for (i=0; i<FULLMISSILEPILE; i++) {
    c=0; 
    if (i<shots) c=1;
    x=citypos[3]+(missilestack[i]&0x0F);
    y=MAX_Y-8+(missilestack[i]>>4);
    tv.set_pixel(x,y, c);
  }
}


        
//
// Draw the cursor/crosshairs on the screen
//
void DrawCursor(uint8_t x, uint8_t y) {
  tv.draw_row(y, x-2, x+3, 2);
  tv.draw_column(x, y-3, y+3, 2);
}





//
// Update and draw all the active fireballs
//
void UpdateExplosions() {
  uint8_t i;
  uint8_t siz;
  
  for (i=0; i<50; i++) {
    if (explosionS[i]>1) {
      siz=ballsize[explosionS[i]];
      if (siz>0) {
        draw_circle_clipped(explosionX[i], explosionY[i], siz, 0, 1);
        explosionS[i]++;
      } else {
        explosionS[i]=0;
        draw_circle_clipped(explosionX[i], explosionY[i], 11, 0, 0);
      }
    }
  }

}


void AttractMode() {
  uint8_t missilesLeft;
  boolean pressed=false;
  uint8_t i;
  uint8_t targetX, targetY;

  tv.fill(0);

  tv.draw_row(0, 0, MAX_X, 1);
  tv.draw_row(MAX_Y-1, 0, MAX_X, 1);
  for (i=0; i<6; i++) DrawCity(i);
  
  targetX=random(3,125);
  targetY=random(15,55);
  cursorX=random(3,115);
  cursorY=random(5,55);
  DrawCursor(cursorX, cursorY);
  
  do {
    missilesLeft=28;
    tv.bitmap(23, 10, bitmap_Missile);
    tv.bitmap(3, 30, bitmap_Command);

    DrawMissileBase(missilesLeft);

    do {
      DrawCursor(cursorX, cursorY);
      if ((cursorX==targetX) && (cursorY==targetY)) {
        if (missilesLeft>0) {
          targetX=random(3,125);
          targetY=random(15,55);
          // Find a free slot for the explosion
          for (i=0;i<MAXEXPLOSIONS && explosionS[i]>0; i++);
          if (i<MAXEXPLOSIONS) {
            missilesLeft--;
            DrawMissileBase(missilesLeft);
            explosionX[i]=cursorX;
            explosionY[i]=cursorY;
            explosionS[i]=1;
          }
        }
      }

      if (cursorX<targetX) cursorX++;
      if (cursorY<targetY) cursorY++;
      if (cursorX>targetX) cursorX--;
      if (cursorY>targetY) cursorY--;
      UpdateExplosions();
      DrawCursor(cursorX, cursorY);
      
      tv.delay(20);
      nc.update();
      if (nc.button_z()) pressed=true;
    } while ((!pressed) && (missilesLeft>0));

  } while (!pressed);

  tv.fill(0);
  tv.draw_row(0, 0, MAX_X, 1);
  tv.draw_row(MAX_Y-1, 0, MAX_X, 1);
  do {
    tv.delay(20);
    nc.update();
  } while (nc.button_z());
    
}




        
        
void loop() {
  uint8_t i;
  float fx, fy;
  uint8_t missilesLeft;
  boolean zIsPressed=false;

  AttractMode();

  cursorX=10;
  cursorY=10;
  missilesLeft=FULLMISSILEPILE;
  for (i=0; i<MAXMISSILES; i++) {
    missileT[i]=FREE;
  }


  for (;;) {
    nc.update();
    tv.fill(0);
    tv.draw_row(0, 0, MAX_X, 1);
    tv.draw_row(MAX_Y-1, 0, MAX_X, 1);
    for (i=0; i<6; i++) DrawCity(i);

    // Remove cursor by XOR'ing it from screen
    DrawCursor(cursorX, cursorY);
    
    // Calculate new position of the crosshair/cursor
    // Offset & scale the posistions to the entrire screen, 
    // including the corners, can be reached with the nunchuck
    // controller. 
    fx=nc.joy_x()-NUNCHUCK_HOR_OFFSET;
    if (fx<0) fx=0;
    fx*=NUNCHUCK_HOR_SCALE;
    if (fx>MAX_X-7) fx=MAX_X-7;

    fy=nc.joy_y()-NUNCHUCK_VER_OFFSET;
    if (fy<0) fy=0;
    fy*=NUNCHUCK_VER_SCALE;
    if (fy>MAX_Y-16) fy=MAX_Y-16;

    cursorX=3+fx;
    cursorY=MAX_Y-12-fy;  // Y-axis is inverted from the Nunchucks
    char buf[5];
    sprintf(buf,"%d",cursorX);
    tv.print(10,10,buf);
    sprintf(buf,"%d",cursorY);
    tv.print(10,20,buf);

    
    DrawMissileBase(missilesLeft);
  
    // Fire a missile if button is pressed
    if (nc.button_z()) {
      if (!zIsPressed) { // No Autorepeat
        zIsPressed=true;
        if (missilesLeft>0) {
          // Find free slot for missile
          uint8_t m;
          for (m=0; m<MAXMISSILES; m++) {
            if (missileT[m]==FREE) break;
          }
          if (m<MAXMISSILES) {
            // Find a free slot for the explosion
            for (i=0;i<MAXEXPLOSIONS && explosionS[i]>0; i++);
            if (i<MAXEXPLOSIONS) {
              missilesLeft--;
              explosionX[i]=cursorX;
              explosionY[i]=cursorY;
              explosionS[i]=1;
              missileX[m]=MAX_X/2;
              missileY[m]=MAX_Y-7;
              missileT[m]=i;
              missileL[m]=1;
            }
          }
        }
      }
    } else {
      zIsPressed=false;
    }

  for (i=0; i<MAXMISSILES; i++) {
    if (missileT[i]!=FREE ) {
      if (tv.draw_line(missileX[i], missileY[i], explosionX[missileT[i]], explosionY[missileT[i]], 1, missileL[i])) {
        explosionS[missileT[i]]=2;
        missileX[i]=0;
        missileY[i]=0;
        missileT[i]=FREE;
      } else {
        missileL[i]+=2;
      }      
    }
  }    


    UpdateExplosions();

    tv.delay_frame(1);
  }
  
}

