#include <stdio.h>
#include "BmpIoLib.h"

int main( int argc, char *argv[] )
{
	IBMP *pBmp;
	FILE *infile;
	int i, j;
	int w, h;

	if ( argc < 2 ) {
		printf( "入力ファイルを指定してください。\n" );
		return -1;
	}

	// ファイルを開く
	infile = fopen( argv[1], "rb" );
	if ( NULL == infile ) {
		printf( "ファイル %s が開けませんでした。\n", argv[1] );
		return  -1;
	}

	// 読み込む
	pBmp = BmpIO_Load( infile );
	fclose( infile );
	if ( NULL == pBmp ) {
		printf( "ファイル %s の読み込みに失敗しました。\n", argv[1] );
		return -1;
	}

	// 幅と高さを取得
	w = BmpIO_GetWidth( pBmp );
	h = BmpIO_GetHeight( pBmp );

	// 出力
	printf( "<html><body><table border=1 >\n" );
	for ( i = h - 1; i >= 0 ; i-- ){	// 上下を逆にしていることに注意
		printf( "<tr>\n" );
		for ( j = 0; j < w; j++ ) {
			// １ます分のデータを出力
			printf( "<td height=15 width=10 border=1 bgcolor=#%02X%02X%02X>&nbsp;</td>\n",
					BmpIO_GetR( j, i, pBmp ),
					BmpIO_GetG( j, i, pBmp ),
					BmpIO_GetB( j, i, pBmp ) );
		}
		printf( "</tr>\n" );
	}
	printf( "</table></body></html>\n" );

	// ビットマップの破棄
	BmpIO_DeleteBitmap( pBmp );
	return 0;
}