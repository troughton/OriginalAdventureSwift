//
//  QuaternionIntrinsics.c
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#import "CBridges.h"

vector_float4 QuaternionMultiply(vector_float4 quaternionLeft, vector_float4 quaternionRight) {
    const __m128 ql = _mm_load_ps(&quaternionLeft);
    const __m128 qr = _mm_load_ps(&quaternionRight);
    
    const __m128 ql3012 = _mm_shuffle_ps(ql, ql, _MM_SHUFFLE(2, 1, 0, 3));
    const __m128 ql3120 = _mm_shuffle_ps(ql, ql, _MM_SHUFFLE(0, 2, 1, 3));
    const __m128 ql3201 = _mm_shuffle_ps(ql, ql, _MM_SHUFFLE(1, 0, 2, 3));
    
    const __m128 qr0321 = _mm_shuffle_ps(qr, qr, _MM_SHUFFLE(1, 2, 3, 0));
    const __m128 qr1302 = _mm_shuffle_ps(qr, qr, _MM_SHUFFLE(2, 0, 3, 1));
    const __m128 qr2310 = _mm_shuffle_ps(qr, qr, _MM_SHUFFLE(0, 1, 3, 2));
    const __m128 qr3012 = _mm_shuffle_ps(qr, qr, _MM_SHUFFLE(2, 1, 0, 3));
    
    uint32_t signBit = 0x80000000;
    uint32_t zeroBit = 0x0;
    uint32_t __attribute__((aligned(16))) mask0001[4] = {zeroBit, zeroBit, zeroBit, signBit};
    uint32_t __attribute__((aligned(16))) mask0111[4] = {zeroBit, signBit, signBit, signBit};
    const __m128 m0001 = _mm_load_ps((float *)mask0001);
    const __m128 m0111 = _mm_load_ps((float *)mask0111);
    
    const __m128 aline = ql3012 * _mm_xor_ps(qr0321, m0001);
    const __m128 bline = ql3120 * _mm_xor_ps(qr1302, m0001);
    const __m128 cline = ql3201 * _mm_xor_ps(qr2310, m0001);
    const __m128 dline = ql3012 * _mm_xor_ps(qr3012, m0111);
    const __m128 r = _mm_hadd_ps(_mm_hadd_ps(aline, bline), _mm_hadd_ps(cline, dline));
    
    return *(vector_float4 *)&r;
}

void glDrawElementsSwift(GLenum mode, GLsizei count, GLenum type, int64_t indices) {
    glDrawElements(mode, count, type, (void*)indices);
}