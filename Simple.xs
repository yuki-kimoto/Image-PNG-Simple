#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "png.h"
#include <stdio.h>
#include "BmpIoLib.h"

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

typedef struct {
  IBMP* pBmp;
} ImagePNGSimple;

MODULE = Image::PNG::Simple PACKAGE = Image::PNG::Simple

SV
new(...)
  PPCODE:
{
  char* class_name = SvPV_nolen(ST(0));
  
  ImagePNGSimple* ips = (ImagePNGSimple*)malloc(sizeof(ImagePNGSimple));
  
  size_t ips_iv = PTR2IV(ips);
  
  SV* ips_sv = sv_2mortal(newSViv(ips_iv));
  
  SV* ips_svrv = sv_2mortal(newRV_inc(ips_sv));
  
  SV* ips_obj = sv_bless(ips_svrv, gv_stashpv(class_name, 1));
  
  XPUSHs(ips_obj);
  XSRETURN(1);
}

SV
DESTORY(...)
  PPCODE:
{
  SV* ips_obj = ST(0);
  SV* ips_sv = SvROK(ips_obj) ? SvRV(ips_obj) : ips_obj;
  size_t ips_iv = SvIV(ips_sv);
  ImagePNGSimple* ips = INT2PTR(ImagePNGSimple*, ips_iv);
  
  if (ips->pBmp != NULL) {
    free(ips->pBmp);
  }
  free(ips);
  
  XSRETURN(0);
}

SV
read_bmp(...)
  PPCODE :
{
  SV* ips_obj = ST(0);
  SV* ips_sv = SvROK(ips_obj) ? SvRV(ips_obj) : ips_obj;
  size_t ips_iv = SvIV(ips_sv);
  ImagePNGSimple* ips = INT2PTR(ImagePNGSimple*, ips_iv);
  
  // Open bitmap file
  SV* sv_file = ST(1);
  char* file = SvPV_nolen(sv_file);
  FILE* infile = fopen(file, "rb");
  if (infile ==  NULL) {
    croak("Can't open bitmap file %s", file);
  }
  
  // Create bitmap data
  IBMP *pBmp = BmpIO_Load(infile);
  fclose(infile);
  if (pBmp == NULL) {
    croak("Can't parse bitmap file %s", file);
  }
  ips->pBmp = pBmp;
  
  XSRETURN(0);
}

SV
write_bmp(...)
  PPCODE:
{
  SV* ips_obj = ST(0);
  SV* ips_sv = SvROK(ips_obj) ? SvRV(ips_obj) : ips_obj;
  size_t ips_iv = SvIV(ips_sv);
  ImagePNGSimple* ips = INT2PTR(ImagePNGSimple*, ips_iv);

  XSRETURN(0);
}

SV
write_png(...)
  PPCODE:
{
  SV* ips_obj = ST(0);
  SV* ips_sv = SvROK(ips_obj) ? SvRV(ips_obj) : ips_obj;
  size_t ips_iv = SvIV(ips_sv);
  ImagePNGSimple* ips = INT2PTR(ImagePNGSimple*, ips_iv);

  XSRETURN(0);
}

SV
test(...)
  PPCODE:
{
  png_structp png;
  png_infop info;
  png_color_8 sBIT;
  png_bytep* lines;
  FILE *outf;
  IV x;
  IV y;

  FILE* infile = fopen("t/dog.bmp", "rb" );
  if (infile ==  NULL) {
    croak("Can't open input file");
  }
  
  IBMP *pBmp = BmpIO_Load(infile);
  fclose( infile );
  if (pBmp == NULL) {
    croak("Fail loading bitmap file");
  }
  
  FILE* outfile = fopen("t/dog_copy.bmp", "wb" );
  if (outfile ==  NULL) {
    croak("Can't open output file");
  }
  BmpIO_Save(outfile, pBmp);
  fclose(outfile);

  IV bit_per_pixcel = BmpIO_GetBitPerPixcel(pBmp);
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

  png_set_IHDR(png, info, BmpIO_GetWidth(pBmp), BmpIO_GetHeight(pBmp), 8, 
      (bit_per_pixcel == 32 ? PNG_COLOR_TYPE_RGB_ALPHA : PNG_COLOR_TYPE_RGB),
      PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_BASE);

  sBIT.red = 8;
  sBIT.green = 8;
  sBIT.blue = 8;
  sBIT.alpha = (png_byte)(bit_per_pixcel == 32 ? 8 : 0);
  png_set_sBIT(png, info, &sBIT);

  png_write_info(png, info);
  png_set_bgr(png);
  
  lines = (png_bytep *)malloc(sizeof(png_bytep *) * BmpIO_GetHeight(pBmp));
  unsigned char* rgb_data = malloc(BmpIO_GetHeight(pBmp) * BmpIO_GetWidth(pBmp) * 3);

  for (y = 0; y < BmpIO_GetHeight(pBmp); y++) {
    for (x = 0; x < BmpIO_GetWidth(pBmp); x++) {
      rgb_data[((BmpIO_GetHeight(pBmp) - y - 1) * BmpIO_GetWidth(pBmp) * 3) + (x * 3)] = BmpIO_GetB(x, y, pBmp);
      rgb_data[((BmpIO_GetHeight(pBmp) - y - 1) * BmpIO_GetWidth(pBmp) * 3) + (x * 3) + 1] = BmpIO_GetG(x, y, pBmp);
      rgb_data[((BmpIO_GetHeight(pBmp) - y - 1) * BmpIO_GetWidth(pBmp) * 3) + (x * 3) + 2] = BmpIO_GetR(x, y, pBmp);
    }
  }
  
  for (y = 0; y < BmpIO_GetHeight(pBmp); y++) {
    lines[y] = (png_bytep)&(rgb_data[y * BmpIO_GetWidth(pBmp) * 3]);
  }

  png_write_image(png, lines);
  png_write_end(png, info);
  png_destroy_write_struct(&png, &info);
  
  free(lines);
  free(rgb_data);
  BmpIO_DeleteBitmap(pBmp);
  fclose(outf);

  XSRETURN(0);
}
