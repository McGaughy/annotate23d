//
//  WorkspaceUIView.h
//  Annotate23D
//
//  Created by William Brown on 2012/02/22.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Cylinderoid.h"
#import "Ellipsoid.h"
#import "Drawable.h"
#import "ShapeTransformer.h"

@protocol ExplainerDelegate <NSObject>
- (void) nextTapWill:(NSString*)doThis;
- (void) showToolHelp;
@end

@interface WorkspaceUIView : UIView <UIActionSheetDelegate> {
  int selectedIndex;
  ShapeTransformer* selectedShape;
  Cylinderoid* lastSelectedCyl;
  bool annotating, annotatingRadii;
  int selectedHandle;
}

@property (assign) bool shapeWantsTouching;
@property (strong) NSMutableArray *drawables;
@property (assign) NSObject<ExplainerDelegate> *explainer;

- (void)nextTapWill:(NSString*)doThis;

/* Returns YES if a shape is currently selected, and false otherwise. */
- (bool)tapAtPoint:(CGPoint)point;
- (void)handleLongPress:(UIGestureRecognizer*)sender;
- (void)clearSelection;

/* Returns YES if a shape is currently selected, and false otherwise. */
- (bool)selectAtPoint:(CGPoint)point;

- (void)resetAnnotationState;
- (bool)connection:(CGPoint)loc;
- (bool)mirror:(CGPoint)loc;
- (bool)alignto:(CGPoint)loc;
- (bool)sameTilt:(CGPoint)loc;
- (bool)sameSize:(CGPoint)loc;
- (bool)sameRadius:(CGPoint)loc;

- (void)deleteSelectedShape;
- (void)addDrawable:(Drawable*)draw;

- (void)actionSheet:(UIActionSheet*)sheet clickedButtonAtIndex:(NSInteger)buttonIndex;

@end
