//
//  GlkRenderer.m
//  Annotate23D
//
//  Created by William Brown on 2012/02/09.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GlkRenderer.h"

@implementation GlkRenderer

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
  glClearColor(1.0, 0.0, 0.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
}

@end