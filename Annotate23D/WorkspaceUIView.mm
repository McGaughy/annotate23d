//
//  WorkspaceUIView.m
//  Annotate23D
//
//  Created by William Brown on 2012/02/22.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WorkspaceUIView.h"
#import "AnnotationArtist.h"
#import "CylinderoidTransformer.h"

#define NO_SELECTION -1

@implementation WorkspaceUIView
@synthesize drawables, shapeWantsTouching, explainer;

- (void)initArrays {
  self.drawables = [[NSMutableArray alloc] init];
  selectedIndex = NO_SELECTION;
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self initArrays];
    [self setUserInteractionEnabled:true];
    [self setMultipleTouchEnabled:true];
  }
  return self;
}
- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self initArrays];
    [self setUserInteractionEnabled:true];
    [self setMultipleTouchEnabled:true];
  }
  return self;
}

- (void) nextTapWill:(NSString *)doThis {
  [explainer nextTapWill:doThis];
}

#pragma mark Annotation handling

- (void) resetAnnotationState {
  lastSelectedCyl = nil;
  annotating = false;
  annotatingRadii = false;
  selectedHandle = NO_SELECTION;
}

- (bool) ensureIsCylinderoid {
  if (![selectedShape isKindOfClass:[CylinderoidTransformer class]]) {
    NSLog(@"That annotation can only be applied to cylinderoids");
    selectedIndex = NO_SELECTION;
    return false;
  }
  return true;
}

- (bool) mirror:(CGPoint) loc {
  [self selectAtPoint:loc];
  if ([self ensureIsCylinderoid]) {
    Cylinderoid* cyl = [(CylinderoidTransformer*) selectedShape cylinderoid];
    if ([cyl connectionConstraint] == nil) {
      NSLog(@"Mirror must be applied to a connected shape");
    } else {
      MirrorAnnotation* ann = [[MirrorAnnotation alloc] init];
      [ann setMirror:cyl];
      
      Cylinderoid* alignTo;
      ConnectionAnnotation* connect_ann = [cyl connectionConstraint];
      if (cyl == [connect_ann first]) {
        alignTo = [connect_ann second];
      } else {
        alignTo = [connect_ann first];
      }
      [ann setAlignTo:alignTo];
      [cyl setMirrorAnnotation:ann];
    }
  } else {
    NSLog(@"Mirror can only be done to cylinderoids");
  }
  [self resetAnnotationState];
  [self clearSelection];
  return true;
}

- (bool) alignto:(CGPoint) loc {
  [self selectAtPoint:loc];
  if ([self ensureIsCylinderoid]) {
    Cylinderoid* cyl = [(CylinderoidTransformer*) selectedShape cylinderoid];
    if ([cyl connectionConstraint] == nil) {
      NSLog(@"Mirror must be applied to a connected shape");
    } else {
      AlignToSheetAnnotation* ann = [[AlignToSheetAnnotation alloc] init];
      [ann setObject:cyl];
      
      Cylinderoid* alignTo;
      ConnectionAnnotation* connect_ann = [cyl connectionConstraint];
      if (cyl == [connect_ann first]) {
        alignTo = [connect_ann second];
      } else {
        alignTo = [connect_ann first];
      }
      
      [ann setAlignTo:alignTo];
      [cyl setAlignmentConstraint:ann];
    }
  }
  [self resetAnnotationState];
  [self clearSelection];
  return true;
}

- (bool) connection:(CGPoint) loc {
  annotating = true;
  annotatingRadii = false;
  
  if (selectedIndex == NO_SELECTION && lastSelectedCyl == nil) {
    [self selectAtPoint:loc];
    if ([self ensureIsCylinderoid]) {
      CylinderoidTransformer* cylt = (CylinderoidTransformer*) selectedShape;
      lastSelectedCyl = [cylt cylinderoid];
    }
    selectedIndex = NO_SELECTION;
    [self nextTapWill:@"Select the shape to move to connect"];
  } else if (selectedIndex == NO_SELECTION) {
    [self selectAtPoint:loc];
    [self ensureIsCylinderoid];
    [self nextTapWill:@"Tap the point at which the two shapes should meet"];
  } else {
    CylinderoidTransformer* cylt = (CylinderoidTransformer*) selectedShape;
    ConnectionAnnotation* ann = [[ConnectionAnnotation alloc] init];
    
    [ann setFirst:lastSelectedCyl];
    [ann setSecond:[cylt cylinderoid]];
    [ann setLocation:loc];
    
    if (![ann isValid]) {
      NSLog(@"Connection at %f,%f is invalid", loc.x, loc.y);
    } else {
      [lastSelectedCyl setConnectionConstraint:ann];
      [[cylt cylinderoid] setConnectionConstraint:ann];
    }
    
    [self resetAnnotationState];
    [self clearSelection];
    [self setNeedsDisplay];
    return true;
    [self nextTapWill:nil];
  }
  
  [self setNeedsDisplay];
  return false;
}

- (bool) sameSize:(CGPoint)loc {
  annotating = true;
  annotatingRadii = false;
  if (selectedIndex == NO_SELECTION) {
    [self selectAtPoint:loc];
    [self ensureIsCylinderoid];
    [self nextTapWill:@"Select the second shape to make of equal size"];
    
  } else {
    int firstIndex = selectedIndex;
    ShapeTransformer* firstShape = selectedShape;

    if (![self selectAtPoint:loc] || ![self ensureIsCylinderoid]) {
      selectedShape = firstShape;
      selectedIndex = firstIndex;
      return true;
    }
    
    int secondIndex = selectedIndex;

    SameLengthAnnotation* annot =[SameLengthAnnotation newWithFirst:[drawables objectAtIndex:firstIndex] second:[drawables objectAtIndex:secondIndex]];
    [[drawables objectAtIndex:firstIndex] setLengthConstraint:annot];
    [[drawables objectAtIndex:secondIndex] setLengthConstraint:annot];
    
    [self resetAnnotationState];
    [self clearSelection];
    [self setNeedsDisplay];
    return true;
  }
  
  [self setNeedsDisplay];
  return false;
}

- (bool) sameRadius:(CGPoint)loc {
  /*
   
   This gets a bit confusing. There are four possible states here, since we
   have to pick spine points, not just shapes. We start in the no-shapes,
   no-points state. In this state, selectedIndex and selectedHandle are both
   NO_SELECTION. A tap in this state means selecting the first shape. After the
   first shape is selected, selectedIndex is not NO_SELECTION but selectedHandle
   is still NO_SELECTION. A tap in this state picks a spine point off of the 
   selected shape, and sets selectedIndex back to NO_SELECTION. Now
   selectedHandle is not NO_SELECTION, but selectedIndex is. In this state, a
   tap means picking the second shape -- from a programmatic view, this is
   exactly the same as picking the first shape. Once that's been picked,
   selectedShape and selectedIndex are both not NO_SELECTION. The next tap is
   the one that picks the final spine point.
   
   */
   
  annotating = true;
  annotatingRadii = true;
  if (selectedIndex == NO_SELECTION) {
    [self selectAtPoint:loc];
    if ([self ensureIsCylinderoid]) {
      CylinderoidTransformer* cylt = (CylinderoidTransformer*) selectedShape;
      [cylt setReadOnly:true];
      if (lastSelectedCyl == nil)
        lastSelectedCyl = [cylt cylinderoid];
      [self nextTapWill:@"Select the radius to set equal"];
    }
    
  } else if (selectedHandle == NO_SELECTION) {
    if ([selectedShape tapAt:loc]) {
      selectedHandle = [(CylinderoidTransformer*) selectedShape selectedSpineHandle];
      if (selectedHandle != NO_SELECTION) selectedIndex = NO_SELECTION;
    }
    
    [self nextTapWill:@"Select the second shape to make of equal radius"];
  } else {
    if ([selectedShape tapAt:loc]) {
      int thisHandle = [(CylinderoidTransformer*) selectedShape selectedSpineHandle];
      if (thisHandle != NO_SELECTION) {
        Cylinderoid* thisCyl = [(CylinderoidTransformer*) selectedShape cylinderoid];
        SameScaleAnnotation* ssa = [SameScaleAnnotation newWithFirst:lastSelectedCyl handle:selectedHandle second:thisCyl handle:thisHandle];
        [[thisCyl radiusConstraints] addObject:ssa];
        [[lastSelectedCyl radiusConstraints] addObject:ssa];
      }
    }
    
    [self clearSelection];
    [self resetAnnotationState];
    [self setNeedsDisplay];
    [self nextTapWill:nil];
    return true;
  }
  [self setNeedsDisplay];
  return false;
}

- (bool) sameTilt:(CGPoint)loc {
  annotating = true;
  annotatingRadii = true;
  if (selectedIndex == NO_SELECTION) {
    [self selectAtPoint:loc];
    
    if ([self ensureIsCylinderoid]) {
      CylinderoidTransformer* cylt = (CylinderoidTransformer*) selectedShape;
      [cylt setReadOnly:true];
      [cylt setShowOnlyTiltHandles:true];
      if (lastSelectedCyl == nil)
        lastSelectedCyl = [cylt cylinderoid];
      [self nextTapWill:@"Select tilted radius to set equal"];
    }
    
  } else if (selectedHandle == NO_SELECTION) {
    if ([selectedShape tapAt:loc]) {
      selectedHandle = [(CylinderoidTransformer*) selectedShape selectedSpineHandle];
      if (selectedHandle != NO_SELECTION) selectedIndex = NO_SELECTION;
    }
    [self nextTapWill:@"Select next shape to make of equal tilt"];
    
  } else {
    if ([selectedShape tapAt:loc]) {
      int thisHandle = [(CylinderoidTransformer*) selectedShape selectedSpineHandle];
      if (thisHandle != NO_SELECTION) {
        Cylinderoid* thisCyl = [(CylinderoidTransformer*) selectedShape cylinderoid];
        SameTiltAnnotation* sta = [SameTiltAnnotation newWithFirst:lastSelectedCyl handle:selectedHandle second:thisCyl handle:thisHandle];
        [[thisCyl tiltConstraints] addObject:sta];
        [[lastSelectedCyl tiltConstraints] addObject:sta];
        
        [self nextTapWill:nil];
        [self clearSelection];
        [self resetAnnotationState];
        return true;
      }
    }
  }
  
  [self setNeedsDisplay];
  return false;
}

#pragma mark User interaction methods

- (void) clearSelection {
  selectedIndex = NO_SELECTION;
  selectedShape = NULL;
  [self setNeedsDisplay];
}

- (bool)tapAtPoint:(CGPoint)point {
  if (selectedIndex == NO_SELECTION) {
    bool selected = [self selectAtPoint:point];
    if (selected) {
      [self nextTapWill:@"Swipe to move, pinch to resize, rotate to spin"];
    }
    [self setNeedsDisplay];
    return selected;
  }
  
  if ([selectedShape tapAt:point]) {
    if ([selectedShape selectedSpineHandle] != NO_SELECTION) {
      if ([selectedShape isKindOfClass:[CylinderoidTransformer class]]) {
        [self nextTapWill:@"Swipe to move, pinch to change radius, tap again to tilt"];
      } else {
        [self nextTapWill:@"Swipe to stretch"];
      }
    } else {
      [self nextTapWill:@"Swipe to move, pinch to resize, rotate to spin"];
    }
    
    [self setNeedsDisplay];
    return YES;
  }
  
  
  selectedIndex = NO_SELECTION;
  [self nextTapWill:nil];
  [self setNeedsDisplay];
  return NO;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  shapeWantsTouching = NO;
  if (selectedIndex != NO_SELECTION) {
    shapeWantsTouching = [selectedShape touchesBegan:touches inView:self];
  }
  
  //if (!shapeWantsTouching) [super touchesBegan:touches withEvent:event];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  if (shapeWantsTouching) {
    [selectedShape touchesMoved:touches inView:self];
    [self setNeedsDisplay];
  }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  if (shapeWantsTouching) {
    [selectedShape touchesEnded:touches inView:self];
  }
}

- (bool)selectAtPoint:(CGPoint)point {
  bool selected = NO;
  for (int i = [drawables count] - 1; i >= 0; i--) {
    Drawable* shape = [drawables objectAtIndex:i];
    if ([shape getPath] != NULL && 
        CGPathContainsPoint([shape getPath], NULL, point, false)) {
      if (i == selectedIndex) break;
      
      // Move the selected object to the back of the array, so that it gets drawn on top.
      [drawables removeObjectAtIndex:i];
      [drawables addObject:shape];
      selectedIndex = [drawables count] - 1;
      selected = YES;
      break;
    }
  }
  
  if (!selected) selectedIndex = NO_SELECTION;
  else {
    selectedShape = [ShapeTransformer 
                     transformerForShape:[drawables objectAtIndex:selectedIndex]];
  }
  
  [self setNeedsDisplay];
  return selected;
}

- (void) handleLongPress:(UIGestureRecognizer *)sender {
  if ([sender state] != UIGestureRecognizerStateBegan) return;
  
  CGPoint pressPoint = [sender locationInView:self];
  bool foundShape = NO;
  
  if (selectedIndex != NO_SELECTION) {
    Drawable* shape = [drawables objectAtIndex:selectedIndex];
    if ([shape getPath] != NULL && 
        CGPathContainsPoint([shape getPath], NULL, pressPoint, false)) {
      foundShape = YES;
    }
  }
  if (!foundShape) {
    foundShape = [self selectAtPoint:pressPoint];
  }
  
  if (foundShape) {
    /* Create UIActionSheet for shape context menu */
    UIActionSheet* actionSheet =
    [[UIActionSheet alloc]
     initWithTitle:@"Shape Menu" delegate:self cancelButtonTitle:nil
     destructiveButtonTitle:@"Delete shape" otherButtonTitles:nil];
    CGRect loc = CGRectMake(pressPoint.x, pressPoint.y, 1, 1);
    [actionSheet showFromRect:loc inView:self animated:true];
  }
}

- (void) deleteSelectedShape {
  if (selectedIndex != NO_SELECTION) {
    if ([selectedShape isKindOfClass:[CylinderoidTransformer class]]) {
      SameLengthAnnotation* sla = [[(CylinderoidTransformer*) selectedShape cylinderoid] lengthConstraint];
      if (sla != NULL) {
        [[sla first] setLengthConstraint:nil];
        [[sla second] setLengthConstraint:nil];
        [sla setFirst:nil];
        [sla setSecond:nil];
      }
    }
    
    [drawables removeObjectAtIndex:selectedIndex];
    selectedIndex = NO_SELECTION;
  }
}

- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == 0) {
    [self deleteSelectedShape];
    [self setNeedsDisplay];
  }
}

#pragma mark Drawing methods

- (void)addDrawable:(Drawable*)draw {
  if (draw == nil) return;
  
  [drawables addObject:draw];
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  for (int i = 0; i < [self.drawables count]; i++) {
    if (i == selectedIndex && selectedShape != nil && (!annotating || annotatingRadii)) {
      [selectedShape drawShapeWithHandles:context];
      continue;
    }
    
    CGContextSetLineWidth(context, 5);
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    if (i == selectedIndex && annotating) {
      CGContextSetFillColorWithColor(context, [UIColor orangeColor].CGColor);
    } else {
      CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    }
    CGContextBeginPath(context);
    CGContextAddPath(context, [[drawables objectAtIndex:i] getPath]);
    CGContextDrawPath(context, kCGPathFillStroke);
  }
  
  if (selectedIndex != NO_SELECTION && 
      [selectedShape isKindOfClass:[CylinderoidTransformer class]]) {
    Cylinderoid* cyl = [(CylinderoidTransformer*) selectedShape cylinderoid];
    SameLengthAnnotation* sla = [cyl lengthConstraint];
    if (sla != NULL) {
      [AnnotationArtist drawSameLengthAnnotation:sla onContext:context];
    }
  
    ConnectionAnnotation* ca = [cyl connectionConstraint];
    if (ca != NULL) {
      [AnnotationArtist drawConnectionAnnotation:ca onContext:context];
    }
    
    for (SameScaleAnnotation* ssa in [cyl radiusConstraints]) {
      [AnnotationArtist drawSameScaleAnnotation:ssa onContext:context];
    }
    
    for (SameTiltAnnotation* sta in [cyl tiltConstraints]) {
      [AnnotationArtist drawSameTiltAnnotation:sta onContext:context];
    }
  }
}

@end
