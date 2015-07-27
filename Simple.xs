#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "png.h"
#include <stdio.h>

/* Windows setjmp and longjmp don't work by Perl default */
#ifdef WIN32
#  undef setjmp
#  undef longjmp
#  include <setjmp.h>
#endif

#define HEADERSIZE   54               /* ヘッダのサイズ 54 = 14 + 40         */
#define PALLETSIZE 1024               /* パレットのサイズ                    */
#define MAXWIDTH   1000               /* 幅(pixel)の上限                     */
#define MAXHEIGHT  1000               /* 高さ(pixel) の上限                  */

unsigned char Bmp_headbuf[HEADERSIZE];/* ヘッダを格納するための変数          */
unsigned char Bmp_Pallet[PALLETSIZE]; /* カラーパレットを格納                */

char Bmp_type[2];                     /* ファイルタイプ "BM"                 */
unsigned long Bmp_size;               /* bmpファイルのサイズ (バイト)        */
unsigned int Bmp_info_header_size; /* 情報ヘッダのサイズ = 40             */
unsigned int Bmp_header_size;      /* ヘッダサイズ = 54*/
long Bmp_height;                      /* 高さ (ピクセル)                     */
long Bmp_width;                       /* 幅   (ピクセル)                     */
unsigned short Bmp_planes;          /* プレーン数 常に 1                   */
unsigned short Bmp_color;          /* 色 (ビット)     24                  */
long Bmp_comp;                        /* 圧縮方法         0                  */
long Bmp_image_size;                  /* 画像部分のファイルサイズ (バイト)   */
long Bmp_xppm;                        /* 水平解像度 (ppm)                    */
long Bmp_yppm;                        /* 垂直解像度 (ppm)                    */

typedef struct {                      /* 1ピクセルあたりの赤緑青の各輝度     */
  unsigned char r;
  unsigned char g;
  unsigned char b;
} color;

typedef struct {
  long height;
  long width;
  color data[MAXHEIGHT][MAXWIDTH];
  IV rgb_data[MAXHEIGHT][MAXWIDTH];
} BitmapImage;

void ReadBmp(char *filename, BitmapImage *imgp);
void WriteBmp(char *filename, BitmapImage *tp);
void PrintBmpInfo(char *filename);
void HMirror(BitmapImage *sp, BitmapImage *tp);
void VMirror(BitmapImage *sp, BitmapImage *tp);
void Rotate90(int a, BitmapImage *sp, BitmapImage *tp);
void Shrink(int a, BitmapImage *sp, BitmapImage *tp);
void Mosaic(int a, BitmapImage *sp, BitmapImage *tp);
void Gray(BitmapImage *sp, BitmapImage *tp);
void Diminish(BitmapImage *sp, BitmapImage *tp, unsigned char x);

// Read bitmap image from file
void ReadBmp(char *filename, BitmapImage *imgp) {
  int i,j;
  int Real_width;
  int y;
  FILE *Bmp_Fp=fopen(filename,"rb");  /* バイナリモード読み込み用にオープン  */
  unsigned char* Bmp_Data;           /* 画像データを1行分格納               */

  if(Bmp_Fp == NULL){
    fprintf(stderr,"Error: file %s couldn\'t open for read!.\n", filename);
    exit(1);
  }
  
  /* ヘッダ読み込み */
  fread(Bmp_headbuf, sizeof(unsigned char), HEADERSIZE, Bmp_Fp);
        
  memcpy(&Bmp_type, Bmp_headbuf, 2);
  if (strncmp(Bmp_type,"BM",2) != 0) {
    fprintf(stderr,"Error: %s is not a bmp file.\n", filename);
    exit(1);
  }
  
  memcpy(&imgp->width, Bmp_headbuf+18, 4);
  memcpy(&imgp->height, Bmp_headbuf+22, 4);
  memcpy(&Bmp_color, Bmp_headbuf+28, 2);
  if (Bmp_color != 24) {
    fprintf(stderr,"Error: Bmp_color = %d is not implemented in this program.\n", Bmp_color);
    exit(1);
  }
  
  if (imgp->width > MAXWIDTH) {
    fprintf(stderr,"Error: Bmp_width = %ld > %d = MAXWIDTH!\n", Bmp_width, MAXWIDTH);
    exit(1);
  }

  if (imgp->height > MAXHEIGHT) {
    fprintf(stderr,"Error: Bmp_height = %ld > %d = MAXHEIGHT!\n", Bmp_height, MAXHEIGHT);
    exit(1);
  }

  /* 4byte 境界にあわせるために実際の幅の計算 */
  Real_width = imgp->width * 3 + imgp->width % 4; 

 /* 配列領域の動的確保. 失敗した場合はエラーメッセージを出力して終了 */
 if((Bmp_Data = (unsigned char *)malloc(Real_width)) == NULL) {
   fprintf(stderr,"Error: Memory allocation failed for Bmp_Data!\n");
   exit(1);
 }
 
  // Read image data
  for(i=0; i < imgp->height; i++) {
    fread(Bmp_Data, 1, Real_width, Bmp_Fp);
    for (j=0; j < imgp->width; j++) {
      imgp->data[imgp->height - i - 1][j].r = Bmp_Data[j * 3];
      imgp->data[imgp->height - i - 1][j].g = Bmp_Data[j * 3 + 1];
      imgp->data[imgp->height - i - 1][j].b = Bmp_Data[j * 3 + 2];
      
      imgp->rgb_data[imgp->height - i - 1][j]
        = (IV)Bmp_Data[j * 3 + 2] * (16 * 16) + (IV)Bmp_Data[j * 3 + 1] * (16) + (IV)Bmp_Data[j * 3];
    }
  }

  // Close file
  fclose(Bmp_Fp); 
  
  // Relese memory
  free(Bmp_Data);
}

// Write bitmap image to file
void WriteBmp(char *filename, BitmapImage *tp) {

  int i,j;
  int Real_width;
  
  // Open file
  FILE *Out_Fp = fopen(filename, "wb");

  // Image one line data
  unsigned char *Bmp_Data;     
  
  if(Out_Fp == NULL){
    fprintf(stderr,"Error: file %s couldn\'t open for write!\n",filename);
    exit(1);
  }

  Bmp_color=24;
  Bmp_header_size=HEADERSIZE;
  Bmp_info_header_size=40;
  Bmp_planes=1;

  /* 4byte 境界にあわせるために実際の幅の計算 */
  Real_width = tp->width * 3 + tp->width % 4;  

  /* 配列領域の動的確保. 失敗した場合はエラーメッセージを出力して終了 */
  if((Bmp_Data = (unsigned char *)malloc(Real_width)) == NULL) {
   fprintf(stderr,"Error: Memory allocation failed for Bmp_Data!\n");
   exit(1);
 }

  /* ヘッダ情報の準備 */
  Bmp_xppm=Bmp_yppm = 0;
  Bmp_image_size = tp->height * Real_width;
  Bmp_size = Bmp_image_size + HEADERSIZE;
  Bmp_headbuf[0]='B';
  Bmp_headbuf[1] = 'M';
  memcpy(Bmp_headbuf+2, &Bmp_size, sizeof(Bmp_size));
  Bmp_headbuf[6] = Bmp_headbuf[7] = Bmp_headbuf[8] = Bmp_headbuf[9] = 0;
  memcpy(Bmp_headbuf+10, &Bmp_header_size, sizeof(Bmp_header_size));
  Bmp_headbuf[11] = Bmp_headbuf[12] = Bmp_headbuf[13] = 0;
  memcpy(Bmp_headbuf+14, &Bmp_info_header_size, sizeof(Bmp_info_header_size)); 
  Bmp_headbuf[15] = Bmp_headbuf[16] = Bmp_headbuf[17]=0;
  memcpy(Bmp_headbuf+18, &tp->width, sizeof(Bmp_width));
  memcpy(Bmp_headbuf+22, &tp->height, sizeof(Bmp_height));
  memcpy(Bmp_headbuf+26, &Bmp_planes, sizeof(Bmp_planes));
  memcpy(Bmp_headbuf+28, &Bmp_color, sizeof(Bmp_color));
  memcpy(Bmp_headbuf+34, &Bmp_image_size, sizeof(Bmp_image_size));
  memcpy(Bmp_headbuf+38, &Bmp_xppm, sizeof(Bmp_xppm));
  memcpy(Bmp_headbuf+42, &Bmp_yppm, sizeof(Bmp_yppm));
  Bmp_headbuf[46] = Bmp_headbuf[47] = Bmp_headbuf[48] = Bmp_headbuf[49] = 0;
  Bmp_headbuf[50] = Bmp_headbuf[51] = Bmp_headbuf[52] = Bmp_headbuf[53] = 0;
  
  /* ヘッダ情報書き出し */
  fwrite(Bmp_headbuf, sizeof(unsigned char), HEADERSIZE, Out_Fp); 

  /* 画像データ書き出し */
  for (i=0;i<tp->height;i++) {
    for (j=0;j<tp->width;j++) {
      Bmp_Data[j*3]   = tp->data[tp->height-i-1][j].r;
      Bmp_Data[j*3+1] = tp->data[tp->height-i-1][j].g;
      Bmp_Data[j*3+2] = tp->data[tp->height-i-1][j].b;
    }
    for (j=tp->width*3; j<Real_width; j++) {
      Bmp_Data[j]=0;
    }
    fwrite(Bmp_Data, sizeof(unsigned char), Real_width, Out_Fp);
  }

  /* 動的に確保した配列領域の解放 */
  free(Bmp_Data);
  
  /* ファイルクローズ */
  fclose(Out_Fp);
}

MODULE = Image::PNG::Simple PACKAGE = Image::PNG::Simple

SV
test(...)
  PPCODE:
{
  png_structp png;
  png_infop info;
  png_color_8 sBIT;
  png_bytep* lines;
  FILE *outf;
  UV y;

  BitmapImage *tmp1;
  
  
  tmp1=(BitmapImage *)malloc(sizeof(BitmapImage));

  ReadBmp("t/dog.bmp",tmp1);

  WriteBmp("t/dog_copy.bmp",tmp1);

  outf = fopen("t/dog_copy.png", "wb");
  if (!outf)
  {
    croak("Can't open png file for writing");
  }
  png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (png == NULL)
  {
    fclose(outf);
    croak("Fail png_create_write_struct");
  }

  info = png_create_info_struct(png);
  if (info == NULL) {
    png_destroy_write_struct(&png, (png_infopp)NULL);
    fclose(outf);
    croak("Fail png_create_info_struct");
  }


  lines = NULL;
  
  if (setjmp(png_jmpbuf(png))) {
    png_destroy_write_struct(&png, &info);
    if (lines != NULL) {
      free(lines);
    }
    fclose(outf);
    croak("libpng internal error");
  }

  png_init_io(png, outf);

  png_set_IHDR(png, info, tmp1->width, tmp1->height, 8, 
      (Bmp_color == 32 ? PNG_COLOR_TYPE_RGB_ALPHA : PNG_COLOR_TYPE_RGB),
      PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_BASE);

  sBIT.red = 8;
  sBIT.green = 8;
  sBIT.blue = 8;
  sBIT.alpha = (png_byte)(Bmp_color == 32 ? 8 : 0);
  png_set_sBIT(png, info, &sBIT);

  png_write_info(png, info);
  png_set_bgr(png);
  
  lines = (png_bytep *)malloc(sizeof(png_bytep *) * tmp1->height);
  
  for (y = 0; y < tmp1->height; y++) {
    lines[y] = (png_bytep)&(tmp1->data[y]);
  }

  png_write_image(png, lines);
  png_write_end(png, info);
  png_destroy_write_struct(&png, &info);
  
  
  free(lines);
  free(tmp1);
  fclose(outf);

  XSRETURN(0);
}
