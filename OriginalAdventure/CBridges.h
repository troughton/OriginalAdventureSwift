//
//  QuaternionIntrinsics.h
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

#ifndef QuaternionIntrinsics_h
#define QuaternionIntrinsics_h

#include <simd/simd.h>
#include <OpenGL/gl3.h>

vector_float4 QuaternionMultiply(vector_float4 quaternionLeft, vector_float4 quaternionRight);

void glDrawElementsSwift(GLenum mode, GLsizei count, GLenum type, int64_t indices);

#endif /* QuaternionIntrinsics_h */
