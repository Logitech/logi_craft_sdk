/*
 Copyright 2018 Logitech Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
 rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
 Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "AppDelegate.h"
#import "Craft.h"
#import "BACraftEventHandler.h"
#import "QuartzCore/QuartzCore.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property LogiCraftClient *client;
@property (weak) IBOutlet NSSlider *horizontalSlider;
@property (weak) IBOutlet NSSlider *verticalSlider;
@property (weak) IBOutlet NSSlider *circularSlider;
@property (weak) IBOutlet NSImageView *publisherImage;
@property (weak) IBOutlet NSStackView *sliderStack;

@end

static float zoom_factor=1.0;
static float rotate_val = 0.0;

@implementation AppDelegate

- (IBAction)onSliderClick:(id)sender {
    [self.client sendMessage:@ {
        @"message_type":@"tool_change",
        @"payload" : @ {
            @"tool": @"slider", // must match the string of tool name in manifest
        }
    }];
    
    // enable slider stack
    _verticalSlider.enabled = YES;
    _circularSlider.enabled = YES;
    _horizontalSlider.enabled = YES;
    
    //disable image
    [_publisherImage setEnabled:NO];
}

- (IBAction)onImageClick:(id)sender {
    [self.client sendMessage:@ {
        @"message_type":@"tool_change",
        @"payload" : @ {
            @"tool": @"image", // must match the string of tool name in manifest
        }
    }];
    
    // enable image
    [_publisherImage setEnabled:YES];
    
    // disable sliders
    _verticalSlider.enabled = NO;
    _circularSlider.enabled = NO;
    _horizontalSlider.enabled = NO;
}



-(void) handleImageToolUpdates:(NSDictionary *)msg_dict {
    NSString *toolOption = msg_dict[@"task_options"][@"current_tool_option"];
    
    CGRect frame = _publisherImage.layer.frame;
    CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    _publisherImage.layer.position = center;
    _publisherImage.layer.anchorPoint = CGPointMake(0.5, 0.5);
    _publisherImage.layer.borderWidth = 1.0;
    
    CGAffineTransform xform;
    
    int ratchet_value = [msg_dict[@"ratchet_delta"] intValue];
    
    if ([toolOption isEqualToString:@"rotate"]) {
        if (ratchet_value == 0) {
            // ignore
            return;
        } else if (ratchet_value > 0) {
            _publisherImage.layer.borderColor = [NSColor blueColor].CGColor;
            rotate_val = rotate_val - ( M_PI )/10.0;
        } else {
            _publisherImage.layer.borderColor = [NSColor redColor].CGColor;
            rotate_val = rotate_val + ( M_PI )/10.0 ;
        }
        
        xform = CGAffineTransformMakeRotation(rotate_val);
        [_publisherImage.layer setAffineTransform: xform];
    }
    
    if ([toolOption isEqualToString:@"zoom"]) {
        NSLog(@"zf:%f", zoom_factor);
        if (ratchet_value == 0) {
            // ignore
            return;
        } else if (ratchet_value > 0) {
            _publisherImage.layer.borderColor = [NSColor blueColor].CGColor;
            if (zoom_factor >= 2.0) {
                return;
            }
            zoom_factor *= 1.1;
            xform = CGAffineTransformMakeScale(zoom_factor, zoom_factor);
        } else {
            _publisherImage.layer.borderColor = [NSColor redColor].CGColor;
            if (zoom_factor <= 0.5){
                return;
            }
            zoom_factor *=0.9;
            xform = CGAffineTransformMakeScale(zoom_factor, zoom_factor);
        }
        
        [_publisherImage.layer setAffineTransform: xform];
    }
}

-(void) handleSliderToolUpdates:(NSDictionary *)msg_dict {
    NSSlider *selectedSlider = nil;
    NSString *selectedSliderType = nil;
    selectedSliderType =  msg_dict[@"task_options"][@"current_tool_option"];
    if ([selectedSliderType isEqualToString:@"horizontal"])
        selectedSlider = self.horizontalSlider;
    else if ([selectedSliderType isEqualToString:@"vertical"])
        selectedSlider = self.verticalSlider;
    else if ([selectedSliderType isEqualToString:@"circular"])
        selectedSlider = self.circularSlider;
    else
        return; // not a valid slider option
    
    double value = selectedSlider.doubleValue;
    value += [msg_dict[@"delta"] doubleValue];
    if (value < 0) value = 0;
    [selectedSlider setDoubleValue:value];
    
    // send the updated value back so that you can see it inside on-screen overlays (real time user feedback)
    [self.client sendMessage:@ {
        @"message_type":@"tool_update",
        @"payload" : @ {
            @"tool": @"slider",
            @"tool_option": selectedSliderType,
            @"tool_option_value" : @(value),
            @"play_task" : @"" // look at SDK documentation for more info on individual fields
        }
    }];
}

-(void) handleCraftEventViaAppDelegate:(NSDictionary *)msg_dict {
    if ([msg_dict[@"message_type"] isEqualToString:@"crown_turn_event"]) {
        
        if ([msg_dict[@"task_options"][@"current_tool"] isEqualToString:@"image"]) {
            [self handleImageToolUpdates:msg_dict];
        }
        
        if ([msg_dict[@"task_options"][@"current_tool"] isEqualToString:@"slider"]) {
            [self handleSliderToolUpdates:msg_dict];
        }
    }
}

-(void) appendToTextViewLog:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"=> %@\n", message]];
        
        NSTextView *tv = self.textArea;
        NSTextStorage *ts = tv.textStorage;
        [ts appendAttributedString:attr];
        [tv scrollRangeToVisible:NSMakeRange([[tv string] length], 0)];
    });
}

- (IBAction)onUnregisterButtonClick:(id)sender {
    [self.disconnectButton setEnabled:NO];
    [self.connectButton setEnabled:YES];
    [self.client disconnect];
}

- (IBAction)onRegisterButtonClick:(id)sender {
    [self.connectButton setEnabled:NO];
    [self.disconnectButton setEnabled:YES];
    
    self.client = [[LogiCraftClient alloc] initWithConnectionType:LOGI_WS];
    self.client.delegate = [[BACraftEventHandler alloc] init];
    
    [self.client connectWithUUID:@"36f0bda7-7562-4c58-8a25-ddb00e9ebabd"];
    
    NSString *imgPath = [@"~/Library/Application Support/Logitech/Logitech Options/Plugins/36f0bda7-7562-4c58-8a25-ddb00e9ebabd/Gallery/crafttest.icns" stringByExpandingTildeInPath];
    
    NSImage *img = [[NSImage alloc] initWithContentsOfFile:imgPath];
    _publisherImage.image = img;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    [self.horizontalSlider setMinValue:0];
    [self.horizontalSlider setMaxValue:150];
    [self.verticalSlider setMinValue:0];
    [self.verticalSlider setMaxValue:10];
    [self.circularSlider setMinValue:0];
    [self.circularSlider setMaxValue:150];
    
    [self.disconnectButton setEnabled:NO];
    
    /* Note:
     This example has only one tool called slider and 3 tool options (horizantal, vertical, circular) under it
     Check for "slider" in manifest.json for plugin with GUID 36f0bda7-7562-4c58-8a25-ddb00e9ebabd
     
     If you multiple tools like say, slider, picker etc each with their set of options and you switch between top
     level tools on UI then you can pass that information to craft keyboard daemon via "tool_change" message
     like shown below
     
     [self.client sendMessage:@ {
     @"message_type":@"tool_change",
     @"payload" : @ {
     @"tool": @"picker", // must match the string of tool name in manifest
     }
     }];
     */
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    if (_client) {
        [_client disconnect];
    }
}

@end
