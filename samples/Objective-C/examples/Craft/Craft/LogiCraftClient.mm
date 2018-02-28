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

#import <Foundation/Foundation.h>
#import "LogiCraftClient.h"

@interface LogiCraftClient()
@property SRWebSocket *socket;
@property NSString *executableName;
@property NSString *manifestPath;
@property NSString *uuid;
@property NSString *session_id;
@property NSNumber *device_id;
@property NSNumber *unit_id;
@property NSNumber *feature_id;

@property bool isConnected;
@end

@implementation LogiCraftClient

-(void)webSocketDidOpen:(SRWebSocket *)socket {
    [self.delegate handleCraftEvent:@"websocket is connected"];
    
    self.isConnected = YES;
    
    if (self.uuid == nil) {
        NSString *uid = [[NSUUID UUID] UUIDString];  // SDK assigned uuid
        self.uuid = uid;
        self.manifestPath = @"";
    }
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSDictionary *registerJson = @{
                   @"message_type": @"register",
                   @"plugin_guid": self.uuid,
                   @"PID": @(pid),
                   @"execName": self.executableName,
                   @"manifestPath": self.manifestPath,
                   @"application_version":@"1.0"
        };
    
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:registerJson options:NSJSONWritingPrettyPrinted error:&err];
    
    if (err == nil) {
        [socket send:jsonData];
    }
}

-(void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    self.isConnected = NO;
    [self.delegate handleCraftEvent:[NSString stringWithFormat:@"websocket is disconnected: %@",reason]];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if ([message isKindOfClass:[NSString class]]) {
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSError *err = nil;
        
        NSDictionary *msg_dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&err];
        
        if (err != nil) {
            [self.delegate handleCraftEvent:[err localizedDescription]];
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(handleCraftEvent:)]) {
            [self.delegate handleCraftEvent:message];
            
            // register ack
            if ([msg_dict[@"message_type"] isEqualToString:@"register_ack"]) {
                self.session_id = msg_dict[@"session_id"];

                NSDictionary *tool_change_json = @{
                                               @"message_type": @"tool_change",
                                               @"session_id": self.session_id,
                                               // slider is the only tool in this example - so hard coded it
                                               @"tool_id": @"slider",
                                               @"reset_options": @false
                                            };
                
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:tool_change_json options:NSJSONWritingPrettyPrinted error:&err];
                
                if (err == nil) {
                    [webSocket send:jsonData];
                }
            }
            
            // crown_touch_event or crown_turn_event
            if ([msg_dict[@"message_type"] isEqualToString:@"crown_touch_event"] ||
                [msg_dict[@"message_type"] isEqualToString:@"crown_turn_event"]) {
                self.device_id = msg_dict[@"device_id"];
                self.unit_id = msg_dict[@"unit_id"];
                self.feature_id = msg_dict[@"feature_id"];
            }
        }
    }
    
    if ([message isKindOfClass:[NSData class]]) {
        NSError *jsonerr = nil;
        NSDictionary *dataDict = [NSJSONSerialization JSONObjectWithData:message options:NSJSONReadingMutableContainers error:&jsonerr];
        NSLog(@"Data : %@",[dataDict description]);
    }
}

-(instancetype) init {
    return [self initWithConnectionType:LOGI_WS];
}

-(instancetype) initWithConnectionType:(LogiConnectionType)type {
    self = [super init];
    if (self)
    {
        NSString * cnxType = @"ws"; // default
        
        switch (type) {
            case LOGI_WS:
                cnxType = @"ws";
                break;
//            case LOGI_WSS:
//                cnxType = @"wss"
//                break;
//            case LOGI_RAW:
//                cnxType = @"tcp"
//                break;
            default:
                cnxType = @"ws";
                break;
        }
        NSString *urlString = [NSString stringWithFormat:@"%@://127.0.0.1:10134",cnxType];
        NSURLRequest *urlReq = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
        self.socket = [[SRWebSocket alloc] initWithURLRequest:urlReq];
        self.socket.delegate = self;
        self.uuid = nil;
    }
    return self;
}

-(void) connect {
    
    if ([[[NSProcessInfo processInfo] arguments][0] containsString:@".app"]) {
        self.executableName = [NSString stringWithFormat:@"%@.app",[[NSProcessInfo processInfo] processName]];
    } else {
        self.executableName = [NSString stringWithFormat:@"Terminal.app"];
    }
    // plugin assets, manifests should be at fixed location
    self.manifestPath = @"/Users/bilahari/Library/Application Support/Logitech/Logitech Options/Plugins";
    [self.socket open];
}

-(void) connectWithUUID:(NSString *)uuid  {
    self.uuid = uuid;
    [self connect];
}

-(void) handleToolUpdate:(NSDictionary *)msg_dict {
    if(msg_dict[@"payload"][@"tool"]
       and msg_dict[@"payload"][@"tool_option"]
       and msg_dict[@"payload"][@"tool_option_value"]
       and msg_dict[@"payload"][@"play_task"]) {
        
        NSDictionary *toolUpdateJson = @{
                                         @"message_type": @"tool_update",
                                         @"session_id": self.session_id,
                                         @"show_overlay": @true,
                                         @"tool_id": msg_dict[@"payload"][@"tool"],
                                         @"tool_options": @[
                                                 @{
                                                     @"name": msg_dict[@"payload"][@"tool_option"],
                                                     @"value": msg_dict[@"payload"][@"tool_option_value"]
                                                     }],
                                         @"play_task" : msg_dict[@"payload"][@"play_task"]
                                         };
        NSError *err = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:toolUpdateJson options:NSJSONWritingPrettyPrinted error:&err];
        
        if (err == nil) {
            [self.socket send:jsonData];
        }
    } else {
        NSDictionary *template_toolUpdateMsgDict = @{
                                                     @"message_type" : @"tool_update",
                                                     @"payload" :  @{
                                                             @"play_task" : @"",
                                                             @"tool" : @"some tool name <Ex:brush>",
                                                             @"tool_option" : @"tool option <Ex:size>",
                                                             @"tool_option_value" : @"<option value:@43>",
                                                             }
                                                     };
        
        NSString *errStr = [NSString stringWithFormat:@"Incorrect info sent, tool_update message should look like %@",[template_toolUpdateMsgDict description]];
        
        [self.delegate handleCraftEvent:errStr];
    }
}

-(void) handleToolChange:(NSDictionary *)msg_dict {
    if(msg_dict[@"payload"][@"tool"]) {
        
        NSDictionary *toolChangeJson = @{
                                         @"message_type": @"tool_change",
                                         @"session_id": self.session_id,
                                         @"tool_id": msg_dict[@"payload"][@"tool"],
                                         @"reset_options": @NO
                                        };
        NSError *err = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:toolChangeJson options:NSJSONWritingPrettyPrinted error:&err];
        
        if (err == nil) {
            [self.socket send:jsonData];
        }
    } else {
        NSDictionary *template_toolUpdateMsgDict = @{
                                                     @"message_type" : @"tool_change",
                                                     @"payload" :  @{
                                                             @"tool" : @"some tool name <Ex:brush>",
                                                        }
                                                     };
        
        NSString *errStr = [NSString stringWithFormat:@"Incorrect info sent, tool_change message should look like %@",[template_toolUpdateMsgDict description]];
        
        [self.delegate handleCraftEvent:errStr];
    }
}

-(void) sendMessage:(NSDictionary *)msg_dict {
    if (msg_dict[@"message_type"] && msg_dict[@"payload"]) {
        if ([msg_dict[@"message_type"] isEqualToString:@"tool_update"]) {
            [self handleToolUpdate:msg_dict];
        }
        if ([msg_dict[@"message_type"] isEqualToString:@"tool_change"]) {
            [self handleToolChange:msg_dict];
        }
    }
}

-(void) disconnect {
    [self.socket close];
    self.socket = nil;
}
@end

