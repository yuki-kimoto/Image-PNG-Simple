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

/*
__LITTLE_ENDIAN__
__BIG_ENDIAN__
*/

/* BMP header size 54 = 14 + 40 */
#define BMP_HEADERSIZE   54

#define BMP_MAXWIDTH   1000
#define BMP_MAXHEIGHT  1000

typedef struct {
  char bmp_type[2];                     /* ファイルタイプ "BM"                 */
  NV bmp_size;               /* bmpファイルのサイズ (バイト)        */
  UV bmp_info_header_size; /* 情報ヘッダのサイズ = 40             */
  UV bmp_header_size;      /* ヘッダサイズ = 54*/
  UV bmp_height;                      /* 高さ (ピクセル)                     */
  UV bmp_width;                       /* 幅   (ピクセル)                     */
  UV bmp_planes;          /* プレーン数 常に 1                   */
  UV bmp_color;          /* 色 (ビット)     24                  */
  UV bmp_comp;                        /* 圧縮方法         0                  */
  UV bmp_image_size;                  /* 画像部分のファイルサイズ (バイト)   */
  UV bmp_xppm;                        /* 水平解像度 (ppm)                    */
  UV bmp_yppm;                        /* 垂直解像度 (ppm)                    */
  
} BMPInfo;

char bmp_type[2];                     /* ファイルタイプ "BM"                 */
NV bmp_size;               /* bmpファイルのサイズ (バイト)        */
UV bmp_info_header_size; /* 情報ヘッダのサイズ = 40             */
UV bmp_header_size;      /* ヘッダサイズ = 54*/
UV bmp_height;                      /* 高さ (ピクセル)                     */
UV bmp_width;                       /* 幅   (ピクセル)                     */
UV bmp_planes;          /* プレーン数 常に 1                   */
UV bmp_color;          /* 色 (ビット)     24                  */
UV bmp_comp;                        /* 圧縮方法         0                  */
UV bmp_image_size;                  /* 画像部分のファイルサイズ (バイト)   */
UV bmp_xppm;                        /* 水平解像度 (ppm)                    */
UV bmp_yppm;                        /* 垂直解像度 (ppm)                    */

typedef struct {                      /* 1ピクセルあたりの赤緑青の各輝度     */
  unsigned char r;
  unsigned char g;
  unsigned char b;
} Color;

typedef struct {
  UV height;
  UV width;
  Color data[BMP_MAXHEIGHT][BMP_MAXWIDTH];
} BMPImage;

void ReadBMP(char *filename, BMPImage *imgp);
void WriteBMP(char *filename, BMPImage *tp);

// Read bitmap image from file
void ReadBMP(char *filename, BMPImage *imgp) {
  IV i,j;
  IV Real_width;
  IV y;
  FILE *bmp_Fp=fopen(filename,"rb");  /* バイナリモード読み込み用にオープン  */
  unsigned char* bmp_Data;           /* 画像データを1行分格納               */

  if(bmp_Fp == NULL){
    fprintf(stderr,"Error: file %s couldn\'t open for read!.\n", filename);
    exit(1);
  }
  
  /* ヘッダ読み込み */
  unsigned char bmp_headbuf[BMP_HEADERSIZE];
  fread(bmp_headbuf, sizeof(unsigned char), BMP_HEADERSIZE, bmp_Fp);
        
  memcpy(&bmp_type, bmp_headbuf, 2);
  if (strncmp(bmp_type,"BM",2) != 0) {
    fprintf(stderr,"Error: %s is not a bmp file.\n", filename);
    exit(1);
  }
  
  memcpy(&imgp->width, bmp_headbuf+18, 4);
  memcpy(&imgp->height, bmp_headbuf+22, 4);
  memcpy(&bmp_color, bmp_headbuf+28, 2);
  if (bmp_color != 24) {
    fprintf(stderr,"Error: bmp_color = %d is not implemented in this program.\n", bmp_color);
    exit(1);
  }
  
  if (imgp->width > BMP_MAXWIDTH) {
    fprintf(stderr,"Error: bmp_width = %ld > %d = BMP_MAXWIDTH!\n", bmp_width, BMP_MAXWIDTH);
    exit(1);
  }

  if (imgp->height > BMP_MAXHEIGHT) {
    fprintf(stderr,"Error: bmp_height = %ld > %d = BMP_MAXHEIGHT!\n", bmp_height, BMP_MAXHEIGHT);
    exit(1);
  }

  /* 4byte 境界にあわせるために実際の幅の計算 */
  Real_width = imgp->width * 3 + imgp->width % 4; 

 /* 配列領域の動的確保. 失敗した場合はエラーメッセージを出力して終了 */
 if((bmp_Data = (unsigned char *)malloc(Real_width)) == NULL) {
   fprintf(stderr,"Error: Memory allocation failed for bmp_Data!\n");
   exit(1);
 }
 
  // Read image data
  for(i=0; i < imgp->height; i++) {
    fread(bmp_Data, 1, Real_width, bmp_Fp);
    for (j=0; j < imgp->width; j++) {
      imgp->data[imgp->height - i - 1][j].r = bmp_Data[j * 3];
      imgp->data[imgp->height - i - 1][j].g = bmp_Data[j * 3 + 1];
      imgp->data[imgp->height - i - 1][j].b = bmp_Data[j * 3 + 2];
    }
  }

  // Close file
  fclose(bmp_Fp); 
  
  // Relese memory
  free(bmp_Data);
}

// Write bitmap image to file
void WriteBMP(char *filename, BMPImage *tp) {

  IV i,j;
  IV Real_width;
  
  // Open file
  FILE *Out_Fp = fopen(filename, "wb");

  // Image one line data
  unsigned char *bmp_Data;     
  
  if(Out_Fp == NULL){
    fprintf(stderr,"Error: file %s couldn\'t open for write!\n",filename);
    exit(1);
  }

  bmp_color = 24;
  bmp_header_size = BMP_HEADERSIZE;
  bmp_info_header_size = 40;
  bmp_planes = 1;

  /* 4byte 境界にあわせるために実際の幅の計算 */
  Real_width = tp->width * 3 + tp->width % 4;  

  /* 配列領域の動的確保. 失敗した場合はエラーメッセージを出力して終了 */
  if((bmp_Data = (unsigned char *)malloc(Real_width)) == NULL) {
   fprintf(stderr, "Error: Memory allocation failed for bmp_Data!\n");
   exit(1);
 }

  /* ヘッダ情報の準備 */
  unsigned char bmp_headbuf[BMP_HEADERSIZE];
  bmp_xppm = bmp_yppm = 0;
  bmp_image_size = tp->height * Real_width;
  bmp_size = bmp_image_size + BMP_HEADERSIZE;
  bmp_headbuf[0]='B';
  bmp_headbuf[1] = 'M';
  memcpy(bmp_headbuf+2, &bmp_size, sizeof(bmp_size));
  bmp_headbuf[6] = bmp_headbuf[7] = bmp_headbuf[8] = bmp_headbuf[9] = 0;
  memcpy(bmp_headbuf+10, &bmp_header_size, sizeof(bmp_header_size));
  bmp_headbuf[11] = bmp_headbuf[12] = bmp_headbuf[13] = 0;
  memcpy(bmp_headbuf+14, &bmp_info_header_size, sizeof(bmp_info_header_size)); 
  bmp_headbuf[15] = bmp_headbuf[16] = bmp_headbuf[17]=0;
  memcpy(bmp_headbuf+18, &tp->width, sizeof(bmp_width));
  memcpy(bmp_headbuf+22, &tp->height, sizeof(bmp_height));
  memcpy(bmp_headbuf+26, &bmp_planes, sizeof(bmp_planes));
  memcpy(bmp_headbuf+28, &bmp_color, sizeof(bmp_color));
  memcpy(bmp_headbuf+34, &bmp_image_size, sizeof(bmp_image_size));
  memcpy(bmp_headbuf+38, &bmp_xppm, sizeof(bmp_xppm));
  memcpy(bmp_headbuf+42, &bmp_yppm, sizeof(bmp_yppm));
  bmp_headbuf[46] = bmp_headbuf[47] = bmp_headbuf[48] = bmp_headbuf[49] = 0;
  bmp_headbuf[50] = bmp_headbuf[51] = bmp_headbuf[52] = bmp_headbuf[53] = 0;
  
  /* ヘッダ情報書き出し */
  fwrite(bmp_headbuf, sizeof(unsigned char), BMP_HEADERSIZE, Out_Fp); 

  /* 画像データ書き出し */
  for (i=0;i<tp->height;i++) {
    for (j=0;j<tp->width;j++) {
      bmp_Data[j*3]   = tp->data[tp->height-i-1][j].r;
      bmp_Data[j*3+1] = tp->data[tp->height-i-1][j].g;
      bmp_Data[j*3+2] = tp->data[tp->height-i-1][j].b;
    }
    for (j=tp->width*3; j<Real_width; j++) {
      bmp_Data[j]=0;
    }
    fwrite(bmp_Data, sizeof(unsigned char), Real_width, Out_Fp);
  }

  /* 動的に確保した配列領域の解放 */
  free(bmp_Data);
  
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

  BMPImage *tmp1;
  
  
  tmp1=(BMPImage *)malloc(sizeof(BMPImage));

  ReadBMP("t/dog.bmp",tmp1);

  WriteBMP("t/dog_copy.bmp",tmp1);

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
      (bmp_color == 32 ? PNG_COLOR_TYPE_RGB_ALPHA : PNG_COLOR_TYPE_RGB),
      PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_BASE);

  sBIT.red = 8;
  sBIT.green = 8;
  sBIT.blue = 8;
  sBIT.alpha = (png_byte)(bmp_color == 32 ? 8 : 0);
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
