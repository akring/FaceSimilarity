//
//  ViewController.h
//  ArcFace
//
//  Created by yalichen on 2017/7/31.
//  Copyright © 2017年 ArcSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FaceSimilarityDelegate <NSObject>

- (void)faceSimilarity:(float)similarity;

@end

@interface ViewController : UIViewController

@property(nonatomic, weak) id<FaceSimilarityDelegate> delegate;

@end

