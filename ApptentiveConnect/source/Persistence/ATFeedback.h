//
//  ATFeedback.h
//  DemoApp
//
//  Created by Andrew Wooster on 3/16/11.
//  Copyright 2011 Apptentive, Inc.. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    ATFeedbackTypeFeedback,
    ATFeedbackTypePraise,
    ATFeedbackTypeBug,
    ATFeedbackTypeQuestion
} ATFeedbackType;

NSString * const ATContactUpdaterFinished;

@interface ATFeedback : NSObject {
}
@property (nonatomic, assign) ATFeedbackType type;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *phone;
@property (nonatomic, retain) UIImage *screenshot;
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) NSString *model;
@property (nonatomic, retain) NSString *os_version;
@property (nonatomic, retain) NSString *carrier;
@property (nonatomic, retain) NSDate *date;
/*! Used to keep hold of screenshot switch state. */
@property (nonatomic, assign) BOOL screenshotSwitchEnabled;

- (NSDictionary *)dictionary;
- (NSDictionary *)apiDictionary;
@end
