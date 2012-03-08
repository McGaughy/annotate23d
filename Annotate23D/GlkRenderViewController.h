//
//  GlkRenderViewController.h
//  Annotate23D
//
//  Created by William Brown on 2012/03/07.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface GlkRenderViewController : GLKViewController

- (id)initWithMesh:(GLfloat[])mesh ofSize:(GLuint)size;

@end