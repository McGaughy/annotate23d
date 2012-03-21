//
//  CylinderoidTransformer.m
//  Annotate23D
//
//  Created by William Brown on 2012/03/13.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CylinderoidTransformer.h"
#import "MathDefs.h"

/* Must be odd. Represents number of pixels from center of
 * handle circle to edge of circle, including central point. */
#define HANDLE_SIZE 19
#define HANDLE_RADIUS ((HANDLE_SIZE - 1) / 2)

/* Handles have an effective radius of 30 pixels */
#define HANDLE_TOUCH_RADIUS_SQUARED 900

/* Represents no handle selected */
#define NO_SELECTION -1

#define ALL_SPINE_POINTS int i = 0; i < [[cylinderoid spine] count]; i++
#define SPINE_POINT(x) [[[cylinderoid spine] objectAtIndex:x] CGPointValue]
#define SET_SPINE_POINT(i, pt) [[cylinderoid spine] replaceObjectAtIndex:i withObject:[NSValue valueWithCGPoint:pt]]
#define RADIUS(x) [[[cylinderoid radii] objectAtIndex:x] floatValue]
#define SET_RADIUS(i, r) [[cylinderoid radii] replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:r]]

@implementation CylinderoidTransformer
@synthesize cylinderoid;

- (bool) tapAt:(CGPoint)pt {
  float closest_squared_dist = -1;
  
  selectedHandleType = SPINE;
  for (ALL_SPINE_POINTS) {
    CGPoint spine_pt = SPINE_POINT(i);
    float sqdist = pow(pt.x - spine_pt.x, 2) + pow(pt.y - spine_pt.y, 2);
    if (closest_squared_dist == -1 || sqdist < closest_squared_dist) {
      selectedHandle = i;
      closest_squared_dist = sqdist;
    }
  }
  
  if (closest_squared_dist > HANDLE_TOUCH_RADIUS_SQUARED) {
    selectedHandle = NO_SELECTION;
    return NO;
  }
  
  return YES;
}

- (bool) touchesBegan:(NSSet *) touches inView:(UIView*) view {
  /* If we're selected, we're always responsive to input. */
  return YES;
}

- (void) touchesMoved:(NSSet *) touches inView:(UIView*) view {
  if (selectedHandle == NO_SELECTION) {
    if ([touches count] == 1) {
      /* Translate cylinderoid */
      UITouch* touch = [[touches objectEnumerator] nextObject];
      CGPoint start = [touch previousLocationInView:view];
      CGPoint end = [touch locationInView:view];
      
      float dx = end.x - start.x, dy = end.y - start.y;
      for (ALL_SPINE_POINTS) {
        CGPoint spine_pt = SPINE_POINT(i);
        spine_pt.x += dx; spine_pt.y += dy;
        SET_SPINE_POINT(i, spine_pt);
      }
    } else if ([touches count] == 2) {
      NSEnumerator* touchEnumerator = [touches objectEnumerator];
      UITouch* touch1 = [touchEnumerator nextObject];
      UITouch* touch2 = [touchEnumerator nextObject];
      
      Vec2 touch1_start = VectorForPoint([touch1 previousLocationInView:view]);
      Vec2 touch2_start = VectorForPoint([touch2 previousLocationInView:view]);
      
      Vec2 touch1_end = VectorForPoint([touch1 locationInView:view]);
      Vec2 touch2_end = VectorForPoint([touch2 locationInView:view]);
      
      
      Vec2 line_start = touch1_start - touch2_start;
      double start_length = line_start.norm();
      line_start /= start_length;
      
      Vec2 line_end = touch1_end - touch2_end;
      double end_length = line_end.norm();
      line_end /= end_length;
      
      Vec2 translate = touch1_end - touch1_start;
      double rotate = (atan2(line_end[1], line_end[0])
                       - atan2(line_start[1], line_start[0]));
      double scale = end_length / start_length;
      
      /* Translate to origin, then scale, then rotate, then translate out of
       * origin, then translate by required amount. */
      Vec2 com = VectorForPoint([cylinderoid com]);
      Transform<float, 2, Affine> trs;
      trs.setIdentity();
      trs.translate(touch1_end);
      trs.rotate(rotate);
      trs.scale(scale);
      trs.translate(-touch1_start);
      
      for (ALL_SPINE_POINTS) {
        Vec2 spine_pt = VectorForPoint(SPINE_POINT(i));
        spine_pt = trs * spine_pt;
        SET_SPINE_POINT(i, CGPointMake(spine_pt[0], spine_pt[1]));
        SET_RADIUS(i, scale * RADIUS(i));
      }
    }
    
  } else if (selectedHandleType == SPINE) {
    if ([touches count] == 1) {
      /* Move spine point */
      UITouch* touch = [[touches objectEnumerator] nextObject];
      CGPoint start = [touch previousLocationInView:view];
      CGPoint end = [touch locationInView:view];
      
      CGPoint spine_pt = SPINE_POINT(selectedHandle);
      spine_pt.x += end.x - start.x;
      spine_pt.y += end.y - start.y;
      SET_SPINE_POINT(selectedHandle, spine_pt);
      
      /* TODO: better smoothing here */
      [cylinderoid smoothSpine:100 lockPoint:selectedHandle];
      
    } else if ([touches count] == 2) {
      /* Scale radii */
      NSEnumerator* touchEnumerator = [touches objectEnumerator];
      UITouch* touch1 = [touchEnumerator nextObject];
      UITouch* touch2 = [touchEnumerator nextObject];
      
      Vec2 touch1_start = VectorForPoint([touch1 previousLocationInView:view]);
      Vec2 touch2_start = VectorForPoint([touch2 previousLocationInView:view]);
      
      Vec2 touch1_end = VectorForPoint([touch1 locationInView:view]);
      Vec2 touch2_end = VectorForPoint([touch2 locationInView:view]);
      
      double start_line_length = (touch1_start - touch2_start).norm();
      double end_line_length = (touch1_end - touch2_end).norm();
      
      double scale_radius_by = end_line_length / start_line_length;
      double old_radius = [[[cylinderoid radii] objectAtIndex:selectedHandle] floatValue];
      double new_radius = old_radius * scale_radius_by;
      
      [[cylinderoid radii] replaceObjectAtIndex:selectedHandle withObject:[NSNumber numberWithDouble:new_radius]];
      
      /* TODO: better smoothing here */
      [cylinderoid smoothRadii:50 lockPoint:selectedHandle];
    }
  }
  
  [cylinderoid calculateSurfacePoints];
}

- (void) touchesEnded:(NSSet *) touches inView:(UIView*) view {}

- (CGPoint) findEndcap1 {
  Vec2 v0 = VectorForPoint([[[cylinderoid spine] objectAtIndex:0] CGPointValue]);
  Vec2 v1 = VectorForPoint([[[cylinderoid spine] objectAtIndex:1] CGPointValue]);
  Vec2 derivative = v1 - v0;
  derivative.normalize();
  
  Vec2 endcap = v0 - derivative * [cylinderoid capRadius1];
  return CGPointMake(endcap[0], endcap[1]);
}

- (id) initWithCylinderoid:(Cylinderoid*)shape {
  self = [self init];
  cylinderoid = shape;
  selectedHandle = NO_SELECTION;
  return self;
}

- (CGRect) handleAt:(CGPoint) pt {
  return CGRectMake(pt.x - HANDLE_RADIUS, pt.y - HANDLE_RADIUS, 
                    HANDLE_SIZE, HANDLE_SIZE);
}

- (void) drawShapeWithHandles:(CGContextRef)context {
  CGContextSetLineWidth(context, 5);
  CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
  CGContextSetFillColor(context, (CGFloat[]) {0., 0.8, 1., 1.});
  CGContextAddPath(context, [cylinderoid getPath]);
  CGContextDrawPath(context, kCGPathFillStroke);
  
  for (ALL_SPINE_POINTS) {
    CGPoint spinePoint = SPINE_POINT(i);
    CGContextAddEllipseInRect(context, [self handleAt:spinePoint]);
    
    CGContextSetLineWidth(context, 2);
    if (selectedHandle == i && selectedHandleType == SPINE)
      CGContextSetFillColor(context, (CGFloat[]) {1., 1., 1., 1.});
    else
      CGContextSetFillColor(context, (CGFloat[]) {1., 1., 1., .3});
    CGContextDrawPath(context, kCGPathFillStroke);
  }
  
  CGPoint endcap1 = [self findEndcap1];
  CGContextAddEllipseInRect(context, [self handleAt:endcap1]);
}

@end
